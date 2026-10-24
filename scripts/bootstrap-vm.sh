#!/usr/bin/env bash
set -Eeuo pipefail

# Bootstrap script for an Ubuntu/Debian VM or cloud instance.
# Usage:
#   export GITHUB_USER=your-github-user
#   export GHCR_TOKEN=your-ghcr-read-token
#   export GHCR_OWNER=${GITHUB_USER}   # optional, defaults to GITHUB_USER
#   ./devops/bootstrap-vm.sh
#
# After this finishes, you can run:
#   APP_VERSION=v1.2.3 GHCR_OWNER=${GITHUB_USER} docker compose \
#     -f devops/docker-compose.prod.yml --env-file .env up -d

if [[ -z "${GITHUB_USER:-}" ]]; then
  echo "Missing required environment variable: GITHUB_USER" >&2
  exit 1
fi

if [[ -z "${GHCR_TOKEN:-}" ]]; then
  echo "Missing required environment variable: GHCR_TOKEN" >&2
  exit 1
fi

GHCR_OWNER="${GHCR_OWNER:-${GITHUB_USER}}"

require_root_or_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    return 0
  fi

  echo "This script requires root privileges or sudo access." >&2
  exit 1
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    echo "Git already installed"
    return 0
  fi

  echo "Installing Git..."

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y git
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y git
  else
    echo "Unsupported OS for Git installation." >&2
    exit 1
  fi
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "Docker already installed"
    return 0
  fi

  echo "Installing Docker Engine and compose plugin..."

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    . /etc/os-release
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null <<EOF
# Added by Ayush360 bootstrap script
# https://docs.docker.com/engine/install/ubuntu/
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable
EOF

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    echo "Unsupported OS for Docker installation." >&2
    exit 1
  fi
}

start_docker_service() {
  echo "Starting Docker service..."
  sudo systemctl enable docker
  sudo systemctl start docker
}

login_to_ghcr() {
  echo "Logging into GitHub Container Registry..."
  echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GITHUB_USER}" --password-stdin
}

main() {
  require_root_or_sudo
  ensure_git
  ensure_docker
  start_docker_service

  docker --version
  docker compose version
  login_to_ghcr

  echo
  echo "Bootstrap complete."
  echo "You can now run the production compose stack with:"
  echo "  export GHCR_OWNER=${GHCR_OWNER}"
  echo "  APP_VERSION=v1.2.3 docker compose -f devops/docker-compose.prod.yml --env-file .env up -d"
}

main "$@"
