[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot), [string]$EvidenceRoot = (Join-Path ([IO.Path]::GetTempPath()) ('installer-remediation-' + [guid]::NewGuid().ToString('N'))), [switch]$BaselineOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[void][IO.Directory]::CreateDirectory($EvidenceRoot)
$script:failures = 0
$script:checks = 0
function Check([bool]$Value, [string]$Name) { $script:checks++; if (!$Value) { $script:failures++; Write-Host "FAIL $Name" } else { Write-Host "PASS $Name" } }
function Put([string]$Path, [string]$Value) { [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path)); [IO.File]::WriteAllText($Path,$Value,[Text.UTF8Encoding]::new($false)) }
function Run([string]$Script, [string[]]$Arguments) {
    $raw = (& pwsh -NoProfile -File (Join-Path $RepositoryRoot $Script) @Arguments 2>&1 | Out-String)
    $code = $LASTEXITCODE
    Put (Join-Path $EvidenceRoot ('process-' + [guid]::NewGuid().ToString('N') + '.log')) $raw
    try { $json = $raw | ConvertFrom-Json -Depth 50 } catch { throw "Process exit ${code}: $raw" }
    [pscustomobject]@{ Code=$code; Json=$json }
}
function Install([string]$FixtureHome) {
    $preview=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$FixtureHome,'-WhatIf')
    if ($preview.Code -ne 0) { throw ($preview.Json | ConvertTo-Json -Depth 40) }
    Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$FixtureHome,'-ApprovedProposalHash',$preview.Json.proposalHash)
}
$fake = 'notes = """' + "`n[agents]`nmax_threads = 9`nmax_depth = 8`n" + '"""' + "`n"
$fakeHome = Join-Path $EvidenceRoot 'false-section'
Put (Join-Path $fakeHome 'config.toml') $fake
$p = Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$fakeHome,'-WhatIf')
Check ($p.Json.changes.config.afterContent.StartsWith($fake)) 'R2 multiline content is byte-preserved'
$ownHome = Join-Path $EvidenceRoot 'preexisting-reviewer'
$reviewerPath=Join-Path $ownHome 'agents/independent-reviewer.toml'
Put $reviewerPath ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'templates/codex/agents/independent-reviewer.toml')))
$i=Install $ownHome
Check ($i.Code -eq 0) 'preexisting fixture installed'
$u=Run 'scripts/install-agent-operations.ps1' @('-Uninstall','-CodexHome',$ownHome,'-WhatIf')
$u=Run 'scripts/install-agent-operations.ps1' @('-Uninstall','-CodexHome',$ownHome,'-ApprovedProposalHash',$u.Json.proposalHash)
Check ((Test-Path -LiteralPath $reviewerPath) -and $u.Code -eq 0) 'R3 preexisting reviewer survives uninstall'
if ($BaselineOnly) { Write-Host "Checks $script:checks failures $script:failures"; exit ([int]($script:failures -gt 0)) }
Import-Module (Join-Path $RepositoryRoot 'scripts/lib/AgentOperations.Contracts.psm1') -Force
foreach ($newline in @("`n","`r`n")) {
    foreach ($quote in @('"""',"'''")) {
        $inputText = "notes = $quote${newline}[agents]${newline}max_threads = 9${newline}[hooks]${newline}enable_hooks = false${newline}$quote${newline}[agents] # real${newline}  max_threads`t= 21  # keep${newline}max_depth=7${newline}other = ['[agents]', [1, 2]]${newline}[other]${newline}x = true"
        $expectedText = $inputText.Replace('= 21  # keep','= 4  # keep').Replace('max_depth=7','max_depth=1')
        Check ((Set-AgentOperationsLimits $inputText 4 1) -ceq $expectedText) "TOML exact spans $quote newline length $($newline.Length)"
        $read=Read-AgentOperationsToml $inputText
        Check (!$read.HasHooks -and !$read.HooksDisabled -and $read.Values.max_threads -eq '21') 'TOML fake hook guards are ignored'
        Check ($inputText.Substring($read.Spans.max_threads.ValueStart,$read.Spans.max_threads.ValueLength) -ceq '21') 'TOML offset points only at managed value'
    }
}
$bomText=[string][char]0xfeff + "[agents]`r`nmax_threads=8`r`nmax_depth=2`r`n"
Check ((Set-AgentOperationsLimits $bomText 4 1) -ceq ($bomText.Replace('threads=8','threads=4').Replace('depth=2','depth=1'))) 'UTF-8 BOM remains in exact postimage'
$commented="[agents]`nmax_threads = 4 # user's inline note`nmax_depth = 1`n"
Check ((Set-AgentOperationsLimits $commented $null $null) -ceq "[agents]`n # user's inline note`n`n") 'Restoration removes assignments while preserving comments and newlines'
$unsupported=@('agents = {max_threads=4}', 'agents.max_depth = 1', '["agents"]', '[ agents ]', "[agents]`n'max_depth'=1", "[agents]`nmax_depth.x=1", "[agents]`nmax_depth=0", "[agents]`nmax_depth=-1", "[agents]`nmax_depth=1_0", "[agents]`nmax_depth=0x1", "[agents]`nmax_depth=1`nmax_depth=2", "[agents]`n[agents]", 'notes = "unterminated', 'notes = [1,2', 'notes = [1}', '[agents.max_threads]', '[agents . max_threads]', '[agents . "max_depth"]', '["agents" . max_threads]', "[agents	.	max_depth]", '[agents . max_threads . child]')
foreach ($inputText in $unsupported) {
    $thrown=$false
    try { $null=Read-AgentOperationsToml $inputText } catch { $thrown=$true }
    Check $thrown "TOML unsupported blocked: $($inputText.Replace("`n",' / '))"
}
foreach ($dottedHeader in @('[agents . max_threads]','[agents . "max_depth"]')) {
    $dottedHome=Join-Path $EvidenceRoot ('dotted-header-' + [guid]::NewGuid().ToString('N'))
    $dottedConfig=Join-Path $dottedHome 'config.toml'
    Put $dottedConfig $dottedHeader
    $dottedPreview=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$dottedHome,'-WhatIf')
    Check ($dottedPreview.Code -eq 2 -and $dottedPreview.Json.status -eq 'blocked') "Installer blocks managed dotted header $dottedHeader"
    Check ([IO.File]::ReadAllText($dottedConfig) -ceq $dottedHeader -and @(Get-ChildItem -LiteralPath $dottedHome -Recurse -Force).Count -eq 1) 'Dotted managed config blocked before any file mutation'
    $dottedProbe=Run 'scripts/probe-agent-operations-activation.ps1' @('-CodexHome',$dottedHome)
    Check (!$dottedProbe.Json.agentLimitsPassed -and $dottedProbe.Json.agentLimitsReason -match 'canonical') 'Probe reports unsupported dotted managed table reason'
}

$blockHome=Join-Path $EvidenceRoot 'unsupported'
Put (Join-Path $blockHome 'config.toml') 'notes = [1,2'
$blocked=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$blockHome,'-WhatIf')
Check ($blocked.Json.status -eq 'blocked' -and !(Test-Path (Join-Path $blockHome 'agent-operations'))) 'Malformed config blocks before backup'
$probe=Run 'scripts/probe-agent-operations-activation.ps1' @('-CodexHome',$blockHome)
Check (!$probe.Json.agentLimitsPassed -and $probe.Json.agentLimitsReason -match 'unclosed') 'Probe malformed config returns false with reason'
$fp='a'*64
foreach ($legacy in @($true,$false,$null,'true')) {
    $manifest=[pscustomobject]@{ createdFiles=[pscustomobject]@{reviewer=$legacy};installerOwnedReviewerFingerprint=$fp }
    $provenance=Get-AgentOperationsReviewerProvenance $manifest $true $fp
    Check (($provenance.origin -eq 'created') -eq ($legacy -is [bool] -and $legacy)) "Legacy reviewer ownership requires boolean true: $legacy"
}
foreach ($bad in @($null,[pscustomobject]@{origin='created';initialFingerprint='bad'},[pscustomobject]@{origin='foreign';initialFingerprint=$fp})) {
    $thrown=$false; try { $null=Get-AgentOperationsReviewerProvenance ([pscustomobject]@{reviewerProvenance=$bad}) $true $fp } catch {$thrown=$true}
    Check $thrown 'Present malformed reviewer provenance blocks'
}
$now=[DateTimeOffset]::UtcNow; $installed=$now.AddMinutes(-20).ToString('o')
$reviewer=[pscustomobject][ordered]@{schemaVersion=2; reviewerFingerprint=$fp; activationBindingHash=$fp; configHash=$fp; observedAtUtc=$now.AddMinutes(-2).UtcDateTime.ToString('o'); hostIdentity=[Environment]::MachineName; runtimeFingerprint=$fp; childSessionId='controlled-child-42'; effectiveSandbox='read-only';readSucceeded=$true;writeDenied=$true}
function ReviewerCheck($Report) { Test-AgentOperationsReviewerEvidence -Evidence $Report -ReviewerFingerprint $fp -ActivationBindingHash $fp -ConfigHash $fp -InstalledAt $installed -ExpectedRuntimeFingerprint $fp -ExpectedSessionId 'controlled-child-42' -Now $now }
Check (ReviewerCheck $reviewer).Passed 'Fresh controlled reviewer accepted'
$futureReviewer=$reviewer|ConvertTo-Json|ConvertFrom-Json
$futureReviewer.observedAtUtc=$now.AddSeconds(30).ToString('o')
Check (ReviewerCheck $futureReviewer).Passed 'Reviewer allows at most thirty seconds of future skew'
$futureReviewer.observedAtUtc=[DateTime]::SpecifyKind($now.DateTime,[DateTimeKind]::Unspecified)
Check (!(ReviewerCheck $futureReviewer).Passed) 'Reviewer rejects timestamp without timezone'
foreach ($change in @(@('schemaVersion',1),@('schemaVersion','2'),@('reviewerFingerprint',('b'*64)),@('activationBindingHash',('b'*64)),@('configHash',('b'*64)),@('hostIdentity','foreign-host'),@('runtimeFingerprint',('b'*64)),@('childSessionId','wrong-child'),@('effectiveSandbox','workspace-write'),@('readSucceeded','true'),@('writeDenied',$false),@('observedAtUtc',$now.AddMinutes(-16).ToString('o')),@('observedAtUtc',$now.AddSeconds(31).ToString('o')),@('observedAtUtc',$now.AddHours(-2).ToString('o')),@('observedAtUtc','bad'))) {
    $bad=$reviewer | ConvertTo-Json | ConvertFrom-Json
    $bad.($change[0])=$change[1]
    Check (!(ReviewerCheck $bad).Passed) "Reviewer rejects $($change[0])=$($change[1])"
}
Check (!(Test-AgentOperationsReviewerEvidence -Evidence $reviewer -ReviewerFingerprint $fp -ActivationBindingHash $fp -ConfigHash $fp -InstalledAt $installed).Passed) 'Reviewer requires runner expected identity'
$combined=[pscustomobject]@{schemaVersion=2;reviewerEvidence=$reviewer;reviewerEvidenceHash=(Get-AgentOperationsEvidenceHash $reviewer);reviewerFingerprint=$fp;activationBindingHash=$fp;configHash=$fp;expectedReviewerRuntimeFingerprint=$fp;expectedReviewerSessionId='controlled-child-42';reviewerObservationAtUtc=$reviewer.observedAtUtc;runtimeObservationAtUtc=$now.AddMinutes(-1).ToString('o');evidenceCreatedAtUtc=$now.ToString('o');expiresAtUtc=$now.AddMinutes(13).ToString('o')}
Check (Test-AgentOperationsActivationFreshness $combined $installed $now) 'Combined expiry uses earliest observation'
$combined.expiresAtUtc=$now.AddMinutes(14).ToString('o')
Check (!(Test-AgentOperationsActivationFreshness $combined $installed $now)) 'Combined cannot extend reviewer lifetime with fresh runtime'
$combined.expiresAtUtc=$now.AddMinutes(13).ToString('o')
Check (!(Test-AgentOperationsActivationFreshness $combined $installed $now.AddMinutes(14))) 'Both windows revalidated at commit time'
$reviewerSchema=Join-Path $RepositoryRoot 'schemas/agent-operations-reviewer-evidence.schema.json'
Check (($reviewer | ConvertTo-Json) | Test-Json -SchemaFile $reviewerSchema) 'Actual reviewer evidence matches schema'

$driftHome=Join-Path $EvidenceRoot 'preexisting-user-drift'
$driftReviewer=Join-Path $driftHome 'agents/independent-reviewer.toml'
Put $driftReviewer ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'templates/codex/agents/independent-reviewer.toml')))
$i=Install $driftHome
$legacyPath=Join-Path $driftHome 'agent-operations/install-manifest.json'
$legacy=[IO.File]::ReadAllText($legacyPath)|ConvertFrom-Json
$legacy.PSObject.Properties.Remove('reviewerProvenance')
$legacy.createdFiles.PSObject.Properties.Remove('reviewer')
Put $legacyPath ($legacy|ConvertTo-Json -Depth 20)
$driftText=[IO.File]::ReadAllText($driftReviewer)+"`n# user change`n"
Put $driftReviewer $driftText
$blocked=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$driftHome,'-WhatIf')
Check ($blocked.Json.status -eq 'blocked') 'Preexisting drift blocks replacement upgrade'
$u=Run 'scripts/install-agent-operations.ps1' @('-Uninstall','-CodexHome',$driftHome,'-WhatIf')
$u=Run 'scripts/install-agent-operations.ps1' @('-Uninstall','-CodexHome',$driftHome,'-ApprovedProposalHash',$u.Json.proposalHash)
Check ($u.Code -eq 0 -and [IO.File]::ReadAllText($driftReviewer) -ceq $driftText) 'Preexisting drift does not block owned object removal'

$activeHome=Join-Path $EvidenceRoot 'activation'
$i=Install $activeHome
$manifestPath=Join-Path $activeHome 'agent-operations/install-manifest.json'
$m=[IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
Check ($m.reviewerProvenance.origin -eq 'created') 'New reviewer records created provenance'
$m.PSObject.Properties.Remove('reviewerProvenance')
Put $manifestPath ($m|ConvertTo-Json -Depth 20)
$noOp=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$activeHome,'-WhatIf')
$beforeNoOp=[IO.File]::ReadAllText($manifestPath)
$noOp=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$activeHome,'-ApprovedProposalHash',$noOp.Json.proposalHash)
Check ([IO.File]::ReadAllText($manifestPath) -ceq $beforeNoOp) 'No-op install preserves metadata'
$binding=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("$($m.telemetrySalt)|activation|$($m.activationChallenge)"))).ToLowerInvariant()
$runtime=Join-Path $activeHome "agent-operations/versions/$($m.runtimeVersion)/agent-operations-hook.ps1"
$report=[pscustomobject][ordered]@{schemaVersion=2;reviewerFingerprint=$m.installerOwnedReviewerFingerprint;activationBindingHash=$binding;configHash=(Get-FileHash (Join-Path $activeHome 'config.toml')).Hash.ToLowerInvariant();observedAtUtc=[DateTime]::UtcNow.ToString('o');hostIdentity=[Environment]::MachineName;runtimeFingerprint=$fp;childSessionId='test-controlled-session';effectiveSandbox='read-only';readSucceeded=$true;writeDenied=$true}
$reportPath=Join-Path $activeHome 'reviewer-evidence.json'; Put $reportPath ($report|ConvertTo-Json)
$logRecord=[ordered]@{schemaVersion=1;runtimeVersion=$m.runtimeVersion;timestamp=[DateTime]::UtcNow.ToString('o');category='activation-probe';eventName='PreToolUse';severity='info';action='observe';repoHash=$fp;sessionHash=$binding}
Put (Join-Path $activeHome 'logs/agent-operations.jsonl') (($logRecord|ConvertTo-Json -Compress)+"`n")
$evidencePath=Join-Path $activeHome 'evidence.json'
$savedReport=[IO.File]::ReadAllText($reportPath)
$report.observedAtUtc='invalid-date'
Put $reportPath ($report|ConvertTo-Json)
$invalidReport=Run 'scripts/probe-agent-operations-activation.ps1' @('-CodexHome',$activeHome,'-ReviewerEvidencePath',$reportPath,'-ExpectedReviewerRuntimeFingerprint',$fp,'-ExpectedReviewerSessionId','test-controlled-session','-ManualHookTrustConfirmed','-ControlledHostTaskConfirmed')
Check ($invalidReport.Code -eq 2 -and !$invalidReport.Json.reviewerWriteDenied -and $invalidReport.Json.reviewerEvidenceReason -match 'observation') 'Malformed reviewer date returns failed evidence with reason'
Put $reportPath $savedReport
$probe=Run 'scripts/probe-agent-operations-activation.ps1' @('-CodexHome',$activeHome,'-ReviewerEvidencePath',$reportPath,'-ExpectedReviewerRuntimeFingerprint',$fp,'-ExpectedReviewerSessionId','test-controlled-session','-ManualHookTrustConfirmed','-ControlledHostTaskConfirmed','-OutputPath',$evidencePath)
Check ($probe.Code -eq 0 -and $probe.Json.reviewerWriteDenied) 'Probe validates controlled v2 synthetic evidence'
Check (([IO.File]::ReadAllText($evidencePath)) | Test-Json -SchemaFile (Join-Path $RepositoryRoot 'schemas/agent-operations-activation-evidence.schema.json')) 'Actual combined evidence matches schema'
$originalEvidence=[IO.File]::ReadAllText($evidencePath)
$originalManifest=[IO.File]::ReadAllText($manifestPath)
$expiryEvidence=$originalEvidence|ConvertFrom-Json -Depth 30
$expiryNow=[DateTimeOffset]::UtcNow
$expiryEvidence.reviewerEvidence.observedAtUtc=$expiryNow.AddMinutes(-15).AddSeconds(12).UtcDateTime.ToString('o')
$expiryEvidence.reviewerObservationAtUtc=$expiryEvidence.reviewerEvidence.observedAtUtc
$expiryEvidence.reviewerEvidenceHash=Get-AgentOperationsEvidenceHash $expiryEvidence.reviewerEvidence
$expiryEvidence.evidenceCreatedAtUtc=$expiryNow.UtcDateTime.ToString('o')
$expiryEvidence.expiresAtUtc=$expiryNow.AddSeconds(12).UtcDateTime.ToString('o')
$m.installedAt=$expiryNow.AddMinutes(-30).UtcDateTime.ToString('o')
Put $manifestPath ($m|ConvertTo-Json -Depth 20)
Put $evidencePath ($expiryEvidence|ConvertTo-Json -Depth 30)
$expiryPreview=Run 'scripts/install-agent-operations.ps1' @('-MarkActive','-CodexHome',$activeHome,'-ActivationEvidencePath',$evidencePath,'-WhatIf')
Check ($expiryPreview.Code -eq 0) 'Near-expiry reviewer passes initial validation'
$expired=Run 'scripts/install-agent-operations.ps1' @('-MarkActive','-CodexHome',$activeHome,'-ActivationEvidencePath',$evidencePath,'-ApprovedProposalHash',$expiryPreview.Json.proposalHash,'-SimulateActivationDelayMilliseconds','13000')
Check ($expired.Code -eq 3 -and (([IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json).state -eq 'awaiting-trust')) 'Reviewer expiry during transaction prevents active commit'
Put $manifestPath $originalManifest
Put $evidencePath $originalEvidence
$mark=Run 'scripts/install-agent-operations.ps1' @('-MarkActive','-CodexHome',$activeHome,'-ActivationEvidencePath',$evidencePath,'-WhatIf')
if ($mark.Code -eq 0) { $mark=Run 'scripts/install-agent-operations.ps1' @('-MarkActive','-CodexHome',$activeHome,'-ActivationEvidencePath',$evidencePath,'-ApprovedProposalHash',$mark.Json.proposalHash) }
Check ($mark.Code -eq 0 -and $mark.Json.status -eq 'active') 'MarkActive accepts current v2 report'
$createdReviewerPath=Join-Path $activeHome 'agents/independent-reviewer.toml'
$createdReviewerText=[IO.File]::ReadAllText($createdReviewerPath)
Put $createdReviewerPath ([string][char]0xfeff + $createdReviewerText)
$bomDrift=Run 'scripts/install-agent-operations.ps1' @('-Uninstall','-CodexHome',$activeHome,'-WhatIf')
Check ($bomDrift.Code -eq 2 -and (Test-Path $createdReviewerPath)) 'Created reviewer BOM byte drift prevents deletion'
Put $createdReviewerPath $createdReviewerText
$u=Run 'scripts/install-agent-operations.ps1' @('-Uninstall','-CodexHome',$activeHome,'-WhatIf')
$u=Run 'scripts/install-agent-operations.ps1' @('-Uninstall','-CodexHome',$activeHome,'-ApprovedProposalHash',$u.Json.proposalHash)
Check ($u.Code -eq 0 -and !(Test-Path (Join-Path $activeHome 'agents/independent-reviewer.toml'))) 'Created reviewer removed on uninstall'

$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start(); $port=$listener.LocalEndpoint.Port
try {
    $tcp=Run 'templates/codex/local-environment/preflight.ps1' @('-Endpoint',"http://127.0.0.1:$port",'-OutputFormat','Json')
    Check ($tcp.Code -eq 0 -and $tcp.Json.schemaVersion -eq 1 -and $tcp.Json.checks[0].kind -eq 'endpoint' -and $tcp.Json.checks[0].level -eq 'tcp-connect') 'TCP listener is explicitly tcp-connect PASS'
} finally { $listener.Stop() }
$tcp=Run 'templates/codex/local-environment/preflight.ps1' @('-Endpoint',"http://127.0.0.1:$port",'-OutputFormat','Json')
Check ($tcp.Code -eq 1 -and !$tcp.Json.ok) 'Closed TCP endpoint fails'
$tcp=Run 'templates/codex/local-environment/preflight.ps1' @('-Endpoint','not-a-uri','-OutputFormat','Json')
Check ($tcp.Code -eq 1 -and !$tcp.Json.ok) 'Invalid endpoint fails'

# A copied source tree is the only mutation target in dependency capture tests.
$sourceFixture=Join-Path $EvidenceRoot 'captured-source'
foreach ($relative in @('scripts/install-agent-operations.ps1','scripts/lib/AgentOperations.Contracts.psm1','scripts/hooks/agent-operations-hook.ps1','templates/codex/agent-operations-hooks.json','templates/codex/agents/independent-reviewer.toml')) {
    $source=Join-Path $RepositoryRoot $relative
    if (!(Test-Path -LiteralPath $source)) { continue }
    $destination=Join-Path $sourceFixture $relative
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
    [IO.File]::Copy($source,$destination,$true)
}
$originalRoot=$RepositoryRoot
$RepositoryRoot=$sourceFixture
try {
    $captureHome=Join-Path $EvidenceRoot 'capture-home'
    [void][IO.Directory]::CreateDirectory($captureHome)
    $bomConfig=[string][char]0xfeff + "[agents]`r`nmax_threads=8 # keep`r`nmax_depth=2`r`n"
    Put (Join-Path $captureHome 'config.toml') $bomConfig
    $preview=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$captureHome,'-WhatIf')
    $modulePath=Join-Path $sourceFixture 'scripts/lib/AgentOperations.Contracts.psm1'
    $moduleText=[IO.File]::ReadAllText($modulePath)
    Put $modulePath ($moduleText+"`n# changed source contract`n")
    $stale=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$captureHome,'-ApprovedProposalHash',$preview.Json.proposalHash)
    Check ($stale.Code -eq 3 -and !(Test-Path (Join-Path $captureHome 'backups'))) 'Changed module invalidates approval before backup'
    Put $modulePath $moduleText
    $barrier=Join-Path $EvidenceRoot 'capture-ready'
    $process=[Diagnostics.Process]::new()
    $process.StartInfo.FileName=(Get-Command pwsh).Source
    $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
    foreach ($argument in @('-NoProfile','-File',(Join-Path $sourceFixture 'scripts/install-agent-operations.ps1'),'-Install','-CodexHome',$captureHome,'-ApprovedProposalHash',$preview.Json.proposalHash,'-SimulationCommitReadyPath',$barrier,'-SimulateCommitDelayMilliseconds','2500')) { $process.StartInfo.ArgumentList.Add($argument) }
    [void]$process.Start()
    $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    while (!(Test-Path -LiteralPath $barrier) -and !$process.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    Check (Test-Path -LiteralPath $barrier) 'Captured module test reaches controlled commit barrier'
    Put $modulePath "throw 'replacement module must never execute in an already captured transaction'"
    if (!$process.WaitForExit(30000)) { $process.Kill($true); throw 'Capture fixture process exceeded timeout.' }
    $raw=$stdoutTask.GetAwaiter().GetResult()+$stderrTask.GetAwaiter().GetResult()
    Put (Join-Path $EvidenceRoot 'capture-transaction.log') $raw
    Check ($process.ExitCode -eq 0) 'Captured module executes original contract after disk replacement'
    $process.Dispose()
    $actualBytes=[IO.File]::ReadAllBytes((Join-Path $captureHome 'config.toml'))
    $expectedBytes=[Text.Encoding]::UTF8.GetBytes($bomConfig.Replace('threads=8','threads=4').Replace('depth=2','depth=1'))
    Check ([Convert]::ToBase64String($actualBytes) -ceq [Convert]::ToBase64String($expectedBytes)) 'Install preserves BOM, CRLF, comments and exact unmanaged bytes'
    Put $modulePath $moduleText
    $fixtureManifestPath=Join-Path $captureHome 'agent-operations/install-manifest.json'
    $fixtureManifest=[IO.File]::ReadAllText($fixtureManifestPath)|ConvertFrom-Json
    $fixtureManifest.reviewerProvenance.origin='preexisting'
    Put $fixtureManifestPath ($fixtureManifest|ConvertTo-Json -Depth 20)
    $templatePath=Join-Path $sourceFixture 'templates/codex/agents/independent-reviewer.toml'
    Put $templatePath ([IO.File]::ReadAllText($templatePath)+"`n# upgraded template`n")
    $upgrade=Run 'scripts/install-agent-operations.ps1' @('-Install','-CodexHome',$captureHome,'-WhatIf')
    Check ($upgrade.Code -eq 2 -and $upgrade.Json.status -eq 'blocked') 'Upgrade cannot replace a preexisting reviewer with a new template'
} finally { $RepositoryRoot=$originalRoot }

Write-Host "Checks $script:checks failures $script:failures"
exit ([int]($script:failures -gt 0))
