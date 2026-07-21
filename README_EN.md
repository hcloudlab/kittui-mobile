# KitTUI Mobile Lite

KitTUI Mobile Lite is a lightweight Bash installer for deploying Xray VLESS Reality and no-domain Hysteria2 on an existing VPS.

It deploys protocols only. It does not harden the operating system.

## What It Does Not Do

The installer does not create SSH login users, edit root login policy, edit `sshd_config`, change SSH ports, enable or reset UFW, install Fail2ban, modify BBR/sysctl settings, or overwrite existing 3X-UI, Xray, or Hysteria2 installations.

If an existing Xray, Hysteria2, or 3X-UI environment is detected, installation stops by default. Use `--force-replace` only when you explicitly accept the backup-and-continue behavior.

## Supported Targets

- Ubuntu 22.04
- Ubuntu 24.04
- Debian 11
- Debian 12
- amd64
- arm64

## Defaults

- Reality: `443/TCP`
- Hysteria2: `443/UDP`

TCP and UDP are checked separately, so both protocols may use numeric port `443`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/kittui-mobile/main/install.sh | sudo bash -s -- install
```

Local development checkout:

```bash
sudo bash install.sh install
```

## Commands

```bash
sudo kittui-mobile status
sudo kittui-mobile show
sudo kittui-mobile repair
sudo kittui-mobile uninstall
```

## Output

Files are generated under `/opt/kittui-mobile/output/`, including share links, raw/base64 subscription files, Mihomo configs, sing-box configs, and separate QR codes for Reality and Hysteria2 when `qrencode` is available.

## Firewall Notice

The script cannot change your VPS provider's cloud firewall. Confirm in the cloud console that the displayed TCP and UDP ports are open.
