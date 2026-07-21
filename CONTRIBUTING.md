# Contributing

## Development Rules

- Keep Bash simple and readable.
- Keep protocol logic in `lib/`.
- Do not add SSH hardening or VPS hardening features to this project.
- Do not use `latest` download URLs.
- Do not commit generated runtime output.
- Preserve idempotency: repeat installs must not rotate credentials.

## Checks

Run:

```bash
shellcheck install.sh uninstall.sh lib/*.sh tests/*.bats
bats tests
bash tests/validate_static.sh
```

If Docker is available, also run container smoke tests from `tests/docker/`.
