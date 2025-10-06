Param()

# Build .plg on Windows (PowerShell). Requires tar available (Windows 10+ has tar via bsdtar)
# $MyInvocation.MyCommand.Definition points to the script path (scripts\build_plg.ps1).
# Compute the repository root as the parent directory of the scripts folder.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = Split-Path -Parent $scriptDir
$releaseDir = Join-Path $root 'release'
if (-not (Test-Path $releaseDir)) { New-Item -ItemType Directory -Path $releaseDir | Out-Null }
$out = Join-Path $releaseDir "intel-xe-gpu-top.plg"
$tmp = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp | Out-Null

Write-Host "Building .plg into $out using temp $tmp"

# Preflight: ensure required source files exist in repo root
$required = @(
	'install.sh',
	'remove.sh',
	'webGui\IntelXeGpu.page',
	'webGui\include\IntelXeGpu.json.php',
	'bin\intel_xe_collector.py',
	'etc\rc.d\S99intel-xe-gpu-top'
)
$missing = @()
foreach ($f in $required) {
	$p = Join-Path $root $f
	if (-not (Test-Path $p)) { $missing += $f }
}
if ($missing.Count -gt 0) {
	Write-Error "Missing required files: $($missing -join ', ')`nPlease run this script from the repository root and ensure these files exist.";
	exit 1
}

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


# Create tar.gz using system tar
Push-Location $tmp
tar -czf $out .
Pop-Location

Write-Host "Built: $out"
