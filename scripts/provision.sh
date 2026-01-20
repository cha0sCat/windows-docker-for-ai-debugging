#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

: "${SYSTEM:=win7}"
: "${STOP_OTHER_SYSTEMS:=1}"
: "${NVM_VERSION:=v0.39.7}"
: "${NODE_VERSION:=20}"
: "${CODEX_NPM_PKG:=@openai/codex}"
: "${SSH_HOST:=127.0.0.1}"
: "${SSH_PORT:=2222}"
: "${SSH_TIMEOUT_SECONDS:=7200}"

log() { printf "[%s] %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

available_systems() {
  local d
  for d in "$ROOT_DIR/systems/"*; do
    [[ -f "$d/compose.yml" ]] || continue
    basename "$d"
  done
}

resolve_system_dir() {
  local system_dir="$ROOT_DIR/systems/$SYSTEM"
  [[ -d "$system_dir" ]] || die "Unknown SYSTEM: $SYSTEM (available: $(available_systems | tr '\n' ' '))"
  [[ -f "$system_dir/compose.yml" ]] || die "Missing compose.yml: $system_dir/compose.yml"
  echo "$system_dir"
}

as_root() {
  if [[ "$(id -u)" == "0" ]]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    die "Need root privileges (sudo missing) to run: $*"
  fi
}

ensure_pkg_tools() {
  if have apt-get; then
    as_root apt-get update
    as_root apt-get install -y --no-install-recommends ca-certificates curl git python3
  fi

  for cmd in curl git python3; do
    have "$cmd" || die "Missing required command: $cmd"
  done
}

ensure_docker() {
  if have docker; then
    log "Docker found: $(docker --version || true)"
  else
    log "Docker not found; installing via get.docker.com"
    ensure_pkg_tools

    as_root sh -c 'curl -fsSL https://get.docker.com -o /tmp/get-docker.sh'
    as_root sh /tmp/get-docker.sh

    log "Docker installed: $(docker --version || true)"
  fi

  DOCKER=(docker)
  if ! docker info >/dev/null 2>&1; then
    if have sudo; then
      log "Docker not accessible; using sudo docker"
      DOCKER=(sudo docker)
    else
      die "docker is installed but not accessible (need root/sudo or docker group access)"
    fi
  fi

}

ensure_compose() {
  if "${DOCKER[@]}" compose version >/dev/null 2>&1; then
    log "Docker Compose found: $("${DOCKER[@]}" compose version | head -n 1)"
    return 0
  fi

  if have apt-get; then
    log "Docker Compose plugin not found; installing docker-compose-plugin"
    as_root apt-get update
    as_root apt-get install -y --no-install-recommends docker-compose-plugin
  fi

  "${DOCKER[@]}" compose version >/dev/null 2>&1 || die "docker compose not available"
}

stop_other_systems() {
  [[ "$STOP_OTHER_SYSTEMS" == "1" ]] || return 0

  local chosen_dir
  chosen_dir="$(resolve_system_dir)"

  local d
  for d in "$ROOT_DIR/systems/"*; do
    [[ -f "$d/compose.yml" ]] || continue
    [[ "$d" == "$chosen_dir" ]] && continue

    log "Stopping other system: $(basename "$d")"
    (cd "$d" && "${DOCKER[@]}" compose down) || true
  done
}

ensure_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
    log "nvm found: $(nvm --version)"
    return 0
  fi

  log "Installing nvm ($NVM_VERSION)"
  ensure_pkg_tools

  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
  log "nvm installed: $(nvm --version)"
}

ensure_node() {
  log "Installing Node.js $NODE_VERSION via nvm"
  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
  nvm alias default "$NODE_VERSION" >/dev/null

  log "Node: $(node -v)"
  log "npm: $(npm -v)"
}

ensure_codex() {
  log "Installing Codex CLI: $CODEX_NPM_PKG"

  npm view "$CODEX_NPM_PKG" version >/dev/null 2>&1 || die "npm package not found: $CODEX_NPM_PKG"

  npm install -g "$CODEX_NPM_PKG"

  have codex || die "codex binary not found after install"
  log "Codex installed: $(codex --version 2>/dev/null || echo 'ok')"
}

start_vm() {
  local system_dir
  system_dir="$(resolve_system_dir)"

  stop_other_systems

  log "Starting VM via docker compose (SYSTEM=$SYSTEM)"
  cd "$system_dir"

  "${DOCKER[@]}" compose up -d
  "${DOCKER[@]}" compose ps
}

wait_for_ssh_banner() {
  log "Waiting for SSH banner on ${SSH_HOST}:${SSH_PORT} (timeout ${SSH_TIMEOUT_SECONDS}s)"

  python3 - <<'PY'
import os, socket, sys, time

host = os.environ.get("SSH_HOST", "127.0.0.1")
port = int(os.environ.get("SSH_PORT", "2222"))
timeout = int(os.environ.get("SSH_TIMEOUT_SECONDS", "7200"))

deadline = time.time() + timeout
last_err = None

while time.time() < deadline:
    try:
        with socket.create_connection((host, port), timeout=5) as s:
            s.settimeout(5)
            data = s.recv(256)
            text = data.decode("utf-8", errors="replace").strip()
            if text.startswith("SSH-"):
                print(text)
                sys.exit(0)
            last_err = f"unexpected banner: {text!r}"
    except Exception as e:
        last_err = str(e)

    time.sleep(5)

print(f"Timed out waiting for SSH on {host}:{port}. Last error: {last_err}", file=sys.stderr)
sys.exit(1)
PY

  log "SSH is ready"
}

main() {
  ensure_pkg_tools
  ensure_docker
  ensure_compose

  ensure_nvm
  ensure_node
  ensure_codex

  start_vm
  wait_for_ssh_banner

  log "Provisioning done"
}

main "$@"
