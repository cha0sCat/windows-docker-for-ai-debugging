# Provisioning workflow

This repo can provision a full environment (Docker + nvm + Node.js + Codex CLI) and then start the Windows VM container until SSH is reachable.

## Local (Linux)

```bash
./scripts/provision.sh
```

## Local (Windows)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/provision-win.ps1
```

Notes:

- The VM image (`dockurr/windows`) is a Linux container image. On Windows Server, Docker often runs in Windows-container mode only, so the script uses WSL2 to run the Linux Docker engine and start the VM.
- By default, the Windows script sets `WAIT_FOR_SSH=0` so the VM can boot/install in the background; set `WAIT_FOR_SSH=1` if you want to block until SSH is reachable.
- The Windows script also configures `netsh interface portproxy` so you can use `127.0.0.1:8006/5900/3389/2222` on the Windows host.

Environment overrides:

- `SYSTEM` (default: `win7`, options: `win7`, `win2022`)
- `STOP_OTHER_SYSTEMS` (default: `1`)
- `NVM_VERSION` (default: `v0.39.7`)
- `NODE_VERSION` (default: `20`)
- `CODEX_NPM_PKG` (default: `@openai/codex`)
- `SSH_HOST` (default: `127.0.0.1`)
- `SSH_PORT` (default: `2222`)
- `SSH_TIMEOUT_SECONDS` (default: `7200`)
- `WSL_DISTRO` (default: `Ubuntu`)
- `WAIT_FOR_SSH` (default: `1` on Linux, `0` in `provision-win.ps1`)
- `SKIP_NODE_AND_CODEX` (default: `0` on Linux, `1` in `provision-win.ps1`)

Examples:

```bash
# Win7
SYSTEM=win7 ./scripts/provision.sh

# Windows Server 2022
SYSTEM=win2022 ./scripts/provision.sh
```

## GitHub Actions

A manual workflow is included at `.github/workflows/provision.yml`.

Notes:

- Running the Windows VM requires enough disk space and, ideally, `/dev/kvm` acceleration.
- Workflow inputs:
  - `runs_on`: `ubuntu` or `win2022`
  - `system`: `win7` or `win2022`
