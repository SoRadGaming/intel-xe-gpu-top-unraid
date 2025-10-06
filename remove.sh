#!/bin/bash
echo "[Intel-Xe-GPU] Removing plugin..."

if [ -x /etc/rc.d/S99intel-xe-gpu-top ]; then
  /etc/rc.d/S99intel-xe-gpu-top stop || true
fi

rm -f /usr/local/sbin/intel_xe_collector.py
rm -f /etc/rc.d/S99intel-xe-gpu-top
rm -rf /usr/local/emhttp/plugins/intel-xe-gpu-top

echo "[Intel-Xe-GPU] Removal complete."
#!/bin/bash
echo "[Intel-Xe-GPU] Removing plugin..."

systemctl stop intel-xe-gpu-top 2>/dev/null || true
rm -f /usr/local/sbin/intel_xe_collector.py
rm -rf /usr/local/emhttp/plugins/intel-xe-gpu-top
rm -f /etc/rc.d/S99intel-xe-gpu-top
echo "[Intel-Xe-GPU] Removed."
