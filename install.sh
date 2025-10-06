#!/bin/bash
echo "[Intel-Xe-GPU] Installing plugin..."

PLUGIN_DIR="/boot/config/plugins/intel-xe-gpu-top"
mkdir -p /usr/local/emhttp/plugins/intel-xe-gpu-top/include
mkdir -p /usr/local/emhttp/plugins/intel-xe-gpu-top
mkdir -p /etc/rc.d
mkdir -p /usr/local/sbin

# Copy files
cp "$PLUGIN_DIR/bin/intel_xe_collector.py" /usr/local/sbin/
cp "$PLUGIN_DIR/webGui/IntelXeGpu.page" /usr/local/emhttp/plugins/intel-xe-gpu-top/
cp "$PLUGIN_DIR/webGui/include/IntelXeGpu.json.php" /usr/local/emhttp/plugins/intel-xe-gpu-top/include/
cp "$PLUGIN_DIR/etc/rc.d/S99intel-xe-gpu-top" /etc/rc.d/

chmod +x /usr/local/sbin/intel_xe_collector.py
chmod +x /etc/rc.d/S99intel-xe-gpu-top

# Start service
/etc/rc.d/S99intel-xe-gpu-top start
echo "[Intel-Xe-GPU] Installation complete."
