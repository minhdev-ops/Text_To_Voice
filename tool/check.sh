#!/usr/bin/env bash
# Local gate — the same two commands CI will run.
#
#   ./tool/check.sh          # analyze + test
#   ./tool/check.sh --fix    # also apply `dart fix`
#
# Exits non-zero on the first failure so it can be dropped straight into CI.

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--fix" ]]; then
  echo "==> dart fix --apply"
  dart fix --apply
fi

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "==> OK"
