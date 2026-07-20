[CmdletBinding()]
param(
    [string]$CodexHome = (Join-Path $HOME ".codex"),
    [string]$ReviewerEvidencePath,
    [switch]$ManualHookTrustConfirmed,
    [switch]$ControlledHostTaskConfirmed,
    [string]$SimulateRuntimeReplacementAfterCapturePath,
    [string]$OutputPath,
    [ValidateSet("Json", "Text")]
    [string]$OutputFormat = "Json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-Sha256Text {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-Sha256File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
    }
    finally {
        $stream.Dispose()
    }
}

function Get-Sha256Bytes {
    param([byte[]]$Bytes)

    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Write-TextAtomic {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent ([System.IO.Path]::GetFullPath($Path))
    if (-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }
    $temporary = Join-Path $directory (".activation-evidence.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
    try {
        [System.IO.File]::WriteAllText($temporary, $Content, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Get-AgentLimits {
    param([string]$Content)

    $values = [ordered]@{ max_threads = $null; max_depth = $null }
    $inAgents = $false
    foreach ($line in ($Content -split "\r?\n")) {
        if ($line -match '^\s*\[([^\]]+)\]\s*(?:#.*)?$') {
            $inAgents = $Matches[1] -eq "agents"
            continue
        }
        if ($inAgents -and $line -match '^\s*(max_threads|max_depth)\s*=\s*([^#\r\n]+?)\s*(?:#.*)?$') {
            $values[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return [pscustomobject]$values
}

function Get-HookFingerprint {
    param([object]$Group)

    return Get-Sha256Text -Text ($Group | ConvertTo-Json -Depth 50 -Compress)
}

function Test-InstalledHookDefinitions {
    param(
        [string]$HooksPath,
        [object]$ExpectedFingerprints
    )

    if (-not (Test-Path -LiteralPath $HooksPath -PathType Leaf) -or $null -eq $ExpectedFingerprints) {
        return $false
    }
    try {
        $hooksDocument = [System.IO.File]::ReadAllText($HooksPath) | ConvertFrom-Json -Depth 50
        foreach ($eventName in @("PreToolUse", "PostToolUse")) {
            $expected = [string](Get-PropertyValue -Object $ExpectedFingerprints -Name $eventName)
            $groups = @((Get-PropertyValue -Object (Get-PropertyValue -Object $hooksDocument -Name "hooks") -Name $eventName))
            if ([string]::IsNullOrWhiteSpace($expected) -or
                @($groups | Where-Object { (Get-HookFingerprint -Group $_) -eq $expected }).Count -ne 1) {
                return $false
            }
        }
        return $true
    }
    catch {
        return $false
    }
}

function ConvertTo-DateTimeOffsetValue {
    param([object]$Value)

    if ($Value -is [DateTimeOffset]) { return $Value }
    if ($Value -is [DateTime]) {
        $dateTime = [DateTime]$Value
        if ($dateTime.Kind -eq [DateTimeKind]::Unspecified) {
            $dateTime = [DateTime]::SpecifyKind($dateTime, [DateTimeKind]::Utc)
        }
        return [DateTimeOffset]::new($dateTime.ToUniversalTime())
    }
    return [DateTimeOffset]::Parse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind
    )
}

function Test-PathWithinRoot {
    param(
        [string]$Path,
        [string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-ManagedPathWithoutReparseAncestors {
    param(
        [string]$CodexHomePath,
        [string]$Path
    )

    $normalizedHome = [System.IO.Path]::GetFullPath($CodexHomePath).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $target = [System.IO.Path]::GetFullPath($Path)
    $relative = [System.IO.Path]::GetRelativePath($normalizedHome, $target)
    if ($relative -eq ".") { return $true }
    if ($relative -eq ".." -or $relative.StartsWith("..$([System.IO.Path]::DirectorySeparatorChar)")) { return $false }

    $current = $normalizedHome
    foreach ($segment in $relative.Split(
        @([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
        [System.StringSplitOptions]::RemoveEmptyEntries
    )) {
        $current = Join-Path $current $segment
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
        }
    }
    return $true
}

function Test-ManagedPathSetSafe {
    param(
        [string]$CodexHomePath,
        [string[]]$Paths
    )

    return @($Paths | Where-Object {
        -not (Test-ManagedPathWithoutReparseAncestors -CodexHomePath $CodexHomePath -Path $_)
    }).Count -eq 0
}

function Get-ActivationTelemetryObservation {
    param(
        [string]$LogsRoot,
        [string]$RuntimeVersion,
        [object]$InstalledAt,
        [string]$ExpectedActivationHash
    )

    try {
        $installedAtValue = ConvertTo-DateTimeOffsetValue -Value $InstalledAt
    }
    catch {
        return [pscustomobject]@{ Observed = $false; Reason = "invalid-installed-at"; ObservedAtUtc = $null }
    }
    $freshnessCutoff = [DateTimeOffset]::UtcNow.AddMinutes(-15)
    $futureTolerance = [DateTimeOffset]::UtcNow.AddMinutes(5)
    $reasons = [System.Collections.Generic.List[string]]::new()

    foreach ($name in @("agent-operations.jsonl", "agent-operations.1.jsonl", "agent-operations.2.jsonl")) {
        $path = Join-Path $LogsRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        foreach ($line in @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $record = $line | ConvertFrom-Json -Depth 10
                $recordedAt = ConvertTo-DateTimeOffsetValue -Value (Get-PropertyValue -Object $record -Name "timestamp")
                if ([string](Get-PropertyValue -Object $record -Name "category") -ne "activation-probe") { continue }
                if ((Get-PropertyValue -Object $record -Name "schemaVersion") -ne 1 -or
                    [string](Get-PropertyValue -Object $record -Name "runtimeVersion") -ne $RuntimeVersion -or
                    [string](Get-PropertyValue -Object $record -Name "eventName") -ne "PreToolUse" -or
                    [string](Get-PropertyValue -Object $record -Name "severity") -ne "info" -or
                    [string](Get-PropertyValue -Object $record -Name "action") -ne "observe" -or
                    [string](Get-PropertyValue -Object $record -Name "repoHash") -notmatch '^[0-9a-f]{64}$') {
                    $reasons.Add("record-contract-mismatch")
                    continue
                }
                if ([string](Get-PropertyValue -Object $record -Name "sessionHash") -ne $ExpectedActivationHash) {
                    $reasons.Add("install-binding-mismatch")
                    continue
                }
                if ($recordedAt -lt $installedAtValue) { $reasons.Add("before-install"); continue }
                if ($recordedAt -lt $freshnessCutoff) { $reasons.Add("stale"); continue }
                if ($recordedAt -gt $futureTolerance) { $reasons.Add("future-timestamp"); continue }
                return [pscustomobject]@{ Observed = $true; Reason = "matched"; ObservedAtUtc = $recordedAt.UtcDateTime.ToString("o") }
            }
            catch {
                $reasons.Add("malformed-record")
            }
        }
    }
    $reason = if ($reasons.Count -eq 0) { "no-activation-record" } else { (@($reasons | Select-Object -Unique) -join ",") }
    return [pscustomobject]@{ Observed = $false; Reason = $reason; ObservedAtUtc = $null }
}

function Invoke-HookProbe {
    param(
        [string]$InputJson,
        [byte[]]$RuntimeBytes,
        [string]$ExpectedRuntimeHash
    )

    $stagingDirectory = $null
    $stagingPath = $null
    try {
        if ((Get-Sha256Bytes -Bytes $RuntimeBytes) -ne $ExpectedRuntimeHash) { return $null }
        $stagingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-agent-operations-probe-{0}" -f [guid]::NewGuid().ToString("N"))
        [void][System.IO.Directory]::CreateDirectory($stagingDirectory)
        $stagingPath = Join-Path $stagingDirectory "agent-operations-hook.ps1"
        $stream = [System.IO.File]::Open($stagingPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try { $stream.Write($RuntimeBytes, 0, $RuntimeBytes.Length) }
        finally { $stream.Dispose() }
        if ((Get-Sha256File -Path $stagingPath) -ne $ExpectedRuntimeHash) { return $null }
        $output = @($InputJson | & pwsh -NoProfile -File $stagingPath -NoTelemetry 2>$null) -join "`n"
        if ($LASTEXITCODE -ne 0) { return $null }
        return $output | ConvertFrom-Json -Depth 20
    }
    catch {
        return $null
    }
    finally {
        if (-not [string]::IsNullOrWhiteSpace($stagingDirectory) -and
            (Test-Path -LiteralPath $stagingDirectory -PathType Container)) {
            $normalizedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
            if ((Test-PathWithinRoot -Path $stagingDirectory -Root $normalizedTemp) -and
                -not ((Get-Item -LiteralPath $stagingDirectory -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                if (-not [string]::IsNullOrWhiteSpace($stagingPath) -and (Test-Path -LiteralPath $stagingPath -PathType Leaf) -and
                    -not ((Get-Item -LiteralPath $stagingPath -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    [System.IO.File]::Delete($stagingPath)
                }
                if (@(Get-ChildItem -LiteralPath $stagingDirectory -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                    [System.IO.Directory]::Delete($stagingDirectory, $false)
                }
            }
        }
    }
}

$codexHomePath = [System.IO.Path]::GetFullPath($CodexHome)
$manifestPath = Join-Path $codexHomePath "agent-operations/install-manifest.json"
$configPath = Join-Path $codexHomePath "config.toml"
$hooksPath = Join-Path $codexHomePath "hooks.json"
$reviewerPath = Join-Path $codexHomePath "agents/independent-reviewer.toml"
$logsRoot = Join-Path $codexHomePath "logs"
$operationsRoot = Join-Path $codexHomePath "agent-operations"
$versionsRoot = Join-Path $operationsRoot "versions"
$baseManagedPaths = @($manifestPath, $configPath, $hooksPath, $reviewerPath, $logsRoot, $operationsRoot, $versionsRoot)
$basePathsSafe = Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $baseManagedPaths

$manifest = $null
try {
    if ($basePathsSafe) {
        $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -Depth 30
    }
}
catch {
    $manifest = [pscustomobject]@{}
}
if ($null -eq $manifest) { $manifest = [pscustomobject]@{} }

$runtimeVersion = [string](Get-PropertyValue -Object $manifest -Name "runtimeVersion")
$runtimeVersionValid = $runtimeVersion -match '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$'
$runtimeDirectory = if ($runtimeVersionValid) { Join-Path $versionsRoot $runtimeVersion } else { Join-Path $versionsRoot "__invalid__" }
$runtimePath = Join-Path $runtimeDirectory "agent-operations-hook.ps1"
$runtimeMarkerPath = Join-Path (Split-Path -Parent $runtimePath) ".agent-operations-owned.json"
$runtimeManagedPaths = @($baseManagedPaths) + @($runtimeDirectory, $runtimePath, $runtimeMarkerPath)
$runtimePathSafe = $basePathsSafe -and $runtimeVersionValid -and
    (Test-PathWithinRoot -Path $runtimePath -Root $versionsRoot) -and
    (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $runtimeManagedPaths)
$runtimeChecksums = Get-PropertyValue -Object $manifest -Name "runtimeChecksums"
$runtimeHash = [string](Get-PropertyValue -Object $runtimeChecksums -Name "hook")
$expectedMarkerHash = [string](Get-PropertyValue -Object $runtimeChecksums -Name "marker")
$reviewerFingerprint = [string](Get-PropertyValue -Object $manifest -Name "installerOwnedReviewerFingerprint")
$activationChallenge = [string](Get-PropertyValue -Object $manifest -Name "activationChallenge")
$telemetrySalt = [string](Get-PropertyValue -Object $manifest -Name "telemetrySalt")
$installedAt = Get-PropertyValue -Object $manifest -Name "installedAt"
$manifestPassed = (Get-PropertyValue -Object $manifest -Name "schemaVersion") -eq 1 -and
    [string](Get-PropertyValue -Object $manifest -Name "owner") -eq "agent-operations" -and
    [string](Get-PropertyValue -Object $manifest -Name "state") -eq "awaiting-trust" -and
    $runtimeVersionValid -and $runtimePathSafe -and
    $activationChallenge -match '^[0-9a-f]{64}$' -and
    $telemetrySalt -match '^[0-9a-f]{64}$'

$runtimePassed = $manifestPassed -and -not [string]::IsNullOrWhiteSpace($runtimeVersion) -and
    $runtimeHash -match '^[0-9a-f]{64}$' -and
    (Get-Sha256File -Path $runtimePath) -eq $runtimeHash -and
    (Get-Sha256File -Path $runtimeMarkerPath) -eq $expectedMarkerHash
$capturedRuntimeBytes = $null
if ($runtimePassed -and (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $runtimeManagedPaths)) {
    try {
        $capturedRuntimeBytes = [System.IO.File]::ReadAllBytes($runtimePath)
        $runtimePassed = (Get-Sha256Bytes -Bytes $capturedRuntimeBytes) -eq $runtimeHash
    }
    catch {
        $runtimePassed = $false
        $capturedRuntimeBytes = $null
    }
}
if ($runtimePassed -and -not [string]::IsNullOrWhiteSpace($SimulateRuntimeReplacementAfterCapturePath) -and
    (Test-Path -LiteralPath $SimulateRuntimeReplacementAfterCapturePath -PathType Leaf)) {
    [System.IO.File]::Copy($SimulateRuntimeReplacementAfterCapturePath, $runtimePath, $true)
}
$reviewerFingerprintPassed = $basePathsSafe -and $reviewerFingerprint -match '^[0-9a-f]{64}$' -and
    (Get-Sha256File -Path $reviewerPath) -eq $reviewerFingerprint
$hooksPassed = $basePathsSafe -and (Test-InstalledHookDefinitions -HooksPath $hooksPath -ExpectedFingerprints (Get-PropertyValue -Object $manifest -Name "installerOwnedHookFingerprints"))
$expectedActivationHash = if ($manifestPassed) { Get-Sha256Text -Text ("$telemetrySalt|activation|$activationChallenge") } else { $null }
$activationTelemetryObservation = Get-ActivationTelemetryObservation -LogsRoot $logsRoot -RuntimeVersion $runtimeVersion -InstalledAt $installedAt -ExpectedActivationHash $expectedActivationHash
$activationTelemetryObserved = [bool]$activationTelemetryObservation.Observed
$runtimeChallengeObserved = $hooksPassed -and $activationTelemetryObserved

$configText = if ($basePathsSafe -and (Test-Path -LiteralPath $configPath -PathType Leaf)) { [System.IO.File]::ReadAllText($configPath) } else { "" }
$agentLimits = Get-AgentLimits -Content $configText
$agentLimitsPassed = $agentLimits.max_threads -eq "4" -and $agentLimits.max_depth -eq "1"

$safeResult = if ($runtimePassed) {
    Invoke-HookProbe -InputJson '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rg TODO src -g \"*.cs\""}}' -RuntimeBytes $capturedRuntimeBytes -ExpectedRuntimeHash $runtimeHash
} else { $null }
$badResult = if ($runtimePassed) {
    Invoke-HookProbe -InputJson '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rg TODO src\\*.cs"}}' -RuntimeBytes $capturedRuntimeBytes -ExpectedRuntimeHash $runtimeHash
} else { $null }
$postResult = if ($runtimePassed) {
    Invoke-HookProbe -InputJson '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"rg absent ."},"tool_response":{"exit_code":1,"stderr":""}}' -RuntimeBytes $capturedRuntimeBytes -ExpectedRuntimeHash $runtimeHash
} else { $null }
$failOpenResult = if ($runtimePassed) { Invoke-HookProbe -InputJson '{' -RuntimeBytes $capturedRuntimeBytes -ExpectedRuntimeHash $runtimeHash } else { $null }

$safeCallPassed = $null -ne $safeResult -and @($safeResult.PSObject.Properties).Count -eq 0
$knownBadPreToolUsePassed = $null -ne $badResult -and $null -ne $badResult.PSObject.Properties["hookSpecificOutput"]
$postToolUsePassed = $null -ne $postResult -and $null -ne $postResult.PSObject.Properties["hookSpecificOutput"]
$failOpenPassed = $null -ne $failOpenResult -and [string]$failOpenResult.systemMessage -match 'remains allowed'
$runtimeStillInstalled = $runtimePassed -and
    (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $runtimeManagedPaths) -and
    (Get-Sha256File -Path $runtimePath) -eq $runtimeHash

$reviewerWriteDenied = $false
if (-not [string]::IsNullOrWhiteSpace($ReviewerEvidencePath) -and (Test-Path -LiteralPath $ReviewerEvidencePath -PathType Leaf)) {
    try {
        $reviewerEvidence = [System.IO.File]::ReadAllText($ReviewerEvidencePath) | ConvertFrom-Json -Depth 20
        $reviewerWriteDenied = [string]$reviewerEvidence.reviewerFingerprint -eq $reviewerFingerprint -and
            [string]$reviewerEvidence.effectiveSandbox -eq "read-only" -and
            $reviewerEvidence.readSucceeded -is [bool] -and $reviewerEvidence.readSucceeded -and
            $reviewerEvidence.writeDenied -is [bool] -and $reviewerEvidence.writeDenied
    }
    catch {
        $reviewerWriteDenied = $false
    }
}

$evidenceCreatedAt = [DateTimeOffset]::UtcNow
$runtimeObservationAt = if ($runtimeChallengeObserved) { ConvertTo-DateTimeOffsetValue -Value $activationTelemetryObservation.ObservedAtUtc } else { $null }
$expiresAt = if ($null -eq $runtimeObservationAt) { $evidenceCreatedAt } else { $runtimeObservationAt.AddMinutes(15) }
$evidenceRuntimeMarkerHash = if ($runtimePathSafe) { Get-Sha256File -Path $runtimeMarkerPath } else { $null }
$evidenceConfigHash = if ($basePathsSafe) { Get-Sha256File -Path $configPath } else { $null }
$evidenceHooksHash = if ($basePathsSafe) { Get-Sha256File -Path $hooksPath } else { $null }
$evidenceReviewerHash = if ($basePathsSafe) { Get-Sha256File -Path $reviewerPath } else { $null }
$evidence = [ordered]@{
    schemaVersion = 1
    runtimeVersion = $runtimeVersion
    runtimeHash = $runtimeHash
    runtimeMarkerHash = $evidenceRuntimeMarkerHash
    configHash = $evidenceConfigHash
    hooksHash = $evidenceHooksHash
    reviewerHash = $evidenceReviewerHash
    reviewerFingerprint = $reviewerFingerprint
    activationBindingHash = $expectedActivationHash
    manualHookTrustConfirmed = [bool]$ManualHookTrustConfirmed
    controlledHostTaskConfirmed = [bool]$ControlledHostTaskConfirmed
    hookDefinitionsPassed = $hooksPassed
    activationTelemetryObserved = $activationTelemetryObserved
    activationTelemetryReason = [string]$activationTelemetryObservation.Reason
    runtimeChallengeObserved = $runtimeChallengeObserved
    runtimeStillInstalled = $runtimeStillInstalled
    runtimeObservationAtUtc = if ($null -eq $runtimeObservationAt) { $null } else { $runtimeObservationAt.UtcDateTime.ToString("o") }
    evidenceCreatedAtUtc = $evidenceCreatedAt.UtcDateTime.ToString("o")
    expiresAtUtc = $expiresAt.UtcDateTime.ToString("o")
    safeCallPassed = $safeCallPassed
    knownBadPreToolUsePassed = $knownBadPreToolUsePassed
    postToolUsePassed = $postToolUsePassed
    failOpenPassed = $failOpenPassed
    agentLimitsPassed = $agentLimitsPassed
    reviewerWriteDenied = $reviewerFingerprintPassed -and $reviewerWriteDenied
}
$allPassed = $runtimePassed -and @(
    "manualHookTrustConfirmed",
    "controlledHostTaskConfirmed",
    "runtimeChallengeObserved",
    "runtimeStillInstalled",
    "safeCallPassed",
    "knownBadPreToolUsePassed",
    "postToolUsePassed",
    "failOpenPassed",
    "agentLimitsPassed",
    "reviewerWriteDenied"
    | Where-Object { -not $evidence[$_] }
).Count -eq 0

$json = ($evidence | ConvertTo-Json -Depth 10) + [Environment]::NewLine
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    Write-TextAtomic -Path $OutputPath -Content $json
}
if ($OutputFormat -eq "Json") {
    Write-Output $json.TrimEnd()
}
else {
    Write-Host ("Activation probe: {0}" -f $(if ($allPassed) { "PASS" } else { "FAIL" }))
    foreach ($name in @("manualHookTrustConfirmed", "controlledHostTaskConfirmed", "runtimeChallengeObserved", "runtimeStillInstalled", "safeCallPassed", "knownBadPreToolUsePassed", "postToolUsePassed", "failOpenPassed", "agentLimitsPassed", "reviewerWriteDenied")) {
        Write-Host ("{0}: {1}" -f $name, $evidence[$name])
    }
}
if ($allPassed) { exit 0 }
exit 2
