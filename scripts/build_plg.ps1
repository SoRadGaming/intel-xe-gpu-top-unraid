Param()

# Build .plg on Windows (PowerShell). Requires tar available (Windows 10+ has tar via bsdtar)
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$out = Join-Path $root "intel-xe-gpu-top.plg"
$tmp = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp | Out-Null

Write-Host "Building .plg into $out using temp $tmp"

New-Item -ItemType Directory -Path (Join-Path $tmp 'boot\config\plugins\intel-xe-gpu-top') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmp 'usr\local\emhttp\plugins\intel-xe-gpu-top\include') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmp 'usr\local\sbin') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmp 'etc\rc.d') -Force | Out-Null

Copy-Item -Path (Join-Path $root 'install.sh') -Destination (Join-Path $tmp 'boot\config\plugins\intel-xe-gpu-top\install.sh') -Force
Copy-Item -Path (Join-Path $root 'remove.sh') -Destination (Join-Path $tmp 'boot\config\plugins\intel-xe-gpu-top\remove.sh') -Force
Copy-Item -Path (Join-Path $root 'webGui\IntelXeGpu.page') -Destination (Join-Path $tmp 'usr\local\emhttp\plugins\intel-xe-gpu-top\IntelXeGpu.page') -Force
Copy-Item -Path (Join-Path $root 'webGui\include\IntelXeGpu.json.php') -Destination (Join-Path $tmp 'usr\local\emhttp\plugins\intel-xe-gpu-top\include\IntelXeGpu.json.php') -Force
Copy-Item -Path (Join-Path $root 'bin\intel_xe_collector.py') -Destination (Join-Path $tmp 'usr\local\sbin\intel_xe_collector.py') -Force
Copy-Item -Path (Join-Path $root 'etc\rc.d\S99intel-xe-gpu-top') -Destination (Join-Path $tmp 'etc\rc.d\S99intel-xe-gpu-top') -Force
Copy-Item -Path (Join-Path $root 'intel-xe-gpu-top.plg') -Destination (Join-Path $tmp 'intel-xe-gpu-top.plg') -Force

# Create tar.gz using system tar
Push-Location $tmp
tar -czf $out .
Pop-Location

Write-Host "Built: $out"
