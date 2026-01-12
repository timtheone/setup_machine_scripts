#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n\033[1;32m==>\033[0m $*"; }

# Parse arguments
DRYRUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)
      DRYRUN=1
      ;;
  esac
done
export DRYRUN

if [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN MODE]\033[0m No changes will be made to the system"
fi

# sudo handling
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

# target user (when running via sudo)
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Summary file shared across modules
SUMMARY_FILE="$SCRIPT_DIR/.summary/summary.tsv"
export SUMMARY_FILE

# Load summary helpers
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/summary.sh"
summary_init reset

log "Bootstrapping for user: $USER_NAME ($USER_HOME)"

# sanity: apt exists
if ! command -v apt-get >/dev/null 2>&1; then
  summary_add "bootstrap.sh" "apt-get" "ERROR" "This setup currently supports Ubuntu/Debian (apt-get)"
  summary_print
  exit 1
fi

# Optional: one global update for clarity
log "Updating apt indexes (global)"
if [[ "$DRYRUN" == "1" ]]; then
  echo -e "\033[1;36m[DRY-RUN]\033[0m Would update apt indexes"
  echo "  Would run: $SUDO apt-get update -y"
  summary_add "bootstrap.sh" "apt-get update" "DRYRUN" "would update indexes"
elif $SUDO apt-get update -y; then
  summary_add "bootstrap.sh" "apt-get update" "INSTALLED" "indexes updated"
else
  summary_add "bootstrap.sh" "apt-get update" "ERROR" "failed to update indexes"
fi

run_module() {
  local module_path="$1"
  local module_name
  module_name="$(basename "$module_path")"

  if [[ ! -f "$module_path" ]]; then
    summary_add "$module_name" "(module file)" "ERROR" "Missing file"
    return 0
  fi

  log "Running module: $module_name"

  # run as target user (so dotfiles land in correct $HOME)
  set +e
  if [[ -n "$SUDO" ]]; then
    $SUDO -u "$USER_NAME" env \
      USER_NAME="$USER_NAME" USER_HOME="$USER_HOME" SUDO="$SUDO" SUMMARY_FILE="$SUMMARY_FILE" DRYRUN="$DRYRUN" \
      bash "$module_path"
  else
    # Already running as root, run directly
    env USER_NAME="$USER_NAME" USER_HOME="$USER_HOME" SUDO="sudo" SUMMARY_FILE="$SUMMARY_FILE" DRYRUN="$DRYRUN" \
      bash "$module_path"
  fi
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    summary_add "$module_name" "(module)" "ERROR" "Exited with code $rc"
  fi
}

for f in \
  "$SCRIPT_DIR/install/00-base.sh" \
  "$SCRIPT_DIR/install/10-zsh-ohmyzsh.sh" \
  "$SCRIPT_DIR/install/20-node-nvm-pnpm.sh" \
  "$SCRIPT_DIR/install/30-docker.sh" \
  "$SCRIPT_DIR/install/40-bun.sh"
do
  run_module "$f"
done

summary_print

log "Done. You may need to log out/in for shell & docker-group changes to apply."
