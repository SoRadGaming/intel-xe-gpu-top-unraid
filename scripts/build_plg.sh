#!/usr/bin/env bash
set -euo pipefail

# Build an Unraid .plg archive from the repository files. Run this on Linux/WSL/Unraid host.
# Output: intel-xe-gpu-top.plg in the repository root.

ROOT_DIR="$(pwd)"
mkdir -p "$ROOT_DIR/release"
OUT="$ROOT_DIR/release/intel-xe-gpu-top.plg"
TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "Building .plg into $OUT using temporary dir $TMPDIR"

mkdir -p "$TMPDIR/boot/config/plugins/intel-xe-gpu-top"
mkdir -p "$TMPDIR/usr/local/emhttp/plugins/intel-xe-gpu-top/include"
mkdir -p "$TMPDIR/usr/local/emhttp/plugins/intel-xe-gpu-top"
mkdir -p "$TMPDIR/usr/local/sbin"
mkdir -p "$TMPDIR/etc/rc.d"

cp "${ROOT_DIR}/install.sh" "$TMPDIR/boot/config/plugins/intel-xe-gpu-top/install.sh"
cp "${ROOT_DIR}/remove.sh" "$TMPDIR/boot/config/plugins/intel-xe-gpu-top/remove.sh"
cp "${ROOT_DIR}/webGui/IntelXeGpu.page" "$TMPDIR/usr/local/emhttp/plugins/intel-xe-gpu-top/IntelXeGpu.page"
cp "${ROOT_DIR}/webGui/include/IntelXeGpu.json.php" "$TMPDIR/usr/local/emhttp/plugins/intel-xe-gpu-top/include/IntelXeGpu.json.php"
cp "${ROOT_DIR}/bin/intel_xe_collector.py" "$TMPDIR/usr/local/sbin/intel_xe_collector.py"
cp "${ROOT_DIR}/etc/rc.d/S99intel-xe-gpu-top" "$TMPDIR/etc/rc.d/S99intel-xe-gpu-top"

# include the manifest at the root of the archive
cp "${ROOT_DIR}/intel-xe-gpu-top.plg" "$TMPDIR/intel-xe-gpu-top.plg"

# set expected permissions
chmod 755 "$TMPDIR/boot/config/plugins/intel-xe-gpu-top/install.sh" || true
chmod 755 "$TMPDIR/boot/config/plugins/intel-xe-gpu-top/remove.sh" || true
chmod 755 "$TMPDIR/usr/local/sbin/intel_xe_collector.py" || true
chmod 755 "$TMPDIR/etc/rc.d/S99intel-xe-gpu-top" || true

(cd "$TMPDIR" && tar -czf "$OUT" .)

echo "Built: $OUT"
echo "Copy $OUT to your Unraid server and install via the web UI or enable the plugin via the Apps tab."
