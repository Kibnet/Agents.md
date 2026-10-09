[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$cliExe = (Get-Command unlimotion-cli -CommandType Application -ErrorAction Stop).Source
& python -B (Join-Path $PSScriptRoot 'fixtures/unlimotion-outcomes/cli_contracts.py') --cli $cliExe --output $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw 'Installed CLI fixture suite failed; inspect retained receipts. No live task-space was selected.' }
