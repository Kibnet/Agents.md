[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [DateTimeOffset]$Since,
    [Parameter(Mandatory)]
    [DateTimeOffset]$Until,
    [string[]]$SessionsRoot = @(
        (Join-Path $HOME ".codex/sessions"),
        (Join-Path $HOME ".codex/archived_sessions")
    ),
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [string]$GoldSetPath,
    [string]$EvidenceSaltPath,
    [string]$EvidenceMapPath,
    [switch]$EmitPrivateReviewSample,
    [ValidateSet("path-glob", "failed-patch", "git-sandbox", "timeout", "user-correction")]
    [string]$PrivateReviewCategory,
    [string]$PrivateReviewSelectionPath,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ClassifierVersion = "3.1.0"
$script:KeyCategories = @("path-glob", "failed-patch", "git-sandbox", "timeout")
$technicalCandidateCategories = if ($EmitPrivateReviewSample) {
    if ($PrivateReviewCategory -in $script:KeyCategories) { @($PrivateReviewCategory) } else { @() }
}
else {
    @($script:KeyCategories)
}
$script:AllCategories = @(
    "path-glob",
    "failed-patch",
    "git-sandbox",
    "timeout",
    "test-failure",
    "build-failure",
    "line-ending",
    "powershell-quoting",
    "network-auth-restore",
    "file-process-lock",
    "missing-dependency",
    "git-conflict-state",
    "wrong-cli-runner-args",
    "expected-no-match",
    "expected-tdd-red",
    "environment-blocker",
    "user-correction",
    "interrupted"
)

if ($Until -le $Since) {
    throw "Until must be later than Since."
}
if ($EmitPrivateReviewSample -and [string]::IsNullOrWhiteSpace($PrivateReviewCategory)) {
    throw "PrivateReviewCategory is required with EmitPrivateReviewSample."
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string[]]$Names
    )

    if ($null -eq $Object) {
        return $null
    }
    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($null -ne $property) {
            return $property.Value
        }
    }
    return $null
}

function Get-Sha256 {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Add-TextFragment {
    param(
        [System.Text.StringBuilder]$Builder,
        [object]$Value,
        [int]$Depth = 0
    )

    if ($null -eq $Value -or $Builder.Length -ge 65536 -or $Depth -gt 8) {
        return
    }
    if ($Value -is [string]) {
        $remaining = 65536 - $Builder.Length
        [void]$Builder.Append($Value.Substring(0, [Math]::Min($remaining, $Value.Length)))
        [void]$Builder.Append("`n")
        return
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($entry in $Value.GetEnumerator()) {
            Add-TextFragment -Builder $Builder -Value $entry.Value -Depth ($Depth + 1)
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            Add-TextFragment -Builder $Builder -Value $item -Depth ($Depth + 1)
        }
        return
    }
    foreach ($property in $Value.PSObject.Properties) {
        Add-TextFragment -Builder $Builder -Value $property.Value -Depth ($Depth + 1)
    }
}

function ConvertTo-BoundedText {
    param([object]$Value)

    $builder = [System.Text.StringBuilder]::new()
    Add-TextFragment -Builder $builder -Value $Value
    return $builder.ToString()
}

function Get-PrivateReviewText {
    param(
        [AllowNull()][string]$Text,
        [int]$MaximumLength = 4000
    )

    if ([string]::IsNullOrEmpty($Text)) { return "" }
    return $Text.Substring(0, [Math]::Min($Text.Length, $MaximumLength))
}

function ConvertFrom-ToolInput {
    param([object]$Value)

    if ($Value -isnot [string]) {
        return $Value
    }
    $trimmed = $Value.Trim()
    if (($trimmed.StartsWith("{") -and $trimmed.EndsWith("}")) -or ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]"))) {
        try {
            return $trimmed | ConvertFrom-Json -Depth 50
        }
        catch {
            return $Value
        }
    }
    return $Value
}

function Get-ToolCommand {
    param([object]$InputObject)

    if ($InputObject -is [string]) {
        return $InputObject
    }
    $command = Get-PropertyValue -Object $InputObject -Names @("command", "cmd", "script", "patch")
    if ($command -is [System.Collections.IEnumerable] -and $command -isnot [string]) {
        return @($command) -join " "
    }
    return [string]$command
}

function Test-CommandName {
    param(
        [string]$Command,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }
    return $Command -match ("(?im)(?:^|[;|&]\s*)" + [regex]::Escape($Name) + "(?:\.exe)?(?:\s|$)")
}

function Test-ConfirmedFailure {
    param([string]$OutputText)

    return $OutputText -match '(?im)(?:^|\b)(?:exit code|exit_code)\s*[:=]\s*[1-9]\d*\b|\bisError\b\s*[:=]\s*true|script failed|tool (?:call )?failed|process exited with code [1-9]\d*'
}

function Get-DirectExitCode {
    param([string]$OutputText)

    $match = [regex]::Match($OutputText, '(?im)^Exit code:\s*(-?\d+)\s*$')
    if (-not $match.Success) { return $null }
    return [int]$match.Groups[1].Value
}

function Test-RgExpectedNoMatch {
    param(
        [string]$Command,
        [string]$OutputText
    )

    if (-not (Test-CommandName -Command $Command -Name "rg")) {
        return $false
    }
    if ((Get-DirectExitCode -OutputText $OutputText) -ne 1) {
        return $false
    }
    return $OutputText -notmatch '(?im)(stderr\s*[:=]\s*\S|^rg:\s.*(?:error|os error|regex parse error|i/o error)|invalid|permission|denied|not recognized|no such file|cannot find|error:)'
}

function Get-CallClassifications {
    param(
        [string]$ToolName,
        [object]$InputObject,
        [object]$OutputObject
    )

    $categories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $command = Get-ToolCommand -InputObject $InputObject
    $outputText = ConvertTo-BoundedText -Value $OutputObject
    $failure = Test-ConfirmedFailure -OutputText $outputText
    $isShellCommand = $ToolName -ieq "shell_command"
    $shellExitCode = if ($isShellCommand) { Get-DirectExitCode -OutputText $outputText } else { $null }
    $shellFailure = $isShellCommand -and $null -ne $shellExitCode -and $shellExitCode -ne 0
    $plannedRed = [bool](Get-PropertyValue -Object $InputObject -Names @("planned_red", "plannedRed", "expected_red", "expectedRed"))

    $environmentSignal = $outputText -match '(?im)(permission denied|access (?:is )?denied|unauthori[sz]ed|authentication|\b401\b|\b403\b|NU1301|unable to load the service index|SSL|certificate|index\.lock|being used by another process|another git process|missing (?:sdk|workload|dependency)|command not found|not recognized as (?:the name of )?a cmdlet)'
    if ($environmentSignal) {
        [void]$categories.Add("environment-blocker")
    }
    if ($outputText -match '(?im)(unauthori[sz]ed|authentication|\b401\b|\b403\b|NU1301|unable to load the service index|SSL|certificate|restore failed)') {
        [void]$categories.Add("network-auth-restore")
    }
    if ($outputText -match '(?im)(index\.lock|being used by another process|another git process|file.+locked|sharing violation)') {
        [void]$categories.Add("file-process-lock")
    }
    if ($outputText -match '(?im)(missing (?:sdk|workload|dependency)|command not found|not recognized as (?:the name of )?a cmdlet|could not execute because.+not found)') {
        [void]$categories.Add("missing-dependency")
    }

    if (Test-RgExpectedNoMatch -Command $command -OutputText $outputText) {
        [void]$categories.Add("expected-no-match")
        return @($categories)
    }

    if ($shellFailure) {
        if ($shellExitCode -eq 124 -or $outputText -match '(?im)(command timed out|timed out after)') {
            [void]$categories.Add("timeout")
        }
        elseif ($outputText -match '(?ims)(being used by another process|process cannot access the file|msb3026|msb3027|блокирует этот файл|sharing violation)') {
            # File locks take precedence over broader permission/path categories.
        }
        elseif ($outputText -match '(?ims)(permission denied|access is denied|unauthorizedaccessexception|index\.lock|cannot lock ref|could not create.*lock|unable to create.*lock|host key verification failed)') {
            [void]$categories.Add("git-sandbox")
        }
        elseif ($outputText -match '(?ims)(parsererror|missing file specification after redirection operator|variable reference is not valid|terminatorexpected|unexpected token|incompleteparseexception|here-string header|cannot bind parameter.*index)') {
            # PowerShell syntax failures take precedence over incidental path text.
        }
        elseif ($outputText -match '(?ims)(^rg:\s.*\(os error (?:2|3|123)\)|cannot find path .*because it does not exist|could not find a part of the path|filenotfounderror|directorynotfoundexception|no such file or directory)') {
            [void]$categories.Add("path-glob")
        }
    }

    $isPatch = $ToolName -match '(?i)apply_patch|patch' -or $command -match '(?i)^\*\*\* Begin Patch'
    if ($isPatch -and $outputText -match '(?im)(failed|error|invalid patch|could not|permission|denied)') {
        [void]$categories.Add("failed-patch")
    }

    $gitCommand = Test-CommandName -Command $command -Name "git"
    if ($gitCommand -and $failure -and $outputText -match '(?im)(conflict|unmerged|not possible to fast-forward|non-fast-forward|would be overwritten|detached HEAD|no upstream)') {
        [void]$categories.Add("git-conflict-state")
    }

    $testCommand = $command -match '(?im)(dotnet\s+(?:test|run).*(?:test|Tests)|npm\s+test|pytest|playwright\s+test|test-validate)'
    if ($testCommand -and $failure) {
        if ($plannedRed -and -not $environmentSignal -and $outputText -notmatch '(?im)(compile error|build failed|MSB\d{4}|CS\d{4})') {
            [void]$categories.Add("expected-tdd-red")
        }
        else {
            [void]$categories.Add("test-failure")
        }
    }
    if ($failure -and $command -match '(?im)(dotnet\s+build|msbuild|npm\s+run\s+build|cargo\s+build)' -or $outputText -match '(?im)(build failed|compile error|error\s+CS\d{4}|error\s+MSB\d{4})') {
        [void]$categories.Add("build-failure")
    }
    if ($failure -and $outputText -match '(?im)(trailing whitespace|CRLF will be replaced by LF|LF will be replaced by CRLF|line endings)') {
        [void]$categories.Add("line-ending")
    }
    if ($failure -and $outputText -match '(?im)(parsererror|unexpected token|variable reference is not valid|terminator.+missing|parameterbindingexception|here-doc|heredoc)') {
        [void]$categories.Add("powershell-quoting")
    }
    if ($failure -and $command -match '(?im)(dotnet\s+(?:test|run).+--filter\b)' -and ($outputText -match '(?im)(TUnit|treenode-filter|unknown option|unrecognized option)')) {
        [void]$categories.Add("wrong-cli-runner-args")
    }

    return @($categories)
}

function Get-TraceIdFromFileName {
    param([string]$Name)

    if ($Name -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl$') {
        return $Matches[1]
    }
    return Get-Sha256 -Text $Name
}

function Test-HighRecallCandidate {
    param(
        [string]$Category,
        [string]$ToolName,
        [object]$InputObject,
        [object]$OutputObject,
        [AllowNull()][string]$Command,
        [AllowNull()][string]$OutputText
    )

    if ($null -eq $Command) { $Command = Get-ToolCommand -InputObject $InputObject }
    if ($null -eq $OutputText) { $OutputText = ConvertTo-BoundedText -Value $OutputObject }
    switch ($Category) {
        "path-glob" {
            return $Command -match '(?i)(?:-LiteralPath\s+[^\r\n]*[*?]|\b(?:rg|Get-Content|Get-ChildItem)\b[^\r\n]*[*?])' -or
                $OutputText -match '(?im)(cannot find|not found|no such file|os error (?:2|3|123)|directorynotfound|filenotfound)'
        }
        "failed-patch" {
            return $ToolName -match '(?i)patch|apply_patch' -or
                $Command -match '(?i)Begin Patch' -or
                $OutputText -match '(?im)(invalid context|invalid patch|patch failed|hunk failed|could not apply)'
        }
        "git-sandbox" {
            return (Test-CommandName -Command $Command -Name "git") -or
                $OutputText -match '(?im)(permission denied|access is denied|index\.lock|cannot lock ref|unable to create.*lock|host key verification failed)'
        }
        "timeout" {
            return $OutputText -match '(?im)(timed out|timeout|exit code:\s*124)' -or
                $Command -match '(?i)\b(?:test|build|restore|playwright)\b'
        }
        default { return $false }
    }
}

function New-EvidenceSample {
    param(
        [object[]]$Candidates,
        [int]$PerLabelLimit = 20
    )

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($category in $script:KeyCategories) {
        $categoryCandidates = @($Candidates |
            Where-Object { $_.category -eq $category } |
            Sort-Object evidenceHash |
            Group-Object evidenceHash |
            ForEach-Object { $_.Group[0] })
        $positives = @($categoryCandidates | Where-Object { $_.predicted } | Sort-Object evidenceHash | Select-Object -First $PerLabelLimit)
        $negativeHighRecall = @($categoryCandidates | Where-Object { -not $_.predicted -and $_.highRecall } | Sort-Object evidenceHash | Select-Object -First $PerLabelLimit)
        $remaining = $PerLabelLimit - $negativeHighRecall.Count
        $background = if ($remaining -gt 0) {
            @($categoryCandidates | Where-Object { -not $_.predicted -and -not $_.highRecall } | Sort-Object evidenceHash | Select-Object -First $remaining)
        }
        else { @() }

        foreach ($candidate in @($positives + $negativeHighRecall + $background)) {
            $entries.Add([ordered]@{
                sessionHash = $candidate.sessionHash
                evidenceHash = $candidate.evidenceHash
                category = $candidate.category
                predicted = [bool]$candidate.predicted
                selectionReason = if ($candidate.highRecall) { "high-recall" } elseif ($candidate.predicted) { "predicted-positive" } else { "background" }
            })
        }
    }
    $correctionCandidates = @($Candidates |
        Where-Object { $_.category -eq "user-correction" } |
        Sort-Object evidenceHash |
        Group-Object evidenceHash |
        ForEach-Object { $_.Group[0] })
    foreach ($candidate in $correctionCandidates) {
        $entries.Add([ordered]@{
            sessionHash = $candidate.sessionHash
            evidenceHash = $candidate.evidenceHash
            category = $candidate.category
            predicted = [bool]$candidate.predicted
            selectionReason = "strong-signal"
        })
    }
    return @($entries | Sort-Object category, evidenceHash)
}

function Get-GoldSetReport {
    param(
        [string]$Path,
        [hashtable]$Predictions,
        [object[]]$ExpectedSample,
        [string]$ExpectedSampleId,
        [string]$ExpectedSamplingAlgorithm,
        [string]$ExpectedSeedId
    )

    $reports = [ordered]@{}
    foreach ($category in $script:KeyCategories) {
        $reports[$category] = [ordered]@{
            status = "manual-review-only"
            reason = "gold-set-missing"
            tp = 0
            fp = 0
            tn = 0
            fn = 0
            invalidEntries = 0
            precision = $null
            recall = $null
            falsePositiveRate = $null
        }
    }
    $reports["user-correction"] = [ordered]@{
        status = "manual-review-only"
        reason = "gold-set-missing"
        reviewed = 0
        confirmed = 0
        rejected = 0
        invalidEntries = 0
    }
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]$reports
    }

    $gold = (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Json -Depth 20
    $entriesValue = Get-PropertyValue -Object $gold -Names @("entries")
    $entries = if ($null -ne $entriesValue -and $entriesValue -is [pscustomobject]) {
        @($entriesValue.PSObject.Properties | ForEach-Object {
            [pscustomobject]@{
                evidenceHash = $_.Name
                category = Get-PropertyValue -Object $_.Value -Names @("category")
                expected = Get-PropertyValue -Object $_.Value -Names @("expected")
            }
        })
    }
    elseif ($gold -is [System.Collections.IEnumerable] -and $gold -isnot [string] -and $null -eq $gold.PSObject.Properties["entries"]) { @($gold) }
    else { @($entriesValue) }
    $sampleMetadataMatches =
        (Get-PropertyValue -Object $gold -Names @("schemaVersion")) -eq 1 -and
        [string](Get-PropertyValue -Object $gold -Names @("samplingAlgorithm")) -eq $ExpectedSamplingAlgorithm -and
        [string](Get-PropertyValue -Object $gold -Names @("seedId")) -eq $ExpectedSeedId -and
        [string](Get-PropertyValue -Object $gold -Names @("sampleId")) -eq $ExpectedSampleId
    foreach ($category in $script:KeyCategories) {
        $tp = 0; $fp = 0; $tn = 0; $fn = 0
        $invalidEntries = 0
        $categoryEntries = @($entries | Where-Object { $_.category -eq $category })
        $expectedHashes = @($ExpectedSample | Where-Object { $_.category -eq $category } | ForEach-Object { [string]$_.evidenceHash } | Sort-Object)
        $actualHashes = @($categoryEntries | ForEach-Object { [string](Get-PropertyValue -Object $_ -Names @("evidenceHash")) } | Sort-Object)
        $sampleMatches = $sampleMetadataMatches -and
            ($expectedHashes -join "|") -eq ($actualHashes -join "|") -and
            @($actualHashes | Select-Object -Unique).Count -eq $actualHashes.Count
        if (-not $sampleMatches) {
            $invalidEntries += [Math]::Max(1, [Math]::Abs($expectedHashes.Count - $actualHashes.Count))
        }
        foreach ($entry in $categoryEntries) {
            $expectedValue = Get-PropertyValue -Object $entry -Names @("expected", "label", "positive")
            $evidenceHash = [string](Get-PropertyValue -Object $entry -Names @("evidenceHash"))
            if ($expectedValue -isnot [bool] -or $evidenceHash -notmatch '^[0-9a-fA-F]{64}$' -or $evidenceHash -notin $expectedHashes) {
                $invalidEntries++
                continue
            }
            $expected = $expectedValue
            $predicted = if (-not [string]::IsNullOrWhiteSpace($evidenceHash) -and $Predictions.ContainsKey($evidenceHash)) {
                [bool]$Predictions[$evidenceHash]
            }
            else {
                $false
            }
            if ($expected -and $predicted) { $tp++ }
            elseif (-not $expected -and $predicted) { $fp++ }
            elseif (-not $expected -and -not $predicted) { $tn++ }
            else { $fn++ }
        }

        $precision = if (($tp + $fp) -gt 0) { $tp / ($tp + $fp) } else { $null }
        $recall = if (($tp + $fn) -gt 0) { $tp / ($tp + $fn) } else { $null }
        $fpr = if (($fp + $tn) -gt 0) { $fp / ($fp + $tn) } else { $null }
        $passed = $invalidEntries -eq 0 -and $null -ne $precision -and $null -ne $recall -and $null -ne $fpr -and $precision -ge 0.90 -and $recall -ge 0.80 -and $fpr -le 0.10
        $reports[$category] = [ordered]@{
            status = if ($passed) { "auto-counted" } else { "manual-review-only" }
            reason = if (-not $sampleMatches) { "gold-sample-mismatch" } elseif ($invalidEntries -gt 0) { "invalid-gold-entry" } elseif ($passed) { "thresholds-passed" } else { "thresholds-failed-or-undefined" }
            tp = $tp
            fp = $fp
            tn = $tn
            fn = $fn
            invalidEntries = $invalidEntries
            precision = $precision
            recall = $recall
            falsePositiveRate = $fpr
        }
    }
    $correctionExpectedHashes = @($ExpectedSample |
        Where-Object { $_.category -eq "user-correction" } |
        ForEach-Object { [string]$_.evidenceHash } |
        Sort-Object)
    $correctionEntries = @($entries | Where-Object { $_.category -eq "user-correction" })
    $correctionActualHashes = @($correctionEntries |
        ForEach-Object { [string](Get-PropertyValue -Object $_ -Names @("evidenceHash")) } |
        Sort-Object)
    $correctionInvalidEntries = 0
    $correctionSampleMatches = $sampleMetadataMatches -and
        ($correctionExpectedHashes -join "|") -eq ($correctionActualHashes -join "|") -and
        @($correctionActualHashes | Select-Object -Unique).Count -eq $correctionActualHashes.Count
    if (-not $correctionSampleMatches) {
        $correctionInvalidEntries += [Math]::Max(1, [Math]::Abs($correctionExpectedHashes.Count - $correctionActualHashes.Count))
    }
    $correctionConfirmed = 0
    $correctionRejected = 0
    foreach ($entry in $correctionEntries) {
        $expectedValue = Get-PropertyValue -Object $entry -Names @("expected", "label", "positive")
        $evidenceHash = [string](Get-PropertyValue -Object $entry -Names @("evidenceHash"))
        if ($expectedValue -isnot [bool] -or $evidenceHash -notin $correctionExpectedHashes) {
            $correctionInvalidEntries++
            continue
        }
        if ($expectedValue) { $correctionConfirmed++ } else { $correctionRejected++ }
    }
    $reports["user-correction"] = [ordered]@{
        status = if ($correctionInvalidEntries -eq 0 -and $correctionExpectedHashes.Count -gt 0) { "manually-reviewed" } else { "manual-review-only" }
        reason = if (-not $correctionSampleMatches) { "gold-sample-mismatch" } elseif ($correctionInvalidEntries -gt 0) { "invalid-gold-entry" } elseif ($correctionExpectedHashes.Count -eq 0) { "no-strong-signals" } else { "all-strong-signals-reviewed" }
        reviewed = $correctionConfirmed + $correctionRejected
        confirmed = $correctionConfirmed
        rejected = $correctionRejected
        invalidEntries = $correctionInvalidEntries
    }
    return [pscustomobject]$reports
}

$resolvedRoots = @($SessionsRoot | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | ForEach-Object { (Resolve-Path -LiteralPath $_).Path } | Select-Object -Unique)
if ($resolvedRoots.Count -eq 0) {
    throw "No session roots exist."
}

$allFileCandidates = @($resolvedRoots | ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Filter "*.jsonl" } | Sort-Object FullName -Unique)
$fileGroups = @($allFileCandidates | Group-Object { Get-TraceIdFromFileName -Name $_.Name })
$duplicateTraceFileCount = [long]@($fileGroups | ForEach-Object { [Math]::Max(0, $_.Count - 1) } | Measure-Object -Sum).Sum
$allFiles = @($fileGroups | ForEach-Object {
    $_.Group |
        Sort-Object @{ Expression = "LastWriteTimeUtc"; Descending = $true }, @{ Expression = "Length"; Descending = $true }, FullName |
        Select-Object -First 1
} | Sort-Object FullName)
$files = @($allFiles | Where-Object { $_.LastWriteTimeUtc -ge $Since.UtcDateTime })
$taskCategories = @{}
$traceCategoryCounts = @{}
$eventCategoryCounts = @{}
foreach ($category in $script:AllCategories) {
    $traceCategoryCounts[$category] = 0
    $eventCategoryCounts[$category] = 0
}
$includedTasks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$includedTraces = 0L
$toolCallCount = 0L
$directToolCallEnvelopeCount = 0L
$otherRecognizedToolCallCount = 0L
$unresolvedCodeModeWrapperCount = 0L
$matchedDirectToolCallCount = 0L
$matchedOtherRecognizedToolCallCount = 0L
$matchedCodeModeWrapperCount = 0L
$unmatchedDirectToolCallCount = 0L
$unmatchedOtherRecognizedToolCallCount = 0L
$unmatchedCodeModeWrapperCount = 0L
$outputWithoutMatchingCallCount = 0L
$boundaryPairCount = 0L
$duplicateCallIdCount = 0L
$malformedLineCount = 0L
$partialTraceCount = 0L
$candidateWithoutWindowCount = 0L
$predictionMap = @{}
$evidenceCandidates = [System.Collections.Generic.List[object]]::new()
$traceMetadata = @{}
$traceAliases = @{}
$traceResults = [System.Collections.Generic.List[object]]::new()
$salt = if (-not [string]::IsNullOrWhiteSpace($EvidenceSaltPath) -and (Test-Path -LiteralPath $EvidenceSaltPath -PathType Leaf)) { (Get-Content -LiteralPath $EvidenceSaltPath -Raw).Trim() } else { $null }
$privateReviewSelection = @{}
if ($EmitPrivateReviewSample -and -not [string]::IsNullOrWhiteSpace($PrivateReviewSelectionPath)) {
    if (-not (Test-Path -LiteralPath $PrivateReviewSelectionPath -PathType Leaf)) {
        throw "PrivateReviewSelectionPath does not exist."
    }
    $selectionDocument = (Get-Content -LiteralPath $PrivateReviewSelectionPath -Raw) | ConvertFrom-Json -Depth 30
    foreach ($entry in @((Get-PropertyValue -Object $selectionDocument -Names @("entries")) | Where-Object { $_.category -eq $PrivateReviewCategory })) {
        $privateReviewSelection[[string]$entry.evidenceHash] = $entry
    }
    if ($privateReviewSelection.Count -eq 0) {
        throw "PrivateReviewSelectionPath has no entries for category '$PrivateReviewCategory'."
    }
}
$lastProgress = [DateTime]::UtcNow
$processedFiles = 0

foreach ($file in $files) {
    $processedFiles++
    if (-not $Quiet -and ([DateTime]::UtcNow - $lastProgress).TotalSeconds -ge 10) {
        Write-Host ("INFO: processed {0}/{1} traces" -f $processedFiles, $files.Count)
        $lastProgress = [DateTime]::UtcNow
    }

    $fileTraceId = Get-TraceIdFromFileName -Name $file.Name
    $traceId = $fileTraceId
    $traceStart = $null
    $traceEnd = $null
    $traceHasWindowRecord = $false
    $traceHasOutsideWindowRecord = $false
    $traceToolCalls = 0L
    $traceDirectToolCallEnvelopes = 0L
    $traceOtherRecognizedToolCalls = 0L
    $traceUnresolvedCodeModeWrappers = 0L
    $traceMatchedDirectToolCalls = 0L
    $traceMatchedOtherRecognizedToolCalls = 0L
    $traceMatchedCodeModeWrappers = 0L
    $traceOutputWithoutMatchingCalls = 0L
    $traceBoundaryPairs = 0L
    $traceDuplicateCallIds = 0L
    $traceCategories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $traceEventCounts = @{}
    $pendingCalls = @{}
    $seenCallIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $taintedCallIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $completedCallContributions = @{}
    $lineNumber = 0L

    $stream = [System.IO.FileStream]::new($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = [System.IO.StreamReader]::new($stream)
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            $lineNumber++
            if (-not $Quiet -and ([DateTime]::UtcNow - $lastProgress).TotalSeconds -ge 10) {
                Write-Host ("INFO: processed {0}/{1} traces; current trace line {2}" -f ($processedFiles - 1), $files.Count, $lineNumber)
                $lastProgress = [DateTime]::UtcNow
            }
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $record = $line | ConvertFrom-Json -Depth 50
            }
            catch {
                $malformedLineCount++
                continue
            }

            $timestampValue = Get-PropertyValue -Object $record -Names @("timestamp")
            [DateTimeOffset]$timestamp = [DateTimeOffset]::MinValue
            $hasTimestamp = if ($timestampValue -is [DateTime]) {
                $timestamp = [DateTimeOffset]::new($timestampValue.ToUniversalTime())
                $true
            }
            elseif ($timestampValue -is [DateTimeOffset]) {
                $timestamp = $timestampValue
                $true
            }
            else {
                [DateTimeOffset]::TryParse([string]$timestampValue, [ref]$timestamp)
            }
            $isInWindow = $hasTimestamp -and $timestamp -ge $Since -and $timestamp -lt $Until
            if ($isInWindow) {
                $traceHasWindowRecord = $true
                if ($null -eq $traceStart -or $timestamp -lt $traceStart) { $traceStart = $timestamp }
                if ($null -eq $traceEnd -or $timestamp -gt $traceEnd) { $traceEnd = $timestamp }
            }
            elseif ($hasTimestamp) {
                $traceHasOutsideWindowRecord = $true
            }

            $recordType = [string](Get-PropertyValue -Object $record -Names @("type"))
            $payload = Get-PropertyValue -Object $record -Names @("payload")
            $payloadType = [string](Get-PropertyValue -Object $payload -Names @("type"))

            if ($recordType -eq "session_meta") {
                $explicitSessionId = [string](Get-PropertyValue -Object $payload -Names @("session_id", "sessionId"))
                $candidateTraceId = [string](Get-PropertyValue -Object $payload -Names @("id"))
                $parentId = [string](Get-PropertyValue -Object $payload -Names @("parent_thread_id", "parentThreadId"))
                if ([string]::IsNullOrWhiteSpace($parentId)) {
                    $parentId = [string](Get-PropertyValue -Object $payload -Names @("forked_from_id", "forkedFromId"))
                }
                if ([string]::IsNullOrWhiteSpace($parentId) -and -not [string]::IsNullOrWhiteSpace($explicitSessionId) -and $explicitSessionId -ne $candidateTraceId) {
                    $parentId = $explicitSessionId
                }
                if (-not [string]::IsNullOrWhiteSpace($candidateTraceId)) { $traceId = $candidateTraceId }
                if (-not [string]::IsNullOrWhiteSpace($candidateTraceId)) {
                    $traceAliases[$fileTraceId] = $candidateTraceId
                    $traceMetadata[$candidateTraceId] = [pscustomobject]@{
                        Id = $candidateTraceId
                        ParentId = $parentId
                        ThreadSource = [string](Get-PropertyValue -Object $payload -Names @("thread_source", "threadSource"))
                    }
                }
                continue
            }

            $isCall = $recordType -eq "response_item" -and $payloadType -in @("custom_tool_call", "function_call", "local_shell_call", "mcp_tool_call", "web_search_call", "computer_call", "shell_call")
            $isOutput = $recordType -eq "response_item" -and $payloadType -in @("custom_tool_call_output", "function_call_output", "local_shell_call_output", "mcp_tool_call_output", "computer_call_output", "shell_call_output")
            if ($hasTimestamp -and $timestamp -ge $Until) {
                if ($isOutput) {
                    $trailingCallId = [string](Get-PropertyValue -Object $payload -Names @("call_id", "callId", "id"))
                    if (-not [string]::IsNullOrWhiteSpace($trailingCallId) -and
                        $pendingCalls.ContainsKey($trailingCallId) -and $pendingCalls[$trailingCallId].IsInWindow) {
                        $traceBoundaryPairs++
                        $pendingCalls.Remove($trailingCallId)
                    }
                }
                continue
            }
            if ($isCall) {
                $callId = [string](Get-PropertyValue -Object $payload -Names @("call_id", "callId", "id"))
                if ([string]::IsNullOrWhiteSpace($callId)) { $callId = "line-$lineNumber" }
                if (-not $seenCallIds.Add($callId)) {
                    $traceDuplicateCallIds++
                    [void]$taintedCallIds.Add($callId)
                    if ($pendingCalls.ContainsKey($callId)) { $pendingCalls.Remove($callId) }
                    if ($completedCallContributions.ContainsKey($callId)) {
                        $priorContribution = $completedCallContributions[$callId]
                        switch ([string]$priorContribution.Kind) {
                            "direct" { $traceMatchedDirectToolCalls-- }
                            "wrapper" { $traceMatchedCodeModeWrappers-- }
                            "other" { $traceMatchedOtherRecognizedToolCalls-- }
                        }
                        foreach ($priorCategory in @($priorContribution.Categories)) {
                            if ($traceEventCounts.ContainsKey($priorCategory)) {
                                $traceEventCounts[$priorCategory] = [long]$traceEventCounts[$priorCategory] - 1
                                if ($traceEventCounts[$priorCategory] -le 0) {
                                    $traceEventCounts.Remove($priorCategory)
                                    [void]$traceCategories.Remove($priorCategory)
                                }
                            }
                        }
                        foreach ($priorCandidate in @($priorContribution.EvidenceCandidates)) {
                            [void]$evidenceCandidates.Remove($priorCandidate)
                        }
                        foreach ($priorPredictionHash in @($priorContribution.PredictionHashes)) {
                            $predictionMap.Remove([string]$priorPredictionHash)
                        }
                        $completedCallContributions.Remove($callId)
                    }
                    continue
                }
                $inputValue = Get-PropertyValue -Object $payload -Names @("input", "arguments", "command")
                $toolName = [string](Get-PropertyValue -Object $payload -Names @("name", "tool_name", "toolName"))
                $isCodeModeWrapper = $payloadType -eq "custom_tool_call" -and $toolName -in @("exec", "functions.exec")
                $isCompatibilityEnvelope = $payloadType -in @("custom_tool_call", "function_call")
                $pendingCalls[$callId] = [pscustomobject]@{
                    Name = $toolName
                    Input = ConvertFrom-ToolInput -Value $inputValue
                    Index = $lineNumber
                    IsCodeModeWrapper = $isCodeModeWrapper
                    IsCompatibilityEnvelope = $isCompatibilityEnvelope
                    IsInWindow = $isInWindow
                }
                if ($isInWindow) {
                    if ($isCompatibilityEnvelope) {
                        $traceToolCalls++
                    }
                    if ($isCodeModeWrapper) {
                        $traceUnresolvedCodeModeWrappers++
                    }
                    elseif ($isCompatibilityEnvelope) {
                        $traceDirectToolCallEnvelopes++
                    }
                    else {
                        $traceOtherRecognizedToolCalls++
                    }
                }
                continue
            }

            if (-not $isInWindow) {
                if ($isOutput) {
                    $outsideCallId = [string](Get-PropertyValue -Object $payload -Names @("call_id", "callId", "id"))
                    if (-not [string]::IsNullOrWhiteSpace($outsideCallId) -and $pendingCalls.ContainsKey($outsideCallId) -and $pendingCalls[$outsideCallId].IsInWindow) {
                        $traceBoundaryPairs++
                        $pendingCalls.Remove($outsideCallId)
                    }
                }
                continue
            }

            if ($recordType -eq "event_msg") {
                if ($payloadType -match '(?i)(abort|cancel|interrupt)') {
                    [void]$traceCategories.Add("interrupted")
                    $traceEventCounts["interrupted"] = 1 + $(if ($traceEventCounts.ContainsKey("interrupted")) { $traceEventCounts["interrupted"] } else { 0 })
                }
                elseif ($payloadType -eq "patch_apply_end" -and -not [bool](Get-PropertyValue -Object $payload -Names @("success"))) {
                    [void]$traceCategories.Add("failed-patch")
                    $traceEventCounts["failed-patch"] = 1 + $(if ($traceEventCounts.ContainsKey("failed-patch")) { $traceEventCounts["failed-patch"] } else { 0 })
                }
                elseif ($payloadType -eq "user_message") {
                    $message = [string](Get-PropertyValue -Object $payload -Names @("message"))
                    if ($message -match '(?im)^\s*(?:исправь|переделай|сделай ревью(?:\s+спеки)?|это не то|я просил(?:а)?\b|ты не (?:сделал|уч[её]л))\s*[.!?]*\s*$') {
                        [void]$traceCategories.Add("user-correction")
                        $traceEventCounts["user-correction"] = 1 + $(if ($traceEventCounts.ContainsKey("user-correction")) { $traceEventCounts["user-correction"] } else { 0 })
                        if ($null -ne $salt -and (-not $EmitPrivateReviewSample -or $PrivateReviewCategory -eq "user-correction")) {
                            $correctionEvidenceHash = Get-Sha256 -Text ("$salt|$traceId|event|$lineNumber|user-correction")
                            if ($privateReviewSelection.Count -gt 0 -and -not $privateReviewSelection.ContainsKey($correctionEvidenceHash)) {
                                continue
                            }
                            $evidenceCandidates.Add([pscustomobject]@{
                                sessionHash = Get-Sha256 -Text ("$salt|$fileTraceId")
                                evidenceHash = $correctionEvidenceHash
                                category = "user-correction"
                                predicted = $true
                                highRecall = $true
                                reviewToolName = "user_message"
                                reviewCommand = ""
                                reviewOutput = Get-PrivateReviewText -Text $message
                            })
                        }
                    }
                }
                continue
            }

            if ($recordType -ne "response_item") { continue }
            if ($isOutput) {
                $callId = [string](Get-PropertyValue -Object $payload -Names @("call_id", "callId", "id"))
                if (-not [string]::IsNullOrWhiteSpace($callId) -and $taintedCallIds.Contains($callId)) {
                    if ($pendingCalls.ContainsKey($callId)) { $pendingCalls.Remove($callId) }
                    continue
                }
                if ([string]::IsNullOrWhiteSpace($callId) -or -not $pendingCalls.ContainsKey($callId)) {
                    $traceOutputWithoutMatchingCalls++
                }
                else {
                    $call = $pendingCalls[$callId]
                    if (-not $call.IsInWindow) {
                        $traceBoundaryPairs++
                        $pendingCalls.Remove($callId)
                        continue
                    }
                    $output = Get-PropertyValue -Object $payload -Names @("output", "result", "response")
                    if ($call.IsCodeModeWrapper) {
                        $traceMatchedCodeModeWrappers++
                        $completedCallContributions[$callId] = [pscustomobject]@{
                            Kind = "wrapper"; Categories = @(); EvidenceCandidates = @(); PredictionHashes = @()
                        }
                        $pendingCalls.Remove($callId)
                        continue
                    }
                    $callKind = if ($call.IsCompatibilityEnvelope) { "direct" } else { "other" }
                    if ($callKind -eq "direct") { $traceMatchedDirectToolCalls++ }
                    else { $traceMatchedOtherRecognizedToolCalls++ }
                    $callEvidenceCandidates = [System.Collections.Generic.List[object]]::new()
                    $callPredictionHashes = [System.Collections.Generic.List[string]]::new()
                    if ($EmitPrivateReviewSample -and $privateReviewSelection.Count -gt 0) {
                        foreach ($keyCategory in $technicalCandidateCategories) {
                            $evidenceHash = Get-Sha256 -Text ("$salt|$traceId|$callId|$keyCategory")
                            if (-not $privateReviewSelection.ContainsKey($evidenceHash)) { continue }
                            $selectionEntry = $privateReviewSelection[$evidenceHash]
                            $privateCandidate = [pscustomobject]@{
                                sessionHash = Get-Sha256 -Text ("$salt|$fileTraceId")
                                evidenceHash = $evidenceHash
                                category = $keyCategory
                                predicted = [bool]$selectionEntry.predicted
                                highRecall = $selectionEntry.selectionReason -eq "high-recall"
                                reviewToolName = $call.Name
                                reviewCommand = Get-PrivateReviewText -Text (Get-ToolCommand -InputObject $call.Input)
                                reviewOutput = Get-PrivateReviewText -Text (ConvertTo-BoundedText -Value $output)
                            }
                            $evidenceCandidates.Add($privateCandidate)
                            $callEvidenceCandidates.Add($privateCandidate)
                        }
                        $completedCallContributions[$callId] = [pscustomobject]@{
                            Kind = $callKind; Categories = @(); EvidenceCandidates = @($callEvidenceCandidates); PredictionHashes = @()
                        }
                        $pendingCalls.Remove($callId)
                        continue
                    }
                    $categories = @(Get-CallClassifications -ToolName $call.Name -InputObject $call.Input -OutputObject $output)
                    foreach ($category in $categories) {
                        [void]$traceCategories.Add($category)
                        $traceEventCounts[$category] = 1 + $(if ($traceEventCounts.ContainsKey($category)) { $traceEventCounts[$category] } else { 0 })
                    }
                    if ($null -ne $salt) {
                        $candidateCommand = Get-ToolCommand -InputObject $call.Input
                        $candidateOutputText = ConvertTo-BoundedText -Value $output
                        $reviewCommand = if ($EmitPrivateReviewSample) { Get-PrivateReviewText -Text $candidateCommand } else { "" }
                        $reviewOutput = if ($EmitPrivateReviewSample) { Get-PrivateReviewText -Text $candidateOutputText } else { "" }
                        foreach ($keyCategory in $technicalCandidateCategories) {
                            $evidenceHash = Get-Sha256 -Text ("$salt|$traceId|$callId|$keyCategory")
                            $predicted = $keyCategory -in $categories
                            $predictionMap[$evidenceHash] = $predicted
                            $candidate = [pscustomobject]@{
                                sessionHash = Get-Sha256 -Text ("$salt|$fileTraceId")
                                evidenceHash = $evidenceHash
                                category = $keyCategory
                                predicted = $predicted
                                highRecall = Test-HighRecallCandidate -Category $keyCategory -ToolName $call.Name -InputObject $call.Input -OutputObject $output -Command $candidateCommand -OutputText $candidateOutputText
                                reviewToolName = $call.Name
                                reviewCommand = $reviewCommand
                                reviewOutput = $reviewOutput
                            }
                            $evidenceCandidates.Add($candidate)
                            $callEvidenceCandidates.Add($candidate)
                            $callPredictionHashes.Add($evidenceHash)
                        }
                    }
                    $completedCallContributions[$callId] = [pscustomobject]@{
                        Kind = $callKind
                        Categories = @($categories)
                        EvidenceCandidates = @($callEvidenceCandidates)
                        PredictionHashes = @($callPredictionHashes)
                    }
                    $pendingCalls.Remove($callId)
                }
            }
        }
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }

    if (-not $traceHasWindowRecord) {
        $candidateWithoutWindowCount++
        continue
    }
    if ($traceHasOutsideWindowRecord) { $partialTraceCount++ }

    $traceUnmatchedDirectToolCalls = @($pendingCalls.Values | Where-Object { $_.IsInWindow -and $_.IsCompatibilityEnvelope -and -not $_.IsCodeModeWrapper }).Count
    $traceUnmatchedCodeModeWrappers = @($pendingCalls.Values | Where-Object { $_.IsInWindow -and $_.IsCodeModeWrapper }).Count
    $traceUnmatchedOtherRecognizedToolCalls = @($pendingCalls.Values | Where-Object { $_.IsInWindow -and -not $_.IsCompatibilityEnvelope }).Count

    $includedTraces++
    $toolCallCount += $traceToolCalls
    $directToolCallEnvelopeCount += $traceDirectToolCallEnvelopes
    $otherRecognizedToolCallCount += $traceOtherRecognizedToolCalls
    $unresolvedCodeModeWrapperCount += $traceUnresolvedCodeModeWrappers
    $matchedDirectToolCallCount += $traceMatchedDirectToolCalls
    $matchedOtherRecognizedToolCallCount += $traceMatchedOtherRecognizedToolCalls
    $matchedCodeModeWrapperCount += $traceMatchedCodeModeWrappers
    $unmatchedDirectToolCallCount += $traceUnmatchedDirectToolCalls
    $unmatchedOtherRecognizedToolCallCount += $traceUnmatchedOtherRecognizedToolCalls
    $unmatchedCodeModeWrapperCount += $traceUnmatchedCodeModeWrappers
    $outputWithoutMatchingCallCount += $traceOutputWithoutMatchingCalls
    $boundaryPairCount += $traceBoundaryPairs
    $duplicateCallIdCount += $traceDuplicateCallIds
    $traceResults.Add([pscustomobject]@{
        TraceId = $traceId
        FileTraceId = $fileTraceId
        Categories = @($traceCategories)
        EventCounts = $traceEventCounts
    })
}

foreach ($traceResult in $traceResults) {
    foreach ($category in $traceResult.Categories) {
        $traceCategoryCounts[$category] = [long]$traceCategoryCounts[$category] + 1
    }
    foreach ($entry in $traceResult.EventCounts.GetEnumerator()) {
        $eventCategoryCounts[$entry.Key] = [long]$eventCategoryCounts[$entry.Key] + [long]$entry.Value
    }

    $metadataId = if ($traceAliases.ContainsKey($traceResult.FileTraceId)) { [string]$traceAliases[$traceResult.FileTraceId] } else { [string]$traceResult.TraceId }
    $rootTraceId = $metadataId
    $visitedTraceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    while ($visitedTraceIds.Add($rootTraceId) -and $traceMetadata.ContainsKey($rootTraceId)) {
        $rootMeta = $traceMetadata[$rootTraceId]
        if ([string]$rootMeta.ThreadSource -eq "user") { break }
        $parentId = [string]$rootMeta.ParentId
        if ([string]::IsNullOrWhiteSpace($parentId)) { break }
        $rootTraceId = if ($traceAliases.ContainsKey($parentId)) { [string]$traceAliases[$parentId] } else { $parentId }
    }

    $taskKey = "primary:" + (Get-Sha256 -Text $rootTraceId)
    [void]$includedTasks.Add($taskKey)
    if (-not $taskCategories.ContainsKey($taskKey)) {
        $taskCategories[$taskKey] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }
    foreach ($category in $traceResult.Categories) {
        [void]$taskCategories[$taskKey].Add($category)
    }
}

$taskCategoryCounts = @{}
foreach ($category in $script:AllCategories) { $taskCategoryCounts[$category] = 0L }
foreach ($taskEntry in $taskCategories.GetEnumerator()) {
    foreach ($category in $taskEntry.Value) {
        $taskCategoryCounts[$category] = [long]$taskCategoryCounts[$category] + 1
    }
}

$samplingAlgorithm = "independent-stratified-v1"
$samplingSeedId = "sha256-order-v1"
$evidenceSample = if ($null -ne $salt) { @(New-EvidenceSample -Candidates @($evidenceCandidates)) } else { @() }
$sampleMaterial = @($evidenceSample | ForEach-Object {
    "{0}|{1}|{2}|{3}" -f $_.category, $_.evidenceHash, ([bool]$_.predicted).ToString().ToLowerInvariant(), $_.selectionReason
}) -join "`n"
$sampleId = if ($null -ne $salt) { Get-Sha256 -Text ("$samplingAlgorithm|$samplingSeedId|$sampleMaterial") } else { $null }
$goldReport = Get-GoldSetReport `
    -Path $GoldSetPath `
    -Predictions $predictionMap `
    -ExpectedSample $evidenceSample `
    -ExpectedSampleId $sampleId `
    -ExpectedSamplingAlgorithm $samplingAlgorithm `
    -ExpectedSeedId $samplingSeedId
$categoriesOutput = [ordered]@{}
foreach ($category in $script:AllCategories) {
    $goldStatus = if ($category -in $script:KeyCategories -or $category -eq "user-correction") { [string]$goldReport.$category.status } else { "descriptive-only" }
    $categoriesOutput[$category] = [ordered]@{
        tasks = [long]$taskCategoryCounts[$category]
        taskRate = if ($includedTasks.Count -gt 0) { [Math]::Round($taskCategoryCounts[$category] / $includedTasks.Count, 4) } else { 0 }
        traces = [long]$traceCategoryCounts[$category]
        events = [long]$eventCategoryCounts[$category]
        countingStatus = $goldStatus
    }
}

$baselineSince = [DateTimeOffset]::Parse("2026-06-17T11:05:24.066Z")
$baselineUntil = [DateTimeOffset]::Parse("2026-07-17T11:05:24.066Z")
$compatibilityApplicable = $Since.ToUniversalTime() -eq $baselineSince -and $Until.ToUniversalTime() -eq $baselineUntil
$compatibilityExpected = [ordered]@{
    topLevelTasks = 25
    traces = 124
    toolCalls = 21955
    categories = [ordered]@{
        "path-glob" = 10
        "failed-patch" = 10
        "git-sandbox" = 8
        "timeout" = 7
    }
}
$compatibilityPassed = $compatibilityApplicable -and
    $includedTasks.Count -eq $compatibilityExpected.topLevelTasks -and
    $includedTraces -eq $compatibilityExpected.traces -and
    $toolCallCount -eq $compatibilityExpected.toolCalls
if ($compatibilityPassed) {
    foreach ($category in $script:KeyCategories) {
        if ($taskCategoryCounts[$category] -ne $compatibilityExpected.categories[$category]) {
            $compatibilityPassed = $false
            break
        }
    }
}

$qualityPairingGap = $unmatchedDirectToolCallCount + $unmatchedCodeModeWrapperCount +
    $unmatchedOtherRecognizedToolCallCount + $outputWithoutMatchingCallCount + $boundaryPairCount + $duplicateCallIdCount
$comparabilityReasons = [System.Collections.Generic.List[string]]::new()
if ($unresolvedCodeModeWrapperCount -gt 0) { $comparabilityReasons.Add("code-mode wrappers hide nested calls") }
if ($qualityPairingGap -gt 0) { $comparabilityReasons.Add("unmatched, boundary, or duplicate call/output pairs were excluded") }
if ($comparabilityReasons.Count -eq 0) { $comparabilityReasons.Add("all observed direct and additional recognized calls have in-window output pairs") }

$summary = [ordered]@{
    schemaVersion = 1
    classifierVersion = $script:ClassifierVersion
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    window = [ordered]@{
        since = $Since.ToUniversalTime().ToString("o")
        until = $Until.ToUniversalTime().ToString("o")
        inclusion = "records-with-timestamp-at-or-after-since-and-before-until; candidate-files-last-write-at-or-after-since"
    }
    denominators = [ordered]@{
        topLevelTasks = $includedTasks.Count
        traces = $includedTraces
        toolCalls = $toolCallCount
        directToolCallEnvelopes = $directToolCallEnvelopeCount
        matchedDirectToolCalls = $matchedDirectToolCallCount
        unresolvedCodeModeWrappers = $unresolvedCodeModeWrapperCount
        matchedCodeModeWrappers = $matchedCodeModeWrapperCount
        otherRecognizedToolCalls = $otherRecognizedToolCallCount
        matchedOtherRecognizedToolCalls = $matchedOtherRecognizedToolCallCount
    }
    comparability = [ordered]@{
        status = if ($unresolvedCodeModeWrapperCount -gt 0 -or $qualityPairingGap -gt 0) { "partial" } else { "complete" }
        reason = @($comparabilityReasons) -join "; "
    }
    parsing = [ordered]@{
        filesAvailable = $allFileCandidates.Count
        uniqueTraceFilesAvailable = $allFiles.Count
        duplicateTraceFilesExcluded = $duplicateTraceFileCount
        filesDiscovered = $files.Count
        filesIncluded = $includedTraces
        malformedLines = $malformedLineCount
        tracesWithRecordsOutsideWindow = $partialTraceCount
        candidateFilesWithoutWindowRecords = $candidateWithoutWindowCount
        unmatchedDirectToolCalls = $unmatchedDirectToolCallCount
        unmatchedCodeModeWrappers = $unmatchedCodeModeWrapperCount
        unmatchedOtherRecognizedToolCalls = $unmatchedOtherRecognizedToolCallCount
        outputsWithoutMatchingCall = $outputWithoutMatchingCallCount
        boundaryPairsExcluded = $boundaryPairCount
        duplicateCallIds = $duplicateCallIdCount
    }
    categories = $categoriesOutput
    goldSet = $goldReport
    compatibility = [ordered]@{
        applicable = $compatibilityApplicable
        passed = $compatibilityPassed
        expected = $compatibilityExpected
        actual = [ordered]@{
            topLevelTasks = $includedTasks.Count
            traces = $includedTraces
            toolCalls = $toolCallCount
            categories = [ordered]@{
                "path-glob" = $taskCategoryCounts["path-glob"]
                "failed-patch" = $taskCategoryCounts["failed-patch"]
                "git-sandbox" = $taskCategoryCounts["git-sandbox"]
                "timeout" = $taskCategoryCounts["timeout"]
            }
        }
    }
    followUp = [ordered]@{
        warningReviewAfterDays = 14
        effectivenessReviewAfterDays = 30
        targetsAreImmediateClaims = $false
    }
}

$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $outputPath)) {
    [void](New-Item -ItemType Directory -Path $outputPath -Force)
}
$summaryJsonPath = Join-Path $outputPath "summary.json"
$summaryMarkdownPath = Join-Path $outputPath "summary.md"
[System.IO.File]::WriteAllText($summaryJsonPath, (($summary | ConvertTo-Json -Depth 50) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))

$markdown = [System.Text.StringBuilder]::new()
[void]$markdown.AppendLine("# Codex session operational error summary")
[void]$markdown.AppendLine("")
[void]$markdown.AppendLine(("Window: `{0}` to `{1}`." -f $summary.window.since, $summary.window.until))
[void]$markdown.AppendLine("")
[void]$markdown.AppendLine(("Denominators: {0} top-level tasks, {1} unique traces, {2} legacy-compatible tool-call envelopes; {3} direct envelopes have {4} matched in-window outputs, {5} code-mode wrappers remain unresolved, and {6} additional recognized envelopes are reported separately." -f $includedTasks.Count, $includedTraces, $toolCallCount, $directToolCallEnvelopeCount, $matchedDirectToolCallCount, $unresolvedCodeModeWrapperCount, $otherRecognizedToolCallCount))
[void]$markdown.AppendLine("")
[void]$markdown.AppendLine("| Category | Tasks | Task rate | Traces | Events | Counting status |")
[void]$markdown.AppendLine("| --- | ---: | ---: | ---: | ---: | --- |")
foreach ($category in $script:AllCategories) {
    $item = $categoriesOutput[$category]
    [void]$markdown.AppendLine(("| `{0}` | {1} | {2:P1} | {3} | {4} | {5} |" -f $category, $item.tasks, $item.taskRate, $item.traces, $item.events, $item.countingStatus))
}
[void]$markdown.AppendLine("")
[void]$markdown.AppendLine(("Compatibility check: {0}." -f $(if (-not $compatibilityApplicable) { "not applicable" } elseif ($compatibilityPassed) { "PASS" } else { "FAIL" })))
[void]$markdown.AppendLine("The 14-day warning review and 30-day effectiveness review are follow-up measurements; this report does not claim that targets are already achieved.")
[System.IO.File]::WriteAllText($summaryMarkdownPath, $markdown.ToString(), [System.Text.UTF8Encoding]::new($false))

if (-not [string]::IsNullOrWhiteSpace($EvidenceMapPath) -and $null -ne $salt) {
    $evidenceOutputPath = [System.IO.Path]::GetFullPath($EvidenceMapPath)
    $evidenceDirectory = Split-Path -Parent $evidenceOutputPath
    if (-not (Test-Path -LiteralPath $evidenceDirectory)) { [void](New-Item -ItemType Directory -Path $evidenceDirectory -Force) }
    $evidencePayload = [ordered]@{
        schemaVersion = 1
        classifierVersion = $script:ClassifierVersion
        samplingAlgorithm = $samplingAlgorithm
        seedId = $samplingSeedId
        sampleId = $sampleId
        candidateCount = $evidenceCandidates.Count
        entries = @($evidenceSample)
    }
    [System.IO.File]::WriteAllText($evidenceOutputPath, (($evidencePayload | ConvertTo-Json -Depth 20) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
}

if ($EmitPrivateReviewSample) {
    if ($null -eq $salt) {
        throw "EvidenceSaltPath must point to an existing private salt when emitting a review sample."
    }
    $privateEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($sampleEntry in @($evidenceSample | Where-Object { $_.category -eq $PrivateReviewCategory })) {
        $candidate = @($evidenceCandidates | Where-Object { $_.evidenceHash -eq $sampleEntry.evidenceHash } | Select-Object -First 1)
        if ($candidate.Count -eq 0) { continue }
        $privateEntries.Add([ordered]@{
            evidenceHash = $sampleEntry.evidenceHash
            category = $sampleEntry.category
            toolName = $candidate[0].reviewToolName
            command = $candidate[0].reviewCommand
            result = $candidate[0].reviewOutput
        })
    }
    [ordered]@{
        schemaVersion = 1
        sampleId = $sampleId
        category = $PrivateReviewCategory
        entries = @($privateEntries)
    } | ConvertTo-Json -Depth 10
}

if (-not $Quiet) {
    Write-Host ("PASS: wrote privacy-safe summaries to {0}" -f $outputPath)
}

if (-not $EmitPrivateReviewSample -and $compatibilityApplicable -and -not $compatibilityPassed) {
    exit 2
}
exit 0
