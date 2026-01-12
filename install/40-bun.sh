#!/usr/bin/env bash
set -euo pipefail

: "${USER_HOME:=$HOME}"
: "${DRYRUN:=0}"

MODULE="$(basename "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/summary.sh"
summary_init

log()  { echo -e "\033[1;32m==>\033[0m $*"; }
skip() { echo -e "\033[1;33mSKIP:\033[0m $*"; }
err()  { echo -e "\033[1;31mERR:\033[0m  $*"; }

BUN_INSTALL="$USER_HOME/.bun"
export BUN_INSTALL
export PATH="$BUN_INSTALL/bin:$PATH"

if command -v bun >/dev/null 2>&1; then
  skip "bun already installed ($(bun -v))"
  summary_add "$MODULE" "bun" "SKIPPED" "already installed"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install bun"
  echo "  Would run: curl -fsSL https://bun.sh/install | bash"
  summary_add "$MODULE" "bun" "DRYRUN" "would install"
else
  log "Installing bun"
  set +e
  curl -fsSL https://bun.sh/install | bash
  rc=$?
  set -e

  if [[ $rc -eq 0 ]] && command -v bun >/dev/null 2>&1; then
    summary_add "$MODULE" "bun" "INSTALLED" "$(bun -v 2>/dev/null || true)"
  else
    err "Failed installing bun (rc=$rc)"
    summary_add "$MODULE" "bun" "ERROR" "install failed (rc=$rc)"
  fi
fi
