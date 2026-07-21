# Risk Assessment

## Main Safety Risks

### Existing Proxy Stack

Risk: the VPS may already have Xray, Hysteria2, 3X-UI, or KitTUI installed.

Mitigation:

- Detect `xray.service`, `hysteria2.service`, `x-ui.service`.
- Detect 3X-UI processes.
- Detect existing `/usr/local/etc/xray/`, `/etc/xray/`, `/etc/hysteria/`, `/opt/kittui/`.
- Abort by default before dependency installation or file writes.
- Require explicit `--force-replace` to continue after timestamped backup.

### User Lockout

Risk: SSH or firewall changes can disconnect the user.

Mitigation:

- No SSH configuration changes.
- No root login changes.
- No password authentication changes.
- No `authorized_keys` changes.
- No UFW enable/reset/default policy changes.
- No sysctl or BBR changes.

### Port Collision

Risk: `443/TCP` or `443/UDP` may already be in use.

Mitigation:

- TCP and UDP are checked independently.
- Occupying process is shown when available.
- Fallback port is printed.
- Non-443 compatibility warning is printed.

### Binary Tampering

Risk: downloaded binaries may be corrupted or replaced.

Mitigation:

- Fixed release versions only.
- SHA-256 verification before install.
- Abort before config generation or service start on mismatch.

### Sensitive Output Leakage

Risk: generated private keys or passwords could be committed or exposed.

Mitigation:

- Runtime output and state are ignored by git.
- `state.json` is `0600`.
- Output generator checks for Reality private-key fields.
- Public repo examples use documentation placeholders only.

### Domain Mode

Risk: automatic ACME may overwrite existing Nginx, Caddy, or Apache configs.

Mitigation:

- Domain mode is gated behind explicit `--hysteria-domain`.
- Existing web servers cause immediate termination.
- The default workflow uses self-signed no-domain Hysteria2.

## Reused Logic From Reference Project

Reusable ideas:

- Modular Bash layout.
- JSON state management with idempotent credentials.
- Candidate port scanning.
- Generated client outputs.
- Shell fixture testing.

Rewritten logic:

- Service names and paths.
- Firewall handling.
- Protocol output formats.
- Conflict detection.
- Binary installation paths.
- Uninstall boundaries.

Excluded logic:

- SSH user/login setup.
- VPS hardening.
- Fail2ban.
- BBR/sysctl.
- Nginx default installation.
- Global Xray/Hysteria2 service replacement.
