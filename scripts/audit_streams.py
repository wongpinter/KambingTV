#!/usr/bin/env python3
"""
DhanyTV IPTV Stream Auditor & Live Playlist Generator
Deep verifies manifests, HLS variant playlists, and actual media chunks (.ts/.m4s).
Generates dhanytv_live.m3u, dhanytv_live_ott.m3u, and live_audit_report.json.
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

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

DEFAULT_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

def parse_m3u(file_path_or_url):
    if file_path_or_url.startswith("http://") or file_path_or_url.startswith("https://"):
        req = urllib.request.Request(file_path_or_url, headers={"User-Agent": DEFAULT_UA})
        with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
            content = resp.read().decode("utf-8", errors="ignore")
        lines = content.splitlines(keepends=True)
    else:
        with open(file_path_or_url, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()

    header_lines = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("#EXTM3U"):
            header_lines.append(line)
            i += 1
            break
        i += 1

    channels = []
    curr_directives = []
    for line in lines[i:]:
        s = line.strip()
        if not s:
            continue
        if s.startswith("#"):
            curr_directives.append(line)
        else:
            url = s
            extinf = ""
            name = "Unknown"
            group = "Other"
            logo = ""
            tvg_id = ""
            headers = {}
            license_type = None
            license_key = None

            for d in curr_directives:
                ds = d.strip()
                if ds.startswith("#EXTINF:"):
                    extinf = ds
                    if "," in ds:
                        name = ds.split(",", 1)[1].strip()
                    m_grp = re.search(r'group-title="([^"]+)"', ds)
                    if m_grp:
                        group = m_grp.group(1).strip()
                    m_logo = re.search(r'tvg-logo="([^"]+)"', ds)
                    if m_logo:
                        logo = m_logo.group(1).strip()
                    m_id = re.search(r'tvg-id="([^"]+)"', ds)
                    if m_id:
                        tvg_id = m_id.group(1).strip()
                elif ds.startswith("#EXTHTTP:"):
                    try:
                        hdr = json.loads(ds[len("#EXTHTTP:"):])
                        if isinstance(hdr, dict):
                            headers.update(hdr)
                    except Exception:
                        pass
                elif ds.startswith("#EXTVLCOPT:"):
                    opt = ds[len("#EXTVLCOPT:"):]
                    if "=" in opt:
                        k, v = opt.split("=", 1)
                        k = k.lower().strip()
                        v = v.strip()
                        if k in ("http-user-agent", "user-agent"):
                            headers["User-Agent"] = v
                        elif k in ("http-referrer", "http-referer", "referrer", "referer"):
                            headers["Referer"] = v
                        elif k in ("http-origin", "origin"):
                            headers["Origin"] = v
                elif ds.startswith("#KODIPROP:"):
                    prop = ds[len("#KODIPROP:"):]
                    if "=" in prop:
                        k, v = prop.split("=", 1)
                        kl = k.lower().strip()
                        if "stream_headers" in kl:
                            for part in v.split("|"):
                                if "=" in part:
                                    hk, hv = part.split("=", 1)
                                    headers[hk.strip()] = hv.strip()
                        elif kl.endswith(".license_type"):
                            license_type = v.strip()
                        elif kl.endswith(".license_key"):
                            license_key = v.strip()

            channels.append({
                "raw_lines": curr_directives + [url + "\n"],
                "directives": curr_directives,
                "url": url,
                "extinf": extinf,
                "name": name,
                "group": group,
                "logo": logo,
                "tvg_id": tvg_id,
                "headers": headers,
                "license_type": license_type,
                "license_key": license_key
            })
            curr_directives = []

    return header_lines, channels

def test_stream_deep(ch, timeout=6):
    url = ch["url"]
    req_headers = {"User-Agent": DEFAULT_UA}
    if ch["headers"]:
        for k, v in ch["headers"].items():
            req_headers[k] = str(v)

    req = urllib.request.Request(url, headers=req_headers)
    start_t = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            status_code = resp.status
            content_type = resp.headers.get("Content-Type", "").lower()
            data = resp.read(8192)
            text = data.decode("utf-8", errors="ignore").strip()

            # 1. HLS Check with chunk probing
            if "#EXTM3U" in text:
                media_manifest_url = url
                media_text = text

                # Master playlist: resolve first valid variant
                if "#EXT-X-STREAM-INF" in text:
                    variants = []
                    for l in text.splitlines():
                        l = l.strip()
                        if l and not l.startswith("#"):
                            variants.append(urljoin(url, l))
                            if len(variants) >= 3:
                                break

                    variant_loaded = False
                    for vurl in variants:
                        try:
                            vreq = urllib.request.Request(vurl, headers=req_headers)
                            with urllib.request.urlopen(vreq, timeout=timeout, context=ctx) as vresp:
                                media_text = vresp.read(8192).decode("utf-8", errors="ignore")
                                media_manifest_url = vurl
                                variant_loaded = True
                                break
                        except Exception:
                            continue

                    if not variant_loaded:
                        elapsed = round(time.time() - start_t, 2)
                        return False, "Master playlist variant failed", elapsed, status_code

                # Probe first media chunk
                chunk_url = None
                for l in media_text.splitlines():
                    l = l.strip()
                    if l and not l.startswith("#"):
                        chunk_url = urljoin(media_manifest_url, l)
                        break

                if chunk_url:
                    try:
                        chunk_headers = dict(req_headers)
                        chunk_headers["Range"] = "bytes=0-1024"
                        creq = urllib.request.Request(chunk_url, headers=chunk_headers)
                        with urllib.request.urlopen(creq, timeout=timeout, context=ctx) as cresp:
                            cdata = cresp.read(512)
                            ctext = cdata.decode("utf-8", errors="ignore")
                            if "<html" in ctext.lower() or "<!doctype html" in ctext.lower():
                                elapsed = round(time.time() - start_t, 2)
                                return False, "Segment returned HTML error", elapsed, cresp.status
                            elapsed = round(time.time() - start_t, 2)
                            return True, f"HLS Playable (chunk verified, {len(cdata)}B)", elapsed, status_code
                    except urllib.error.HTTPError as ce:
                        elapsed = round(time.time() - start_t, 2)
                        return False, f"HLS manifest OK but chunk HTTP {ce.code}", elapsed, ce.code
                    except Exception as ce:
                        elapsed = round(time.time() - start_t, 2)
                        return False, f"HLS manifest OK but chunk failed ({ce})", elapsed, 0

                elapsed = round(time.time() - start_t, 2)
                return True, "HLS Media Playlist (no chunk probe)", elapsed, status_code

            # 2. DASH MPD Check
            if "<MPD" in text or "<mpd" in text or "urn:mpeg:dash:schema" in text:
                elapsed = round(time.time() - start_t, 2)
                return True, "DASH MPD Manifest", elapsed, status_code

            # 3. Direct video/audio/octet-stream
            if any(vt in content_type for vt in ["video", "audio", "octet-stream"]) or len(data) > 0:
                if "<html" in text.lower() or "<!doctype html" in text.lower():
                    m = re.search(r"<title>([^<]+)</title>", text, re.IGNORECASE)
                    title = m.group(1).strip() if m else "HTML error page"
                    elapsed = round(time.time() - start_t, 2)
                    return False, f"HTML returned ({title})", elapsed, status_code
                elapsed = round(time.time() - start_t, 2)
                return True, f"Direct Media ({content_type or 'binary'})", elapsed, status_code

            elapsed = round(time.time() - start_t, 2)
            return False, f"Unrecognized body ({content_type})", elapsed, status_code

    except urllib.error.HTTPError as e:
        elapsed = round(time.time() - start_t, 2)
        return False, f"HTTP Error {e.code}: {e.reason}", elapsed, e.code
    except urllib.error.URLError as e:
        elapsed = round(time.time() - start_t, 2)
        reason_str = str(e.reason)
        if "timed out" in reason_str.lower():
            reason_str = "Connection timed out"
        elif "connection refused" in reason_str.lower():
            reason_str = "Connection refused"
        elif "name or service not known" in reason_str.lower() or "nodename" in reason_str.lower():
            reason_str = "DNS resolution failed"
        return False, f"URLError: {reason_str}", elapsed, 0
    except TimeoutError:
        elapsed = round(time.time() - start_t, 2)
        return False, "Connection timed out", elapsed, 0
    except Exception as e:
        elapsed = round(time.time() - start_t, 2)
        return False, f"Error: {e}", elapsed, 0

def run_audit(source_path, ott_path, out_live_path, out_live_ott_path, out_report_path, max_workers=30):
    print("=== Starting DhanyTV Deep Stream Audit ===")
    print(f"Source: {source_path}")
    print(f"OTT: {ott_path}")

    main_headers, channels = parse_m3u(source_path)
    ott_headers, ott_channels = parse_m3u(ott_path)
    ott_urls = set(c["url"] for c in ott_channels)

    total = len(channels)
    print(f"Parsed {total} total channels ({len(ott_channels)} OTT).")
    print(f"Testing manifests AND media segments with {max_workers} worker threads...")

    results = []
    live_channels = []
    dead_channels = []
    completed = 0
    start_all = time.time()

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_map = {executor.submit(test_stream_deep, ch): ch for ch in channels}
        for future in concurrent.futures.as_completed(future_map):
            ch = future_map[future]
            completed += 1
            is_live, reason, latency, code = future.result()
            res_item = {
                "name": ch["name"],
                "group": ch["group"],
                "url": ch["url"],
                "logo": ch["logo"],
                "tvg_id": ch["tvg_id"],
                "is_live": is_live,
                "reason": reason,
                "latency_sec": latency,
                "status_code": code,
                "has_drm": bool(ch["license_type"] or ch["license_key"]),
                "drm_type": ch["license_type"],
                "is_ott": ch["url"] in ott_urls,
                "raw_lines": ch["raw_lines"]
            }
            results.append(res_item)
            if is_live:
                live_channels.append(res_item)
            else:
                dead_channels.append(res_item)

            if completed % 50 == 0 or completed == total:
                pct = (completed / total) * 100
                print(f"[{completed}/{total} ({pct:.1f}%)] Live: {len(live_channels)}, Dead: {len(dead_channels)}, Elapsed: {time.time()-start_all:.1f}s")

    total_time = round(time.time() - start_all, 1)
    print(f"\nAudit completed in {total_time}s!")
    print(f"Total: {total} | Truly Playable Live: {len(live_channels)} ({len(live_channels)/total*100:.1f}%) | Dead: {len(dead_channels)} ({len(dead_channels)/total*100:.1f}%)")

    url_order = {ch["url"]: idx for idx, ch in enumerate(channels)}
    live_channels.sort(key=lambda x: url_order.get(x["url"], 99999))
    dead_channels.sort(key=lambda x: url_order.get(x["url"], 99999))

    # Output live files
    os.makedirs(os.path.dirname(os.path.abspath(out_live_path)), exist_ok=True)
    with open(out_live_path, "w", encoding="utf-8") as f:
        for h in main_headers:
            f.write(h + "\n")
        f.write("\n")
        for item in live_channels:
            for l in item["raw_lines"]:
                f.write(l)
            f.write("\n")

    ott_live_channels = [item for item in live_channels if item["is_ott"]]
    with open(out_live_ott_path, "w", encoding="utf-8") as f:
        for h in ott_headers:
            f.write(h + "\n")
        f.write("\n")
        for item in ott_live_channels:
            for l in item["raw_lines"]:
                f.write(l)
            f.write("\n")

    group_stats = defaultdict(lambda: {"total": 0, "live": 0, "dead": 0})
    for r in results:
        g = r["group"]
        group_stats[g]["total"] += 1
        if r["is_live"]:
            group_stats[g]["live"] += 1
        else:
            group_stats[g]["dead"] += 1

    reasons_counter = Counter()
    for d in dead_channels:
        r = d["reason"]
        if "HTTP Error 403" in r:
            reasons_counter["HTTP 403 (Forbidden / Token Expired)"] += 1
        elif "HTTP Error 404" in r:
            reasons_counter["HTTP 404 (Not Found / Stream Removed)"] += 1
        elif "chunk HTTP 404" in r:
            reasons_counter["Ghost Manifest (Segments 404)"] += 1
        elif "HTTP Error 451" in r:
            reasons_counter["HTTP 451 (Legal Reasons / Blocked)"] += 1
        elif "HTTP Error 5" in r:
            reasons_counter["HTTP 5xx (Server Error)"] += 1
        elif "timed out" in r.lower():
            reasons_counter["Connection Timed Out"] += 1
        elif "refused" in r.lower():
            reasons_counter["Connection Refused"] += 1
        elif "dns" in r.lower() or "name or service not known" in r.lower():
            reasons_counter["DNS Resolution Error"] += 1
        elif "html" in r.lower():
            reasons_counter["Returned HTML Error Page"] += 1
        else:
            reasons_counter[r[:40]] += 1

    audit_summary = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_channels": total,
        "live_count": len(live_channels),
        "live_percentage": round(len(live_channels)/total*100, 1),
        "dead_count": len(dead_channels),
        "dead_percentage": round(len(dead_channels)/total*100, 1),
        "ott_live_count": len(ott_live_channels),
        "duration_seconds": total_time,
        "failure_reasons": dict(reasons_counter.most_common(12)),
        "groups": {g: s for g, s in sorted(group_stats.items(), key=lambda x: -x[1]["live"])},
        "live_channels": [
            {
                "name": c["name"],
                "group": c["group"],
                "url": c["url"],
                "reason": c["reason"],
                "latency_sec": c["latency_sec"],
                "has_drm": c["has_drm"],
                "is_ott": c["is_ott"]
            }
            for c in live_channels
        ],
        "dead_channels": [
            {
                "name": c["name"],
                "group": c["group"],
                "url": c["url"],
                "reason": c["reason"],
                "latency_sec": c["latency_sec"]
            }
            for c in dead_channels
        ]
    }

    os.makedirs(os.path.dirname(os.path.abspath(out_report_path)), exist_ok=True)
    with open(out_report_path, "w", encoding="utf-8") as f:
        json.dump(audit_summary, f, indent=2)

    print(f"Generated {out_live_path} ({len(live_channels)} channels)")
    print(f"Generated {out_live_ott_path} ({len(ott_live_channels)} channels)")
    print(f"Generated {out_report_path}")

if __name__ == "__main__":
    src = "/tmp/dhanytv.m3u"
    ott = "/tmp/dhanytv-ott.m3u"
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_live = os.path.join(base, "dhanytv_live.m3u")
    out_live_ott = os.path.join(base, "dhanytv_live_ott.m3u")
    out_rep = os.path.join(base, "artifacts", "live_audit_report.json")
    run_audit(src, ott, out_live, out_live_ott, out_rep)
