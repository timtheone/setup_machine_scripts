#!/usr/bin/env bash
set -euo pipefail

: "${SUDO:=sudo}"
: "${USER_NAME:=$USER}"
: "${DRYRUN:=0}"

MODULE="$(basename "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/summary.sh"
summary_init

log()  { echo -e "\033[1;32m==>\033[0m $*"; }
skip() { echo -e "\033[1;33mSKIP:\033[0m $*"; }
err()  { echo -e "\033[1;31mERR:\033[0m  $*"; }

# Install docker if missing
if command -v docker >/dev/null 2>&1; then
  skip "Docker already installed ($(docker --version 2>/dev/null || true))"
  summary_add "$MODULE" "docker" "SKIPPED" "already installed"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install Docker Engine + Compose plugin"
  echo "  Would run: $SUDO apt-get install -y ca-certificates curl gnupg"
  summary_add "$MODULE" "docker prereqs" "DRYRUN" "would install"
  echo "  Would run: $SUDO install -m 0755 -d /etc/apt/keyrings"
  summary_add "$MODULE" "/etc/apt/keyrings" "DRYRUN" "would create"
  # shellcheck disable=SC1091
  source /etc/os-release
  ARCH="$(dpkg --print-architecture)"
  DOCKER_DISTRO=""
  CODENAME="${VERSION_CODENAME:-}"
  if [[ "${ID:-}" == "ubuntu" ]]; then
    DOCKER_DISTRO="ubuntu"
  elif [[ "${ID:-}" == "debian" ]]; then
    DOCKER_DISTRO="debian"
  else
    DOCKER_DISTRO="(detected distro)"
  fi
  echo "  Would run: curl -fsSL https://download.docker.com/linux/${DOCKER_DISTRO}/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
  summary_add "$MODULE" "docker gpg key" "DRYRUN" "would install"
  echo "  Would add docker repo to /etc/apt/sources.list.d/docker.list"
  summary_add "$MODULE" "docker repo" "DRYRUN" "would add ${DOCKER_DISTRO} ${CODENAME}"
  echo "  Would run: $SUDO apt-get update -y"
  summary_add "$MODULE" "apt-get update (docker repo)" "DRYRUN" "would update"
  echo "  Would run: $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
  summary_add "$MODULE" "docker" "DRYRUN" "would install"
  echo "  Would run: $SUDO systemctl enable --now docker"
else
  log "Installing Docker Engine + Compose plugin (official Docker repo)"

  set +e
  $SUDO apt-get install -y ca-certificates curl gnupg
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    summary_add "$MODULE" "docker prereqs" "ERROR" "failed installing prereqs (rc=$rc)"
  else
    summary_add "$MODULE" "docker prereqs" "INSTALLED" ""
  fi

  set +e
  $SUDO install -m 0755 -d /etc/apt/keyrings
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    summary_add "$MODULE" "/etc/apt/keyrings" "ERROR" "mkdir/install failed (rc=$rc)"
  fi

  # Detect distro for docker repo
  # shellcheck disable=SC1091
  source /etc/os-release
  ARCH="$(dpkg --print-architecture)"
  DOCKER_DISTRO=""
  CODENAME="${VERSION_CODENAME:-}"

  if [[ "${ID:-}" == "ubuntu" ]]; then
    DOCKER_DISTRO="ubuntu"
  elif [[ "${ID:-}" == "debian" ]]; then
    DOCKER_DISTRO="debian"
  else
    summary_add "$MODULE" "docker repo" "ERROR" "Unsupported distro ID=${ID:-unknown}"
    exit 0
  fi

  # GPG key
  set +e
  curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "docker gpg key" "INSTALLED" ""
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg || true
  else
    summary_add "$MODULE" "docker gpg key" "ERROR" "failed (rc=$rc)"
    exit 0
  fi

  # Repo list
  set +e
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_DISTRO} ${CODENAME} stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "docker repo" "INSTALLED" "${DOCKER_DISTRO} ${CODENAME}"
  else
    summary_add "$MODULE" "docker repo" "ERROR" "failed writing repo file (rc=$rc)"
    exit 0
  fi

  # Update indexes after adding repo
  set +e
  $SUDO apt-get update -y
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "apt-get update (docker repo)" "INSTALLED" ""
  else
    summary_add "$MODULE" "apt-get update (docker repo)" "ERROR" "failed (rc=$rc)"
    exit 0
  fi

  # Install docker packages
  set +e
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "docker" "INSTALLED" ""
  else
    err "Failed installing docker packages (rc=$rc)"
    summary_add "$MODULE" "docker" "ERROR" "apt-get install failed (rc=$rc)"
    exit 0
  fi

  $SUDO systemctl enable --now docker >/dev/null 2>&1 || true
fi

# docker compose check
if docker compose version >/dev/null 2>&1; then
  summary_add "$MODULE" "docker compose" "SKIPPED" "already available"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install docker-compose-plugin"
  echo "  Would run: $SUDO apt-get install -y docker-compose-plugin"
  summary_add "$MODULE" "docker compose" "DRYRUN" "would install"
else
  log "docker compose not found; attempting to install docker-compose-plugin"
  set +e
  $SUDO apt-get install -y docker-compose-plugin
  rc=$?
  set -e
  if [[ $rc -eq 0 ]] && docker compose version >/dev/null 2>&1; then
    summary_add "$MODULE" "docker compose" "INSTALLED" ""
  else
    summary_add "$MODULE" "docker compose" "ERROR" "plugin install failed (rc=$rc)"
  fi
fi

# Add user to docker group
if getent group docker >/dev/null 2>&1; then
  if id -nG "$USER_NAME" | tr ' ' '\n' | grep -q '^docker$'; then
    skip "User $USER_NAME already in docker group"
    summary_add "$MODULE" "docker group" "SKIPPED" "user already in group"
  elif [[ "$DRYRUN" == "1" ]]; then
    echo -e "\033[1;36m[DRY-RUN]\033[0m Would add $USER_NAME to docker group"
    echo "  Would run: $SUDO usermod -aG docker $USER_NAME"
    summary_add "$MODULE" "docker group" "DRYRUN" "would add user to group"
  else
    log "Adding $USER_NAME to docker group (requires logout/login)"
    set +e
    $SUDO usermod -aG docker "$USER_NAME"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      summary_add "$MODULE" "docker group" "INSTALLED" "added user to group"
    else
      summary_add "$MODULE" "docker group" "ERROR" "usermod failed (rc=$rc)"
    fi
  fi
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would add $USER_NAME to docker group (after docker install)"
  summary_add "$MODULE" "docker group" "DRYRUN" "would add user to group"
else
  summary_add "$MODULE" "docker group" "ERROR" "docker group not found"
fi
