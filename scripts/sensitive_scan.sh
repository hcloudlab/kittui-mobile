#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

patterns=(
  'PRIVATE KEY'
  'BEGIN OPENSSH PRIVATE KEY'
  'hysteria2://[^[:space:]]+@[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
  'vless://[0-9a-fA-F-]{36}@'
)

for pattern in "${patterns[@]}"; do
  if grep -RIE "$pattern" "$ROOT" \
    --exclude-dir=.git \
    --exclude-dir=.test-output \
    --exclude='sensitive_scan.sh' \
    --exclude='*.md' >/dev/null; then
    printf 'Sensitive pattern matched: %s\n' "$pattern" >&2
    exit 1
  fi
done

printf 'Sensitive scan passed.\n'
