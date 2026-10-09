[CmdletBinding()]
param([string]$RootPath = (Join-Path $PSScriptRoot '..'), [switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
$checker = Join-Path $PSScriptRoot 'fixtures/unlimotion-outcomes/static_contracts.py'
$arguments = @('-B', $checker, '--root', (Resolve-Path -LiteralPath $RootPath).Path)
if ($ValidateOnly) { $arguments += '--validate-only' }
& python @arguments
if ($LASTEXITCODE -ne 0) { throw 'Unlimotion static guards failed. No behavioral verdict is implied.' }
