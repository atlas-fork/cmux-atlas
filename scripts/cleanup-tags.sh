#!/usr/bin/env bash
set -euo pipefail

# Clean up cmux-atlas tagged build artifacts.
#
# Manual usage:
#   ./scripts/cleanup-tags.sh            # interactive: delete all tagged runs
#   ./scripts/cleanup-tags.sh --dry-run  # preview only
#   ./scripts/cleanup-tags.sh --force    # delete without prompting
#
# Internal auto mode:
# - When CMUX_CLEANUP_MODE=auto, keep the current tag plus at most one other
#   recent/running tag and delete the rest.

DRY_RUN=0
FORCE=0

DERIVED_DATA_ROOT="${CMUX_DERIVED_DATA_ROOT:-$HOME/Library/Developer/Xcode/DerivedData}"
APP_SUPPORT_DIR="${CMUX_APP_SUPPORT_DIR:-$HOME/Library/Application Support/cmux-atlas}"
TMP_ROOT="${CMUX_TMP_ROOT:-/tmp}"
CLEANUP_MODE="${CMUX_CLEANUP_MODE:-manual}"
CURRENT_TAG="${CMUX_CLEANUP_CURRENT_TAG:-}"

usage() {
  sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

stat_mtime() {
  local path="$1"
  stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo 0
}

paths_for_tag() {
  local tag="$1"
  cat <<EOF
$DERIVED_DATA_ROOT/cmux-atlas-${tag}
$TMP_ROOT/cmux-atlas-${tag}
$TMP_ROOT/cmux-atlas-debug-${tag}.sock
$TMP_ROOT/cmux-debug-${tag}.sock
$TMP_ROOT/cmux-atlas-debug-${tag}.log
$TMP_ROOT/cmux-debug-${tag}.log
$TMP_ROOT/cmux-xcodebuild-${tag}.log
$APP_SUPPORT_DIR/cmuxd-dev-${tag}.sock
EOF
}

tag_size_kb() {
  local tag="$1"
  local total=0
  local path=""
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    total=$(( total + $(du -sk "$path" 2>/dev/null | awk '{print $1}' || echo 0) ))
  done < <(paths_for_tag "$tag")
  echo "$total"
}

tag_last_modified() {
  local tag="$1"
  local latest=0
  local path=""
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    local mtime
    mtime="$(stat_mtime "$path")"
    if (( mtime > latest )); then
      latest="$mtime"
    fi
  done < <(paths_for_tag "$tag")
  echo "$latest"
}

is_running_tag() {
  local tag="$1"
  pgrep -f "cmux Atlas DEV ${tag}\.app/Contents/MacOS/cmux Atlas DEV" >/dev/null 2>&1
}

discover_tags() {
  local seen=" "
  local path=""
  local base=""
  local tag=""

  while IFS= read -r -d '' path; do
    [[ -e "$path" ]] || continue
    base="$(basename "$path")"
    case "$base" in
      cmux-atlas-*)
        tag="${base#cmux-atlas-}"
        ;;
      cmux-atlas-debug-*.sock)
        tag="${base#cmux-atlas-debug-}"
        tag="${tag%.sock}"
        ;;
      cmux-debug-*.sock)
        tag="${base#cmux-debug-}"
        tag="${tag%.sock}"
        ;;
      cmux-atlas-debug-*.log)
        tag="${base#cmux-atlas-debug-}"
        tag="${tag%.log}"
        ;;
      cmux-debug-*.log)
        tag="${base#cmux-debug-}"
        tag="${tag%.log}"
        ;;
      cmux-xcodebuild-*.log)
        tag="${base#cmux-xcodebuild-}"
        tag="${tag%.log}"
        ;;
      cmuxd-dev-*.sock)
        tag="${base#cmuxd-dev-}"
        tag="${tag%.sock}"
        ;;
      *)
        continue
        ;;
    esac
    tag="${tag%/}"
    [[ -n "$tag" ]] || continue
    if [[ "$seen" == *" $tag "* ]]; then
      continue
    fi
    seen="${seen}${tag} "
    printf '%s\n' "$tag"
  done < <(
    find "$DERIVED_DATA_ROOT" -maxdepth 1 -type d -name 'cmux-atlas-*' -print0 2>/dev/null
    find "$TMP_ROOT" -maxdepth 1 \( -type d -o -type l -o -type s -o -type f \) \
      \( -name 'cmux-atlas-*' -o -name 'cmux-atlas-debug-*.sock' -o -name 'cmux-debug-*.sock' -o -name 'cmux-atlas-debug-*.log' -o -name 'cmux-debug-*.log' -o -name 'cmux-xcodebuild-*.log' \) \
      -print0 2>/dev/null
    find "$APP_SUPPORT_DIR" -maxdepth 1 -type s -name 'cmuxd-dev-*.sock' -print0 2>/dev/null
  )
}

human_size() {
  local kb="$1"
  if (( kb >= 1048576 )); then
    awk "BEGIN { printf \"%.1fG\", ${kb} / 1048576 }"
  elif (( kb >= 1024 )); then
    awk "BEGIN { printf \"%.0fM\", ${kb} / 1024 }"
  else
    printf '%sK' "$kb"
  fi
}

declare -a ALL_TAGS=()
while IFS= read -r tag; do
  [[ -n "$tag" ]] || continue
  ALL_TAGS+=("$tag")
done < <(discover_tags)

if [[ "${#ALL_TAGS[@]}" -eq 0 ]]; then
  echo "No cmux-atlas-* tags found. Nothing to clean."
  exit 0
fi

declare -a KEEP_TAGS=()
if [[ "$CLEANUP_MODE" == "auto" ]]; then
  if [[ -n "$CURRENT_TAG" ]]; then
    KEEP_TAGS+=("$CURRENT_TAG")
  fi

  while IFS='|' read -r running mtime tag; do
    [[ -n "$tag" ]] || continue
    if [[ "$tag" == "$CURRENT_TAG" ]]; then
      continue
    fi
    KEEP_TAGS+=("$tag")
    break
  done < <(
    for tag in "${ALL_TAGS[@]}"; do
      if is_running_tag "$tag"; then running=1; else running=0; fi
      printf '%s|%s|%s\n' "$running" "$(tag_last_modified "$tag")" "$tag"
    done | sort -t'|' -k1,1nr -k2,2nr
  )
fi

should_keep() {
  local tag="$1"
  local kept=""
  for kept in "${KEEP_TAGS[@]:-}"; do
    if [[ "$kept" == "$tag" ]]; then
      return 0
    fi
  done
  return 1
}

declare -a DELETE_TAGS=()
declare -a SKIPPED_TAGS=()

for tag in "${ALL_TAGS[@]}"; do
  if should_keep "$tag"; then
    SKIPPED_TAGS+=("$tag")
  else
    DELETE_TAGS+=("$tag")
  fi
done

if [[ "${#DELETE_TAGS[@]}" -eq 0 ]]; then
  echo "No tags eligible for cleanup."
  [[ "${#SKIPPED_TAGS[@]}" -gt 0 ]] && echo "Keeping: ${SKIPPED_TAGS[*]}"
  exit 0
fi

total_kb=0
for tag in "${DELETE_TAGS[@]}"; do
  total_kb=$(( total_kb + $(tag_size_kb "$tag") ))
done

echo "Found ${#DELETE_TAGS[@]} tag(s) eligible for cleanup (~$(human_size "$total_kb")):"
for tag in "${DELETE_TAGS[@]}"; do
  notes=()
  if is_running_tag "$tag"; then
    notes+=("running")
  fi
  latest="$(tag_last_modified "$tag")"
  if [[ "$latest" -gt 0 ]]; then
    age_hours=$(( ( $(date +%s) - latest ) / 3600 ))
    notes+=("${age_hours}h old")
  fi

  line="  - $tag  [$(human_size "$(tag_size_kb "$tag")")"
  if [[ "${#notes[@]}" -gt 0 ]]; then
    line="${line}, ${notes[*]}"
  fi
  line="${line}]"
  echo "$line"
done

[[ "${#SKIPPED_TAGS[@]}" -gt 0 ]] && echo "Keeping: ${SKIPPED_TAGS[*]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "(dry run — nothing deleted)"
  exit 0
fi

if [[ "$FORCE" -eq 0 ]]; then
  echo
  if [[ "$CLEANUP_MODE" == "auto" ]]; then
    printf "Delete these old/excess tags? [y/N] "
  else
    printf "Delete all tagged runs listed above? [y/N] "
  fi
  read -r answer
  if [[ "$answer" != [yY]* ]]; then
    echo "Aborted."
    exit 0
  fi
fi

deleted=0
for tag in "${DELETE_TAGS[@]}"; do
  echo "Cleaning: $tag"
  pkill -f "cmux Atlas DEV ${tag}\.app/Contents/MacOS/cmux Atlas DEV" 2>/dev/null || true

  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    rm -rf "$path"
  done < <(paths_for_tag "$tag")

  deleted=$(( deleted + 1 ))
done

echo
echo "Deleted ${deleted} tag(s), reclaimed ~$(human_size "$total_kb")."
