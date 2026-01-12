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

NVM_DIR="$USER_HOME/.nvm"
export NVM_DIR

# Install nvm
if [[ -d "$NVM_DIR" ]]; then
  skip "nvm already installed at $NVM_DIR"
  summary_add "$MODULE" "nvm" "SKIPPED" "already installed"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install nvm"
  echo "  Would run: curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
  summary_add "$MODULE" "nvm" "DRYRUN" "would install"
else
  log "Installing nvm"
  set +e
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "nvm" "INSTALLED" ""
  else
    err "Failed to install nvm (rc=$rc)"
    summary_add "$MODULE" "nvm" "ERROR" "install failed (rc=$rc)"
  fi
fi

# Ensure nvm lines are in .zshrc (nvm installer sometimes misses this)
ZSHRC="$USER_HOME/.zshrc"
if [[ -f "$ZSHRC" ]] && [[ -s "$NVM_DIR/nvm.sh" ]]; then
  if ! grep -q 'NVM_DIR' "$ZSHRC"; then
    if [[ "$DRYRUN" == "1" ]]; then
      echo -e "\033[1;36m[DRY-RUN]\033[0m Would add nvm initialization to .zshrc"
      summary_add "$MODULE" "nvm .zshrc" "DRYRUN" "would add"
    else
      log "Adding nvm initialization to .zshrc"
      cat >> "$ZSHRC" << 'EOF'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
      summary_add "$MODULE" "nvm .zshrc" "INSTALLED" "added to .zshrc"
    fi
  else
    skip "nvm already configured in .zshrc"
    summary_add "$MODULE" "nvm .zshrc" "SKIPPED" "already in .zshrc"
  fi
fi

# Load nvm for this run (skip in dry-run if nvm not installed)
# shellcheck disable=SC1091
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
elif [[ "$DRYRUN" == "1" ]]; then
  # In dry-run mode, just report what would happen for remaining items
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install Node LTS via nvm"
  echo "  Would run: nvm install --lts"
  summary_add "$MODULE" "node (LTS)" "DRYRUN" "would install"
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would set nvm default to lts/*"
  echo "  Would run: nvm alias default lts/*"
  summary_add "$MODULE" "nvm default" "DRYRUN" "would set to lts/*"
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install pnpm via corepack"
  echo "  Would run: corepack enable && corepack prepare pnpm@latest --activate"
  summary_add "$MODULE" "pnpm" "DRYRUN" "would install"
  exit 0
else
  summary_add "$MODULE" "nvm load" "ERROR" "nvm.sh not found"
  exit 0
fi

if ! command -v nvm >/dev/null 2>&1; then
  summary_add "$MODULE" "nvm" "ERROR" "nvm not available in this shell"
  exit 0
fi

# Node LTS install (idempotent)
if command -v node >/dev/null 2>&1; then
  # still ensure LTS exists; user might have a different version active
  if nvm ls "lts/*" 2>/dev/null | grep -q "N/A"; then
    log "Installing Node LTS"
    set +e
    nvm install --lts
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      summary_add "$MODULE" "node (LTS)" "INSTALLED" "$(node -v 2>/dev/null || true)"
    else
      summary_add "$MODULE" "node (LTS)" "ERROR" "nvm install --lts failed (rc=$rc)"
    fi
  else
    skip "Node LTS already installed"
    summary_add "$MODULE" "node (LTS)" "SKIPPED" "already installed"
  fi
else
  log "Installing Node LTS (node not found)"
  set +e
  nvm install --lts
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "node (LTS)" "INSTALLED" "$(node -v 2>/dev/null || true)"
  else
    summary_add "$MODULE" "node (LTS)" "ERROR" "nvm install --lts failed (rc=$rc)"
  fi
fi

# Set default alias to LTS
DEFAULT_ALIAS="$(nvm alias default 2>/dev/null || true)"
if echo "$DEFAULT_ALIAS" | grep -q 'lts/\*'; then
  skip "nvm default already set to lts/*"
  summary_add "$MODULE" "nvm default" "SKIPPED" "already lts/*"
else
  log "Setting nvm default to lts/*"
  set +e
  nvm alias default "lts/*"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "nvm default" "INSTALLED" "set to lts/*"
  else
    summary_add "$MODULE" "nvm default" "ERROR" "failed (rc=$rc)"
  fi
fi

# pnpm via corepack
if command -v pnpm >/dev/null 2>&1; then
  skip "pnpm already installed ($(pnpm -v))"
  summary_add "$MODULE" "pnpm" "SKIPPED" "already installed"
else
  if command -v corepack >/dev/null 2>&1; then
    log "Installing pnpm via corepack"
    set +e
    corepack enable
    corepack prepare pnpm@latest --activate
    rc=$?
    set -e
    if [[ $rc -eq 0 ]] && command -v pnpm >/dev/null 2>&1; then
      summary_add "$MODULE" "pnpm" "INSTALLED" "$(pnpm -v 2>/dev/null || true)"
    else
      summary_add "$MODULE" "pnpm" "ERROR" "corepack/pnpm activation failed (rc=$rc)"
    fi
  else
    summary_add "$MODULE" "pnpm" "ERROR" "corepack not found (is Node too old?)"
  fi
fi
