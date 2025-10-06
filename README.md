# intel-xe-gpu-top Unraid plugin

This plugin collects metrics from Intel Xe (Battlemage) GPUs by probing kernel sysfs (DRM + hwmon). It does not rely on `intel_gpu_top` and instead reads sensor attributes exported by the kernel driver.

Files of interest:
- `install.sh` — plugin installer (copies files to Unraid paths and starts service)
- `remove.sh` — plugin remover (stops service and removes files)
- `bin/intel_xe_collector.py` — Python collector that probes `/sys/class/drm` and `/sys/class/hwmon`
- `etc/rc.d/S99intel-xe-gpu-top` — init script to start/stop the collector
- `webGui/IntelXeGpu.page` — Unraid web GUI page
- `webGui/include/IntelXeGpu.json.php` — PHP wrapper that proxies to the local collector

Quick install (run on Unraid host as root):

```bash
# Copy plugin directory to /boot/config/plugins/intel-xe-gpu-top
cd /boot/config/plugins/intel-xe-gpu-top
./install.sh
```

Quick test (on Unraid host):

```bash
# check health
curl -sS http://127.0.0.1:9200/health
# get metrics
curl -sS http://127.0.0.1:9200/metrics | jq
```

Uninstall:

```bash
cd /boot/config/plugins/intel-xe-gpu-top
./remove.sh
```

Notes on kernel interfaces and permissions:
- The collector probes `/sys/class/drm/card*/device` and `/sys/class/hwmon/hwmon*` for sensor attributes. Your Unraid kernel/drivers must expose hwmon entries for the Battlemage GPUs.
- Typical paths read by the collector: `/sys/class/drm/cardX/device/hwmon/hwmonY/temp*_input`, `power*_input`, `fan*_input` and label files.
- If sensors are not exposed, the collector will return `error: "no hwmon metrics found; kernel/driver may not expose sensors"` for that card.
- Ensure the plugin runs as root (Unraid plugin scripts do) so it has permission to read sysfs.

Building the `.plg` package

Linux/WSL/Unraid (bash):

```bash
./scripts/build_plg.sh
# produces release/intel-xe-gpu-top.plg
```

Windows (PowerShell):

```powershell
.
\scripts\build_plg.ps1
# produces release\intel-xe-gpu-top.plg
```

Install the produced `.plg` via the Unraid web UI: Plugins → Install Plugin → Choose File and upload the `.plg` created above.

## View Metrics
- JSON: `http://tower:9200/metrics`
- GUI:  Dashboard → Intel Xe GPU

