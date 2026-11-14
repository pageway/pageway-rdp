# Pageway RDP

[English](README.md) | **简体中文**

把这台 Windows 电脑的远程桌面装进浏览器。网关运行在被控机上，不需要中心服务、账号系统，也不需要在其他设备上安装远程客户端。

**Everything is a page away.**

[![Release](https://img.shields.io/github/v/release/pageway/pageway-rdp)](https://github.com/pageway/pageway-rdp/releases)
[![Release workflow](https://github.com/pageway/pageway-rdp/actions/workflows/release.yml/badge.svg)](https://github.com/pageway/pageway-rdp/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

<img src="docs/images/login.zh-CN.png" alt="Pageway RDP Windows 登录页" width="480">

## 功能

- 直接运行在被控 Windows 电脑上，只连接这台电脑自己的 RDP 服务。
- 浏览器通过 IronRDP 完成 CredSSP/NLA、桌面解码和渲染。
- 支持动态分辨率、高分屏物理像素渲染、原始大小/适应窗口/填满窗口，以及 32 位无损或 16 位压缩图形。
- 提供全屏、Ctrl+Alt+Del、Windows 键、可钉住并自动隐藏的连接栏和剪贴板。
- 支持简体中文/英文，以及浅色、深色和跟随系统主题。
- 提供 x64 和 ARM64 两种安装包。

## 环境要求

Pageway RDP 支持 Windows 10/11 专业版、企业版、教育版，以及 Windows Server 2016 或更高版本。Windows 家庭版不提供远程桌面服务端，无法作为被控机。

安装器会检查原生 RDP 宿主组件，但不会安装或替换 Windows 组件。被控机运行时不需要 Rust、Node.js、Python 或额外运行库。

连接设备请使用较新的 Chromium 浏览器或 Firefox。

## 安装

从 [Releases](https://github.com/pageway/pageway-rdp/releases/latest) 下载适合这台电脑的安装包：

| 处理器架构 | 文件 |
| --- | --- |
| x64（AMD64） | `Pageway-RDP-Setup-1.0.0-windows-x64.exe` |
| ARM64 | `Pageway-RDP-Setup-1.0.0-windows-arm64.exe` |

双语安装器需要管理员授权，默认使用端口 `7172`。安装器会启用本机远程桌面、允许 Pageway RDP 通过防火墙，并设置登录 Windows 后自动启动。

从开始菜单打开 **Pageway RDP**，或直接访问：

```text
http://127.0.0.1:7172/
```

## 连接

输入被控电脑的 Windows 用户名和密码。其他设备把 `127.0.0.1` 换成这台电脑的局域网或私网组网地址。

Pageway RDP 会记住上次输入的用户名和显示偏好，自身不保存 Windows 密码；密码由浏览器密码管理器按需保存。

### 首次连接与证书信任

第一次从其他设备通过 HTTP 访问时，Pageway RDP 会要求选择如何信任被控电脑的本机证书。

<img src="docs/images/first-trust.zh-CN.png" alt="Pageway RDP 证书身份确认弹窗" width="720">

- **永久信任并连接**：下载对应平台的信任文件并按页面步骤操作。Windows 上同一个本机根证书可供 Chrome、Edge 和 Firefox 120 及以上版本使用。
- **仅本次继续**：在浏览器安全警告页选择“高级 → 继续前往”。Chrome 和 Edge 通常约 7 天后会再次询问。
- **受限模式**：不信任证书并继续使用 HTTP。剪贴板通过手动文本面板收发，全屏系统组合键捕获不可用。

两种信任方式的远程会话都使用 HTTPS 和 WSS。本机根证书仅允许本机名和私网地址。本机 IP 变化时网关会自动换发网站证书，无需重新导入根证书。

> **安全提示：**不要把 Pageway RDP 端口直接暴露到公网。请只在可信局域网或私网组网中使用。

### 会话操作

顶部连接栏提供全屏、Ctrl+Alt+Del、Windows 键、剪贴板和断开连接。默认钉住；取消钉住后 3 秒自动隐藏，鼠标移到屏幕顶边可重新打开。HTTPS 页面中，Chromium 全屏时可以捕获 Windows 组合键。

默认使用原始大小、32 位无损图形和动态分辨率，并按本机屏幕缩放比例使用物理像素。连接前可在“高级”中改为适应窗口、填满窗口或 16 位压缩图形。

在 localhost 或 HTTPS 页面中，Chromium 可自动同步文本、HTML 和 PNG 图片。Firefox 和 HTTP 会话通过剪贴板面板手动收发文本。

当前版本还不支持声音、打印、文件传输、麦克风和摄像头，见[后续路线](#后续路线)。

## 设置与卸载

需要修改网页端口时，重新运行安装器。RDP 目标固定为 `127.0.0.1:3389`，Pageway RDP 不提供中间 RDP 代理模式。

配置、日志和本机证书位于 `%LOCALAPPDATA%\Pageway RDP`：

```text
config.json
gateway.log
tls\
```

在 Windows“安装的应用”中卸载 Pageway RDP。卸载时可选择是否保留配置和日志，静默卸载会同时删除它们：

```powershell
& "$env:ProgramFiles\Pageway RDP\uninstall.exe" /S
```

卸载不会关闭 Windows 远程桌面，因为它可能在安装前已经启用或被其他用途使用。

## 后续路线

Pageway RDP 的目标是：原生远程桌面客户端（mstsc）有的功能，只要浏览器允许，Pageway RDP 都要有，并尽量按 mstsc 的方式处理。整体分为四期，每期在真实 Windows 主机上测试后作为一个小版本单独发布。各期的产品边界不变：只连接本机自己的 RDP 服务 `127.0.0.1:3389`，不做中心服务器，不安装 Windows 组件。

标注 **HTTPS** 的功能需要安全页面（已信任证书或通过 localhost 访问），受限模式下浏览器会禁用相关接口。

### 第一期：基础（1.0.0 已完成）

- IronRDP 改为 fork 子模块直接维护，不再在构建时打补丁。
- 同一端口提供 HTTPS/WSS 和 HTTP，首次信任弹窗，以及各平台的证书下载。
- 高分屏清晰度：会话按本机屏幕缩放比例使用物理像素和缩放系数。
- 全屏、mstsc 式连接栏，全屏时捕获 Windows 组合键。
- HTTPS 下文本、HTML、图片剪贴板；HTTP 下保留手动文本面板。

### 第二期：本地资源

对应 mstsc 的“本地资源”选项卡。

- **远程音频**，与 mstsc 一样提供三个选项：
  - **在此计算机上播放**（默认）：在浏览器中播放远程声音，先支持 PCM，再加 IMA-ADPCM 以节省流量。HTTP 下同样可用。
  - **在远程计算机上播放**：声音留在远程电脑。
  - **不播放**：即当前行为。
- **打印**：与 mstsc 一样默认开启。远程会话中出现基于 `Microsoft Print to PDF` 驱动的虚拟打印机，每个打印任务在浏览器新标签页中以 PDF 打开，再从那里交给本机打印机。
- **文件传输**：把文件拖进远程画面即可粘贴到远程电脑；在远程电脑上复制的文件会在浏览器中提示下载。把本地文件夹映射为远程盘符放在第四期。
- **音频录制**（HTTPS）：把本机麦克风传到远程电脑。与 mstsc 一样默认关闭。
- **发布验收**：远程系统提示音能在本机播放；在远程记事本打印后浏览器收到 PDF；拖放上传和远程复制后下载都可用；麦克风能在远程会话中录音。

### 第三期：流畅度

对应 mstsc 的“体验”选项卡，以及 mstsc 默认使用的图形通道。

- **批量压缩**：启用 RDP 6.1 批量压缩，几乎零成本地减少流量。
- **连接速度预设**：与 mstsc 一样提供局域网、宽带、低速预设，控制桌面背景、字体平滑、桌面合成、拖动时显示窗口内容、菜单和窗口动画、视觉样式。默认局域网，即全部开启。
- **时区重定向**：把浏览器时区传给远程，远程会话显示本地时间。
- **断线自动重连**：保存服务器下发的自动重连凭据，网络中断后自动重连，并显示 mstsc 式的“正在重新连接”遮罩。
- **图形通道（RDPGFX）**：对流畅度和带宽影响最大的一项。先支持不需要外部解码器的 Planar、ClearCodec、RemoteFX Progressive，再通过 WebCodecs 支持 H.264 AVC420/AVC444 解码（HTTPS）。之后颜色深度选项改为 mstsc 的“最高质量（32 位）”语义。
- **发布验收**：图形通道与服务器协商成功；断开网络后会话自动重连。

### 第四期：实验项

这些功能依赖较新的或特定浏览器才有的接口。

- **多显示器**（HTTPS，Chromium）：通过 Window Management API 让会话跨本机多台显示器。
- **触摸输入**：把触摸手势作为 RDP 多点触控输入发给远程电脑。
- **摄像头**（HTTPS）：把本机摄像头重定向到远程电脑，用 WebCodecs 编码视频。
- **移动端软键盘**：在手机和平板上用屏幕键盘向远程会话输入。
- **本地文件夹映射为远程盘符**（Chromium）：把在浏览器中选择的文件夹映射为远程会话中的驱动器。

### 不在计划内

- 智能卡、串口和并口、USB 及其他即插即用设备：浏览器不提供这些设备所需的访问能力。WebUSB 只覆盖少数设备，仅作为研究项。
- RD 网关、服务器重定向、UDP 传输：超出 Pageway RDP 产品边界，或浏览器无法支持。

## 架构

```text
浏览器（IronRDP WASM）──WebSocket / RDCleanPath──> Pageway RDP 网关 ──TLS──> 本机 RDP 服务（3389）
```

浏览器完成 CredSSP/NLA、桌面解码和渲染。Rust 网关负责协议接入、TLS 终结和双向字节透传。

## 开发与发布

构建命令、目录结构、检查项和发布流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。面向用户的变更记录在 [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md)。

## 许可

Pageway RDP 使用 [MIT 许可证](LICENSE)。

感谢 [Devolutions IronRDP](https://github.com/Devolutions/IronRDP) 提供 RDP 协议栈和 Web 客户端。Pageway RDP 对 IronRDP 的修改维护在 `IronRDP` 子模块所引用的 fork 中。
