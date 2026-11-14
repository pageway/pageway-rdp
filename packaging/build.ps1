[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string]$Arch = 'x64',
    [switch]$FrontendOnly,
    [switch]$SkipFrontend
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$IronRdp = Join-Path $Root 'IronRDP'
$WebCrate = Join-Path $IronRdp 'crates\ironrdp-web'
$Component = Join-Path $IronRdp 'web-client\iron-remote-desktop'
$Frontend = Join-Path $Root 'frontend'
$Version = (Get-Content -Raw (Join-Path $Root 'VERSION')).Trim()
$CargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (Test-Path $CargoBin) {
    $env:PATH = "$CargoBin;$env:PATH"
}

function Invoke-Native {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory = $Root
    )
    Write-Host "+ $FilePath $($ArgumentList -join ' ')"
    Push-Location $WorkingDirectory
    try {
        & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "$FilePath exited with code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

function Build-Frontend {
    Invoke-Native 'rustup.exe' @('target', 'add', 'wasm32-unknown-unknown')
    $previousRustFlags = $env:RUSTFLAGS
    try {
        $env:RUSTFLAGS = '--cfg getrandom_backend="wasm_js" -Ctarget-feature=+simd128,+bulk-memory'
        $wasmArguments = @('build', '--target', 'web', $WebCrate)
        $lock = [IO.File]::ReadAllText((Join-Path $IronRdp 'Cargo.lock'))
        $versionMatch = [regex]::Match($lock, '(?m)^name = "wasm-bindgen"\r?\nversion = "([^"]+)"')
        if ($versionMatch.Success) {
            $cache = Join-Path $env:LOCALAPPDATA "wasm-pack\wasm-bindgen-$($versionMatch.Groups[1].Value)"
            if (Test-Path (Join-Path $cache 'wasm-bindgen.exe')) {
                $env:PATH = "$cache;$env:PATH"
                $wasmArguments = @('build', '--mode', 'no-install', '--target', 'web', $WebCrate)
            }
        }
        Invoke-Native 'wasm-pack.exe' $wasmArguments
    } finally {
        $env:RUSTFLAGS = $previousRustFlags
    }

    $gluePath = Join-Path $WebCrate 'pkg\ironrdp_web.js'
    $glue = Get-Content -Raw $gluePath
    $original = "new URL('ironrdp_web_bg.wasm', import.meta.url)"
    if ($glue.Contains($original)) {
        $glue = $glue.Replace($original, 'wasmUrl')
        [IO.File]::WriteAllText($gluePath, "import wasmUrl from './ironrdp_web_bg.wasm?url';`n$glue")
    } elseif (-not $glue.Contains('import wasmUrl')) {
        throw "Unexpected wasm-bindgen glue in $gluePath"
    }

    $TsConfig = Join-Path $Component 'node_modules\@tsconfig\svelte'
    New-Item -ItemType Directory -Path $TsConfig -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $TsConfig 'package.json'), '{"name":"@tsconfig/svelte","version":"5.0.0"}')
    $tsconfigContent = @'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "allowJs": true,
    "checkJs": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": true
  }
}
'@
    [IO.File]::WriteAllText((Join-Path $TsConfig 'tsconfig.json'), $tsconfigContent)

    Invoke-Native 'npm.cmd' @('ci') $Frontend
    Invoke-Native 'npm.cmd' @('run', 'build') $Frontend
}

function New-InstallerBitmap {
    param(
        [string]$Source,
        [string]$Destination,
        [int]$Width,
        [int]$Height,
        [string]$Tag
    )
    Add-Type -AssemblyName System.Drawing
    $image = [Drawing.Image]::FromFile($Source)
    try {
        $bitmap = [Drawing.Bitmap]::new($Width, $Height)
        try {
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([Drawing.Color]::White)
                $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $scale = [Math]::Min(($Width - 20) / $image.Width, ($Height - 20) / $image.Height)
                $drawWidth = [int]($image.Width * $scale)
                $drawHeight = [int]($image.Height * $scale)
                $x = [int](($Width - $drawWidth) / 2)
                $y = [int](($Height - $drawHeight) / 2)
                if ($Tag) {
                    $y -= 10
                }
                $graphics.DrawImage($image, $x, $y, $drawWidth, $drawHeight)
                if ($Tag) {
                    # The logo artwork leaves its bottom ~15% blank under the wordmark.
                    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
                    $ink = [Drawing.Color]::FromArgb(20, 20, 20)
                    $font = [Drawing.Font]::new('Segoe UI Semibold', 9, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
                    $pen = [Drawing.Pen]::new($ink, 1.2)
                    $brush = [Drawing.SolidBrush]::new($ink)
                    $format = [Drawing.StringFormat]::new()
                    try {
                        $format.Alignment = [Drawing.StringAlignment]::Center
                        $format.LineAlignment = [Drawing.StringAlignment]::Center
                        $text = ($Tag.ToCharArray() -join [char]0x200A)
                        $tagWidth = [Math]::Ceiling($graphics.MeasureString($text, $font).Width) + 8
                        $tagHeight = 14
                        $tagX = ($Width - $tagWidth) / 2
                        $tagY = $y + [int]($drawHeight * 0.88)
                        $radius = 4
                        $path = [Drawing.Drawing2D.GraphicsPath]::new()
                        $path.AddArc($tagX, $tagY, $radius * 2, $radius * 2, 180, 90)
                        $path.AddArc($tagX + $tagWidth - $radius * 2, $tagY, $radius * 2, $radius * 2, 270, 90)
                        $path.AddArc($tagX + $tagWidth - $radius * 2, $tagY + $tagHeight - $radius * 2, $radius * 2, $radius * 2, 0, 90)
                        $path.AddArc($tagX, $tagY + $tagHeight - $radius * 2, $radius * 2, $radius * 2, 90, 90)
                        $path.CloseFigure()
                        $graphics.DrawPath($pen, $path)
                        $path.Dispose()
                        $graphics.DrawString($text, $font, $brush, [Drawing.RectangleF]::new($tagX, $tagY + 0.5, $tagWidth, $tagHeight), $format)
                    } finally {
                        $format.Dispose()
                        $brush.Dispose()
                        $pen.Dispose()
                        $font.Dispose()
                    }
                }
            } finally {
                $graphics.Dispose()
            }
            $bitmap.Save($Destination, [Drawing.Imaging.ImageFormat]::Bmp)
        } finally {
            $bitmap.Dispose()
        }
    } finally {
        $image.Dispose()
    }
}

function Find-MakeNsis {
    $command = Get-Command 'makensis.exe' -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    $candidate = Join-Path ${env:ProgramFiles(x86)} 'NSIS\Bin\makensis.exe'
    if (Test-Path $candidate) {
        return $candidate
    }
    throw 'NSIS is required; install it with choco install nsis'
}

if (-not $SkipFrontend) {
    Build-Frontend
}
if ($FrontendOnly) {
    return
}
if (-not (Test-Path (Join-Path $Frontend 'dist\index.html'))) {
    throw 'Frontend output is missing; run without -SkipFrontend first'
}

$target = if ($Arch -eq 'x64') { 'x86_64-pc-windows-msvc' } else { 'aarch64-pc-windows-msvc' }
Invoke-Native 'rustup.exe' @('target', 'add', $target)
$previousRustFlags = $env:RUSTFLAGS
try {
    $env:RUSTFLAGS = '-Ctarget-feature=+crt-static'
    Invoke-Native 'cargo.exe' @('build', '--release', '--target', $target, '--manifest-path', (Join-Path $Root 'gateway\Cargo.toml'))
} finally {
    $env:RUSTFLAGS = $previousRustFlags
}

$buildAssets = Join-Path $Root 'build\nsis-assets'
New-Item -ItemType Directory -Path $buildAssets -Force | Out-Null
New-InstallerBitmap -Source (Join-Path $Root 'assets\pageway-logo.png') -Destination (Join-Path $buildAssets 'welcome.bmp') -Width 164 -Height 314 -Tag 'RDP'
New-InstallerBitmap -Source (Join-Path $Root 'assets\pageway-app.png') -Destination (Join-Path $buildAssets 'header.bmp') -Width 150 -Height 57

$dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$gatewayExe = Join-Path $Root "gateway\target\$target\release\pageway-rdp.exe"
$makeNsis = Find-MakeNsis
$output = Join-Path $dist "Pageway-RDP-Setup-$Version-windows-$Arch.exe"
$arguments = @(
    '/INPUTCHARSET', 'UTF8',
    "/DVERSION=$Version",
    "/DARCH=$Arch",
    "/DOUTPUT_FILE=$output",
    "/DGATEWAY_EXE=$gatewayExe",
    "/DWEB_DIR=$(Join-Path $Frontend 'dist')",
    "/DROOT_DIR=$Root",
    "/DBUILD_ASSETS=$buildAssets",
    (Join-Path $Root 'packaging\installer.nsi')
)
Invoke-Native $makeNsis $arguments
Write-Host "Built $output"
