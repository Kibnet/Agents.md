[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BaselineRoot,
    [Parameter(Mandatory=$true)][string]$CandidateRoot,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [ValidateSet('baseline','candidate','both')][string]$Phase = 'both',
    [string]$Cases,
    [switch]$HeldOut,
    [switch]$Preflight
)
$ErrorActionPreference = 'Stop'
$runtime = Join-Path $PSScriptRoot 'fixtures/outcome-contracts/runtime.py'
$arguments = @('-B', $runtime, '--baseline', $BaselineRoot, '--candidate', $CandidateRoot, '--output', $OutputDirectory, '--phase', $Phase)
if ($Cases) { $arguments += @('--cases', $Cases) }
if ($HeldOut) { $arguments += '--heldout' }
if ($Preflight) { $arguments += '--preflight' }
& python @arguments
if ($LASTEXITCODE -ne 0) { throw "Behavioral execution did not complete (exit $LASTEXITCODE); inspect retained evidence. No behavioral PASS is implied." }
Write-Host 'Execution complete. Independent oracle review of traces and artifacts remains required.'
