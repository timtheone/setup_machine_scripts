#!/usr/bin/env bash
set -euo pipefail

: "${SUDO:=sudo}"
: "${DRYRUN:=0}"
MODULE="$(basename "${BASH_SOURCE[0]}")"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/summary.sh"
summary_init

log()  { echo -e "\033[1;32m==>\033[0m $*"; }
skip() { echo -e "\033[1;33mSKIP:\033[0m $*"; }
err()  { echo -e "\033[1;31mERR:\033[0m  $*"; }

install_pkg_if_missing() {
  local pkg="$1"

  if dpkg -s "$pkg" >/dev/null 2>&1; then
    skip "Package '$pkg' already installed"
    summary_add "$MODULE" "$pkg" "SKIPPED" "already installed"
    return 0
  fi

  if [[ "$DRYRUN" == "1" ]]; then
    echo -e "\033[1;36m[DRY-RUN]\033[0m Would install package: $pkg"
    echo "  Would run: $SUDO apt-get install -y $pkg"
    summary_add "$MODULE" "$pkg" "DRYRUN" "would install"
    return 0
  fi

  log "Installing package: $pkg"
  set +e
  $SUDO apt-get install -y "$pkg"
  local rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "$pkg" "INSTALLED" ""
  else
    err "Failed installing '$pkg' (rc=$rc)"
    summary_add "$MODULE" "$pkg" "ERROR" "apt-get install failed (rc=$rc)"
  fi
}

# base dev tooling
for pkg in \
  ca-certificates gnupg lsb-release software-properties-common \
  curl wget git \
  build-essential make gcc g++ \
  unzip zip tar xz-utils \
  jq ripgrep \
  htop tmux tree \
  openssh-client \
  net-tools dnsutils iputils-ping \
  python3 python3-pip python3-venv \
  fd-find
do
  install_pkg_if_missing "$pkg"
done

# Make `fd` available if only `fdfind` exists
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  if [[ "$DRYRUN" == "1" ]]; then
    echo -e "\033[1;36m[DRY-RUN]\033[0m Would link fdfind -> fd"
    echo "  Would run: $SUDO ln -sf $(command -v fdfind) /usr/local/bin/fd"
    summary_add "$MODULE" "fd symlink" "DRYRUN" "would link fdfind to fd"
  else
    log "Linking fdfind -> fd"
    set +e
    $SUDO ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      summary_add "$MODULE" "fd symlink" "INSTALLED" "linked fdfind to fd"
    else
      summary_add "$MODULE" "fd symlink" "ERROR" "ln failed (rc=$rc)"
    fi
  fi
else
  summary_add "$MODULE" "fd symlink" "SKIPPED" "fd already available (or fdfind missing)"
fi
