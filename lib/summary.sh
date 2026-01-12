#!/usr/bin/env bash
set -euo pipefail

: "${SUMMARY_FILE:?SUMMARY_FILE is required}"
: "${DRYRUN:=0}"

# Dry-run aware command execution
# Usage: run_cmd "description" command arg1 arg2 ...
# In dry-run mode: prints what would happen, returns 0
# In normal mode: executes the command, returns its exit code
run_cmd() {
  local desc="$1"
  shift
  if [[ "$DRYRUN" == "1" ]]; then
    echo -e "\033[1;36m[DRY-RUN]\033[0m $desc"
    echo "  Would run: $*"
    return 0
  else
    "$@"
  fi
}

# Returns the appropriate status for recording
# Usage: status=$(dry_status "INSTALLED")
# Returns "DRYRUN" if in dry-run mode, otherwise the passed status
dry_status() {
  local status="$1"
  if [[ "$DRYRUN" == "1" ]]; then
    echo "DRYRUN"
  else
    echo "$status"
  fi
}

# Returns detail string with "would" prefix in dry-run mode
# Usage: detail=$(dry_detail "installed" "would install")
dry_detail() {
  local normal="$1"
  local dryrun="${2:-would $normal}"
  if [[ "$DRYRUN" == "1" ]]; then
    echo "$dryrun"
  else
    echo "$normal"
  fi
}

summary_init() {
  local force_reset="${1:-}"
  mkdir -p "$(dirname "$SUMMARY_FILE")"
  if [[ ! -f "$SUMMARY_FILE" ]] || [[ "$force_reset" == "reset" ]]; then
    printf "module\titem\tstatus\tdetails\n" > "$SUMMARY_FILE"
  fi
}

summary_add() {
  local module="$1"
  local item="$2"
  local status="$3"   # INSTALLED | SKIPPED | ERROR
  local details="${4:-}"
  printf "%s\t%s\t%s\t%s\n" "$module" "$item" "$status" "$details" >> "$SUMMARY_FILE"
}

summary_print() {
  echo
  echo "================ Summary ================"
  if command -v column >/dev/null 2>&1; then
    column -ts $'\t' "$SUMMARY_FILE"
  else
    cat "$SUMMARY_FILE"
  fi
  echo "========================================="
  echo

  # totals (nice to have)
  local installed skipped errors dryrun
  installed="$(awk -F'\t' 'NR>1 && $3=="INSTALLED"{c++} END{print c+0}' "$SUMMARY_FILE")"
  skipped="$(awk -F'\t' 'NR>1 && $3=="SKIPPED"{c++} END{print c+0}' "$SUMMARY_FILE")"
  errors="$(awk -F'\t' 'NR>1 && $3=="ERROR"{c++} END{print c+0}' "$SUMMARY_FILE")"
  dryrun="$(awk -F'\t' 'NR>1 && $3=="DRYRUN"{c++} END{print c+0}' "$SUMMARY_FILE")"
  echo "Totals: INSTALLED=$installed  SKIPPED=$skipped  DRYRUN=$dryrun  ERROR=$errors"
  echo
}
