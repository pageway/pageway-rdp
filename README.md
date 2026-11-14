# Pageway

**English** | [简体中文](README.zh-CN.md)

Self-hosted remote desktop for a Windows PC, delivered through its own web page. The gateway runs on the controlled PC; no central service, account system, or separate remote client is required.

**Everything is a page away.**

[![Release](https://img.shields.io/github/v/release/pageway/pageway-rdp)](https://github.com/pageway/pageway-rdp/releases)
[![Release workflow](https://github.com/pageway/pageway-rdp/actions/workflows/release.yml/badge.svg)](https://github.com/pageway/pageway-rdp/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

<img src="docs/images/login.png" alt="Pageway Windows sign-in page" width="480">

## Features

- Runs directly on the controlled Windows PC and connects only to its local RDP service.
- Uses IronRDP in the browser for CredSSP/NLA, desktop decoding, and rendering.
- Supports dynamic resolution, HiDPI physical-pixel rendering, actual-size/fit/fill scaling, and 32-bit lossless or 16-bit compressed graphics.
- Provides fullscreen mode, Ctrl+Alt+Del, Windows key, a pinnable auto-hiding connection bar, and clipboard integration.
- Includes Simplified Chinese and English interfaces, plus light, dark, and system themes.
- Ships x64 and ARM64 installers for machine-wide or current-user installation.

## Requirements

Pageway supports Windows 10/11 Pro, Enterprise, and Education, and Windows Server 2016 or later. Windows Home does not include an RDP server and cannot be the controlled PC.

The installer checks for the native Windows RDP host components; it does not install or replace Windows components. The controlled PC needs no Rust, Node.js, Python, or additional runtime.

Use a current Chromium-based browser or Firefox on the connecting device.

## Install

Download the appropriate installer from [Releases](https://github.com/pageway/pageway-rdp/releases/latest):

| Scope | Architecture | File |
| --- | --- | --- |
| All users, administrator required | x64 (AMD64) | `Pageway-Setup-1.0.0-windows-x64.exe` |
| Current user | x64 (AMD64) | `Pageway-Setup-1.0.0-windows-x64-user.exe` |
| All users, administrator required | ARM64 | `Pageway-Setup-1.0.0-windows-arm64.exe` |
| Current user | ARM64 | `Pageway-Setup-1.0.0-windows-arm64-user.exe` |

The bilingual installer defaults to port `7172`. It enables Remote Desktop, adds a firewall exception for Pageway, and starts Pageway after Windows sign-in. A current-user installation can request administrator approval once for these system changes.

Open **Pageway** from the Start menu, or visit:

```text
http://127.0.0.1:7172/
```

## Connect

Sign in with the Windows username and password of the controlled PC. From another device, replace `127.0.0.1` with the PC's LAN or private-overlay-network address.

Pageway remembers the last username and display preferences. It does not store the Windows password; password storage is left to the browser's password manager.

### First connection and certificate trust

When another device first connects over HTTP, Pageway asks how to trust the PC's local certificate.

<img src="docs/images/first-trust.png" alt="Pageway certificate identity confirmation" width="720">

- **Trust permanently and connect**: download the platform-specific trust file and follow the on-screen steps. On Windows, the same local root certificate works with Chrome, Edge, and Firefox 120 or later.
- **Continue this time only**: continue through the browser's certificate warning with **Advanced → Proceed**. Chrome and Edge normally ask again after about seven days.
- **Limited mode**: stay on HTTP without trusting the certificate. Clipboard transfer uses the manual text panel, and fullscreen system-key capture is unavailable.

Both trust options use HTTPS and WSS for the remote session. The local CA is restricted to the PC name and private-network addresses. Pageway replaces the website certificate when local IP addresses change, without requiring the root certificate to be imported again.

> **Security:** do not expose the Pageway port directly to the public internet. Use a trusted LAN or a private overlay network.

### During a session

The connection bar provides fullscreen, Ctrl+Alt+Del, Windows key, clipboard, and disconnect controls. It is pinned by default. Unpin it to hide automatically after three seconds; move the pointer to the top edge to reveal it again. On HTTPS, Chromium can capture Windows shortcuts in fullscreen mode.

The default display mode uses actual size, 32-bit lossless graphics, dynamic resolution, and physical pixels matching the local display scale. Open **Advanced** before connecting to choose fit/fill scaling or 16-bit compressed graphics.

On localhost or HTTPS, Chromium can synchronize text, HTML, and PNG clipboard content automatically. Firefox and HTTP sessions use the clipboard panel for manual text transfer.

Current limitations include no audio, microphone, camera, or video redirection.

## Settings and uninstall

Run the installer again to change the web port. The RDP destination is fixed to `127.0.0.1:3389`; Pageway is not an intermediate RDP proxy.

Configuration, logs, and local certificates are stored in `%LOCALAPPDATA%\Pageway`:

```text
config.json
gateway.log
tls\
```

Uninstall Pageway from Windows **Installed apps**. The uninstaller can ask whether to keep configuration and logs. Silent uninstall removes them:

```powershell
& "$env:ProgramFiles\Pageway\uninstall.exe" /S
```

For a current-user installation, the uninstaller is under `$env:LOCALAPPDATA\Programs\Pageway\uninstall.exe`. Uninstalling does not disable Windows Remote Desktop, because it may have been enabled before installation or used by other software.

## Roadmap

The following phases are planned, not commitments for the current release. Each phase must preserve the product boundary: one gateway on each controlled PC, no central account or management service, no mandatory relay, no public-internet exposure by default, and no silent storage of credentials.

### Phase 2 — Complete the everyday RDP experience

**Goal:** make the existing Windows RDP client suitable for longer daily sessions before adding more protocols.

- **Audio:** add remote audio output first, with mute and volume controls. Evaluate microphone input separately; camera and video redirection must not be exposed as working options until they have real end-to-end support.
- **Files and drives:** build on IronRDP's file-transfer support for explicit upload/download, then evaluate drive redirection. Require visible user actions and clear remote/local direction; never expose an entire local disk by default.
- **Input coverage:** verify Unicode, IME, international keyboard layouts, key-up cleanup after focus loss, and special combinations on Chromium and Firefox.
- **Display coverage:** test multi-monitor layouts, monitor changes, DPI changes, window resizing, and fullscreen transitions without losing the existing dynamic-resolution and no-overflow behavior.
- **Quality gate:** repeat Windows 10/11 and Windows Server tests, poor-network and long-session tests, clipboard regression tests, and disconnect/reconnect cleanup. Keep features that are not fully implemented out of the release UI.

### Phase 3 — Add VNC without changing the product model

**Goal:** connect a browser to an existing VNC server on the controlled machine through the same kind of local web page, while leaving the RDP path independent.

- Select a maintained RFB/VNC implementation after reviewing its license, protocol coverage, and WebAssembly or gateway integration costs; keep protocol code separate from shared UI.
- Start with desktop video, keyboard/mouse input, scaling, and text clipboard. Treat server-side resizing, audio, and file transfer as separate capabilities rather than assuming RDP behavior carries over.
- Design authentication and transport security per VNC server. Do not describe legacy VNC password authentication as encrypted, do not accept unknown TLS identities silently, and do not reuse the RDP certificate UI without adapting its meaning.
- Define the supported gateway operating systems and installers explicitly. A Linux VNC host must not weaken or complicate the existing Windows RDP installer.
- Test against at least two maintained VNC servers, including wrong-password, disconnect, resize, keyboard-layout, and untrusted-network cases. Document any server-specific limitation next to the connection option.

### Phase 4 — Add SSH terminal access

**Goal:** provide a browser terminal for the controlled machine's own SSH server, with the same no-central-service boundary.

- Use a maintained SSH implementation after license and security review. Support password and keyboard-interactive authentication first; private keys and passphrases, if added, must remain in memory and never be written to Pageway configuration or logs.
- Implement host-key verification before authentication, with a clear fingerprint confirmation flow and a hard failure when a previously trusted host key changes. Do not default to accepting every host key.
- Provide UTF-8 rendering, terminal resize, colors, scrollback, clipboard, and reliable control keys. Keep terminal session state separate from RDP/VNC components.
- Defer port forwarding, agent forwarding, SFTP, and tunneling until the basic terminal is stable; none should be enabled implicitly.
- Test Windows OpenSSH Server and at least one maintained Linux SSH server, covering host-key mismatch, authentication failure, disconnects, resize, non-ASCII text, and secret-free logs.

## Architecture

```text
Browser (IronRDP WASM) ── WebSocket / RDCleanPath ──> Pageway gateway ── TLS ──> Local RDP service (3389)
```

The browser performs CredSSP/NLA, desktop decoding, and rendering. The Rust gateway handles protocol ingress, TLS termination, and bidirectional byte relay.

## Development

Build instructions, repository layout, checks, and the release process are in [CONTRIBUTING.md](CONTRIBUTING.md). User-facing changes are recorded in [CHANGELOG.md](CHANGELOG.md).

## License

Pageway is available under the [MIT License](LICENSE).

Thanks to [Devolutions IronRDP](https://github.com/Devolutions/IronRDP) for the RDP protocol stack and web client. Pageway's IronRDP changes are maintained in the fork referenced by the `IronRDP` submodule.
