#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT"/lib/*.sh "$ROOT"/scripts/*.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT"/lib/*.sh "$ROOT"/scripts/*.sh "$ROOT"/tests/*.bats
else
  printf 'shellcheck not found; skipped static ShellCheck.\n' >&2
fi

if grep -R "releases/latest" "$ROOT"/install.sh "$ROOT"/uninstall.sh "$ROOT"/lib "$ROOT"/scripts >/dev/null; then
  printf 'latest download URL is forbidden.\n' >&2
  exit 1
fi

for forbidden in 'ufw[[:space:]]+reset' 'ufw[[:space:]]+enable' 'systemctl[[:space:]]+.*fail2ban' '>[[:space:]]*/etc/ssh/sshd_config' 'sysctl[[:space:]]+-w' 'authorized_keys' 'PasswordAuthentication[[:space:]]+'; do
  if grep -R "$forbidden" "$ROOT"/install.sh "$ROOT"/uninstall.sh "$ROOT"/lib "$ROOT"/scripts >/dev/null; then
    printf 'Forbidden operation found: %s\n' "$forbidden" >&2
    exit 1
  fi
done

"$ROOT/scripts/sensitive_scan.sh"

printf 'Static validation passed.\n'
