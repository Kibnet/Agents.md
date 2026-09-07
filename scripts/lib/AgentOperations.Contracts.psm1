Set-StrictMode -Version Latest

# This scanner locates complete statements; it deliberately does not implement all TOML semantics.
function Read-AgentOperationsToml {
    param([AllowNull()][string]$Content)
    $text = if ($null -eq $Content) { '' } else { $Content }
    $statements = [Collections.Generic.List[object]]::new()
    $start=if ($text.Length -gt 0 -and $text[0] -eq [char]0xfeff) {1} else {0}; $i=$start; $state=''; $comment=$false; $codeEnd=-1
    $stack=[Collections.Generic.Stack[char]]::new()
    while ($i -lt $text.Length) {
        $c=$text[$i]
        if ($comment) { if ($c -ne "`n") { $i++; continue }; $comment=$false }
        elseif ($state -ne '') {
            $quote=$state[0]; $multi=$state.Length -eq 3
            if ($quote -eq '"' -and $c -eq '\') { $i+=2; continue }
            if ($c -eq $quote) {
                $count=1
                while (($i+$count) -lt $text.Length -and $text[$i+$count] -eq $quote) { $count++ }
                if (!$multi) { $state=''; $i++; continue }
                if ($count -ge 3) { if ($count -gt 5) { throw 'TOML ambiguous quote run.' }; $state=''; $i+=$count; continue }
            }
            if (!$multi -and $c -in @("`r","`n")) { throw 'TOML unclosed single-line string.' }
            $i++; continue
        }
        elseif ($c -eq '#') { $comment=$true; if ($stack.Count -eq 0) { $codeEnd=$i }; $i++; continue }
        elseif ($c -eq '"' -or $c -eq "'") {
            if ($i+2 -lt $text.Length -and $text[$i+1] -eq $c -and $text[$i+2] -eq $c) { $state=([string]$c)*3; $i+=3 } else { $state=[string]$c; $i++ }; continue
        }
        elseif ($c -in @('[','{')) { $stack.Push($c) }
        elseif ($c -in @(']','}')) {
            if ($stack.Count -eq 0) { throw 'TOML unmatched closing delimiter.' }
            $opening=$stack.Pop()
            if (($opening -eq '[' -and $c -ne ']') -or ($opening -eq '{' -and $c -ne '}')) { throw 'TOML mismatched nesting.' }
        }
        if ($c -eq "`n" -and $stack.Count -eq 0) {
            $end=if ($codeEnd -ge 0) {$codeEnd} else {$i}
            $statements.Add([pscustomobject]@{ Start=$start; End=$i+1; Code=$text.Substring($start,$end-$start).TrimEnd("`r",' ',"`t"); ValueStart=-1; ValueLength=0; Key=''; Section='' })
            $start=$i+1; $codeEnd=-1
        }
        $i++
    }
    if ($state -ne '' -or $stack.Count -ne 0) { throw 'TOML unclosed string or array.' }
    if ($start -lt $text.Length) {
        $end=if ($codeEnd -ge 0) {$codeEnd} else {$text.Length}
        $statements.Add([pscustomobject]@{ Start=$start; End=$text.Length; Code=$text.Substring($start,$end-$start).TrimEnd("`r",' ',"`t"); ValueStart=-1; ValueLength=0; Key=''; Section='' })
    }
    $section=''; $agents=$null; $agentEnd=$text.Length; $values=[ordered]@{max_threads=$null;max_depth=$null}; $spans=@{}; $hooks=$false; $disabled=$false
    foreach ($statement in $statements) {
        $code=$statement.Code.Trim()
        if (!$code) { continue }
        if ($code.StartsWith('[')) {
            if ($null -ne $agents -and $agentEnd -eq $text.Length) { $agentEnd=$statement.Start }
            if ($code -notmatch '^\[\[?[^\r\n]+?\]\]?$') { throw 'TOML unsupported table header.' }
            $name=$code.Trim('[',']').Trim(); $semantic=($name.Replace('"','').Replace("'",'') -replace '\s*\.\s*','.')
            if ($name.Contains('\')) { throw 'TOML escaped table keys are unsupported.' }
            if (($semantic -eq 'agents' -and $code -cne '[agents]') -or $semantic -match '^agents\.(max_threads|max_depth)(?:\.|$)' -or ($semantic -match '^agents\.' -and $name -match '["'']')) { throw 'TOML managed table must be canonical [agents].' }
            if ($code -ceq '[agents]') { if ($null -ne $agents) { throw 'TOML duplicate agents table.' }; $agents=$statement }
            $section=$name
            if ($semantic -match '^hooks(?:\.|$)') { $hooks=$true }
            continue
        }
        if ($statement.Code -notmatch '^\s*(?<key>(?:"(?:\\.|[^"\\])*"|''[^'']*''|[A-Za-z0-9_-]+)(?:\s*\.\s*(?:"(?:\\.|[^"\\])*"|''[^'']*''|[A-Za-z0-9_-]+))*)\s*=\s*(?<value>[\s\S]+)$') { throw 'TOML unsupported or malformed statement.' }
        $key=$Matches.key; $value=$Matches.value
        $semantic=($key.Replace('"','').Replace("'",'') -replace '\s*\.\s*','.')
        if ($key.Contains('\')) { throw 'TOML escaped keys are unsupported.' }
        $statement.Key=$key; $statement.Section=$section
        if (!$section -and $semantic -match '^agents(?:\.|$)') { throw 'TOML inline/dotted agents are unsupported.' }
        if (!$section -and $semantic -match '^hooks(?:\.|$)') { $hooks=$true }
        if (($semantic -in @('hooks_enabled','enable_hooks') -and $value -eq 'false') -or ($semantic -in @('managed_hooks_only','hooks_managed_only') -and $value -eq 'true')) { $disabled=$true }
        if ($section -ceq 'agents' -and $semantic -match '^(max_threads|max_depth)(?:\.|$)') {
            if ($key -cnotin @('max_threads','max_depth') -or $value -notmatch '^[1-9][0-9]*$') { throw 'TOML managed limits require bare keys and positive decimal integers.' }
            if ($spans.ContainsKey($key)) { throw 'TOML duplicate managed limit.' }
            $valueMatch=[regex]::Match($statement.Code,'=\s*(?<value>[1-9][0-9]*)\s*$')
            $statement.ValueStart=$statement.Start+$valueMatch.Groups['value'].Index; $statement.ValueLength=$valueMatch.Groups['value'].Length
            $spans[$key]=$statement; $values[$key]=$value
        }
    }
    [pscustomobject]@{ Statements=@($statements); Values=[pscustomobject]$values; Spans=$spans; Agents=$agents; AgentEnd=$agentEnd; HasHooks=$hooks; HooksDisabled=$disabled }
}
function Set-AgentOperationsLimits {
    param([AllowNull()][string]$Content,[AllowNull()][object]$MaxThreads,[AllowNull()][object]$MaxDepth)
    $text=if ($null -eq $Content) {''} else {$Content}
    $parsed=Read-AgentOperationsToml $text; $newline=if ($text.Contains("`r`n")) {"`r`n"} else {"`n"}
    $edits=[Collections.Generic.List[object]]::new(); $add=''
    foreach ($entry in @(@{Name='max_threads';Value=$MaxThreads},@{Name='max_depth';Value=$MaxDepth})) {
        if ($null -ne $entry.Value -and [string]$entry.Value -notmatch '^[1-9][0-9]*$') { throw 'Invalid requested agent limit.' }
        if ($parsed.Spans.ContainsKey($entry.Name)) {
            $span=$parsed.Spans[$entry.Name]
            if ($null -eq $entry.Value) { $edits.Add(@{Start=$span.Start;Length=$span.Code.Length;Value=''}) }
            else { $edits.Add(@{Start=$span.ValueStart;Length=$span.ValueLength;Value=[string]$entry.Value}) }
        } elseif ($null -ne $entry.Value) { $add+="$($entry.Name) = $($entry.Value)$newline" }
    }
    if ($add) {
        $offset=$parsed.AgentEnd
        if ($null -eq $parsed.Agents) { $add="[agents]$newline$add"; $offset=$text.Length }
        if ($offset -gt 0 -and $text[$offset-1] -ne "`n") { $add=$newline+$add }
        $edits.Add(@{Start=$offset;Length=0;Value=$add})
    }
    foreach ($edit in @($edits | Sort-Object Start -Descending)) { $text=$text.Remove($edit.Start,$edit.Length).Insert($edit.Start,$edit.Value) }
    $verified=Read-AgentOperationsToml $text
    if ([string]$verified.Values.max_threads -cne [string]$MaxThreads -or [string]$verified.Values.max_depth -cne [string]$MaxDepth) { throw 'TOML postimage agent limit verification failed.' }
    return $text
}
function Get-AgentOperationsProperty {
    param([object]$Object,[string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [Collections.IDictionary]) { return $Object[$Name] }
    $property=$Object.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }; return $null
}
function Get-AgentOperationsReviewerProvenance {
    param([object]$Manifest,[bool]$ReviewerExists,[string]$CurrentFingerprint)
    $provenance=Get-AgentOperationsProperty $Manifest 'reviewerProvenance'
    $present=if ($Manifest -is [Collections.IDictionary]) { $Manifest.Contains('reviewerProvenance') } else { $null -ne $Manifest -and $null -ne $Manifest.PSObject.Properties['reviewerProvenance'] }
    if ($present) {
        $origin=Get-AgentOperationsProperty $provenance 'origin'; $initial=Get-AgentOperationsProperty $provenance 'initialFingerprint'
        if ($origin -isnot [string] -or $origin -cnotin @('created','preexisting') -or $initial -isnot [string] -or $initial -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid reviewerProvenance; ownership cannot be proven.' }; return $provenance
    }
    if ($null -eq $Manifest) { return [pscustomobject]@{origin=$(if ($ReviewerExists) {'preexisting'} else {'created'}); initialFingerprint=$CurrentFingerprint} }
    $legacy=Get-AgentOperationsProperty (Get-AgentOperationsProperty $Manifest 'createdFiles') 'reviewer'
    $origin=if ($legacy -is [bool] -and $legacy) {'created'} else {'preexisting'}
    $initial=[string](Get-AgentOperationsProperty $Manifest 'installerOwnedReviewerFingerprint')
    if ($initial -notmatch '^[0-9a-f]{64}$') { $initial=$CurrentFingerprint }
    [pscustomobject]@{origin=$origin;initialFingerprint=$initial}
}
function ConvertTo-AgentOperationsDate {
    param([object]$Value)
    if ($Value -is [DateTimeOffset]) { return $Value }
    if ($Value -is [DateTime]) { if ($Value.Kind -eq [DateTimeKind]::Unspecified) { throw 'Timestamp timezone is missing.' }; return [DateTimeOffset]$Value.ToUniversalTime() }
    if ($Value -isnot [string] -or $Value -notmatch '(?:Z|\+00:00)$') { throw 'Expected a UTC timestamp.' }
    return [DateTimeOffset]::Parse($Value,[Globalization.CultureInfo]::InvariantCulture)
}
function Test-AgentOperationsObservationTime {
    param([object]$ObservedAt,[object]$InstalledAt,[DateTimeOffset]$Now=[DateTimeOffset]::UtcNow)
    try { $observed=ConvertTo-AgentOperationsDate $ObservedAt; $installed=ConvertTo-AgentOperationsDate $InstalledAt; return $observed -ge $installed -and $observed -ge $Now.AddMinutes(-15) -and $observed -le $Now.AddSeconds(30) } catch { return $false }
}
function Test-AgentOperationsReviewerEvidence {
    param([object]$Evidence,[string]$ReviewerFingerprint,[string]$ActivationBindingHash,[string]$ConfigHash,[object]$InstalledAt,[string]$ExpectedRuntimeFingerprint,[string]$ExpectedSessionId,[DateTimeOffset]$Now=[DateTimeOffset]::UtcNow)
    $reason='verified'; $passed=$false
    try {
        $allowed=@('schemaVersion','reviewerFingerprint','activationBindingHash','configHash','observedAtUtc','hostIdentity','runtimeFingerprint','childSessionId','effectiveSandbox','readSucceeded','writeDenied')
        if ($Evidence -isnot [pscustomobject] -or @($Evidence.PSObject.Properties.Name | Where-Object { $_ -cnotin $allowed }).Count -gt 0) { throw 'Unsupported reviewer evidence object fields.' }
        $version=Get-AgentOperationsProperty $Evidence 'schemaVersion'
        if (($version -isnot [long] -and $version -isnot [int]) -or $version -ne 2) { throw 'Reviewer evidence requires integer schemaVersion 2.' }
        foreach ($hash in @($ReviewerFingerprint,$ActivationBindingHash,$ConfigHash)) { if ($hash -cnotmatch '^[0-9a-f]{64}$') { throw 'Expected binding fingerprint is invalid.' } }
        if ($ExpectedRuntimeFingerprint -cnotmatch '^[0-9a-f]{64}$' -or [string]::IsNullOrWhiteSpace($ExpectedSessionId)) { throw 'Expected controlled child identity is missing.' }
        foreach ($pair in @(@('reviewerFingerprint',$ReviewerFingerprint),@('activationBindingHash',$ActivationBindingHash),@('configHash',$ConfigHash),@('hostIdentity',[Environment]::MachineName),@('runtimeFingerprint',$ExpectedRuntimeFingerprint),@('childSessionId',$ExpectedSessionId),@('effectiveSandbox','read-only'))) {
            $actual=Get-AgentOperationsProperty $Evidence $pair[0]
            if ($actual -isnot [string] -or $actual -cne $pair[1]) { throw "Reviewer evidence $($pair[0]) mismatch." }
        }
        foreach ($name in @('readSucceeded','writeDenied')) { $value=Get-AgentOperationsProperty $Evidence $name; if ($value -isnot [bool] -or !$value) { throw "Reviewer evidence $name must be true." } }
        if (!(Test-AgentOperationsObservationTime (Get-AgentOperationsProperty $Evidence 'observedAtUtc') $InstalledAt $Now)) { throw 'Reviewer observation is stale, future, or predates install.' }
        $passed=$true
    } catch { $reason=$_.Exception.Message }
    [pscustomobject]@{Passed=$passed;Reason=$reason}
}
function Get-AgentOperationsEvidenceHash {
    param([object]$Evidence)
    $canonical=[ordered]@{}
    foreach ($property in @($Evidence.PSObject.Properties | Sort-Object Name)) {
        $value=$property.Value
        if ($property.Name -eq 'observedAtUtc') { try { $value=(ConvertTo-AgentOperationsDate $value).UtcDateTime.ToString('o') } catch { } }
        $canonical[$property.Name]=$value
    }
    $bytes=[Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Depth 30 -Compress))
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
function Test-AgentOperationsActivationFreshness {
    param([object]$Evidence,[object]$InstalledAt,[DateTimeOffset]$Now=[DateTimeOffset]::UtcNow)
    try {
        $version=Get-AgentOperationsProperty $Evidence 'schemaVersion'
        if (($version -isnot [int] -and $version -isnot [long]) -or $version -ne 2) { return $false }
        $reviewer=Get-AgentOperationsProperty $Evidence 'reviewerEvidence'
        $check=Test-AgentOperationsReviewerEvidence -Evidence $reviewer -ReviewerFingerprint $Evidence.reviewerFingerprint -ActivationBindingHash $Evidence.activationBindingHash -ConfigHash $Evidence.configHash -InstalledAt $InstalledAt -ExpectedRuntimeFingerprint $Evidence.expectedReviewerRuntimeFingerprint -ExpectedSessionId $Evidence.expectedReviewerSessionId -Now $Now
        if (!$check.Passed -or (Get-AgentOperationsEvidenceHash $reviewer) -cne $Evidence.reviewerEvidenceHash) { return $false }
        $reviewed=ConvertTo-AgentOperationsDate $reviewer.observedAtUtc
        if ((ConvertTo-AgentOperationsDate $Evidence.reviewerObservationAtUtc) -ne $reviewed -or !(Test-AgentOperationsObservationTime $Evidence.runtimeObservationAtUtc $InstalledAt $Now)) { return $false }
        $runtime=ConvertTo-AgentOperationsDate $Evidence.runtimeObservationAtUtc; $created=ConvertTo-AgentOperationsDate $Evidence.evidenceCreatedAtUtc; $expires=ConvertTo-AgentOperationsDate $Evidence.expiresAtUtc
        $earliest=if ($runtime -lt $reviewed) {$runtime.AddMinutes(15)} else {$reviewed.AddMinutes(15)}
        return $Evidence.schemaVersion -eq 2 -and $created -le $Now.AddSeconds(30) -and $created -ge $reviewed.AddSeconds(-30) -and $created -ge $runtime.AddSeconds(-30) -and $expires -eq $earliest -and $Now -le $expires
    } catch { return $false }
}
Export-ModuleMember -Function Read-AgentOperationsToml,Set-AgentOperationsLimits,Get-AgentOperationsReviewerProvenance,Test-AgentOperationsReviewerEvidence,Test-AgentOperationsActivationFreshness,Get-AgentOperationsEvidenceHash,ConvertTo-AgentOperationsDate,Test-AgentOperationsObservationTime
