<#
.SYNOPSIS
  Run CC-OS locally in its own CraftOS-PC VM.

.DESCRIPTION
  The VM lives in .vm\ inside this project (its own CraftOS-PC data directory),
  so it never touches your normal CraftOS-PC computers in %APPDATA%.
  Each launch copies .\root into every VM computer,
  leaving the VM's own data (logs, /UserData) alone, writes the dev startup file
  and boots CraftOS-PC. The VM is marked as a dev machine, so the GitHub updater
  never runs inside it.

  The emulated devices come from peripheral list files (format: see
  .vm\peripherals\default.txt). Pick them with -Peripherals: a path, or the name
  of a list in .vm\peripherals\. Several lists are combined. Mod devices such as
  Mekanism are faked in Lua (dev\mock-peripherals.lua).

.EXAMPLE
  .\run-local.ps1                 # sync + boot (same PCs and peripherals as last time)
  .\run-local.ps1 -Computers 3    # boot 3 networked CC-OS PCs (remembered for next time)
  .\run-local.ps1 -Computers 1    # back to a single PC
  .\run-local.ps1 -Peripherals mekanism            # only the mock Mekanism devices
  .\run-local.ps1 -Peripherals default,mekanism    # combine lists (remembered)
  .\run-local.ps1 -Peripherals .\my-devices.txt    # your own list file
  .\run-local.ps1 -ListPeripherals                 # show the lists in .vm\peripherals
  .\run-local.ps1 -Fresh          # wipe the VM computers first (new config, logs, settings)
  .\run-local.ps1 -NoPeripherals  # boot without any emulated devices
  .\run-local.ps1 -Installer      # let the GitHub installer run on boot (turns dev mode off)
#>
param(
    [switch]$Fresh,
    [switch]$NoPeripherals,
    [switch]$Installer,
    [switch]$ListPeripherals,
    [string[]]$Peripherals = @(),               # empty = same as last time ("default" at first)
    [int]$Id = 1,
    [ValidateRange(0, 8)][int]$Computers = 0,   # 0 = same as last time
    [string]$CraftOS = "$env:LOCALAPPDATA\CraftOS-PC\CraftOS-PC.exe"
)

$ErrorActionPreference = "Stop"
$project   = $PSScriptRoot
$vmDir     = Join-Path $project ".vm"
$periphDir = Join-Path $vmDir "peripherals"

if ($ListPeripherals) {
    Write-Host "Peripheral lists in ${periphDir}:"
    Get-ChildItem $periphDir -Filter *.txt | ForEach-Object { Write-Host "  $($_.BaseName)" }
    exit 0
}

if (-not (Test-Path $CraftOS)) {
    Write-Error "CraftOS-PC not found at '$CraftOS'. Pass -CraftOS <path to CraftOS-PC.exe>."
}

if ($Fresh) {
    # Wipe the per-machine state only; the shared setup (global config, peripheral lists) is in git.
    Write-Host "Wiping VM computers in $vmDir"
    foreach ($item in @("computer", "computers.txt", "peripherals-used.txt")) {
        $path = Join-Path $vmDir $item
        if (Test-Path $path) { Remove-Item -Recurse -Force $path }
    }
    Get-ChildItem (Join-Path $vmDir "config") -Filter *.json -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "global.json" } | Remove-Item -Force
}
New-Item -ItemType Directory -Force $vmDir | Out-Null

function Read-State([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    $text = Get-Content -Raw $path
    if ($null -eq $text) { return "" }
    return $text.Trim()
}

# Remember how many PCs the VM has, so a plain .\run-local.ps1 keeps them all.
$countFile = Join-Path $vmDir "computers.txt"
if ($Computers -eq 0) {
    $Computers = 1
    $saved = 0
    if ([int]::TryParse((Read-State $countFile), [ref]$saved) -and $saved -ge 1 -and $saved -le 8) {
        $Computers = $saved
    }
}
[IO.File]::WriteAllText($countFile, "$Computers")

# Work out which peripheral list files to use (and remember them for next time).
function Resolve-PeripheralFile([string]$name) {
    $candidates = @($name, (Join-Path $project $name), (Join-Path $periphDir $name), (Join-Path $periphDir "$name.txt"))
    foreach ($c in $candidates) {
        if ((Test-Path $c -PathType Leaf)) { return (Resolve-Path $c).Path }
    }
    return $null
}

$usedFile = Join-Path $vmDir "peripherals-used.txt"
$explicit = $Peripherals.Count -gt 0
if (-not $explicit) {
    $Peripherals = @((Read-State $usedFile) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($Peripherals.Count -eq 0) { $Peripherals = @("default") }
}
# Allow -Peripherals "a,b" as well as -Peripherals a,b
$Peripherals = @($Peripherals | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$periphFiles = @()
foreach ($name in $Peripherals) {
    $file = Resolve-PeripheralFile $name
    if ($file) { $periphFiles += $file }
    elseif ($explicit) { Write-Error "Peripheral list '$name' not found (looked for a file, and in $periphDir). Try -ListPeripherals." }
    else { Write-Warning "Peripheral list '$name' from last time no longer exists; skipping it." }
}
if ($periphFiles.Count -eq 0 -and -not $explicit) {
    $default = Resolve-PeripheralFile "default"
    if ($default) { $periphFiles = @($default) }
}
[IO.File]::WriteAllText($usedFile, ($periphFiles -join "`n"))

$periphText = ($periphFiles | ForEach-Object { "[all]`n" + (Get-Content -Raw $_) }) -join "`n"
# Embed as a Lua long string; pick a bracket level that doesn't occur in the text.
$level = 1
while ($periphText.Contains("]" + ("=" * $level) + "]")) { $level++ }
$eq = "=" * $level
$periphLua = "_G.CCOS_PERIPHERALS = [$eq[`n$periphText`n]$eq]"

# A brand-new VM config makes CraftOS-PC ask about analytics before booting;
# answer "no" for this isolated VM so it boots straight away.
$vmConfig = Join-Path $vmDir "config\global.json"
if (-not (Test-Path $vmConfig) -or (Get-Item $vmConfig).Length -eq 0) {
    New-Item -ItemType Directory -Force (Split-Path $vmConfig) | Out-Null
    [IO.File]::WriteAllText($vmConfig, "{`n    `"snooperEnabled`": false`n}`n")
}

$mocks    = Get-Content -Raw (Join-Path $project "dev\mock-peripherals.lua")
$template = Get-Content -Raw (Join-Path $project "dev\vm-startup.lua")
$ids = @($Id) + @(1..($Computers - 1) | Where-Object { $Computers -gt 1 } | ForEach-Object { $Id + $_ })
$extra = ($ids | Select-Object -Skip 1) -join ", "

foreach ($pc in $ids) {
    $computer = Join-Path $vmDir "computer\$pc"
    New-Item -ItemType Directory -Force $computer | Out-Null

    # Mirror the OS; keep the VM's own runtime data.
    Write-Host "Syncing root -> VM computer $pc"
    robocopy (Join-Path $project "root") (Join-Path $computer "root") /MIR /NJH /NJS /NFL /NDL /NP `
        /XD (Join-Path $computer "root\sys\logs\programLogs") /XF main.log .manifest | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Error "robocopy (root) failed ($LASTEXITCODE)" }
    # OSadditinalResources is no longer used; drop the copy older runs left in the VM
    $oldResources = Join-Path $computer "OSadditinalResources"
    if (Test-Path $oldResources) { Remove-Item -Recurse -Force $oldResources }
    New-Item -ItemType Directory -Force (Join-Path $computer "UserData") | Out-Null

    # Set these on _G: plain globals in startup.lua land in the program's own env, which rawget(_G, ...) can't see
    $header = if ($pc -eq $Id) { "_G.CCOS_EXTRA = { $extra }" } else { "_G.CCOS_SECONDARY = true" }
    if ($NoPeripherals) { $header += "`n_G.CCOS_NO_PERIPHERALS = true" }
    if ($Installer) { $header += "`n_G.CCOS_RUN_INSTALLER = true" }
    $header += "`n$periphLua"
    [IO.File]::WriteAllText((Join-Path $computer "startup.lua"), "$header`n$mocks`n$template")
}

$periphNames = if ($NoPeripherals) { "none" } elseif ($periphFiles.Count) { ($periphFiles | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) }) -join ", " } else { "none" }
Write-Host "Booting CC-OS (VM dir: $vmDir, computers: $($ids -join ', '), peripherals: $periphNames)"
if ($Computers -eq 1) { Write-Host "Tip: .\run-local.ps1 -Computers 2 adds a second PC (e.g. for failover); it's remembered." }
Start-Process $CraftOS -ArgumentList "--directory", "`"$vmDir`"", "--id", $Id
exit 0 # robocopy's "files copied" code (1) would otherwise leak out as a failure
