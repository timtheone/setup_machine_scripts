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

# Check if gh is already installed
if command -v gh >/dev/null 2>&1; then
  skip "GitHub CLI (gh) already installed"
  summary_add "$MODULE" "gh" "SKIPPED" "already installed ($(gh --version | head -n1))"
  exit 0
fi

if [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install GitHub CLI"
  echo "  Would add GitHub CLI apt repository"
  echo "  Would run: $SUDO apt-get install -y gh"
  summary_add "$MODULE" "gh" "DRYRUN" "would install"
  exit 0
fi

log "Installing GitHub CLI (gh)"

# Add GitHub CLI repository
set +e

# Import GitHub CLI GPG key
if ! curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null 2>&1; then
  err "Failed to import GitHub CLI GPG key"
  summary_add "$MODULE" "gh gpg key" "ERROR" "failed to import GPG key"
  exit 1
fi
$SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

# Add repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Update apt indexes
if ! $SUDO apt-get update -y; then
  err "Failed to update apt indexes after adding GitHub CLI repository"
  summary_add "$MODULE" "gh repo" "ERROR" "apt-get update failed"
  exit 1
fi

# Install gh
$SUDO apt-get install -y gh
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  log "GitHub CLI installed successfully"
  summary_add "$MODULE" "gh" "INSTALLED" "$(gh --version | head -n1)"
else
  err "Failed to install GitHub CLI (rc=$rc)"
  summary_add "$MODULE" "gh" "ERROR" "apt-get install failed (rc=$rc)"
  exit 1
fi
