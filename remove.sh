#!/bin/bash
echo "[Intel-Xe-GPU] Removing plugin..."

systemctl stop intel-xe-gpu-top 2>/dev/null || true
rm -f /usr/local/sbin/intel_xe_collector.py
rm -rf /usr/local/emhttp/plugins/intel-xe-gpu-top
rm -f /etc/rc.d/S99intel-xe-gpu-top
echo "[Intel-Xe-GPU] Removed."
