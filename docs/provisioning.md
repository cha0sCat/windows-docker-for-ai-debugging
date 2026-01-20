# Provisioning workflow

This repo can provision a full environment (Docker + nvm + Node.js + Codex CLI) and then start the Windows VM container until SSH is reachable.

## Local (Linux)

```bash
./scripts/provision.sh
```

Environment overrides:

- `NVM_VERSION` (default: `v0.39.7`)
- `NODE_VERSION` (default: `20`)
- `CODEX_NPM_PKG` (default: `@openai/codex`)
- `SSH_HOST` (default: `127.0.0.1`)
- `SSH_PORT` (default: `2222`)
- `SSH_TIMEOUT_SECONDS` (default: `7200`)

## GitHub Actions

A manual workflow is included at `.github/workflows/provision.yml`.

Notes:

- Running the Windows VM requires a host with enough disk space and, ideally, `/dev/kvm` acceleration.
- GitHub-hosted runners typically do not have enough disk for Windows VM images; use a self-hosted runner.
