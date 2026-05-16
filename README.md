# Codex reconnect 5 次解决脚本

这个项目用于修复 Windows 上使用 Clash Verge / Mihomo 时，Codex 反复出现 `reconnect 5` 的问题。

如果你是新手，先看 [GUIDE.md](./GUIDE.md)，里面有一步一步的截图式文字流程。

## 一句话使用

最简单方式：双击运行：

```text
Run-Fix-AutoDetect.cmd
```

这个方式不要求项目必须放在 D 盘，也不怕你把文件夹改名。

如果你想用 PowerShell，先进入“你实际下载的文件夹”，再运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort
```

运行完成后，完全退出 Codex 和 Clash Verge，再先打开 Clash Verge，后打开 Codex。

## 如果自动检测失败

先查看本机可能的 Clash 端口：

双击：

```text
Run-CheckPort.cmd
```

或者在 PowerShell 里运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Check-ClashPort.ps1
```

如果它提示端口是 `7897`：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7897
```

如果它提示端口是 `7895`：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7895
```

如果你的 Clash 界面显示的是其他端口，比如 `12345`，就把命令里的端口换成 `12345`：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 12345
```

端口选择规则：

- 优先选 Clash Verge 的“混合代理端口 / Mixed Port”。
- 如果没有 Mixed Port，再选 HTTP Port。
- 不要选 redir-port、tproxy-port、TUN 端口。
- 如果同时看到 `7892` 和 `7897`，通常 `7897` 才是 mixed-port。

如果 Clash / Mihomo 不在本机，而是在局域网其他设备上，例如代理地址是 `192.168.1.10:7897`：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyHost 192.168.1.10 -ProxyPort 7897
```

这些命令是在 PowerShell 里运行的，不需要写进 `.ps1` 文件里面。

## 这个脚本会做什么

`Fix-CodexReconnect5.ps1` 会执行这些修复：

- 设置 Codex 可继承的用户级代理环境变量。
- 设置 `NO_PROXY=localhost,127.0.0.1,::1`，避免本地服务被代理。
- 给 Windows 系统代理绕过列表补上 `::1`。
- 自动读取 Clash Verge 当前配置，在规则增强文件里添加 OpenAI/Codex 相关域名。
- 设置 Clash Verge merge 增强：`ipv6: false`。
- 设置 Clash Verge：`auto_close_connection: false`。
- 修改 Clash Verge 文件前创建 `.bak-时间戳` 备份。

脚本不会删除任何文件。

## 预演模式

想先看脚本会做什么，不实际修改：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort -WhatIf
```

## 管理员模式可选项

少数后台组件可能走 WinHTTP。这个设置需要管理员权限。

用管理员 PowerShell 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort -TryWinHttpImport
```

如果不是管理员，脚本会提示失败，但其他修复仍然有效。

## 文件说明

- `Fix-CodexReconnect5.ps1`：主修复脚本。
- `Check-ClashPort.ps1`：只读端口检查脚本。
- `Run-Fix-AutoDetect.cmd`：双击运行主修复脚本，自动检测端口。
- `Run-CheckPort.cmd`：双击检查 Clash 端口。
- `GUIDE.md`：新手详细指南。
- `.gitignore`：忽略备份和日志文件。

## 手动恢复环境变量

如果需要清除脚本设置的用户级环境变量，在 PowerShell 中运行：

```powershell
[Environment]::SetEnvironmentVariable("HTTP_PROXY", $null, "User")
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", $null, "User")
[Environment]::SetEnvironmentVariable("ALL_PROXY", $null, "User")
[Environment]::SetEnvironmentVariable("http_proxy", $null, "User")
[Environment]::SetEnvironmentVariable("https_proxy", $null, "User")
[Environment]::SetEnvironmentVariable("all_proxy", $null, "User")
[Environment]::SetEnvironmentVariable("NO_PROXY", $null, "User")
[Environment]::SetEnvironmentVariable("no_proxy", $null, "User")
```

Clash Verge 配置可以用脚本生成的 `.bak-时间戳` 文件手动对比恢复。
