<#
.SYNOPSIS
  Run CC-OS locally in its own CraftOS-PC VM.

.DESCRIPTION
  The VM lives in .vm\ inside this project (its own CraftOS-PC data directory),
  so it never touches your normal CraftOS-PC computers in %APPDATA%.
  Each launch copies .\root and .\OSadditinalResources into every VM computer,
  leaving the VM's own data (logs, /UserData) alone, writes the dev startup file
  and boots CraftOS-PC. The VM is marked as a dev machine, so the GitHub updater
  never runs inside it.

.EXAMPLE
  .\run-local.ps1                 # sync + boot (same number of PCs as last time; 1 at first)
  .\run-local.ps1 -Computers 3    # boot 3 networked CC-OS PCs (remembered for next time)
  .\run-local.ps1 -Computers 1    # back to a single PC
  .\run-local.ps1 -Fresh          # wipe the VM first (new config, logs, settings)
  .\run-local.ps1 -NoPeripherals  # boot without the emulated test devices
#>
param(
    [switch]$Fresh,
    [switch]$NoPeripherals,
    [int]$Id = 1,
    [ValidateRange(0, 8)][int]$Computers = 0,   # 0 = same as last time
    [string]$CraftOS = "$env:LOCALAPPDATA\CraftOS-PC\CraftOS-PC.exe"
)

$ErrorActionPreference = "Stop"
$project = $PSScriptRoot
$vmDir   = Join-Path $project ".vm"

if (-not (Test-Path $CraftOS)) {
    Write-Error "CraftOS-PC not found at '$CraftOS'. Pass -CraftOS <path to CraftOS-PC.exe>."
}

# Remember how many PCs the VM has, so a plain .\run-local.ps1 keeps them all.
$countFile = Join-Path $vmDir "computers.txt"
if ($Computers -eq 0) {
    $Computers = 1
    if (Test-Path $countFile) {
        $saved = 0
        if ([int]::TryParse((Get-Content -Raw $countFile).Trim(), [ref]$saved) -and $saved -ge 1 -and $saved -le 8) {
            $Computers = $saved
        }
    }
}

if ($Fresh -and (Test-Path $vmDir)) {
    Write-Host "Wiping VM at $vmDir"
    Remove-Item -Recurse -Force $vmDir
}
New-Item -ItemType Directory -Force $vmDir | Out-Null
[IO.File]::WriteAllText($countFile, "$Computers")

# A brand-new VM config makes CraftOS-PC ask about analytics before booting;
# answer "no" for this isolated VM so it boots straight away.
$vmConfig = Join-Path $vmDir "config\global.json"
if (-not (Test-Path $vmConfig) -or (Get-Item $vmConfig).Length -eq 0) {
    New-Item -ItemType Directory -Force (Split-Path $vmConfig) | Out-Null
    [IO.File]::WriteAllText($vmConfig, "{`n    `"snooperEnabled`": false`n}`n")
}

$template = Get-Content -Raw (Join-Path $project "dev\vm-startup.lua")
$ids = @($Id) + @(1..($Computers - 1) | Where-Object { $Computers -gt 1 } | ForEach-Object { $Id + $_ })
$extra = ($ids | Select-Object -Skip 1) -join ", "

foreach ($pc in $ids) {
    $computer = Join-Path $vmDir "computer\$pc"
    New-Item -ItemType Directory -Force $computer | Out-Null

    # Mirror the OS and your add-ons; keep the VM's own runtime data.
    Write-Host "Syncing root + OSadditinalResources -> VM computer $pc"
    robocopy (Join-Path $project "root") (Join-Path $computer "root") /MIR /NJH /NJS /NFL /NDL /NP `
        /XD (Join-Path $computer "root\sys\logs\programLogs") /XF main.log .manifest | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Error "robocopy (root) failed ($LASTEXITCODE)" }
    robocopy (Join-Path $project "OSadditinalResources") (Join-Path $computer "OSadditinalResources") /MIR `
        /NJH /NJS /NFL /NDL /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Error "robocopy (OSadditinalResources) failed ($LASTEXITCODE)" }
    New-Item -ItemType Directory -Force (Join-Path $computer "UserData") | Out-Null

    $header = if ($pc -eq $Id) { "CCOS_EXTRA = { $extra }" } else { "CCOS_SECONDARY = true" }
    if ($NoPeripherals) { $header += "`nCCOS_NO_PERIPHERALS = true" }
    [IO.File]::WriteAllText((Join-Path $computer "startup.lua"), "$header`n$template")
}

Write-Host "Booting CC-OS (VM dir: $vmDir, computers: $($ids -join ', '))"
if ($Computers -eq 1) { Write-Host "Tip: .\run-local.ps1 -Computers 2 adds a second PC (e.g. for failover); it's remembered." }
Start-Process $CraftOS -ArgumentList "--directory", "`"$vmDir`"", "--id", $Id
exit 0 # robocopy's "files copied" code (1) would otherwise leak out as a failure
