# KitTUI Mobile Lite Architecture

## Scope

KitTUI Mobile Lite is a protocol-only VPS deployment script for the mobile-first workflow shown in the YouTube video "不用电脑，只用手机5分钟部署Reality和Hysteria2".

It deploys only:

- Xray VLESS Reality over TCP.
- Hysteria2 over UDP with self-signed TLS by default.
- Local client links and config files.
- Status, repair, show, and uninstall commands.

It deliberately does not perform SSH hardening, user login management, Fail2ban setup, BBR tuning, sysctl changes, or broad firewall policy changes.

## Reference Analysis

The original `hcloudlab/kitTUI` project was read-only input. It contains useful patterns for:

- Modular Bash libraries.
- JSON state files.
- Protocol port candidate selection.
- Output generation.
- Shell contract tests and fixtures.

The following logic must be rewritten or excluded for this project:

- SSH account creation and login policy changes.
- `sshd_config` edits.
- UFW default policy changes or `ufw enable`.
- Fail2ban installation.
- BBR/sysctl tuning.
- Default nginx/acme setup.
- Use of global `xray.service` and `hysteria2.service`.
- `v2ray.json` output, which is misleading for Reality.

## Runtime Layout

```text
/opt/kittui-mobile/
├── app/
│   ├── install.sh
│   └── lib/
├── bin/
│   ├── xray
│   └── hysteria
├── config/
│   ├── xray/config.json
│   └── hysteria2/config.yaml
├── certs/
│   ├── hysteria2.crt
│   └── hysteria2.key
├── output/
├── logs/
├── backup/
└── state.json
```

The command installed at `/usr/local/bin/kittui-mobile` sources `/opt/kittui-mobile/app/lib/main.sh`.

## Services

- `kittui-mobile-xray.service`
- `kittui-mobile-hysteria2.service`

Both use isolated service accounts:

- `kittui-xray`
- `kittui-hysteria`

The accounts are system users with `/usr/sbin/nologin`. Low-port binding is handled through systemd capabilities:

- `AmbientCapabilities=CAP_NET_BIND_SERVICE`
- `CapabilityBoundingSet=CAP_NET_BIND_SERVICE`
- `NoNewPrivileges=true`

## Port Selection

Reality TCP candidates:

```text
443 8443 2083 2087 2096
```

Hysteria2 UDP candidates:

```text
443 8443 2053 2083 2087 2096
```

TCP and UDP are checked independently, so both protocols may use numeric port `443` when each transport is free.

When `443` is busy, the script prints:

- Transport type.
- Owning process when available.
- Automatically selected replacement port.
- Compatibility warning for non-443 ports.

## State and Idempotency

`state.json` is permissioned `0600` and stores generated credentials so repeat installs do not rotate:

- Reality UUID.
- Reality private/public key pair.
- Reality Short ID.
- Hysteria2 password.
- Hysteria2 certificate fingerprint.
- Selected ports.
- Firewall rules created by this project.

`show` reads existing output only. `repair` recreates missing project files and services without generating new credentials when state is present.

## Binary Supply Chain

Versions are fixed in `lib/constants.sh`:

- `XRAY_VERSION`
- `HYSTERIA_VERSION`

The installer never downloads `latest`. Xray assets are verified against the fixed release `.dgst` file. Hysteria2 assets are verified against the fixed release `hashes.txt` entry.

Checksum failure aborts before configs are written or services are started.

## Firewall Handling

The script detects UFW, firewalld, nftables, iptables, or no active firewall.

Default behavior:

- UFW active: only add this project's TCP/UDP ports.
- firewalld active: only add this project's TCP/UDP ports.
- nftables/iptables custom rules: print required ports and reference commands; do not modify.
- No active firewall: do not enable one.

Uninstall removes only firewall rules recorded in `state.json`.

## Outputs

`/opt/kittui-mobile/output/` contains:

- `share-links.txt`
- `reality.txt`
- `hysteria2.txt`
- `subscription-raw.txt`
- `subscription-base64.txt`
- `mihomo-complete.yaml`
- `mihomo-provider.yaml`
- `sing-box-complete.json`
- `sing-box-outbounds.json`
- `reality-qr.png` when `qrencode` exists
- `hysteria2-qr.png` when `qrencode` exists
- `install-summary.txt`

The output generator refuses to continue if generated files contain Reality private-key fields.
