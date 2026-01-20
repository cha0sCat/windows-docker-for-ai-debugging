$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$rootDir = Resolve-Path (Join-Path $PSScriptRoot "..")

function Write-Log {
  param([Parameter(Mandatory = $true)][string]$Message)
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  Write-Host "[$ts] $Message"
}

function Die {
  param([Parameter(Mandatory = $true)][string]$Message)
  Write-Error $Message
  exit 1
}

function Test-Command {
  param([Parameter(Mandatory = $true)][string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-AvailableSystems {
  $systemsDir = Join-Path $rootDir "systems"
  if (!(Test-Path $systemsDir)) { return @() }

  Get-ChildItem -Path $systemsDir -Directory | ForEach-Object {
    $compose = Join-Path $_.FullName "compose.yml"
    if (Test-Path $compose) { $_.Name }
  }
}

function Resolve-SystemDir {
  param([Parameter(Mandatory = $true)][string]$System)

  $systemDir = Join-Path (Join-Path $rootDir "systems") $System
  if (!(Test-Path $systemDir)) {
    $available = (Get-AvailableSystems) -join " "
    Die "Unknown SYSTEM: $System (available: $available)"
  }

  $compose = Join-Path $systemDir "compose.yml"
  if (!(Test-Path $compose)) { Die "Missing compose.yml: $compose" }

  return $systemDir
}

function Ensure-Node {
  param([Parameter(Mandatory = $true)][string]$DesiredMajor)

  if ((Test-Command node) -and (Test-Command npm)) {
    Write-Log ("Node: " + (& node -v))
    Write-Log ("npm: " + (& npm -v))
    return
  }

  if (!(Test-Command choco)) {
    Die "Node.js not found and Chocolatey (choco) is missing; install Node.js $DesiredMajor manually."
  }

  Write-Log "Installing Node.js via Chocolatey..."
  choco install nodejs-lts -y --no-progress | Out-Host

  if (!(Test-Command node) -or !(Test-Command npm)) {
    Die "Node.js install did not make node/npm available on PATH."
  }

  Write-Log ("Node: " + (& node -v))
  Write-Log ("npm: " + (& npm -v))
}

function Ensure-Codex {
  param([Parameter(Mandatory = $true)][string]$Package)

  if (Test-Command codex) {
    Write-Log ("Codex: " + (& codex --version))
    return
  }

  if (!(Test-Command npm)) {
    Die "npm not found; cannot install Codex CLI."
  }

  Write-Log "Installing Codex CLI: $Package"
  npm install -g $Package | Out-Host

  if (!(Test-Command codex)) {
    Die "codex binary not found after install"
  }

  Write-Log ("Codex: " + (& codex --version))
}

function Convert-ToWslPath {
  param([Parameter(Mandatory = $true)][string]$WindowsPath)

  $p = (Resolve-Path $WindowsPath).Path -replace "\\", "/"
  if ($p -match "^([A-Za-z]):/(.*)$") {
    return "/mnt/$($Matches[1].ToLower())/$($Matches[2])"
  }

  return $p
}

function Get-WslDistros {
  $out = & wsl -l -q 2>$null
  if ($LASTEXITCODE -ne 0) { return @() }

  return @($out | ForEach-Object { ($_ -replace "\0", "").Trim() } | Where-Object { $_ })
}

function Ensure-Wsl {
  if (!(Test-Command wsl)) { Die "wsl.exe not found (WSL is required on Windows runners)" }

  Write-Log "Ensuring WSL2 + kernel..."
  & wsl --set-default-version 2 | Out-Host
  & wsl --update --web-download | Out-Host
}

function Ensure-WslDistro {
  param([Parameter(Mandatory = $true)][string]$Distro)

  $distros = Get-WslDistros
  if ($distros -contains $Distro) {
    Write-Log "WSL distro found: $Distro"
    return
  }

  Write-Log "Installing WSL distro: $Distro"
  & wsl --install -d $Distro --no-launch | Out-Host

  $distrosAfter = Get-WslDistros
  if (!($distrosAfter -contains $Distro)) {
    Die "WSL distro install did not register '$Distro'."
  }
}

function Invoke-WslBash {
  param(
    [Parameter(Mandatory = $true)][string]$Distro,
    [Parameter(Mandatory = $true)][string]$Command
  )

  & wsl -d $Distro -u root -- bash -lc $Command
  if ($LASTEXITCODE -ne 0) { Die "WSL command failed (exit=$LASTEXITCODE)" }
}

function Get-WslIPv4 {
  param([Parameter(Mandatory = $true)][string]$Distro)

  $ips = & wsl -d $Distro -u root -- bash -lc "hostname -I"
  if ($LASTEXITCODE -ne 0) { Die "Failed to get WSL IP (exit=$LASTEXITCODE)" }

  $text = (($ips | Out-String) -replace "\0", "").Trim()
  $first = ($text -split "\s+")[0]
  if ([string]::IsNullOrWhiteSpace($first)) { Die "Failed to parse WSL IP from: $text" }

  return $first
}

function Ensure-PortProxy {
  param(
    [Parameter(Mandatory = $true)][string]$ConnectAddress,
    [Parameter(Mandatory = $true)][int]$Port
  )

  & netsh interface portproxy delete v4tov4 listenaddress=127.0.0.1 listenport=$Port *> $null
  & netsh interface portproxy add v4tov4 listenaddress=127.0.0.1 listenport=$Port connectaddress=$ConnectAddress connectport=$Port | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "Failed to configure portproxy for 127.0.0.1:$Port -> ${ConnectAddress}:$Port" }
}

if ($env:OS -ne "Windows_NT") {
  Die "This script is Windows-only. Use ./scripts/provision.sh on Linux."
}

$system = if ([string]::IsNullOrWhiteSpace($env:SYSTEM)) { "win7" } else { $env:SYSTEM }
$stopOther = if ([string]::IsNullOrWhiteSpace($env:STOP_OTHER_SYSTEMS)) { "1" } else { $env:STOP_OTHER_SYSTEMS }
$nodeMajor = if ([string]::IsNullOrWhiteSpace($env:NODE_VERSION)) { "20" } else { $env:NODE_VERSION }
$codexPkg = if ([string]::IsNullOrWhiteSpace($env:CODEX_NPM_PKG)) { "@openai/codex" } else { $env:CODEX_NPM_PKG }
$sshHost = if ([string]::IsNullOrWhiteSpace($env:SSH_HOST)) { "127.0.0.1" } else { $env:SSH_HOST }
$sshPort = if ([string]::IsNullOrWhiteSpace($env:SSH_PORT)) { 2222 } else { [int]$env:SSH_PORT }
$sshTimeout = if ([string]::IsNullOrWhiteSpace($env:SSH_TIMEOUT_SECONDS)) { 7200 } else { [int]$env:SSH_TIMEOUT_SECONDS }
$wslDistro = if ([string]::IsNullOrWhiteSpace($env:WSL_DISTRO)) { "Ubuntu" } else { $env:WSL_DISTRO }
$skipNodeAndCodex = if ([string]::IsNullOrWhiteSpace($env:SKIP_NODE_AND_CODEX)) { "1" } else { $env:SKIP_NODE_AND_CODEX }
$waitForSsh = if ([string]::IsNullOrWhiteSpace($env:WAIT_FOR_SSH)) { "0" } else { $env:WAIT_FOR_SSH }

Write-Log "Provisioning (Windows) start"
Write-Log "SYSTEM=$system"

Ensure-Node -DesiredMajor $nodeMajor
Ensure-Codex -Package $codexPkg

Ensure-Wsl
Ensure-WslDistro -Distro $wslDistro

Resolve-SystemDir -System $system | Out-Null

$wslRoot = Convert-ToWslPath $rootDir
Write-Log "WSL repo path: $wslRoot"

Invoke-WslBash -Distro $wslDistro -Command "cd / && true"

$wslEnv = @(
  "SYSTEM='$system'",
  "STOP_OTHER_SYSTEMS='$stopOther'",
  "NODE_VERSION='$nodeMajor'",
  "CODEX_NPM_PKG='$codexPkg'",
  "SSH_HOST='$sshHost'",
  "SSH_PORT='$sshPort'",
  "SSH_TIMEOUT_SECONDS='$sshTimeout'",
  "WAIT_FOR_SSH='$waitForSsh'",
  "SKIP_NODE_AND_CODEX='$skipNodeAndCodex'"
) -join " "

Write-Log "Starting VM inside WSL (distro=$wslDistro)"
Invoke-WslBash -Distro $wslDistro -Command "cd '$wslRoot' && $wslEnv ./scripts/provision.sh"

Write-Log "Configuring Windows -> WSL port proxy on 127.0.0.1 ..."
$wslIp = Get-WslIPv4 -Distro $wslDistro
Write-Log "WSL IP: $wslIp"
foreach ($p in 2222, 3389, 5900, 8006) { Ensure-PortProxy -ConnectAddress $wslIp -Port $p }

Write-Log "Provisioning done"
