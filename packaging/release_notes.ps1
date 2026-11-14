param(
    [string]$Output = 'release-notes.md'
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$version = [IO.File]::ReadAllText((Join-Path $root 'VERSION'), [Text.Encoding]::UTF8).Trim()

function Get-VersionSection([string]$File) {
    $changelog = [IO.File]::ReadAllText((Join-Path $root $File), [Text.Encoding]::UTF8) -replace "`r`n", "`n"
    $pattern = "(?ms)^## \[$([regex]::Escape($version))\][^\n]*\n(.*?)(?=^## \[|\z)"
    $match = [regex]::Match($changelog, $pattern)
    if (-not $match.Success -or -not $match.Groups[1].Value.Trim()) {
        throw "$File has no section for VERSION $version"
    }
    $match.Groups[1].Value.Trim()
}

$english = Get-VersionSection 'CHANGELOG.md'
$chinese = Get-VersionSection 'CHANGELOG.zh-CN.md'
# Kept ASCII-only because Windows PowerShell 5.1 reads BOM-less scripts with the ANSI code page.
$chineseLabel = -join [char[]](0x7B80, 0x4F53, 0x4E2D, 0x6587)
$notes = "$english`n`n<details>`n<summary>$chineseLabel</summary>`n`n$chinese`n`n</details>`n"
$outputPath = if ([IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path (Get-Location) $Output }
[IO.File]::WriteAllText($outputPath, $notes, [Text.UTF8Encoding]::new($false))
Write-Output $notes
