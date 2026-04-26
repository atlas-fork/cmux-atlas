#!/usr/bin/env bash
# Regression test for https://github.com/manaflow-ai/cmux/issues/385.
# Ensures paid/gated CI jobs are never run for fork pull requests.
#
# The runner label itself is not asserted (the fork has migrated between
# warp/atlas-macos-arm64/depot/macos-14 over time); only the fork-PR guard
# is required so external contributors cannot trigger paid macOS minutes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/ci.yml"

EXPECTED_IF="if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository"

if ! grep -Fq "$EXPECTED_IF" "$WORKFLOW_FILE"; then
  echo "FAIL: Missing fork pull_request guard in $WORKFLOW_FILE"
  echo "Expected line:"
  echo "  $EXPECTED_IF"
  exit 1
fi

check_job_has_fork_guard() {
  local job="$1"
  if ! awk -v job="^  ${job}:" '
    $0 ~ job { in_job=1; next }
    in_job && /^  [^[:space:]]/ { in_job=0 }
    in_job && /github.event.pull_request.head.repo.full_name == github.repository/ { saw_guard=1 }
    END { exit !saw_guard }
  ' "$WORKFLOW_FILE"; then
    echo "FAIL: ${job} block must keep the fork pull_request guard"
    exit 1
  fi
  echo "PASS: ${job} fork guard is present"
}

check_job_has_fork_guard tests
check_job_has_fork_guard tests-build-and-lag
check_job_has_fork_guard ui-regressions
