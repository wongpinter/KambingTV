#!/usr/bin/env python3
"""
Merge verified live streams from iptv-org into DhanyTV live playlist.
Tests each candidate stream with deep chunk verification before inclusion.
"""

import os
import sys
import time
import json
import ssl
import re
from urllib.parse import urlparse, urljoin
import urllib.request
import urllib.error
import concurrent.futures

from audit_streams import parse_m3u, test_stream_deep, DEFAULT_UA, ctx

SOURCES = [
    {
        "url": "https://iptv-org.github.io/iptv/countries/id.m3u",
        "default_group": "Indonesia Channels",
        "name_suffix": " (iptv-org)",
        "country": "Indonesia"
    },
    {
        "url": "https://iptv-org.github.io/iptv/countries/sg.m3u",
        "default_group": "Singapore",
        "name_suffix": " (iptv-org)",
        "country": "Singapore"
    },
    {
        "url": "https://iptv-org.github.io/iptv/countries/my.m3u",
        "default_group": "Malaysia",
        "name_suffix": " (iptv-org)",
        "country": "Malaysia"
    }
]

def merge_sources():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    current_live_path = os.path.join(base_dir, "dhanytv_live.m3u")
    current_live_ott_path = os.path.join(base_dir, "dhanytv_live_ott.m3u")

    print(f"Loading current live playlist from {current_live_path}...")
    headers, existing_channels = parse_m3u(current_live_path)
    existing_urls = set(c["url"].strip() for c in existing_channels)
    print(f"Existing live channels: {len(existing_channels)}")

    # Load known dead stream URLs
    dead_urls = set()
    dead_file = os.path.join(base_dir, "lib", "services", "dead_streams.dart")
    if os.path.exists(dead_file):
        with open(dead_file, "r") as df:
            for l in df:
                m = re.search(r"'(https?://[^']+)'", l)
                if m:
                    dead_urls.add(m.group(1).strip())
    print(f"Loaded {len(dead_urls)} dead stream URLs to avoid.")

    existing_channels = [c for c in existing_channels if c["url"].strip() not in dead_urls]
    existing_urls = set(c["url"].strip() for c in existing_channels)
    print(f"Clean existing live channels: {len(existing_channels)}")

    new_verified_channels = []

    for src in SOURCES:
        src_url = src["url"]
        print(f"\nFetching source: {src_url}...")
        try:
            _, src_channels = parse_m3u(src_url)
            print(f"Parsed {len(src_channels)} channels from {src['country']}.")
        except Exception as e:
            print(f"Failed to fetch {src_url}: {e}")
            continue

        # Filter out existing and dead URLs
        candidates = [c for c in src_channels if c["url"].strip() not in existing_urls and c["url"].strip() not in dead_urls]
        print(f"New candidate streams: {len(candidates)}")

        print(f"Testing {len(candidates)} candidate streams with deep chunk verification...")
        live_for_source = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=25) as executor:
            future_map = {executor.submit(test_stream_deep, ch): ch for ch in candidates}
            for future in concurrent.futures.as_completed(future_map):
                ch = future_map[future]
                is_live, reason, latency, code = future.result()
                if is_live:
                    live_for_source.append((ch, reason, latency))
                    existing_urls.add(ch["url"].strip())

        print(f"Verified live from {src['country']}: {len(live_for_source)} / {len(candidates)}")

        for ch, reason, latency in live_for_source:
            # Normalize group
            original_extinf = ch["extinf"]
            target_group = src["default_group"]
            clean_name = ch["name"]

            # Format clean extinf line
            # Ensure group-title is set
            if 'group-title="' in original_extinf:
                new_extinf = re.sub(r'group-title="[^"]*"', f'group-title="{target_group}"', original_extinf)
            else:
                # Insert before channel name
                comma_idx = original_extinf.rfind(",")
                if comma_idx > 0:
                    new_extinf = f'{original_extinf[:comma_idx]} group-title="{target_group}",{original_extinf[comma_idx+1:]}'
                else:
                    new_extinf = f'{original_extinf} group-title="{target_group}"'

            # Reconstruct directives with updated EXTINF
            new_directives = []
            for d in ch["directives"]:
                if d.strip().startswith("#EXTINF:"):
                    new_directives.append(new_extinf + "\n")
                else:
                    new_directives.append(d)

            ch["raw_lines"] = new_directives + [ch["url"] + "\n"]
            ch["group"] = target_group
            ch["extinf"] = new_extinf
            new_verified_channels.append(ch)

    print(f"\nTotal new verified channels to add: {len(new_verified_channels)}")

    # Combine existing + new
    combined_channels = existing_channels + new_verified_channels
    print(f"Total merged live channels: {len(combined_channels)}")

    # Write merged files
    print(f"Writing {current_live_path}...")
    with open(current_live_path, "w", encoding="utf-8") as f:
        for h in headers:
            f.write(h + "\n")
        f.write("\n")
        for c in combined_channels:
            for l in c["raw_lines"]:
                f.write(l)
            f.write("\n")

    # Write OTT file (only HLS non-drm)
    ott_channels = [c for c in combined_channels if not c["license_type"] and not c["license_key"] and not c["url"].endswith(".mpd")]
    print(f"Writing {current_live_ott_path} ({len(ott_channels)} channels)...")
    with open(current_live_ott_path, "w", encoding="utf-8") as f:
        for h in headers:
            f.write(h + "\n")
        f.write("\n")
        for c in ott_channels:
            for l in c["raw_lines"]:
                f.write(l)
            f.write("\n")

    # Copy to assets/
    assets_live = os.path.join(base_dir, "assets", "dhanytv_live.m3u")
    assets_live_ott = os.path.join(base_dir, "assets", "dhanytv_live_ott.m3u")
    with open(assets_live, "w", encoding="utf-8") as f:
        with open(current_live_path, "r", encoding="utf-8") as src_f:
            f.write(src_f.read())
    with open(assets_live_ott, "w", encoding="utf-8") as f:
        with open(current_live_ott_path, "r", encoding="utf-8") as src_f:
            f.write(src_f.read())

    print(f"Copied updated playlists to {assets_live} and {assets_live_ott}.")
    return len(existing_channels), len(new_verified_channels), len(combined_channels)

if __name__ == "__main__":
    merge_sources()
