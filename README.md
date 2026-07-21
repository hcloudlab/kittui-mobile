# KitTUI Mobile Lite

KitTUI Mobile Lite 是一个轻量 Bash 部署脚本，用于在已有 VPS 上快速部署：

- Xray VLESS Reality；
- Hysteria2 无域名自签名模式；
- 本地客户端分享链接和配置文件。

本项目只部署协议，不做系统安全加固。

## 不会做什么

脚本不会创建 SSH 登录用户、不会修改 root 登录、不会修改 `sshd_config`、不会改 SSH 端口、不会启用或重置 UFW、不会安装 Fail2ban、不会修改 BBR/sysctl，也不会覆盖 3X-UI、用户原有 Xray 或 Hysteria2。

检测到已有 Xray、Hysteria2 或 3X-UI 时，默认直接取消安装。只有显式传入 `--force-replace` 才会在备份后继续。

## 支持系统

已纳入测试目标：

- Ubuntu 22.04
- Ubuntu 24.04
- Debian 11
- Debian 12
- amd64
- arm64

## 默认端口

- Reality：`443/TCP`
- Hysteria2：`443/UDP`

TCP 和 UDP 会分别检测，所以两个协议可以同时使用数字端口 `443`。如果端口被占用，脚本会显示占用协议、占用程序、自动选择的新端口，并提示非 443 端口可能影响兼容性。

## 一键安装

正式推荐命令，锁定 `v0.1.0-beta.1`：

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/kittui-mobile/v0.1.0-beta.1/install.sh | sudo bash -s -- install
```

开发版，不建议普通用户使用：

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/kittui-mobile/main/install.sh | sudo bash -s -- install
```

本地开发目录运行：

```bash
sudo bash install.sh install
```

指定 VPS 地址：

```bash
sudo bash install.sh install --server-host YOUR_VPS_IP
```

检测到已有环境但确认要继续：

```bash
sudo bash install.sh install --force-replace
```

不修改防火墙：

```bash
sudo bash install.sh install --no-firewall
```

## 常用命令

```bash
sudo kittui-mobile status
sudo kittui-mobile show
sudo kittui-mobile repair
sudo kittui-mobile uninstall
```

## 输出目录

安装后输出位于：

```text
/opt/kittui-mobile/output/
```

包含：

- `share-links.txt`
- `reality.txt`
- `hysteria2.txt`
- `subscription-raw.txt`
- `subscription-base64.txt`
- `mihomo-complete.yaml`
- `mihomo-provider.yaml`
- `sing-box-complete.json`
- `sing-box-outbounds.json`
- `reality-qr.png`
- `hysteria2-qr.png`
- `install-summary.txt`

二维码是两个独立文件，不会把 Reality 和 Hysteria2 放进同一个二维码。

## Hysteria2 自签名证书风险

默认无域名模式会生成自签名证书，兼容链接会包含 `insecure=1`。这会降低 TLS 验证强度。

脚本同时生成安全增强版链接，包含 Hysteria2 官方 URI 参数 `pinSHA256`。根据 Hysteria2 官方 URI 规范，协议名支持 `hysteria2` 和 `hy2`，`pinSHA256` 用于固定服务器证书 SHA-256 指纹。不同第三方客户端对该参数的兼容程度可能不同；如果导入失败，请先使用 `hysteria2.txt` 中的兼容版，再在客户端内手动配置证书指纹。

## Mihomo

`mihomo-provider.yaml` 只包含代理节点列表。

`mihomo-complete.yaml` 是完整配置，包含基础端口、代理、策略组和规则，可直接选择 Reality 或 Hysteria2。

## sing-box

`sing-box-outbounds.json` 是 outbound 片段。

`sing-box-complete.json` 是完整客户端配置，包含 inbound、outbound 和 route。

## 云防火墙提醒

脚本只能处理 VPS 内部防火墙，无法修改 VPS 厂商的云防火墙。安装完成后，请到云控制台确认已放行显示的 TCP 和 UDP 端口。

## 不提供公开订阅托管

本项目只生成本地节点分享链接和配置文件，不提供匿名公共订阅托管服务。
