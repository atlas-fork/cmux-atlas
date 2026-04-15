#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CANONICAL_DOCS="atlas-docs/feature-inventory.md, README.md, CLI/cmux.swift (cmux welcome), docs/atlas-test-practice.md, docs/cvm-cmux-codex-interplay.md, CHANGELOG.md"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/atlas-devlog.sh add "Short summary of what this commit delivers" --docs "none needed"
  ./scripts/atlas-devlog.sh current-file
EOF
}

month_file() {
  date '+atlas-docs/devlog/%Y-%m.md'
}

current_file_path() {
  cd "$PROJECT_DIR"
  printf '%s
' "$(month_file)"
}

append_entry() {
  local summary="$1"
  local docs_updates="$2"
  cd "$PROJECT_DIR"

  local rel_file
  rel_file="$(month_file)"
  local abs_file="$PROJECT_DIR/$rel_file"
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M %Z')"
  local staged_files
  staged_files="$(git diff --cached --name-only --diff-filter=ACMR | paste -sd ', ' -)"

  mkdir -p "$(dirname "$abs_file")"

  if [[ ! -f "$abs_file" ]]; then
    printf '# Atlas Devlog: %s

' "$(date '+%Y-%m')" > "$abs_file"
  fi

  if [[ -z "$docs_updates" ]]; then
    docs_updates='PENDING - replace with "none needed" or list the canonical docs you updated'
  fi

  {
    printf '## %s

' "$timestamp"
    printf -- '- Branch: `%s`
' "$branch"
    printf -- '- Delivery: %s
' "$summary"
    printf -- '- Canonical docs reviewed: `%s`
' "$CANONICAL_DOCS"
    printf -- '- Canonical docs updates: %s
' "$docs_updates"
    if [[ -n "$staged_files" ]]; then
      printf -- '- Staged files: `%s`
' "$staged_files"
    fi
    printf '
'
  } >> "$abs_file"

  printf '%s
' "$rel_file"
}

cmd="${1:-}"

case "$cmd" in
  add)
    shift
    if [[ $# -eq 0 ]]; then
      usage
      exit 1
    fi

    summary="$1"
    shift
    docs_updates=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --docs)
          shift
          if [[ $# -eq 0 ]]; then
            usage
            exit 1
          fi
          docs_updates="$1"
          shift
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    done

    append_entry "$summary" "$docs_updates"
    ;;
  current-file)
    current_file_path
    ;;
  *)
    usage
    exit 1
    ;;
esac
