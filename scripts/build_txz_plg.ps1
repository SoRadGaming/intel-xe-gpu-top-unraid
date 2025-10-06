param(
    [string]$Version = "2025.01",
    [string]$Name = "intel-xe-gpu-top",
    [string]$Owner = "",
    [string]$Repo = "",
    [switch]$Upload
)

<#
Requirements:
 - 7z available in PATH (7-Zip)
 - PowerShell 5+ (Windows 10/11)
 - Optional: GitHub CLI `gh` configured if -Upload is used

What this does:
 - Builds release/<name>-<version>.txz (Slackware-style package with slack-desc)
 - Computes MD5
 - Generates a minimal manifest `release\intel-xe-gpu-top.plg` referencing the release download URL
 - If -Upload is supplied and gh is available, creates a GitHub release (tag v<version>) and uploads the txz asset
#>

function Fail($msg) { Write-Error $msg; exit 1 }

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition | Split-Path -Parent
$pkg = "$Name-$Version"
$tmp = Join-Path $env:TEMP $pkg
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tmp | Out-Null

Write-Host "Preparing package layout in $tmp"

# Preflight checks: ensure required source files exist and 7z is available
$required = @(
  'install.sh',
  'remove.sh',
  'etc\rc.d\S99intel-xe-gpu-top',
  'bin\intel_xe_collector.py',
  'webGui\IntelXeGpu.page',
  'webGui\include\IntelXeGpu.json.php'
)
$miss = @()
foreach ($f in $required) {
  if (-not (Test-Path (Join-Path $root $f))) { $miss += $f }
}
if ($miss.Count -gt 0) { Fail "Missing required files: $($miss -join ', '). Ensure you run this from the repository root." }

if (-not (Get-Command 7z -ErrorAction SilentlyContinue)) { Fail "7z not found in PATH. Install 7-Zip (https://www.7-zip.org/) and ensure '7z' is in your PATH." }

# create directories and copy files to match installed paths
New-Item -ItemType Directory -Path (Join-Path $tmp "boot\config\plugins\$Name") -Force | Out-Null
Copy-Item -Path (Join-Path $root 'install.sh') -Destination (Join-Path $tmp "boot\config\plugins\$Name\install.sh") -Force
Copy-Item -Path (Join-Path $root 'remove.sh') -Destination (Join-Path $tmp "boot\config\plugins\$Name\remove.sh") -Force

New-Item -ItemType Directory -Path (Join-Path $tmp 'etc\rc.d') -Force | Out-Null
Copy-Item -Path (Join-Path $root 'etc\rc.d\S99intel-xe-gpu-top') -Destination (Join-Path $tmp 'etc\rc.d\S99intel-xe-gpu-top') -Force

New-Item -ItemType Directory -Path (Join-Path $tmp 'usr\local\sbin') -Force | Out-Null
Copy-Item -Path (Join-Path $root 'bin\intel_xe_collector.py') -Destination (Join-Path $tmp 'usr\local\sbin\intel_xe_collector.py') -Force

New-Item -ItemType Directory -Path (Join-Path $tmp "usr\local\emhttp\plugins\$Name\include") -Force | Out-Null
Copy-Item -Path (Join-Path $root 'webGui\IntelXeGpu.page') -Destination (Join-Path $tmp "usr\local\emhttp\plugins\$Name\IntelXeGpu.page") -Force
Copy-Item -Path (Join-Path $root 'webGui\include\IntelXeGpu.json.php') -Destination (Join-Path $tmp "usr\local\emhttp\plugins\$Name\include\IntelXeGpu.json.php") -Force

# slack-desc
Set-Content -Path (Join-Path $tmp 'slack-desc') -Value "# slack-desc for $Name`n$Name - Intel Xe GPU Top plugin for Unraid`n" -Encoding utf8

mkdir release -ErrorAction SilentlyContinue | Out-Null
$txz = Join-Path (Get-Location) "release\$pkg.txz"

Write-Host "Creating tar and txz using 7z (requires 7z in PATH)"
if (-not (Get-Command 7z -ErrorAction SilentlyContinue)) { Fail "7z not found in PATH. Install 7-Zip and ensure 7z is available." }

$cwd = Get-Location
Push-Location $tmp
# create tar archive of the package content
$tarPath = Join-Path $tmp "$pkg.tar"
& 7z a -ttar $tarPath * | Out-Null
Pop-Location

# compress tar to xz format (.txz)
if (Test-Path $txz) { Remove-Item $txz -Force }
& 7z a -txz $txz $tarPath | Out-Null
Remove-Item $tarPath -Force

Write-Host "Created: $txz"

# compute MD5
$md5 = (Get-FileHash -Path $txz -Algorithm MD5).Hash.ToLower()
Write-Host "MD5: $md5"

# generate manifest (.plg) referencing the release download URL
$plgPath = Join-Path (Get-Location) "release\$Name.plg"
$gitURL = if ($Owner -and $Repo) { "https://github.com/$Owner/$Repo/releases/download" } else { "https://github.com/<owner>/<repo>/releases/download" }

# Create manifest template with placeholders to avoid PowerShell expanding shell $() or &
$plgTemplate = @'
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE PLUGIN [
  <!ENTITY name      "__NAME__">
  <!ENTITY author    "SoRadGaming">
  <!ENTITY version   "__VERSION__">
  <!ENTITY gitURL    "__GITURL__">
  <!ENTITY md5       "__MD5__">
  <!ENTITY plugin    "/boot/config/plugins/&name;">
  <!ENTITY emhttp    "/usr/local/emhttp/plugins/&name;">
]>

<PLUGIN name="&name;" author="&author;" version="&version;" min="6.10.0">
  <CHANGES>
    Initial release - Intel Xe GPU plugin
  </CHANGES>

  <FILE Run="/bin/bash">
  <INLINE>
    rm -f $(ls /boot/config/plugins/&name;/intel-xe-gpu-top*.txz 2>/dev/null|grep -v '&version;')
  </INLINE>
  </FILE>

  <FILE Name="/boot/config/plugins/&name;/intel-xe-gpu-top-&version;.txz" Run="upgradepkg --install-new">
    <URL>&gitURL;/&version;/intel-xe-gpu-top-&version;.txz</URL>
    <MD5>&md5;</MD5>
  </FILE>

  <FILE Run="/bin/bash" Method="remove">
  <INLINE>
    removepkg intel-xe-gpu-top-&version;
    rm -rf /usr/local/emhttp/plugins/&name;
    rm -rf &plugin;
  </INLINE>
  </FILE>
</PLUGIN>
'@

# substitute placeholders with actual values
$plg = $plgTemplate -replace '__NAME__', $Name -replace '__VERSION__', $Version -replace '__GITURL__', $gitURL -replace '__MD5__', $md5
Set-Content -Path $plgPath -Value $plg -Encoding UTF8
Write-Host "Generated manifest: $plgPath"

if ($Upload) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail "gh (GitHub CLI) not found in PATH. Install and authenticate before using -Upload." }
    if (-not ($Owner -and $Repo)) { Fail "To upload you must supply -Owner and -Repo parameters." }

    $tag = "v$Version"
  Write-Host "Creating GitHub release $tag and uploading $txz"
  gh release create $tag $txz --title $tag --notes "Release $tag"
  if ($LASTEXITCODE -ne 0) { Fail "gh release create failed" }
  Write-Host "Uploaded asset to release $tag"
    # After upload, output the expected raw manifest URL for use in Unraid
    $rawPlgUrl = "https://raw.githubusercontent.com/$Owner/$Repo/main/release/$Name.plg"
    Write-Host "Manifest URL (raw): $rawPlgUrl"
}

Write-Host "Done."
