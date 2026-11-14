param(
    [string]$Output = 'release-notes.md'
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$version = [IO.File]::ReadAllText((Join-Path $root 'VERSION'), [Text.Encoding]::UTF8).Trim()
$changelog = [IO.File]::ReadAllText((Join-Path $root 'CHANGELOG.md'), [Text.Encoding]::UTF8)
$pattern = "(?ms)^## \[$([regex]::Escape($version))\].*?(?=^## \[|\z)"
$match = [regex]::Match($changelog, $pattern)
if (-not $match.Success) {
    throw "CHANGELOG.md has no section for VERSION $version"
}
$notes = $match.Value.Trim() + "`n"
$outputPath = if ([IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path (Get-Location) $Output }
[IO.File]::WriteAllText($outputPath, $notes, [Text.UTF8Encoding]::new($false))
Write-Output $notes
