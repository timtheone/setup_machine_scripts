#!/usr/bin/env bash
set -euo pipefail

: "${SUDO:=sudo}"
: "${USER_NAME:=$USER}"
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

# Ensure zsh installed (via apt as root)
if command -v zsh >/dev/null 2>&1; then
  skip "zsh already installed"
  summary_add "$MODULE" "zsh" "SKIPPED" "already installed"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install zsh"
  echo "  Would run: $SUDO apt-get install -y zsh"
  summary_add "$MODULE" "zsh" "DRYRUN" "would install"
else
  log "Installing zsh"
  set +e
  $SUDO apt-get install -y zsh
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "zsh" "INSTALLED" ""
  else
    err "Failed to install zsh (rc=$rc)"
    summary_add "$MODULE" "zsh" "ERROR" "apt-get install failed (rc=$rc)"
  fi
fi

# Install oh-my-zsh (non-interactive)
if [[ -d "$USER_HOME/.oh-my-zsh" ]]; then
  skip "oh-my-zsh already installed"
  summary_add "$MODULE" "oh-my-zsh" "SKIPPED" "already installed"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would install oh-my-zsh"
  echo "  Would run: curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh"
  summary_add "$MODULE" "oh-my-zsh" "DRYRUN" "would install"
else
  log "Installing oh-my-zsh"
  export RUNZSH=no CHSH=no KEEP_ZSHRC=yes
  set +e
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "oh-my-zsh" "INSTALLED" ""
  else
    err "Failed to install oh-my-zsh (rc=$rc)"
    summary_add "$MODULE" "oh-my-zsh" "ERROR" "install script failed (rc=$rc)"
  fi
fi

# Ensure .zshrc exists
if [[ -f "$USER_HOME/.zshrc" ]]; then
  summary_add "$MODULE" ".zshrc" "SKIPPED" "already exists"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would create .zshrc"
  echo "  Would run: touch $USER_HOME/.zshrc"
  summary_add "$MODULE" ".zshrc" "DRYRUN" "would create"
else
  log "Creating .zshrc"
  set +e
  touch "$USER_HOME/.zshrc"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" ".zshrc" "INSTALLED" "created"
  else
    summary_add "$MODULE" ".zshrc" "ERROR" "touch failed (rc=$rc)"
  fi
fi

# Configure plugins
if grep -q '^plugins=(git docker)' "$USER_HOME/.zshrc" 2>/dev/null; then
  skip "oh-my-zsh plugins already set to (git docker)"
  summary_add "$MODULE" "zsh plugins" "SKIPPED" "already (git docker)"
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would set oh-my-zsh plugins to (git docker)"
  if grep -q '^plugins=' "$USER_HOME/.zshrc" 2>/dev/null; then
    echo "  Would run: sed -i 's/^plugins=.*/plugins=(git docker)/' $USER_HOME/.zshrc"
  else
    echo "  Would run: echo 'plugins=(git docker)' >> $USER_HOME/.zshrc"
  fi
  summary_add "$MODULE" "zsh plugins" "DRYRUN" "would set to (git docker)"
else
  log "Setting oh-my-zsh plugins to (git docker)"
  set +e
  if grep -q '^plugins=' "$USER_HOME/.zshrc" 2>/dev/null; then
    sed -i 's/^plugins=.*/plugins=(git docker)/' "$USER_HOME/.zshrc"
  else
    echo 'plugins=(git docker)' >> "$USER_HOME/.zshrc"
  fi
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "zsh plugins" "INSTALLED" "set to (git docker)"
  else
    summary_add "$MODULE" "zsh plugins" "ERROR" "failed to edit .zshrc (rc=$rc)"
  fi
fi

# Default shell to zsh
ZSH_PATH="$(command -v zsh || true)"
CURRENT_SHELL="$(getent passwd "$USER_NAME" | cut -d: -f7)"

if [[ -n "$ZSH_PATH" && "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
  skip "Default shell already zsh"
  summary_add "$MODULE" "default shell" "SKIPPED" "already zsh"
elif [[ -z "$ZSH_PATH" ]]; then
  if [[ "$DRYRUN" == "1" ]]; then
    echo -e "\033[1;36m[DRY-RUN]\033[0m Would set default shell to zsh (after zsh install)"
    summary_add "$MODULE" "default shell" "DRYRUN" "would set to zsh"
  else
    summary_add "$MODULE" "default shell" "ERROR" "zsh not found on PATH"
  fi
elif [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would change default shell for $USER_NAME to zsh"
  echo "  Would run: $SUDO chsh -s $ZSH_PATH $USER_NAME"
  summary_add "$MODULE" "default shell" "DRYRUN" "would set to zsh"
else
  log "Changing default shell for $USER_NAME to zsh"
  set +e
  $SUDO chsh -s "$ZSH_PATH" "$USER_NAME"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    summary_add "$MODULE" "default shell" "INSTALLED" "set to zsh"
  else
    summary_add "$MODULE" "default shell" "ERROR" "chsh failed (rc=$rc)"
  fi
fi
