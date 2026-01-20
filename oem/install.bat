@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "OEMDIR=%~dp0"
set "LOG=%OEMDIR%install.log"
set "MSI=%OEMDIR%OpenSSH-Win64-v9.5.0.0.msi"

echo [%DATE% %TIME%] OEM install start > "%LOG%"
echo OEMDIR=%OEMDIR%>> "%LOG%"

if not exist "%MSI%" (
  echo [%DATE% %TIME%] ERROR: missing MSI: %MSI%>> "%LOG%"
  exit /b 1
)

echo [%DATE% %TIME%] Installing OpenSSH Server (Win32-OpenSSH) ...>> "%LOG%"
msiexec /i "%MSI%" /qn /norestart ADDLOCAL=Server >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo [%DATE% %TIME%] msiexec exit code: !RC!>> "%LOG%"

echo [%DATE% %TIME%] Ensuring Docker user is Administrator ...>> "%LOG%"
net localgroup Administrators Docker /add >> "%LOG%" 2>&1

echo [%DATE% %TIME%] Updating sshd_config and PATH ...>> "%LOG%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$openSsh = Join-Path $env:ProgramFiles 'OpenSSH';" ^
  "$path = [Environment]::GetEnvironmentVariable('Path',[System.EnvironmentVariableTarget]::Machine);" ^
  "if ($path -notlike ('*' + $openSsh + '*')) { [Environment]::SetEnvironmentVariable('Path', $path + ';' + $openSsh, [System.EnvironmentVariableTarget]::Machine) }" ^
  "$cfg = Join-Path $env:ProgramData 'ssh\\sshd_config';" ^
  "if (!(Test-Path $cfg)) { exit 0 };" ^
  "$lines = Get-Content -LiteralPath $cfg -ErrorAction SilentlyContinue;" ^
  "$hasSub = ($lines -match '^Subsystem\\s+sftp\\s+');" ^
  "if ($hasSub) { $lines = $lines -replace '^Subsystem\\s+sftp\\s+.*$','Subsystem sftp sftp-server.exe' } else { $lines += 'Subsystem sftp sftp-server.exe' };" ^
  "if (-not ($lines -match '^[#\\s]*PasswordAuthentication\\s+yes\\s*$')) { $lines += 'PasswordAuthentication yes' };" ^
  "Set-Content -LiteralPath $cfg -Value $lines -Encoding ASCII" >> "%LOG%" 2>&1

echo [%DATE% %TIME%] Opening firewall port 22 ...>> "%LOG%"
netsh advfirewall firewall add rule name="OpenSSH SSH Server (sshd)" dir=in action=allow protocol=TCP localport=22 >> "%LOG%" 2>&1

echo [%DATE% %TIME%] Enabling and starting sshd service ...>> "%LOG%"
sc.exe config sshd start= auto >> "%LOG%" 2>&1
sc.exe stop sshd >> "%LOG%" 2>&1
sc.exe start sshd >> "%LOG%" 2>&1
sc.exe query sshd >> "%LOG%" 2>&1

echo [%DATE% %TIME%] OEM install done>> "%LOG%"
exit /b 0
