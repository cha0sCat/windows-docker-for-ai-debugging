# windows-docker-for-ai-debugging

Windows VMs inside Docker via `dockurr/windows`, with an automatic SSH server install (Win32-OpenSSH) using an OEM `install.bat`.

## Systems

- Windows 7: `systems/win7`
- Windows Server 2022: `systems/win2022`

## Quick start

```bash
# pick one
cd systems/win7
# cd systems/win2022

docker compose up -d
```

## Connect

Ports are the same for both systems (stop one VM before starting the other):

- Web noVNC: `http://127.0.0.1:8006`
- Raw VNC: `127.0.0.1:5900`
- RDP: `127.0.0.1:3389` (username `Docker`, password `admin`)
- SSH: `ssh -p 2222 Docker@127.0.0.1` (password `admin`)

## Repo layout

- `oem/`: shared OEM installer scripts (mounted into each VM).
- `systems/*/storage/`: persistent VM disk/state (ignored by git).
- `systems/*/shared/`: host folder exposed to Windows as `Shared` on the desktop (ignored by git).
- `scripts/provision.sh`: installs Docker + nvm + Node 20 + Codex CLI, then starts the selected VM and waits for SSH.

See `docs/provisioning.md` for the GitHub Actions workflow and environment options.
