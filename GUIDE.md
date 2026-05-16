# 新手使用指南

这份指南给完全不熟悉 PowerShell、端口、代理的新手使用。

## 第 1 步：确认 Clash Verge 已经打开

先打开 Clash Verge / Mihomo，确认它能正常上网。

如果你能通过 Clash 打开 ChatGPT、Google、GitHub 这类网站，说明代理本身大概率是正常的。

## 第 2 步：找到你的代理端口

端口就是一个数字，比如 `7897`、`7890`、`7895`、`10809`。

优先使用 Clash Verge 里显示的“混合代理端口 / Mixed Port”。不要优先使用 `redir-port`、`tproxy-port`、`tun` 相关端口。

### 方法 A：自动检测，最推荐

最简单方式：双击这个文件：

```text
Run-CheckPort.cmd
```

这个文件会自动在当前项目文件夹里运行，不要求项目必须放在 D 盘，也不怕你把文件夹改名。

如果你想手动打开 PowerShell，就先进入“你实际下载的文件夹”，再输入：

```powershell
powershell -ExecutionPolicy Bypass -File .\Check-ClashPort.ps1
```

进入实际下载文件夹的方法：在文件资源管理器里打开这个项目文件夹，右键空白处，选择“在终端中打开”或“在 PowerShell 中打开”。

它会显示类似结果：

```text
Configured Clash/Mihomo mixed port:
7897

Possible local proxy ports:

LocalAddress LocalPort ProcessName
------------ --------- -----------
127.0.0.1         7897 verge-mihomo

Suggested command:
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7897
```

复制最后一行 `Suggested command` 运行即可。

### 方法 B：从 Clash Verge 界面看

打开 Clash Verge，通常在这些位置能看到端口：

- 设置
- 网络设置
- 系统代理
- 混合代理端口 / Mixed Port

如果显示：

```text
混合代理端口：7897
```

那运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7897
```

如果显示：

```text
混合代理端口：7895
```

那运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7895
```

如果显示的是任何其他数字，比如 `12345`，就把 `-ProxyPort` 后面的数字改成它：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 12345
```

## 第 3 步：运行修复脚本

最简单方式：双击这个文件：

```text
Run-Fix-AutoDetect.cmd
```

如果你想手动打开 PowerShell，就先进入“你实际下载的文件夹”，再运行自动检测端口：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort
```

进入实际下载文件夹的方法：在文件资源管理器里打开这个项目文件夹，右键空白处，选择“在终端中打开”或“在 PowerShell 中打开”。

如果自动检测不准，就手动指定端口：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 你的端口
```

例子：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7897
```

## 第 4 步：重启顺序很重要

脚本运行完以后：

1. 完全退出 Codex。
2. 完全退出 Clash Verge，不只是关闭窗口，要从托盘图标里退出。
3. 重新打开 Clash Verge。
4. 等 Clash Verge 显示代理正常。
5. 再重新打开 Codex。

## 如果代理不在本机

大多数人都是本机代理，地址是：

```text
127.0.0.1
```

如果你的 Clash / Mihomo 在另一台电脑、路由器或局域网设备上，例如：

```text
192.168.1.10:7897
```

那么运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyHost 192.168.1.10 -ProxyPort 7897
```

## 先试运行，不实际修改

如果你担心脚本会改坏，可以先用 `-WhatIf`：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort -WhatIf
```

它只会显示准备修改什么，不会真的修改。

## 常见问题

### 1. 我找不到 7897，怎么办？

不用必须是 `7897`。每个人的 Clash 端口都可能不同。

你只需要找到自己的“混合代理端口 / Mixed Port”，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 你的端口
```

### 2. 我看到好几个端口，应该选哪个？

优先顺序：

1. 选 Clash Verge 显示的“混合代理端口 / Mixed Port”。
2. 如果没有 Mixed Port，再选 HTTP Port。
3. 不要选 redir-port、tproxy-port、TUN 端口。

例如同时看到 `7892` 和 `7897`，而 Clash 显示 `mixed-port: 7897`，就选 `7897`。

### 3. PowerShell 提示不能运行脚本怎么办？

使用 README 里的完整命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort
```

`-ExecutionPolicy Bypass` 只对这一次运行生效。

### 4. 运行后还是 reconnect 怎么办？

按顺序检查：

- Clash Verge 是否先于 Codex 启动。
- Codex 和 Clash Verge 是否都完全重启过。
- Clash 节点是否固定，不要用自动测速切换节点。
- 换一个稳定节点再试。
- 再用管理员 PowerShell 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort -TryWinHttpImport
```

### 5. 脚本会删除文件吗？

不会。脚本只会设置环境变量、修改 Clash Verge 的几个配置项，并创建备份文件。
