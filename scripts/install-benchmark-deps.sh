#!/usr/bin/env bash

# If invoked with `sh`, restart with bash so arrays and other bash features work.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
fi

log() {
  printf '[bench-deps] %s\n' "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

docker_compose_available() {
  docker compose version >/dev/null 2>&1
}

ensure_docker_compose_plugin_darwin() {
  if docker_compose_available; then
    return 0
  fi

  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    log "docker compose is missing."
    log "Install Docker Desktop or provide a Compose v2 plugin."
    exit 1
  fi

  if ! command_exists docker-compose; then
    brew install docker-compose
  fi

  mkdir -p "${HOME}/.docker/cli-plugins"
  ln -sf "$(command -v docker-compose)" "${HOME}/.docker/cli-plugins/docker-compose"

  if ! docker_compose_available; then
    log "docker compose is still unavailable after installing docker-compose."
    log "Open Docker Desktop and ensure Compose v2 is enabled, then rerun this script."
    exit 1
  fi
}

ensure_cmd() {
  local cmd="$1"
  local hint="$2"
  if command_exists "$cmd"; then
    return 0
  fi
  log "missing command: ${cmd}"
  log "${hint}"
  exit 1
}

install_python_packages() {
  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    ensure_cmd python3 "Install Python 3 first."
    python3 - <<'PY'
import importlib.util
import sys
missing = [pkg for pkg in ("pandas", "matplotlib") if importlib.util.find_spec(pkg) is None]
if missing:
    print("Missing Python packages: " + ", ".join(missing))
    sys.exit(1)
print("Python benchmark packages are installed.")
PY
    return 0
  fi

  python3 -m pip install --user --upgrade pip
  python3 -m pip install --user pandas matplotlib
}

install_rust_with_rustup() {
  if command_exists cargo; then
    return 0
  fi

  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    log "missing command: cargo (install Rust via rustup)"
    exit 1
  fi

  log "Installing Rust toolchain (cargo) via rustup..."
  curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable

  # shellcheck disable=SC1090
  source "${HOME}/.cargo/env"
}

install_darwin() {
  if [[ "${CHECK_ONLY}" -eq 0 ]]; then
    ensure_cmd brew "Install Homebrew first: https://brew.sh"
  fi

  if [[ "${CHECK_ONLY}" -eq 0 ]]; then
    brew install go python rustup-init
  fi

  install_rust_with_rustup

  if ! command_exists swift; then
    if [[ "${CHECK_ONLY}" -eq 1 ]]; then
      log "missing command: swift (install Xcode Command Line Tools)"
      exit 1
    fi

    log "Swift toolchain missing. Triggering Xcode Command Line Tools install..."
    xcode-select --install || true
    log "Finish the Xcode Command Line Tools installation, then rerun this script."
    exit 1
  fi

  if ! command_exists docker; then
    if [[ "${CHECK_ONLY}" -eq 1 ]]; then
      log "missing command: docker (install Docker Desktop)"
      exit 1
    fi
    brew install --cask docker
    log "Docker Desktop was installed. Start Docker Desktop once, then rerun this script."
    exit 1
  fi

  ensure_docker_compose_plugin_darwin

  ensure_cmd curl "Install curl."
  ensure_cmd python3 "Install Python 3."
  ensure_cmd pip3 "Install pip for Python 3."
  install_python_packages
}

install_linux() {
  if ! command_exists apt-get; then
    log "This installer currently supports Linux systems with apt-get."
    log "Install dependencies manually on your distro, then rerun with --check."
    exit 1
  fi

  if [[ "${CHECK_ONLY}" -eq 0 ]]; then
    run_as_root apt-get update
    run_as_root apt-get install -y \
      build-essential \
      ca-certificates \
      curl \
      docker-compose-plugin \
      docker.io \
      golang-go \
      libssl-dev \
      pkg-config \
      python3 \
      python3-pip
  fi

  install_rust_with_rustup

  if ! command_exists swift; then
    log "Swift is not installed."
    log "Install Swift from https://www.swift.org/install/linux/ and rerun this script."
    exit 1
  fi

  ensure_cmd docker "Install Docker."
  if ! docker_compose_available; then
    log "docker compose is missing (install docker-compose-plugin)."
    exit 1
  fi

  ensure_cmd go "Install Go."
  ensure_cmd curl "Install curl."
  ensure_cmd python3 "Install Python 3."
  ensure_cmd pip3 "Install pip for Python 3."
  install_python_packages
}

main() {
  local os
  os="$(uname -s)"

  case "$os" in
    Darwin)
      install_darwin
      ;;
    Linux)
      install_linux
      ;;
    *)
      log "Unsupported OS: ${os}"
      exit 1
      ;;
  esac

  # shellcheck disable=SC1090
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"

  ensure_cmd cargo "Rust toolchain (cargo) is required."
  ensure_cmd go "Go is required."
  ensure_cmd swift "Swift is required."
  ensure_cmd docker "Docker is required."
  if ! docker_compose_available; then
    log "docker compose is required."
    exit 1
  fi
  ensure_cmd python3 "Python 3 is required."

  log "Benchmark dependencies are ready."
  cargo --version || true
  go version || true
  swift --version || true
  docker --version || true
  docker compose version || true
  python3 --version || true
}

main "$@"
