#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

git config core.hooksPath .githooks

echo "Installed repo-managed git hooks:"
echo "  core.hooksPath = .githooks"
