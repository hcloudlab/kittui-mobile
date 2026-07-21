# Security Policy

## Public Repository Rules

Do not commit:

- Real server IP addresses.
- UUIDs from live nodes.
- Reality private keys.
- Hysteria2 passwords.
- SSH keys.
- Test server credentials.
- Real proxy links.
- Runtime QR codes.
- Real `state.json`.
- Sensitive logs.

Runtime files are ignored by `.gitignore`, but contributors should still review `git diff` before committing.

## Reporting Issues

Open a GitHub issue for non-sensitive bugs.

For sensitive reports, do not paste keys, logs with credentials, or live node links. Redact values before sharing.
