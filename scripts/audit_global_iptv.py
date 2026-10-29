#!/usr/bin/env python3
"""
Global IPTV Stream Auditor & Merger
Scans all 188+ countries from iptv-org (12,800+ channels) with deep segment probing.
Merges only confirmed working live streams into dhanytv_live.m3u and assets.
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
from collections import defaultdict, Counter

from audit_streams import parse_m3u, test_stream_deep, DEFAULT_UA, ctx

def run_global_audit(workers=100, timeout=4.0):
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    source_path = "/tmp/iptv_org_all.m3u"
    current_live_path = os.path.join(base_dir, "dhanytv_live.m3u")
    current_live_ott_path = os.path.join(base_dir, "dhanytv_live_ott.m3u")
    report_path = os.path.join(base_dir, "artifacts", "global_live_report.json")

    print(f"=== Starting Global IPTV Audit across all countries ===")
    print(f"Source: {source_path}")
    print(f"Workers: {workers} | Per-stream timeout: {timeout}s")

    # 1. Load existing live channels
    existing_headers, existing_channels = parse_m3u(current_live_path)
    existing_urls = {c["url"].strip(): c for c in existing_channels}
    print(f"Existing verified channels: {len(existing_channels)}")

    # 2. Load dead URLs to skip network calls
    dead_urls = set()
    dead_file = os.path.join(base_dir, "lib", "services", "dead_streams.dart")
    if os.path.exists(dead_file):
        with open(dead_file, "r") as df:
            for l in df:
                m = re.search(r"'(https?://[^']+)'", l)
                if m:
                    dead_urls.add(m.group(1).strip())
    print(f"Loaded {len(dead_urls)} known dead URLs to auto-skip.")

    # 3. Parse global playlist
    all_headers, all_channels = parse_m3u(source_path)
    total = len(all_channels)
    print(f"Parsed {total} total channels from iptv-org index.country.m3u.")

    # Deduplicate candidates within global list and against existing
    candidates_to_test = []
    seen_urls = set(existing_urls.keys())

    for ch in all_channels:
        u = ch["url"].strip()
        if u in dead_urls:
            continue
        if u in seen_urls:
            continue
        seen_urls.add(u)
        candidates_to_test.append(ch)

    print(f"New unique candidate streams to test: {len(candidates_to_test)}")

    live_results = list(existing_channels)  # start with existing verified
    dead_count = len(dead_urls)
    completed = 0
    start_t = time.time()

    def probe_wrapper(ch):
        return ch, test_stream_deep(ch, timeout=timeout)

    print(f"Launching thread pool with {workers} workers...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        future_map = {executor.submit(probe_wrapper, ch): ch for ch in candidates_to_test}
        for future in concurrent.futures.as_completed(future_map):
            completed += 1
            ch, (is_live, reason, latency, code) = future.result()
            if is_live:
                ch["is_live"] = True
                ch["latency_sec"] = latency
                ch["live_reason"] = reason
                live_results.append(ch)
            else:
                dead_count += 1

            if completed % 500 == 0 or completed == len(candidates_to_test):
                elapsed = time.time() - start_t
                rate = completed / elapsed if elapsed > 0 else 0
                pct = (completed / len(candidates_to_test)) * 100
                rem = (len(candidates_to_test) - completed) / rate if rate > 0 else 0
                print(f"[{completed}/{len(candidates_to_test)} ({pct:.1f}%)] Live: {len(live_results)} | Dead: {dead_count} | {rate:.1f} ch/s | Rem: {rem/60:.1f}m")

    total_time = round(time.time() - start_t, 1)
    print(f"\nAudit completed in {total_time}s ({total_time/60:.1f} minutes)!")
    print(f"Total verified live channels: {len(live_results)}")

    # Sort channels by group then name
    live_results.sort(key=lambda c: (c["group"], c["name"]))

    # Write dhanytv_live.m3u
    print(f"Writing {current_live_path}...")
    with open(current_live_path, "w", encoding="utf-8") as f:
        for h in existing_headers:
            f.write(h + "\n")
        f.write("\n")
        for c in live_results:
            for l in c["raw_lines"]:
                f.write(l)
            f.write("\n")

    # Write dhanytv_live_ott.m3u (HLS non-DRM)
    ott_channels = [c for c in live_results if not c.get("license_type") and not c.get("license_key") and not c["url"].endswith(".mpd")]
    print(f"Writing {current_live_ott_path} ({len(ott_channels)} OTT channels)...")
    with open(current_live_ott_path, "w", encoding="utf-8") as f:
        for h in existing_headers:
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

    # Generate country summary
    country_counts = Counter(c["group"] for c in live_results)
    summary = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_live_channels": len(live_results),
        "total_ott_channels": len(ott_channels),
        "total_countries": len(country_counts),
        "duration_seconds": total_time,
        "top_countries": dict(country_counts.most_common(50))
    }
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    print(f"Summary saved to {report_path}")
    print(f"Top countries:")
    for country, count in country_counts.most_common(15):
        print(f"  * {country}: {count} live channels")

if __name__ == "__main__":
    run_global_audit(workers=90, timeout=3.5)
