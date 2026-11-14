# Contributing to Pageway RDP

This document contains maintainer and developer instructions. For installation and day-to-day use, see [README.md](README.md) or [README.zh-CN.md](README.zh-CN.md).

## Repository layout

```text
frontend/             Pageway RDP web interface and first-trust page
gateway/              Rust HTTP/HTTPS/WebSocket gateway and tests
IronRDP/              Pageway's IronRDP fork, pinned as a Git submodule
packaging/            Build scripts and NSIS installer
assets/               Application logos and installer images
docs/images/          Images referenced by GitHub documentation
.github/workflows/    Automated packaging and releases
```

## Prerequisites

Build installers on Windows with:

- Rust stable and `rustup`
- `wasm-pack`
- Node.js 22 or later
- NSIS (`choco install nsis`)

The build statically links the Windows CRT. Target machines do not need these tools.

## Clone and build

Clone the repository and the pinned IronRDP submodule together:

```powershell
git clone --recurse-submodules https://github.com/pageway/pageway-rdp.git
cd pageway-rdp
```

Build the x64 installer:

```powershell
.\packaging\build.ps1 -Arch x64
```

Other common builds:

```powershell
# Build the ARM64 installer
.\packaging\build.ps1 -Arch arm64

# Build only the WASM and web frontend
.\packaging\build.ps1 -FrontendOnly

# Rebuild an installer using an existing frontend/dist
.\packaging\build.ps1 -SkipFrontend -Arch x64
```

Installers are written to `dist/`. They install for all users and require administrator approval. The build script also applies the required Vite compatibility adjustment to generated wasm-bindgen glue and links the Windows CRT statically.

For frontend development, build the WASM package once and then start Vite:

```powershell
.\packaging\build.ps1 -FrontendOnly
cd frontend
npm run dev
```

## IronRDP submodule

Pageway's changes are maintained directly in the `IronRDP` submodule on the `pageway` branch of [pageway/IronRDP](https://github.com/pageway/IronRDP). They are not temporary build patches.

When changing the submodule:

1. Review the upstream and dependency licenses, retain attribution, and test the corresponding behavior.
2. Commit and push the IronRDP change in the submodule repository.
3. In the parent repository, update the `IronRDP` gitlink to that committed revision.
4. Verify that a fresh `git clone --recurse-submodules` obtains the same source and builds successfully.

Do not leave the parent repository pointing at a local-only submodule commit; GitHub Actions cannot fetch it.

## Checks

Run these checks before submitting changes:

```powershell
npm ci --prefix frontend
npm run build --prefix frontend
cargo test --manifest-path gateway/Cargo.toml
cargo fmt --manifest-path gateway/Cargo.toml --check
cargo fmt --manifest-path IronRDP/Cargo.toml --check
git diff --check
git -C IronRDP diff --check
```

For UI changes, also open the actual page in a browser and exercise the golden path and relevant edge cases. Build success and static checks do not replace an RDP sign-in, fullscreen, clipboard, disconnect, and reconnect test when those paths are affected.

Never put real Windows passwords, private keys, certificates with private keys, or other credentials in source files, screenshots, test scripts, logs, issues, or commit messages. Clean up temporary browser profiles, test processes, remote installations, and certificate exceptions after testing.

## Documentation

- `README.md` is the default English GitHub landing page and is written for users.
- `README.zh-CN.md` is the Simplified Chinese counterpart. Keep both files synchronized and use relative paths such as `docs/images/login.png` so GitHub renders images directly.
- `CHANGELOG.md` (English) and `CHANGELOG.zh-CN.md` (Simplified Chinese) contain user-facing changes. Keep the same version sections in both; together they become the GitHub Release description.
- Developer and release instructions belong here rather than expanding the user README.

## Automated packaging and release

The [`release`](.github/workflows/release.yml) workflow supports manual runs and version tags.

### 1. Build and inspect artifacts without publishing

1. Push the intended commit to GitHub.
2. Open **Actions → release → Run workflow** and run it from the intended branch.
3. Wait for `notes` and `installers` to succeed. `installers` builds the web frontend once, then both architectures, and fails unless exactly the two expected installers exist.
4. Download the two installers from the workflow run's **Artifacts** section. Each artifact is a single uncompressed `.exe`:
   - `Pageway-RDP-Setup-x.y.z-windows-x64.exe`
   - `Pageway-RDP-Setup-x.y.z-windows-arm64.exe`
5. Install and test the downloaded packages.
6. Open the `notes` job summary on the run page to preview the description the tag run will put on the GitHub Release page.

A manual run uploads artifacts only; it does not create a GitHub Release.

### 2. Prepare version metadata

Before tagging, update the same version in:

- `VERSION`
- `gateway/Cargo.toml`
- `frontend/package.json`
- `frontend/package-lock.json`

Add a matching `## [x.y.z] - YYYY-MM-DD` section to both `CHANGELOG.md` and `CHANGELOG.zh-CN.md`. The `notes` job rejects a tag that does not match `VERSION`, and `packaging/release_notes.ps1` fails if either section is missing.

The script builds the Release description from the English section, followed by the Chinese section inside a collapsed `<details>` block. Preview it locally with:

```powershell
.\packaging\release_notes.ps1 release-notes.md
```

### 3. Publish a release

After the artifacts and metadata have been verified, create and push a matching tag:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

The tag run rebuilds the two installers and creates a GitHub Release with only those two files attached. Its description shows English by default, with Simplified Chinese collapsed below it.

> Pushing a version tag creates a public Release immediately in the current workflow. Do not tag a commit until the manual artifacts have passed verification. To change an already tagged release, create a new corrective version instead of silently replacing what users downloaded.
