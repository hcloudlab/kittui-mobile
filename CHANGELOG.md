# Changelog

## [0.1.0-beta.1] - 2026-07-21

### Added

- 首个KitTUI Mobile Lite公开测试版本。
- 支持一键部署Xray VLESS Reality和Hysteria2。
- Reality默认优先使用443/TCP。
- Hysteria2默认优先使用443/UDP。
- 支持端口占用检测和候选端口切换。
- 使用独立目录和独立systemd服务，避免覆盖普通Xray与Hysteria2服务。
- 检测现有3X-UI、Xray和Hysteria2环境，默认停止安装。
- 支持UFW、firewalld和自定义防火墙环境检测。
- 生成Shadowrocket、v2rayN、Mihomo、OpenClash和sing-box相关客户端输出。
- 为Reality和Hysteria2分别生成二维码。
- 提供install、status、show、repair和uninstall命令。
- 加入ShellCheck、Bats和GitHub Actions测试。

### Safety

- 不修改SSH账户或SSH配置。
- 不执行系统安全加固。
- 不修改BBR、sysctl或Fail2ban。
- 不启用、重置或更改UFW默认策略。
- 检测到已有代理环境时，默认拒绝覆盖。

### Known limitations

- 本版本仍属于Beta测试版。
- 尚未完成所有VPS厂商和系统镜像的实机验证。
- Hysteria2证书指纹参数在不同第三方客户端中的兼容性可能不同。
- 脚本无法修改VPS厂商控制台中的云防火墙。
- 域名和ACME模式尚未作为本期视频的默认流程验证。
