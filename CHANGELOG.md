# Changelog

**English** | [简体中文](CHANGELOG.zh-CN.md)

## [1.0.0] - 2026-11-13

First stable release.

- The Rust gateway connects the browser over WebSocket and RDCleanPath, terminates TLS to the local RDP service, and relays traffic in both directions.
- The IronRDP WASM web client supports CredSSP/NLA, dynamic resolution, 32-bit lossless or 16-bit compressed graphics, full clipboard on Chromium and a manual text clipboard on Firefox, Simplified Chinese and English, and light, dark, and system themes.
- Run the installer again to change the port. The RDP destination is fixed to this PC, and no separate gateway password is required.
- The bilingual NSIS installer checks the native RDP host components, configures Remote Desktop, the firewall, and startup after sign-in, and provides administrator installers for x64 and ARM64.
- The gateway links the Windows CRT statically, so target PCs need no build tools or extra runtimes.
- One web port serves both HTTPS/WSS and HTTP. On first remote access, a Remote Desktop-style identity prompt lets users continue once or permanently trust the local certificate (shared by Chrome, Edge, and Firefox on Windows). The root certificate is restricted to the PC name and private addresses, and the website certificate is reissued automatically when IP addresses change.
- Physical pixels and RDP scaling follow the browser's display scale, improving sharpness on HiDPI screens.
- The connection bar uses consistently sized icon buttons, can be pinned, auto-hidden, and revealed from the top edge, and provides fullscreen, Ctrl+Alt+Del, Windows key, clipboard, and disconnect controls. Fullscreen HTTPS sessions can capture system shortcuts.
- Pageway's IronRDP changes are maintained directly in the submodule source instead of being patched during the build.
