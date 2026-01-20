# Provisioning workflow

This repo can provision a full environment (Docker + nvm + Node.js + Codex CLI) and then start the Windows VM container until SSH is reachable.

## Local (Linux)

```bash
./scripts/provision.sh
```

Environment overrides:

- `SYSTEM` (default: `win7`, options: `win7`, `win2022`)
- `STOP_OTHER_SYSTEMS` (default: `1`)
- `NVM_VERSION` (default: `v0.39.7`)
- `NODE_VERSION` (default: `20`)
- `CODEX_NPM_PKG` (default: `@openai/codex`)
- `SSH_HOST` (default: `127.0.0.1`)
- `SSH_PORT` (default: `2222`)
- `SSH_TIMEOUT_SECONDS` (default: `7200`)

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
