[CmdletBinding()]
param([string]$EvidenceDirectory, [string]$BaselineRoot, [switch]$ClassificationOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
if([string]::IsNullOrWhiteSpace($EvidenceDirectory)){$EvidenceDirectory=Join-Path ([IO.Path]::GetTempPath()) ('agent-telemetry-remediation-'+[Guid]::NewGuid().ToString('N'))}
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
$work=Join-Path $EvidenceDirectory ('fixtures-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
$results=[Collections.Generic.List[object]]::new()
$foreignChecks=[Collections.Generic.List[object]]::new()
$salt='a'*64
function Assert([bool]$Value,[string]$Name){$results.Add([pscustomobject]@{name=$Name;passed=$Value});if(-not $Value){throw "FAIL: $Name"}}
function Load-Functions([string]$Path){$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$null,[ref]$errors);if($errors.Count){throw $errors[0]};foreach($f in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([scriptblock]::Create('function script:'+$f.Name+' '+$f.Body.Extent.Text))}}
function Store([string]$Path){return [AgentOperations.SafeStore]::new($Path,$salt,[Diagnostics.Stopwatch]::StartNew(),1500)}
function Fresh([string]$Name){$p=Join-Path $work $Name;[void][IO.Directory]::CreateDirectory($p);return $p}
function Event([DateTimeOffset]$Time){return (@{timestamp=$Time.ToString('o');category='test'}|ConvertTo-Json -Compress)}
function Attempt([scriptblock]$Body){try{& $Body;return $false}catch{return $true}}
function Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Run-Hook([string]$Hook,[string]$Root,[string]$Name){
 $payload=Join-Path $work "$Name-input.json"; $manifest=Join-Path $work "$Name-manifest.json"
 $version=if($Hook -eq $candidateHook){'3.2.0'}else{'3.1.0'}
 @{hook_event_name='PostToolUse';tool_name='shell_command';tool_input=@{command='rg absent .'};tool_response=@{exit_code=1;stderr=''};cwd=$work;session_id='test'}|ConvertTo-Json -Depth 10|Set-Content $payload
 @{schemaVersion=1;owner='agent-operations';runtimeVersion=$version;telemetrySalt=$salt;activationChallenge=('b'*32);runtimeChecksums=@{hook=(Hash $Hook).ToLowerInvariant()}}|ConvertTo-Json -Depth 5|Set-Content $manifest
 $sw=[Diagnostics.Stopwatch]::StartNew();$stdout=& pwsh -NoProfile -File $Hook -InputPath $payload -TelemetryRoot $Root -InstallManifestPath $manifest 2> (Join-Path $work "$Name-stderr.txt");$exit=$LASTEXITCODE;$sw.Stop()
 return [pscustomobject]@{exit=$exit;milliseconds=$sw.Elapsed.TotalMilliseconds;stdout=($stdout -join "`n");stderr=([IO.File]::ReadAllText((Join-Path $work "$Name-stderr.txt")))}
}
$candidateHook=Join-Path $repo 'scripts/hooks/agent-operations-hook.ps1'
try {
 if(-not $IsWindows){throw 'FAIL: Windows local NTFS evidence required'}
 if($BaselineRoot){
  Load-Functions (Join-Path $BaselineRoot 'scripts/hooks/agent-operations-hook.ps1')
  $shape=[pscustomobject]@{tool_response=[pscustomobject]@{exit_code=1;stderr=''}}
  $baselineCompound=Get-PostClassification $shape shell_command 'rg missing .; exit 1'
  Assert ($baselineCompound.Outcome -eq 'expected-no-match') 'baseline R5 reproduced compound normalization defect'
  $baseRoot=Fresh 'baseline-symlink';$foreign=Join-Path $work 'baseline-foreign.txt';[IO.File]::WriteAllText($foreign,'foreign sentinel');$before=Hash $foreign
  New-Item -ItemType SymbolicLink -Path (Join-Path $baseRoot 'agent-operations.jsonl') -Target $foreign | Out-Null
  $run=Run-Hook (Join-Path $BaselineRoot 'scripts/hooks/agent-operations-hook.ps1') $baseRoot 'baseline';$after=Hash $foreign
  Assert ($before -ne $after) 'baseline R4 reproduced foreign symlink append'
  $baselineColdRoot=Fresh 'baseline-cold';$baselineCold=Run-Hook (Join-Path $BaselineRoot 'scripts/hooks/agent-operations-hook.ps1') $baselineColdRoot 'baseline-cold'
  $baselineLock=[IO.File]::Open((Join-Path $baselineColdRoot '.agent-operations.lock'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  try{$baselineContended=Run-Hook (Join-Path $BaselineRoot 'scripts/hooks/agent-operations-hook.ps1') $baselineColdRoot 'baseline-contended'}finally{$baselineLock.Dispose()}
  @{compound=$baselineCompound;symlink=@{before=$before;after=$after;hook=$run};cold=$baselineCold;contention=$baselineContended}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $EvidenceDirectory 'baseline-telemetry.json')
  Load-Functions (Join-Path $BaselineRoot 'scripts/analyze-codex-session-errors.ps1')
  $baselineDocs=@(Get-CallClassifications shell_command ([pscustomobject]@{command='Get-Content docs.md'}) "Script completed`nExit code: 0`nOutput:`n401 SSL build failed traceback")
  Assert ($baselineDocs.Count -gt 0) 'baseline R6 reproduced successful docs false positives'
 }
 Load-Functions $candidateHook
 $vectors=Get-Content (Join-Path $repo 'scripts/fixtures/agent-operations/telemetry-direct-command-vectors.json') -Raw|ConvertFrom-Json
 foreach($v in $vectors){Assert (($null -ne (Get-SingleDirectCommand $v.command)) -eq $v.direct) ('hook AST '+$v.command)}
 foreach($case in @(@{exit=0;stderr='';expected='success'},@{exit=1;stderr='';expected='expected-no-match'},@{exit=2;stderr='';expected='real-failure'},@{exit=1;stderr='error';expected='real-failure'})){
  $p=[pscustomobject]@{tool_response=[pscustomobject]@{exit_code=$case.exit;stderr=$case.stderr}};$c=Get-PostClassification $p shell_command 'rg absent .';Assert ($c.Outcome -eq $case.expected) ('hook exit '+$case.exit+' stderr '+$case.stderr)
 }
 $missing=[pscustomobject]@{tool_response=[pscustomobject]@{exit_code=1}};Assert ((Get-PostClassification $missing shell_command 'rg absent .').Outcome -eq 'real-failure') 'hook missing stderr cannot normalize'
 $responses=Get-Content (Join-Path $repo 'scripts/fixtures/agent-operations/telemetry-rg-response-vectors.json') -Raw|ConvertFrom-Json
 foreach($v in $responses){$c=Get-PostClassification ([pscustomobject]@{tool_response=$v.response}) shell_command 'rg absent .';Assert (($c.Outcome -eq 'expected-no-match') -eq $v.expectedNoMatch) ('hook response '+$v.name)}
 if(-not $ClassificationOnly){
 $compile=[Diagnostics.Stopwatch]::StartNew();Initialize-TelemetryNative;$compile.Stop()
 $now=[DateTimeOffset]::UtcNow
 $root=Fresh 'normal';$s=Store $root;try{$s.Append((Event $now),$now);Assert (-not $s.RecordWarning('key',$now)) 'first warning recorded';Assert ($s.RecordWarning('key',$now)) 'duplicate warning suppressed'}finally{$s.Dispose()}
 $s=Store $root;try{$s.Maintain($now);$s.Append((Event $now),$now)}finally{$s.Dispose()};Assert ((Get-Content (Join-Path $root 'agent-operations.jsonl')).Count -eq 2) 'same owned segment appended across runs'
 foreach($leaf in @('agent-operations.jsonl','agent-operations.1.jsonl','agent-operations.2.jsonl','.agent-operations.lock','.agent-operations-store.json','.agent-operations-warning-state.json','.agent-operations-rotation-recovery.json')){
  foreach($kind in @('SymbolicLink','HardLink')){
   $p=Fresh ($kind+'-'+$leaf.TrimStart('.'));$outside=Join-Path $work ([Guid]::NewGuid().ToString('N')+'.txt');[IO.File]::WriteAllText($outside,'foreign sentinel');$hash=Hash $outside
   New-Item -ItemType $kind -Path (Join-Path $p $leaf) -Target $outside|Out-Null
   $s=$null;try{$s=Store $p;$s.Maintain($now);$s.Append((Event $now),$now)}catch{}finally{if($s){$s.Dispose()}}
   $after=Hash $outside;$foreignChecks.Add([pscustomobject]@{kind=$kind;leaf=$leaf;beforeSha256=$hash;afterSha256=$after})
   Assert ($after -eq $hash) ("foreign $kind $leaf unchanged")
  }
 }
 $dangling=Fresh 'dangling';$absent=Join-Path $work 'must-not-create.txt';New-Item -ItemType SymbolicLink -Path (Join-Path $dangling 'agent-operations.jsonl') -Target $absent|Out-Null
 $s=Store $dangling;try{Assert (Attempt {$s.Append((Event $now),$now)}) 'dangling link rejected'}finally{$s.Dispose()};Assert (-not (Test-Path $absent)) 'dangling target not created'
 $outside=Fresh 'junction-target';$junction=Join-Path $work 'junction';New-Item -ItemType Junction -Path $junction -Target $outside|Out-Null
 Assert (Attempt {$s=Store (Join-Path $junction 'child');$s.Dispose()}) 'intermediate junction rejected';Assert (-not (Test-Path (Join-Path $outside 'child'))) 'junction target directory unchanged'
 foreach($path in @('\\localhost\c$\temp','\\?\C:\temp',($work+'\..\escape'),($work+'\file:stream'))){Assert (Attempt {$s=Store $path;$s.Dispose()}) ('unsafe root '+$path)}
 $legacy=Fresh 'legacy';$legacyLog=Join-Path $legacy 'agent-operations.jsonl';[IO.File]::WriteAllText($legacyLog,(Event $now.AddDays(-46))+"`n");$hash=Hash $legacyLog
 $s=Store $legacy;try{$s.Maintain($now);Assert (Attempt {$s.Append((Event $now),$now)}) 'legacy active path blocks append'}finally{$s.Dispose()};Assert ((Hash $legacyLog) -eq $hash) 'exact-name valid legacy JSONL remains unowned after scan'
 $aged=Fresh 'age';$s=Store $aged;try{$s.Append((Event $now.AddDays(-46)),$now.AddDays(-46));$s.Append((Event $now),$now);$s.Maintain($now);Assert (-not (Test-Path (Join-Path $aged 'agent-operations.jsonl'))) 'fresh append cannot extend old-event retention';$s.Append((Event $now.AddDays(-45)),$now.AddDays(-45));$s.Maintain($now);Assert (Test-Path (Join-Path $aged 'agent-operations.jsonl')) 'exact 45-day boundary retained'}finally{$s.Dispose()}
 $rollback=Fresh 'clock-rollback';$s=Store $rollback;try{$s.Append((Event $now),$now);$s.Append((Event $now.AddDays(-46)),$now.AddDays(-46));$s.Maintain($now);Assert (-not (Test-Path (Join-Path $rollback 'agent-operations.jsonl'))) 'clock rollback decreases segment minimum'}finally{$s.Dispose()}
 $malformed=Fresh 'malformed';$s=Store $malformed;try{$s.Append('invalid',$now);$s.Maintain($now);Assert (-not (Test-Path (Join-Path $malformed 'agent-operations.jsonl'))) 'owned malformed segment deleted'}finally{$s.Dispose()}
 $mismatch=Fresh 'identity-mismatch';$s=Store $mismatch;try{$s.Append((Event $now),$now)}finally{$s.Dispose()};$path=Join-Path $mismatch 'agent-operations.jsonl';Move-Item $path ($path+'.old');[IO.File]::WriteAllText($path,'replacement sentinel');$hash=Hash $path
 Assert (Attempt {$s=Store $mismatch;$s.Dispose()}) 'replacement identity rejected';Assert ((Hash $path) -eq $hash) 'replacement foreign file unchanged'
 $oversized=Fresh 'oversized';$s=Store $oversized;try{Assert (Attempt {$s.Append(('x'*65537),$now)}) 'oversized event rejected'}finally{$s.Dispose()}
 $oversized=Fresh 'oversized-line';$s=Store $oversized;try{$s.Append((Event $now),$now)}finally{$s.Dispose()};[IO.File]::AppendAllText((Join-Path $oversized 'agent-operations.jsonl'),('x'*65537));$hash=Hash (Join-Path $oversized 'agent-operations.jsonl');$s=Store $oversized;try{Assert (Attempt {$s.Maintain($now)}) 'oversized owned scan line skipped'}finally{$s.Dispose()};Assert ((Hash (Join-Path $oversized 'agent-operations.jsonl')) -eq $hash) 'oversized scan does not delete or rewrite segment'
 $s=Store $root;try{$busy=[Diagnostics.Stopwatch]::StartNew();Assert (Attempt {$other=Store $root;$other.Dispose()}) 'concurrent writer lock conflict skips';$busy.Stop();Assert ($busy.ElapsedMilliseconds -lt 1500) 'contention bounded without retry loop'}finally{$s.Dispose()}
 $s=Store $root;try{Assert (Attempt {$other=Store ($root.ToUpperInvariant().Replace('\','/'));$other.Dispose()}) 'case and slash alias shares physical lock'}finally{$s.Dispose()}
 $near=Fresh 'three-near-limit';$fill=[Diagnostics.Stopwatch]::StartNew();$s=[AgentOperations.SafeStore]::new($near,$salt,$fill,60000)
 $largeEvent=@{timestamp=$now.ToString('o');padding=('x'*65300)}|ConvertTo-Json -Compress
 try{for($i=0;$i -lt 480;$i++){$s.Append($largeEvent,$now)}}finally{$s.Dispose()}
 $segments=@(Get-ChildItem -LiteralPath $near -File -Filter '*.jsonl');Assert ($segments.Count -eq 3 -and @($segments|Where-Object {$_.Length -gt 10MB -or $_.Length -lt 9MB}).Count -eq 0) 'three owned near-limit segments at most 10 MB each'
 $maintenance=[Diagnostics.Stopwatch]::StartNew();$s=[AgentOperations.SafeStore]::new($near,$salt,$maintenance,1500);try{$s.Maintain($now);$s.Append($largeEvent,$now)}finally{$s.Dispose()};$maintenance.Stop()
 Assert ($maintenance.ElapsedMilliseconds -lt 1500) 'near-30 MB bounded maintenance finishes cooperative budget'
 Assert (@(Get-ChildItem -LiteralPath $near -File -Filter '*.jsonl').Count -eq 3) 'fourth segment creation retains only three slots'
 $inUse=Join-Path $near 'agent-operations.jsonl';$renamed=$inUse+'.released';Move-Item -LiteralPath $inUse -Destination $renamed;Move-Item -LiteralPath $renamed -Destination $inUse;Assert (Test-Path $inUse) 'all segment handles released after maintenance'
 $deadline=[Diagnostics.Stopwatch]::StartNew();Assert (Attempt {$s=[AgentOperations.SafeStore]::new((Join-Path $work 'deadline'),$salt,$deadline,0)}) 'expired budget skips before filesystem mutation';Assert (-not(Test-Path (Join-Path $work 'deadline'))) 'deadline created no root'
 # Compile an instrumented copy solely in this harness. Barriers cannot be activated in production.
 $nativeFunction=(Get-Command Initialize-TelemetryNative).Definition
 $native=[regex]::Match($nativeFunction,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
 $native=$native.Replace('namespace AgentOperations {','namespace AgentOperationsTelemetryHarness {').Replace('public sealed class SafeStore : IDisposable {','public sealed class SafeStore : IDisposable { public static Action<string> Barrier; static void At(string point){Barrier?.Invoke(point);}')
 $native=$native.Replace('Check(); if(!anchor) Leaf(name);','Check(); if(!anchor) Leaf(name); At("before:"+name);')
 $native=$native.Replace('rootIdentity=Identity(root,true);','rootIdentity=Identity(root,true); At("root-open");')
 $native=$native.Replace('created=ios.Information.ToInt64()==2;','created=ios.Information.ToInt64()==2; if(status>=0)At("opened:"+name);')
 $native=$native.Replace('try {WriteAll(metadata,bytes);originalMetadata=bytes;}','try {At("before-metadata-write");WriteAll(metadata,bytes);At("after-metadata-write");originalMetadata=bytes;}')
 Add-Type -TypeDefinition $native
 $race=Fresh 'race-parent';$script:barrierHit=$false;$script:replaceBlocked=$false
 [AgentOperationsTelemetryHarness.SafeStore]::Barrier=[Action[string]]{param($point)if($point -eq 'root-open'){$script:barrierHit=$true;$script:replaceBlocked=Attempt {Move-Item -LiteralPath $race -Destination ($race+'-moved') -ErrorAction Stop}}}
 $s=[AgentOperationsTelemetryHarness.SafeStore]::new($race,$salt,[Diagnostics.Stopwatch]::StartNew(),1500);$s.Dispose();Assert ($script:barrierHit -and $script:replaceBlocked) 'controlled parent replacement blocked while held'
 $race=Fresh 'race-leaf';$foreign=Join-Path $work 'race-foreign.txt';[IO.File]::WriteAllText($foreign,'race sentinel');$hash=Hash $foreign;$script:barrierHit=$false
 [AgentOperationsTelemetryHarness.SafeStore]::Barrier=[Action[string]]{param($point)if($point -eq 'before:agent-operations.jsonl' -and -not $script:barrierHit){$script:barrierHit=$true;New-Item -ItemType SymbolicLink -Path (Join-Path $race 'agent-operations.jsonl') -Target $foreign|Out-Null}}
 $s=[AgentOperationsTelemetryHarness.SafeStore]::new($race,$salt,[Diagnostics.Stopwatch]::StartNew(),1500);try{Assert (Attempt {$s.Append((Event $now),$now)}) 'controlled pre-open leaf substitution rejected'}finally{$s.Dispose()};Assert ($script:barrierHit -and (Hash $foreign) -eq $hash) 'race foreign bytes unchanged'
 $race=Fresh 'race-open-leaf';$script:barrierHit=$false;$script:replaceBlocked=$false
 [AgentOperationsTelemetryHarness.SafeStore]::Barrier=[Action[string]]{param($point)if($point -eq 'opened:agent-operations.jsonl'){$script:barrierHit=$true;$script:replaceBlocked=Attempt {Move-Item -LiteralPath (Join-Path $race 'agent-operations.jsonl') -Destination (Join-Path $race 'moved.jsonl') -ErrorAction Stop}}}
 $s=[AgentOperationsTelemetryHarness.SafeStore]::new($race,$salt,[Diagnostics.Stopwatch]::StartNew(),1500);try{$s.Append((Event $now),$now)}finally{$s.Dispose()};Assert ($script:barrierHit -and $script:replaceBlocked) 'controlled post-open leaf replacement blocked'
 [AgentOperationsTelemetryHarness.SafeStore]::Barrier=$null
 $transaction=Fresh 'rollback-transaction';$s=[AgentOperationsTelemetryHarness.SafeStore]::new($transaction,$salt,[Diagnostics.Stopwatch]::StartNew(),1500);try{$s.Append((Event $now),$now)}finally{$s.Dispose()};$logHash=Hash (Join-Path $transaction 'agent-operations.jsonl');$metaHash=Hash (Join-Path $transaction '.agent-operations-store.json')
 [AgentOperationsTelemetryHarness.SafeStore]::Barrier=[Action[string]]{param($point)if($point -eq 'after-metadata-write'){throw 'controlled storage failure'}}
 $s=[AgentOperationsTelemetryHarness.SafeStore]::new($transaction,$salt,[Diagnostics.Stopwatch]::StartNew(),1500);try{Assert (Attempt {$s.Append((Event $now),$now)}) 'controlled append transaction failure'}finally{$s.Dispose()};[AgentOperationsTelemetryHarness.SafeStore]::Barrier=$null
 Assert ((Hash (Join-Path $transaction 'agent-operations.jsonl')) -eq $logHash -and (Hash (Join-Path $transaction '.agent-operations-store.json')) -eq $metaHash) 'append rollback restores exact log and metadata bytes'
 $creation=Fresh 'rollback-create';$s=[AgentOperationsTelemetryHarness.SafeStore]::new($creation,$salt,[Diagnostics.Stopwatch]::StartNew(),1500)
 [AgentOperationsTelemetryHarness.SafeStore]::Barrier=[Action[string]]{param($point)if($point -eq 'after-metadata-write'){throw 'controlled binding failure'}}
 try{Assert (Attempt {$s.Append((Event $now),$now)}) 'controlled exclusive-create binding failure'}finally{$s.Dispose()};[AgentOperationsTelemetryHarness.SafeStore]::Barrier=$null;Assert (-not(Test-Path (Join-Path $creation 'agent-operations.jsonl'))) 'failed create rolls back owned new file'
 $s=Store $creation;try{$s.Append((Event $now),$now)}finally{$s.Dispose()};Assert (Test-Path (Join-Path $creation 'agent-operations.jsonl')) 'recovery after failed binding releases handles'
 }
 Load-Functions (Join-Path $repo 'scripts/analyze-codex-session-errors.ps1')
 foreach($v in $vectors){Assert (($null -ne(Get-SingleDirectCommand $v.command)) -eq $v.direct) ('analyzer AST '+$v.command)}
 $docs='401 403 SSL certificate build failed traceback permission denied missing sdk index.lock invalid patch'
 foreach($output in @([pscustomobject]@{exit_code=0;output=$docs},[pscustomobject]@{isError=$false;output=$docs},"Script completed`nExit code: 0`nOutput:`n$docs",$docs,"Documentation`nExit code: 1`nOutput:`n$docs")){
  Assert (@(Get-CallClassifications shell_command ([pscustomobject]@{command='Get-Content docs.md'}) $output).Count -eq 0) 'successful or unknown documentation has no failure categories'
 }
 foreach($v in $vectors){$c=@(Get-CallClassifications shell_command ([pscustomobject]@{command=$v.command}) ([pscustomobject]@{exit_code=1;stderr=''}));Assert (('expected-no-match' -in $c) -eq $v.direct) ('analyzer rg outcome '+$v.command)}
 foreach($v in $responses){$c=@(Get-CallClassifications shell_command ([pscustomobject]@{command='rg absent .'}) $v.response);Assert (('expected-no-match' -in $c) -eq $v.expectedNoMatch) ('analyzer response '+$v.name)}
 foreach($value in @('2147483648','-2147483649',('9'*200))){Assert ((Get-StructuralOutcome "Script failed`nExit code: $value`nOutput:`nignored").Outcome -eq 'unknown') 'out-of-range legacy exit code remains unknown'}
 Assert ('network-auth-restore' -in @(Get-CallClassifications exec_command ([pscustomobject]@{command='fetch'}) ([pscustomobject]@{exit_code=1;stderr='401 SSL'}))) 'typed failure is classified'
 Assert ('timeout' -in @(Get-CallClassifications exec_command ([pscustomobject]@{command='run'}) ([pscustomobject]@{timed_out=$true}))) 'typed timeout classified without keyword'
 Assert ((Get-StructuralOutcome ([pscustomobject]@{exit_code='1';output=$docs})).Outcome -eq 'unknown') 'string exit code is not typed evidence'
 Assert ((Get-StructuralOutcome "Script failed`nExit code: 2`nOutput:`n$docs").Outcome -eq 'failure') 'known legacy header failure recognized'
 Assert ('failed-patch' -in @(Get-CallClassifications apply_patch ([pscustomobject]@{}) ([pscustomobject]@{success=$false}))) 'typed patch success false remains classified'
 # Initial undefined rates must retain numeric zero denominators and cannot auto-count.
 $script:KeyCategories=@('path-glob','failed-patch','git-sandbox','timeout')
 $gold=Get-GoldSetReport -Path '' -Predictions @{} -ExpectedSample @() -ExpectedSampleId '' -ExpectedSamplingAlgorithm '' -ExpectedSeedId ''
 Assert ($null -eq $gold.'path-glob'.precision -and $gold.'path-glob'.precisionDenominator -eq 0 -and $gold.'path-glob'.status -ne 'auto-counted') 'zero denominator is null rate and numeric zero count'
 $emptyGold=Join-Path $work 'empty-gold.json';@{schemaVersion=1;samplingAlgorithm='independent-stratified-v1';seedId='sha256-order-v1';sampleId='empty';entries=@{}}|ConvertTo-Json -Depth 5|Set-Content $emptyGold
 $gold=Get-GoldSetReport -Path $emptyGold -Predictions @{} -ExpectedSample @() -ExpectedSampleId 'empty' -ExpectedSamplingAlgorithm 'independent-stratified-v1' -ExpectedSeedId 'sha256-order-v1'
 Assert ($null -eq $gold.'path-glob'.precision -and $null -eq $gold.'path-glob'.recall -and $null -eq $gold.'path-glob'.falsePositiveRate -and $gold.'path-glob'.precisionDenominator -eq 0 -and $gold.'path-glob'.status -eq 'manual-review-only') 'matching empty gold sample cannot claim undefined accuracy'
 $report=Join-Path $work 'analyzer-report';$map=Join-Path $work 'evidence-map.json'
 & pwsh -NoProfile -File (Join-Path $repo 'scripts/analyze-codex-session-errors.ps1') -Since 2026-01-01T00:00:00Z -Until 2026-01-02T00:00:00Z -SessionsRoot (Join-Path $repo 'scripts/fixtures/agent-operations/telemetry-analyzer-outcomes') -OutputDirectory $report -EvidenceSaltPath (Join-Path $repo 'scripts/fixtures/agent-operations/analyzer-salt.txt') -EvidenceMapPath $map -Quiet
 Assert ($LASTEXITCODE -eq 0) 'end-to-end analyzer completes'
 $summary=Get-Content (Join-Path $report 'summary.json') -Raw|ConvertFrom-Json -Depth 30;$evidence=Get-Content $map -Raw|ConvertFrom-Json -Depth 30
 Assert ($summary.evaluationScope -eq 'selected-stratified-sample' -and $summary.evaluation.sampleSize -eq @($evidence.entries).Count -and $summary.evaluation.strategy -eq 'independent-stratified-v1') 'report records actual selected sample size and strategy'
 Assert ($summary.structuralOutcomes.success -eq 2 -and $summary.structuralOutcomes.unknown -eq 2 -and $summary.structuralOutcomes.failure -eq 6) 'report retains success failure and unknown counts and continues after oversized exit code'
 Assert ($summary.categories.'network-auth-restore'.events -eq 1 -and $summary.categories.'expected-no-match'.events -eq 1 -and $summary.categories.'timeout'.events -eq 1 -and $summary.categories.'failed-patch'.events -eq 1 -and $summary.categories.'build-failure'.events -eq 0) 'end-to-end structural outcomes precede error keyword categories'
 $privacy=Get-Content (Join-Path $report 'summary.json') -Raw;Assert ($privacy -notmatch 'Get-Content docs|rg missing|401 SSL|traceback') 'summary privacy excludes raw command and output'
 $historical=Fresh 'historical-window';$historicSource=Get-Content (Join-Path $repo 'scripts/fixtures/agent-operations/telemetry-analyzer-outcomes/trace-outcomes.jsonl') -Raw
 [IO.File]::WriteAllText((Join-Path $historical 'trace-historical.jsonl'),$historicSource.Replace('2026-01-01','2026-07-01'))
 $historicalReport=Join-Path $work 'historical-report'
 & pwsh -NoProfile -File (Join-Path $repo 'scripts/analyze-codex-session-errors.ps1') -Since 2026-06-17T11:05:24.066Z -Until 2026-07-17T11:05:24.066Z -SessionsRoot $historical -OutputDirectory $historicalReport -Quiet
 Assert ($LASTEXITCODE -eq 0) 'valid historical-window input completes despite different old reference counts'
 $historicSummary=Get-Content (Join-Path $historicalReport 'summary.json') -Raw|ConvertFrom-Json -Depth 30
 Assert ($historicSummary.evaluation.sampleSize -eq 0 -and $null -eq $historicSummary.goldSet.'path-glob'.precision) 'no-salt report retains zero sample size and undefined precision'
 Assert ($historicSummary.compatibility.applicable -and -not $historicSummary.compatibility.passed -and -not $historicSummary.compatibility.isQualityGate -and $historicSummary.compatibility.status -eq 'historical-counts-differ') 'historical count mismatch is informational'
 Assert ($historicSummary.compatibility.delta.toolCalls -eq ($historicSummary.compatibility.actual.toolCalls-$historicSummary.compatibility.expected.toolCalls)) 'historical comparison retains numeric deltas'
 if(-not $ClassificationOnly){
 $cold=Run-Hook $candidateHook (Fresh 'cold-hook') 'cold-hook';Assert ($cold.exit -eq 0) 'cold hook exit zero';Assert ($cold.stdout -match 'ripgrep') 'warning survives telemetry skip';Assert ($cold.milliseconds -lt 5000) 'cold hook within host timeout'
 $warm=Run-Hook $candidateHook (Join-Path $work 'cold-hook') 'next-hook';Assert ($warm.exit -eq 0) 'subsequent process hook exit zero'
 $s=Store (Join-Path $work 'cold-hook');try{$contended=Run-Hook $candidateHook (Join-Path $work 'cold-hook') 'contended-hook'}finally{$s.Dispose()};Assert ($contended.exit -eq 0 -and $contended.stdout -match 'ripgrep') 'contended hook preserves warning and exits zero'
 @{nativeInitMs=$compile.Elapsed.TotalMilliseconds;cold=$cold;nextProcess=$warm;contention=$contended;inProcessContentionMs=$busy.Elapsed.TotalMilliseconds;nearLimitMaintenanceMs=$maintenance.Elapsed.TotalMilliseconds}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $EvidenceDirectory 'latency.json')
 }
} finally {
 $results|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceDirectory 'assertions.json')
 $foreignChecks|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceDirectory 'foreign-file-hashes.json')
}
Write-Host ("PASS: telemetry remediation {0} assertions; evidence {1}" -f $results.Count,$EvidenceDirectory)
