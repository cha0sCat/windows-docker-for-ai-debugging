# Windows Server 2022 + OpenSSH (dockur/windows)

This folder contains a ready-to-run setup for a Windows Server 2022 VM inside Docker, using `dockurr/windows`, plus an automatic SSH server install via an OEM `install.bat`.

## Quick start

```bash
cd /root/win7-ssh/systems/win2022
docker compose up -d
```

Then connect:

- Web noVNC: `http://127.0.0.1:8006`
- Raw VNC: `127.0.0.1:5900`
- RDP: `127.0.0.1:3389` (username `Docker`, password `admin`)
- SSH: `ssh -p 2222 Docker@127.0.0.1` (password `admin`)

## What gets installed

- Win32-OpenSSH Server via `../../oem/OpenSSH-Win64-v9.5.0.0.msi`
- Firewall rule for TCP/22
- `sshd` service set to auto-start

## Files

- `compose.yml`: container + port mappings + volumes.
- `../../oem/install.bat`: executed during the final stage of Windows automatic installation.
- `storage/`: persistent VM disk/state (ignored by git).
- `shared/`: host folder exposed to Windows as `Shared` on the desktop.

## Notes

- First run may take a while (ISO download + unattended install). State is persisted in `storage/`.
- To reinstall from scratch: stop the container and delete `storage/`.
- Copy files via SSH: `scp -P 2222 ./file Docker@127.0.0.1:Desktop/`
