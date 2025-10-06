#!/usr/bin/env python3
"""
Collector for Intel Xe (Battlemage) GPUs that probes kernel sysfs entries (DRM + hwmon)
instead of using intel_gpu_top. Returns a JSON array of detected DRM cards and available metrics.

This is best-effort: different kernels/drivers expose different attributes. The collector
will populate `temperatures`, `powers`, and `fans` maps when hwmon exposes them. If no
data is available for a card, an `error` field will explain.
"""

import os
import time
import json
import threading
import http.server
import socketserver
import argparse
import sys
from pathlib import Path
import glob

SYSFS_DRM = Path("/sys/class/drm")


def _read_text(path: Path):
    try:
        return path.read_text().strip()
    except Exception:
        return None


def _normalize_temp(value: int):
    # Some kernel entries report millidegrees (e.g. 42000) or degrees (42)
    try:
        v = int(value)
    except Exception:
        return None
    if v > 1000:
        return v / 1000.0
    return float(v)


def parse_hwmon(hwmon_path: Path):
    metrics = {"temperatures": {}, "powers": {}, "fans": {}}
    # temperature inputs
    for temp in hwmon_path.glob("temp*_input"):
        name_file = temp.with_name(temp.name.replace("_input", "_label"))
        label = _read_text(name_file) or temp.stem
        val = _read_text(temp)
        if val is None:
            continue
        t = _normalize_temp(val)
        if t is not None:
            metrics["temperatures"][label] = t

    # power inputs
    for p in hwmon_path.glob("power*_input"):
        label_file = p.with_name(p.name.replace("_input", "_label"))
        label = _read_text(label_file) or p.stem
        val = _read_text(p)
        if val is None:
            continue
        try:
            pv = int(val)
            # many hwmon power values are in microwatts; convert to watts if large
            if pv > 1_000_000:
                metrics["powers"][label] = pv / 1_000_000.0
            elif pv > 1000:
                metrics["powers"][label] = pv / 1000.0
            else:
                metrics["powers"][label] = float(pv)
        except Exception:
            continue

    # fan inputs
    for f in hwmon_path.glob("fan*_input"):
        label_file = f.with_name(f.name.replace("_input", "_label"))
        label = _read_text(label_file) or f.stem
        val = _read_text(f)
        if val is None:
            continue
        try:
            metrics["fans"][label] = int(val)
        except Exception:
            continue

    return metrics


def probe_card(card_path: Path):
    card = {"name": card_path.name, "timestamp": time.time()}
    device_link = card_path / "device"
    if not device_link.exists():
        card["error"] = "no device link"
        return card

    try:
        pci_dev = Path(os.path.realpath(device_link))
    except Exception as e:
        card["error"] = f"failed to resolve device: {e}"
        return card

    card["pci_path"] = str(pci_dev)
    vendor = _read_text(pci_dev / "vendor")
    device = _read_text(pci_dev / "device")
    driver = None
    drv_link = pci_dev / "driver"
    if drv_link.exists():
        try:
            driver = os.path.basename(os.path.realpath(drv_link))
        except Exception:
            driver = None

    if vendor:
        card["vendor"] = vendor
    if device:
        card["device_id"] = device
    if driver:
        card["driver"] = driver

    found_any = False
    card_metrics = {"temperatures": {}, "powers": {}, "fans": {}}

    # look for hwmon under the PCI device
    hwmon_glob = list(pci_dev.glob("hwmon/hwmon*"))
    for hw in hwmon_glob:
        try:
            parsed = parse_hwmon(hw)
            # merge parsed maps
            for k in ("temperatures", "powers", "fans"):
                card_metrics[k].update(parsed.get(k, {}))
            found_any = True
        except Exception:
            continue

    # Some drivers expose hwmon one level up
    parent_hwmon = list(pci_dev.glob("../*/hwmon/hwmon*"))
    for hw in parent_hwmon:
        try:
            parsed = parse_hwmon(hw)
            for k in ("temperatures", "powers", "fans"):
                card_metrics[k].update(parsed.get(k, {}))
            found_any = True
        except Exception:
            continue

    card.update(card_metrics)

    if not found_any:
        # try scanning all hwmon entries and match by device symlink if possible
        hwmons = [Path(p) for p in glob.glob('/sys/class/hwmon/hwmon*')]
        for hw in hwmons:
            name = _read_text(hw / 'name')
            # best-effort: include hwmon entries that mention 'gpu' or 'intel' in the name
            if name and ('gpu' in name.lower() or 'intel' in name.lower() or 'i915' in name.lower()):
                try:
                    parsed = parse_hwmon(hw)
                    for k in ("temperatures", "powers", "fans"):
                        card_metrics[k].update(parsed.get(k, {}))
                    found_any = True
                except Exception:
                    continue
        card.update(card_metrics)

    if not found_any:
        card["error"] = "no hwmon metrics found; kernel/driver may not expose sensors"

    return card


def get_gpu_metrics():
    results = {"timestamp": time.time(), "cards": []}
    if not SYSFS_DRM.exists():
        results["error"] = "/sys/class/drm not present"
        return results

    cards = sorted(SYSFS_DRM.glob('card*'))
    for c in cards:
        # only consider primary cards (cardX) not renderD or controlD
        if c.name.startswith('card') and not c.name.startswith('card'):
            continue
        # skip entries like controlDxxx which aren't cards
        if 'render' in c.name or 'control' in c.name:
            continue
        try:
            card_metrics = probe_card(c)
            results["cards"].append(card_metrics)
        except Exception as e:
            results["cards"].append({"name": c.name, "error": str(e)})

    if not results["cards"]:
        results["error"] = "no drm cards found"

    return results


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            m = get_gpu_metrics()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(m, indent=2).encode())
        elif self.path == "/health":
            data = get_gpu_metrics()
            ok = True
            if data.get("error"):
                ok = False
            else:
                # healthy if at least one card without an error field
                ok = any('error' not in c for c in data.get('cards', []))
            self.send_response(200 if ok else 503)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": ok}).encode())
        else:
            self.send_response(404)
            self.end_headers()


def run_server(port):
    with socketserver.TCPServer(("", port), Handler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=9200)
    parser.add_argument("--daemon", action="store_true")
    args = parser.parse_args()

    if args.daemon:
        t = threading.Thread(target=run_server, args=(args.port,), daemon=True)
        t.start()
        try:
            while True:
                time.sleep(10)
        except KeyboardInterrupt:
            sys.exit(0)
    else:
        print(json.dumps(get_gpu_metrics(), indent=2))