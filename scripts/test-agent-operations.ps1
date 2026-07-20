[CmdletBinding()]
param(
    [ValidateSet("All", "Hooks", "Installer", "Analyzer", "Privacy")]
    [string]$Area = "All"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$hookScript = Join-Path $repositoryRoot "scripts/hooks/agent-operations-hook.ps1"
$installerScript = Join-Path $repositoryRoot "scripts/install-agent-operations.ps1"
$activationProbeScript = Join-Path $repositoryRoot "scripts/probe-agent-operations-activation.ps1"
$analyzerScript = Join-Path $repositoryRoot "scripts/analyze-codex-session-errors.ps1"
$behavioralSmokeSchema = Join-Path $repositoryRoot "schemas/agent-operations-behavioral-smoke.schema.json"
$smokeReviewSchema = Join-Path $repositoryRoot "schemas/agent-operations-smoke-review.schema.json"
$goldLabelsSchema = Join-Path $repositoryRoot "schemas/agent-operations-gold-labels.schema.json"
$fixtureRoot = Join-Path $repositoryRoot "scripts/fixtures/agent-operations"
$preflightScript = Join-Path $repositoryRoot "templates/codex/local-environment/preflight.ps1"
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
$testRoot = Join-Path $tempBase ("agent-operations-tests-" + [guid]::NewGuid().ToString("N"))
[void](New-Item -ItemType Directory -Path $testRoot)

$script:Failed = $false
$script:Passed = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        $script:Passed++
        return
    }
    $script:Failed = $true
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    Assert-True -Condition ($Actual -eq $Expected) -Message ("{0}; expected '{1}', actual '{2}'" -f $Message, $Expected, $Actual)
}

function Write-TestText {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-FileTreeFingerprint {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return "missing"
    }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @(Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName)) {
        $relative = [System.IO.Path]::GetRelativePath($Root, $item.FullName)
        if ($item.PSIsContainer) {
            $lines.Add("D|$relative|$([int]$item.Attributes)")
        }
        else {
            $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $lines.Add("F|$relative|$hash|$([int]$item.Attributes)")
        }
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-TextSha256 {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Test-JsonSchemaDocument {
    param(
        [string]$Json,
        [string]$SchemaPath
    )

    try { return [bool]($Json | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop) }
    catch { return $false }
}

function Wait-ForTestPath {
    param(
        [string]$Path,
        [int]$TimeoutSeconds = 15
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $Path) { return $true }
        Start-Sleep -Milliseconds 50
    }
    return $false
}

function Invoke-JsonProcess {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    $output = @(& pwsh -NoProfile -File $ScriptPath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $raw = @($output | ForEach-Object { [string]$_ }) -join "`n"
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $json = $raw | ConvertFrom-Json -Depth 50 } catch { }
    }
    return [pscustomobject]@{ ExitCode = $exitCode; Raw = $raw; Json = $json }
}

function Invoke-HookFixture {
    param(
        [object]$Payload,
        [string]$TelemetryRoot,
        [string]$InstallManifestPath,
        [switch]$NoTelemetry,
        [switch]$SimulateRotationFailureAfterArchiveReplace,
        [switch]$SimulateRotationRollbackFailure,
        [switch]$SimulateRecoveryMarkerDriftBeforeQuarantine,
        [switch]$SimulateRecoveryQuarantineVerificationFailure,
        [switch]$SimulateRecoveryCleanupFailureAfterFirstDelete
    )

    $inputPath = Join-Path $testRoot ("hook-input-" + [guid]::NewGuid().ToString("N") + ".json")
    Write-TestText -Path $inputPath -Content (($Payload | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $arguments = @{ InputPath = $inputPath }
    if (-not [string]::IsNullOrWhiteSpace($TelemetryRoot)) {
        $arguments.TelemetryRoot = $TelemetryRoot
        if ([string]::IsNullOrWhiteSpace($InstallManifestPath)) {
            $InstallManifestPath = Join-Path $testRoot "hook-install-manifest.json"
            if (-not (Test-Path -LiteralPath $InstallManifestPath -PathType Leaf)) {
                $hookHash = (Get-FileHash -LiteralPath $hookScript -Algorithm SHA256).Hash.ToLowerInvariant()
                $hookManifest = [ordered]@{
                    schemaVersion = 1
                    owner = "agent-operations"
                    runtimeVersion = "3.1.0"
                    runtimeChecksums = [ordered]@{ hook = $hookHash }
                    telemetrySalt = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
                    activationChallenge = "0123456789abcdef0123456789abcdef"
                }
                Write-TestText -Path $InstallManifestPath -Content (($hookManifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
            }
        }
        $arguments.InstallManifestPath = $InstallManifestPath
    }
    if ($NoTelemetry) { $arguments.NoTelemetry = $true }
    if ($SimulateRotationFailureAfterArchiveReplace) { $arguments.SimulateRotationFailureAfterArchiveReplace = $true }
    if ($SimulateRotationRollbackFailure) { $arguments.SimulateRotationRollbackFailure = $true }
    if ($SimulateRecoveryMarkerDriftBeforeQuarantine) { $arguments.SimulateRecoveryMarkerDriftBeforeQuarantine = $true }
    if ($SimulateRecoveryQuarantineVerificationFailure) { $arguments.SimulateRecoveryQuarantineVerificationFailure = $true }
    if ($SimulateRecoveryCleanupFailureAfterFirstDelete) { $arguments.SimulateRecoveryCleanupFailureAfterFirstDelete = $true }
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $raw = @(& $hookScript @arguments) -join "`n"
    $stopwatch.Stop()
    $json = $raw | ConvertFrom-Json -Depth 20
    return [pscustomobject]@{ Raw = $raw; Json = $json; Duration = $stopwatch.Elapsed }
}

function Get-AllPropertyNames {
    param([object]$Value)

    $names = [System.Collections.Generic.List[string]]::new()
    function Visit {
        param([object]$Current)
        if ($null -eq $Current -or $Current -is [string] -or $Current -is [System.ValueType]) { return }
        if ($Current -is [System.Collections.IEnumerable]) {
            foreach ($item in $Current) { Visit -Current $item }
            return
        }
        foreach ($property in $Current.PSObject.Properties) {
            $names.Add($property.Name)
            Visit -Current $property.Value
        }
    }
    Visit -Current $Value
    return @($names)
}

function Test-Hooks {
    Write-Host "INFO: hook contracts" -ForegroundColor Cyan
    $telemetry = Join-Path $testRoot "hook-telemetry"

    $bad = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"
        turn_id = "turn-rg"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = 'rg TODO src\*.cs' }
    }) -TelemetryRoot $telemetry
    Assert-True -Condition ($null -ne $bad.Json.PSObject.Properties["hookSpecificOutput"]) -Message "raw rg path glob should produce model-visible context"
    Assert-True -Condition ($bad.Duration.TotalSeconds -le 2) -Message "hook fixture should complete within two seconds"

    $duplicate = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"
        turn_id = "turn-rg"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = 'rg TODO src\*.cs' }
    }) -TelemetryRoot $telemetry
    Assert-Equal -Actual @($duplicate.Json.PSObject.Properties).Count -Expected 0 -Message "duplicate warning in one turn should be suppressed"

    $safe = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = 'rg TODO src -g "*.cs"' }
    }) -NoTelemetry
    Assert-Equal -Actual @($safe.Json.PSObject.Properties).Count -Expected 0 -Message "safe rg -g call should not warn"

    $literal = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = 'Get-Content -LiteralPath "docs\*.md"' }
    }) -NoTelemetry
    Assert-True -Condition ($literal.Raw -match "LiteralPath") -Message "LiteralPath wildcard should warn"

    $heredoc = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "python - <<'PY'`nprint('x')`nPY" }
    }) -NoTelemetry
    Assert-True -Condition ($heredoc.Raw -match "heredoc") -Message "Bash heredoc on Windows should warn"

    $hereString = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "@'`ntext`n'@ | python -" }
    }) -NoTelemetry
    Assert-Equal -Actual @($hereString.Json.PSObject.Properties).Count -Expected 0 -Message "PowerShell here-string should remain safe"

    $tunit = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"
        tool_name = "Bash"
        cwd = (Join-Path $fixtureRoot "tunit")
        tool_input = [pscustomobject]@{ command = 'dotnet test --filter "Name=Fixture"' }
    }) -NoTelemetry
    Assert-True -Condition ($tunit.Raw -match "treenode-filter") -Message "TUnit VSTest filter should warn only with repo evidence"

    $noMatch = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PostToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "rg absent ." }
        tool_response = [pscustomobject]@{ exit_code = 1; stderr = "" }
    }) -NoTelemetry
    Assert-True -Condition ($noMatch.Raw -match "expected no-match") -Message "rg exit 1 without stderr should be normalized"

    $stalePatch = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PostToolUse"
        tool_name = "apply_patch"
        tool_input = [pscustomobject]@{}
        tool_response = [pscustomobject]@{ exit_code = 1; error = "Invalid Context 4" }
    }) -NoTelemetry
    Assert-True -Condition ($stalePatch.Raw -match "smaller updated hunk") -Message "stale patch should propose reread and smaller hunk"

    $unknown = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PostToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "git status" }
        tool_response = "opaque response"
    }) -NoTelemetry
    Assert-Equal -Actual @($unknown.Json.PSObject.Properties).Count -Expected 0 -Message "unknown response shape should stay unclassified"

    $stringFalseTimeout = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PostToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "git status" }
        tool_response = [pscustomobject]@{ exit_code = 0; timed_out = "false"; summary = "No permission denied failures" }
    }) -NoTelemetry
    Assert-Equal -Actual @($stringFalseTimeout.Json.PSObject.Properties).Count -Expected 0 -Message "string false must not become a timeout or permission warning"

    $genericFailure = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PostToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "example --bad-argument" }
        tool_response = [pscustomobject]@{ exit_code = 2; stderr = "Unknown argument" }
    }) -NoTelemetry
    Assert-Equal -Actual @($genericFailure.Json.PSObject.Properties).Count -Expected 0 -Message "generic nonzero should remain telemetry-only"

    $timeout = Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PostToolUse"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "dotnet test" }
        tool_response = [pscustomobject]@{ timed_out = $true }
    }) -NoTelemetry
    Assert-True -Condition ($timeout.Raw -match "Do not repeat") -Message "structured timeout should warn against an identical retry"

    foreach ($result in @($bad, $duplicate, $safe, $literal, $heredoc, $hereString, $tunit, $noMatch, $stalePatch, $unknown, $stringFalseTimeout, $genericFailure, $timeout)) {
        $propertyNames = @(Get-AllPropertyNames -Value $result.Json)
        Assert-True -Condition (@($propertyNames | Where-Object { $_ -in @("decision", "continue", "permissionDecision", "stop", "retry") }).Count -eq 0) -Message "warn-only hook must not emit blocking or retry fields"
    }

    $activeLog = Join-Path $telemetry "agent-operations.jsonl"
    Assert-True -Condition (Test-Path -LiteralPath $activeLog -PathType Leaf) -Message "hook should write sanitized telemetry"
    $logRecords = @(Get-Content -LiteralPath $activeLog | ForEach-Object { $_ | ConvertFrom-Json })
    $requiredFields = @("schemaVersion", "timestamp", "runtimeVersion", "eventName", "category", "severity", "action", "exitClass", "repoHash")
    $allowedFields = @($requiredFields) + "sessionHash"
    foreach ($record in $logRecords) {
        Assert-True -Condition (@($record.PSObject.Properties.Name | Where-Object { $_ -notin $allowedFields }).Count -eq 0) -Message "telemetry record should use the field allowlist"
        Assert-True -Condition (@($requiredFields | Where-Object { $null -eq $record.PSObject.Properties[$_] }).Count -eq 0) -Message "telemetry record should contain every required approved field"
        Assert-True -Condition ([string]$record.repoHash -match '^[0-9a-f]{64}$') -Message "repository identity should be a salted SHA-256 hash"
    }

    $unsaltedRoot = Join-Path $testRoot "unsalted-telemetry"
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $unsaltedRoot -InstallManifestPath (Join-Path $testRoot "missing-manifest.json"))
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $unsaltedRoot "agent-operations.jsonl"))) -Message "telemetry must stay disabled when a private salt is unavailable"

    $foreignManifestPath = Join-Path $testRoot "foreign-hook-manifest.json"
    Write-TestText -Path $foreignManifestPath -Content "{`"schemaVersion`":1,`"owner`":`"foreign`",`"runtimeVersion`":`"3.1.0`",`"telemetrySalt`":`"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`"}`n"
    $foreignManifestTelemetry = Join-Path $testRoot "foreign-manifest-telemetry"
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $foreignManifestTelemetry -InstallManifestPath $foreignManifestPath)
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $foreignManifestTelemetry "agent-operations.jsonl"))) -Message "telemetry must reject a foreign or checksum-unbound manifest even when its salt is syntactically valid"

    $rotationRoot = Join-Path $testRoot "rotation"
    [void](New-Item -ItemType Directory -Path $rotationRoot -Force)
    $largeLog = Join-Path $rotationRoot "agent-operations.jsonl"
    Write-TestText -Path (Join-Path $rotationRoot "agent-operations.1.jsonl") -Content "previous-one`n"
    Write-TestText -Path (Join-Path $rotationRoot "agent-operations.2.jsonl") -Content "previous-two`n"
    $foreignLog = Join-Path $rotationRoot "agent-operations-foreign.jsonl"
    Write-TestText -Path $foreignLog -Content "foreign`n"
    [System.IO.File]::SetLastWriteTimeUtc($foreignLog, [DateTime]::UtcNow.AddDays(-100))
    $stream = [System.IO.File]::Open($largeLog, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try { $stream.SetLength(10MB) } finally { $stream.Dispose() }
    [System.IO.File]::SetLastWriteTimeUtc($largeLog, [DateTime]::UtcNow)
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "rg TODO . -g '*.md'" }
    }) -TelemetryRoot $rotationRoot)
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $rotationRoot "agent-operations.1.jsonl")) -Message "10 MB log should rotate"
    Assert-True -Condition (@(Get-ChildItem -LiteralPath $rotationRoot -File | Where-Object { $_.Name -match '^agent-operations(?:\.[12])?\.jsonl$' }).Count -le 3) -Message "log retention should keep at most three owned JSONL files"
    Assert-Equal -Actual ([System.IO.File]::ReadAllText((Join-Path $rotationRoot "agent-operations.2.jsonl"))) -Expected "previous-one`n" -Message "rotation should promote the previous .1 log without deleting its data"
    Assert-True -Condition (Test-Path -LiteralPath $foreignLog -PathType Leaf) -Message "retention must preserve foreign files sharing the log prefix"

    $lockedRotationRoot = Join-Path $testRoot "locked-rotation"
    [void](New-Item -ItemType Directory -Path $lockedRotationRoot -Force)
    $lockedActive = Join-Path $lockedRotationRoot "agent-operations.jsonl"
    $lockedOne = Join-Path $lockedRotationRoot "agent-operations.1.jsonl"
    $lockedTwo = Join-Path $lockedRotationRoot "agent-operations.2.jsonl"
    $stream = [System.IO.File]::Open($lockedActive, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try { $stream.SetLength(10MB) } finally { $stream.Dispose() }
    Write-TestText -Path $lockedOne -Content "locked-one`n"
    Write-TestText -Path $lockedTwo -Content "locked-two`n"
    $lockedDestination = [System.IO.File]::Open($lockedTwo, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
    try {
        [void](Invoke-HookFixture -Payload ([pscustomobject]@{
            hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
        }) -TelemetryRoot $lockedRotationRoot)
    }
    finally {
        $lockedDestination.Dispose()
    }
    Assert-Equal -Actual ([System.IO.File]::ReadAllText($lockedTwo)) -Expected "locked-two`n" -Message "failed rotation must preserve the previous destination"
    Assert-Equal -Actual ([System.IO.File]::ReadAllText($lockedOne)) -Expected "locked-one`n" -Message "failed rotation must preserve the previous source"
    Assert-Equal -Actual (Get-Item -LiteralPath $lockedActive).Length -Expected 10MB -Message "failed rotation must not truncate the active log"

    $recoveryRotationRoot = Join-Path $testRoot "recovery-rotation"
    [void](New-Item -ItemType Directory -Path $recoveryRotationRoot -Force)
    $recoveryActive = Join-Path $recoveryRotationRoot "agent-operations.jsonl"
    $stream = [System.IO.File]::Open($recoveryActive, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try { $stream.SetLength(10MB) } finally { $stream.Dispose() }
    Write-TestText -Path (Join-Path $recoveryRotationRoot "agent-operations.1.jsonl") -Content "recovery-one`n"
    Write-TestText -Path (Join-Path $recoveryRotationRoot "agent-operations.2.jsonl") -Content "recovery-two`n"
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $recoveryRotationRoot -SimulateRotationFailureAfterArchiveReplace -SimulateRotationRollbackFailure)
    $recoveryCopies = @(Get-ChildItem -LiteralPath $recoveryRotationRoot -File -Filter ".agent-operations.rollback-*.tmp")
    $recoveryContents = @($recoveryCopies | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) })
    Assert-True -Condition (@($recoveryCopies | Where-Object Name -match 'rollback-active').Count -eq 1) -Message "incomplete rotation rollback must retain a recovery copy of the active log"
    Assert-True -Condition ($recoveryContents -contains "recovery-one`n") -Message "incomplete rotation rollback must retain a recovery copy of the previous .1 archive"
    Assert-True -Condition ($recoveryContents -contains "recovery-two`n") -Message "incomplete rotation rollback must retain a recovery copy of the previous .2 archive"
    $recoveryMarkers = @(Get-ChildItem -LiteralPath $recoveryRotationRoot -File -Filter "agent-operations-recovery-*.json")
    Assert-Equal -Actual $recoveryMarkers.Count -Expected 1 -Message "incomplete rotation rollback should publish one discoverable recovery marker"
    $staleRecoveryMarker = [System.IO.File]::ReadAllText($recoveryMarkers[0].FullName) | ConvertFrom-Json -Depth 10
    $staleRecoveryMarker.createdAtUtc = [DateTime]::UtcNow.AddDays(-8).ToString("o")
    Write-TestText -Path $recoveryMarkers[0].FullName -Content (($staleRecoveryMarker | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $recoveryRotationRoot)
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath $recoveryRotationRoot -File -Filter ".agent-operations.rollback-*.tmp").Count -Expected 0 -Message "verified recovery copies should be removed after the recovery retention window"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath $recoveryRotationRoot -File -Filter "agent-operations-recovery-*.json").Count -Expected 0 -Message "verified stale recovery marker should be removed with its copies"

    $duplicateRecoveryRoot = Join-Path $testRoot "duplicate-recovery"
    [void](New-Item -ItemType Directory -Path $duplicateRecoveryRoot -Force)
    $duplicateRecoveryName = ".agent-operations.rollback-active.$([guid]::NewGuid().ToString('N')).tmp"
    $duplicateRecoveryPath = Join-Path $duplicateRecoveryRoot $duplicateRecoveryName
    Write-TestText -Path $duplicateRecoveryPath -Content "preserve-duplicate`n"
    $duplicateRecoveryHash = (Get-FileHash -LiteralPath $duplicateRecoveryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $duplicateRecoveryMarker = [ordered]@{
        schemaVersion = 1
        owner = "agent-operations"
        createdAtUtc = [DateTime]::UtcNow.AddDays(-8).ToString("o")
        files = @(
            [ordered]@{ name = $duplicateRecoveryName; sha256 = $duplicateRecoveryHash },
            [ordered]@{ name = $duplicateRecoveryName; sha256 = $duplicateRecoveryHash }
        )
    }
    $duplicateRecoveryMarkerPath = Join-Path $duplicateRecoveryRoot ("agent-operations-recovery-{0}.json" -f [guid]::NewGuid().ToString("N"))
    Write-TestText -Path $duplicateRecoveryMarkerPath -Content (($duplicateRecoveryMarker | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $duplicateRecoveryRoot)
    Assert-True -Condition (Test-Path -LiteralPath $duplicateRecoveryPath -PathType Leaf) -Message "duplicate recovery roles must be preserved for manual inspection"
    Assert-True -Condition (Test-Path -LiteralPath $duplicateRecoveryMarkerPath -PathType Leaf) -Message "invalid duplicate recovery marker must not be consumed"

    $markerDriftRoot = Join-Path $testRoot "recovery-marker-drift"
    [void](New-Item -ItemType Directory -Path $markerDriftRoot -Force)
    $markerDriftName = ".agent-operations.rollback-active.$([guid]::NewGuid().ToString('N')).tmp"
    $markerDriftPath = Join-Path $markerDriftRoot $markerDriftName
    Write-TestText -Path $markerDriftPath -Content "marker-drift`n"
    $markerDriftDocument = [ordered]@{
        schemaVersion = 1; owner = "agent-operations"; createdAtUtc = [DateTime]::UtcNow.AddDays(-8).ToString("o")
        files = @([ordered]@{ name = $markerDriftName; sha256 = (Get-FileHash -LiteralPath $markerDriftPath -Algorithm SHA256).Hash.ToLowerInvariant() })
    }
    $markerDriftMarkerPath = Join-Path $markerDriftRoot ("agent-operations-recovery-{0}.json" -f [guid]::NewGuid().ToString("N"))
    Write-TestText -Path $markerDriftMarkerPath -Content (($markerDriftDocument | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $markerDriftRoot -SimulateRecoveryMarkerDriftBeforeQuarantine)
    Assert-True -Condition (Test-Path -LiteralPath $markerDriftPath -PathType Leaf) -Message "marker drift before quarantine must preserve recovery bytes"
    Assert-True -Condition (Test-Path -LiteralPath $markerDriftMarkerPath -PathType Leaf) -Message "marker drift before quarantine must preserve the marker for inspection"

    $verificationFailureRoot = Join-Path $testRoot "recovery-verification-failure"
    [void](New-Item -ItemType Directory -Path $verificationFailureRoot -Force)
    $verificationFailureName = ".agent-operations.rollback-active.$([guid]::NewGuid().ToString('N')).tmp"
    $verificationFailurePath = Join-Path $verificationFailureRoot $verificationFailureName
    Write-TestText -Path $verificationFailurePath -Content "verification-failure`n"
    $verificationFailureDocument = [ordered]@{
        schemaVersion = 1; owner = "agent-operations"; createdAtUtc = [DateTime]::UtcNow.AddDays(-8).ToString("o")
        files = @([ordered]@{ name = $verificationFailureName; sha256 = (Get-FileHash -LiteralPath $verificationFailurePath -Algorithm SHA256).Hash.ToLowerInvariant() })
    }
    $verificationFailureMarkerPath = Join-Path $verificationFailureRoot ("agent-operations-recovery-{0}.json" -f [guid]::NewGuid().ToString("N"))
    Write-TestText -Path $verificationFailureMarkerPath -Content (($verificationFailureDocument | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $verificationFailureRoot -SimulateRecoveryQuarantineVerificationFailure)
    Assert-True -Condition (Test-Path -LiteralPath $verificationFailurePath -PathType Leaf) -Message "pre-commit quarantine verification failure must restore the moved copy"
    Assert-True -Condition (Test-Path -LiteralPath $verificationFailureMarkerPath -PathType Leaf) -Message "pre-commit quarantine verification failure must preserve the canonical marker"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath $verificationFailureRoot -File -Filter ".agent-operations.recovery-delete.*.tmp").Count -Expected 0 -Message "pre-commit quarantine verification failure must not leave an untracked moved copy"

    $cleanupFailureRoot = Join-Path $testRoot "recovery-cleanup-failure"
    [void](New-Item -ItemType Directory -Path $cleanupFailureRoot -Force)
    $cleanupFailureEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($role in @("active", "one", "two")) {
        $name = ".agent-operations.rollback-$role.$([guid]::NewGuid().ToString('N')).tmp"
        $path = Join-Path $cleanupFailureRoot $name
        Write-TestText -Path $path -Content ("cleanup-$role`n")
        $cleanupFailureEntries.Add([ordered]@{ name = $name; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() })
    }
    $cleanupFailureDocument = [ordered]@{
        schemaVersion = 1; owner = "agent-operations"; createdAtUtc = [DateTime]::UtcNow.AddDays(-8).ToString("o"); files = @($cleanupFailureEntries)
    }
    $cleanupFailureMarkerPath = Join-Path $cleanupFailureRoot ("agent-operations-recovery-{0}.json" -f [guid]::NewGuid().ToString("N"))
    Write-TestText -Path $cleanupFailureMarkerPath -Content (($cleanupFailureDocument | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [pscustomobject]@{ command = "git status" }
    }) -TelemetryRoot $cleanupFailureRoot -SimulateRecoveryCleanupFailureAfterFirstDelete)
    Assert-True -Condition (-not (Test-Path -LiteralPath $cleanupFailureMarkerPath)) -Message "cleanup commit failure must not restore a marker that references an already deleted copy"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath $cleanupFailureRoot -File -Filter ".agent-operations.recovery-marker-delete.*.tmp").Count -Expected 1 -Message "cleanup commit failure should retain one quarantined marker"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath $cleanupFailureRoot -File -Filter ".agent-operations.recovery-delete.*.tmp").Count -Expected 2 -Message "cleanup commit failure should retain only the not-yet-deleted quarantined copies"

    $concurrentRoot = Join-Path $testRoot "concurrent-telemetry"
    $concurrentManifest = Join-Path $testRoot "hook-install-manifest.json"
    $jobs = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt 12; $index++) {
        $concurrentInput = Join-Path $testRoot ("concurrent-hook-{0:D2}.json" -f $index)
        $concurrentPayload = [ordered]@{
            hook_event_name = "PostToolUse"
            session_id = "session-$index"
            cwd = $repositoryRoot
            tool_name = "Bash"
            tool_input = [ordered]@{ command = "git status" }
            tool_response = [ordered]@{ exit_code = 0 }
        }
        Write-TestText -Path $concurrentInput -Content (($concurrentPayload | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
        $jobs.Add((Start-Job -ScriptBlock {
            param($HookScript, $InputPath, $TelemetryRoot, $ManifestPath)
            & pwsh -NoProfile -File $HookScript -InputPath $InputPath -TelemetryRoot $TelemetryRoot -InstallManifestPath $ManifestPath
        } -ArgumentList $hookScript, $concurrentInput, $concurrentRoot, $concurrentManifest))
    }
    try {
        $null = @($jobs | Wait-Job -Timeout 30)
        $jobFailures = @($jobs | Where-Object { $_.State -ne "Completed" })
        Assert-Equal -Actual $jobFailures.Count -Expected 0 -Message "concurrent hook processes should complete"
        $null = @($jobs | Receive-Job -ErrorAction SilentlyContinue)
    }
    finally {
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    $concurrentLines = @(Get-Content -LiteralPath (Join-Path $concurrentRoot "agent-operations.jsonl"))
    Assert-Equal -Actual $concurrentLines.Count -Expected 12 -Message "concurrent telemetry appends should not lose records"
    foreach ($line in $concurrentLines) {
        $parsedConcurrentRecord = $null
        try { $parsedConcurrentRecord = $line | ConvertFrom-Json } catch { }
        Assert-True -Condition ($null -ne $parsedConcurrentRecord) -Message "each concurrent telemetry line should remain valid JSON"
    }

    $aliasTelemetryParent = Join-Path $testRoot "alias-telemetry-target"
    $aliasTelemetryLink = Join-Path $testRoot "alias-telemetry-link"
    $aliasTelemetryRoot = Join-Path $aliasTelemetryParent "logs"
    [void](New-Item -ItemType Directory -Path $aliasTelemetryRoot -Force)
    [void](New-Item -ItemType Junction -Path $aliasTelemetryLink -Target $aliasTelemetryParent)
    $aliasTelemetryJobs = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt 16; $index++) {
        $aliasInput = Join-Path $testRoot ("alias-telemetry-{0:D2}.json" -f $index)
        $aliasPayload = [ordered]@{
            hook_event_name = "PostToolUse"; session_id = "alias-$index"; cwd = $repositoryRoot; tool_name = "Bash"
            tool_input = [ordered]@{ command = "git status" }; tool_response = [ordered]@{ exit_code = 0 }
        }
        Write-TestText -Path $aliasInput -Content (($aliasPayload | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
        $lexicalTelemetryRoot = if ($index % 2 -eq 0) { $aliasTelemetryRoot } else { Join-Path $aliasTelemetryLink "logs" }
        $aliasTelemetryJobs.Add((Start-Job -ScriptBlock {
            param($HookScript, $InputPath, $TelemetryRoot, $ManifestPath)
            & pwsh -NoProfile -File $HookScript -InputPath $InputPath -TelemetryRoot $TelemetryRoot -InstallManifestPath $ManifestPath
        } -ArgumentList $hookScript, $aliasInput, $lexicalTelemetryRoot, $concurrentManifest))
    }
    try {
        $null = @($aliasTelemetryJobs | Wait-Job -Timeout 30)
        $null = @($aliasTelemetryJobs | Receive-Job -ErrorAction SilentlyContinue)
    }
    finally {
        $aliasTelemetryJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    $aliasTelemetryLines = @(Get-Content -LiteralPath (Join-Path $aliasTelemetryRoot "agent-operations.jsonl"))
    Assert-Equal -Actual $aliasTelemetryLines.Count -Expected 16 -Message "telemetry locking should serialize mixed lexical aliases of one physical logs directory"
}

function Initialize-InstallerFixture {
    param(
        [string]$CodexHome,
        [switch]$WithForeignConfig
    )

    [void](New-Item -ItemType Directory -Path $CodexHome -Force)
    if ($WithForeignConfig) {
        Write-TestText -Path (Join-Path $CodexHome "config.toml") -Content ([System.IO.File]::ReadAllText((Join-Path $fixtureRoot "installer/config-foreign.toml")))
        Write-TestText -Path (Join-Path $CodexHome "hooks.json") -Content ([System.IO.File]::ReadAllText((Join-Path $fixtureRoot "installer/hooks-foreign.json")))
    }
}

function Test-Installer {
    Write-Host "INFO: installer contracts" -ForegroundColor Cyan
    $codexHome = Join-Path $testRoot "installer-main"
    Initialize-InstallerFixture -CodexHome $codexHome -WithForeignConfig
    $beforePreview = Get-FileTreeFingerprint -Root $codexHome
    $preview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $preview.ExitCode -Expected 0 -Message "install preview should pass"
    Assert-Equal -Actual $preview.Json.status -Expected "proposed" -Message "install preview status"
    Assert-Equal -Actual $preview.Json.proposalHash.Length -Expected 64 -Message "proposal hash should be SHA-256"
    Assert-True -Condition ($null -eq $preview.Json.changes.reviewer.beforeHash) -Message "proposal must distinguish a missing reviewer from an empty file"
    Assert-Equal -Actual (Get-TextSha256 -Text $preview.Json.changes.config.beforeContent) -Expected $preview.Json.changes.config.beforeHash -Message "preview should expose exact config before content bound to its hash"
    Assert-Equal -Actual (Get-TextSha256 -Text $preview.Json.changes.config.afterContent) -Expected $preview.Json.changes.config.afterHash -Message "preview should expose exact proposed config content bound to its hash"
    Assert-Equal -Actual (Get-TextSha256 -Text $preview.Json.changes.hooks.afterContent) -Expected $preview.Json.changes.hooks.afterHash -Message "preview should expose exact proposed hooks document bound to its hash"
    Assert-Equal -Actual $preview.Json.changes.reviewer.afterContent -Expected $preview.Json.changes.reviewer.content -Message "preview should expose the exact reviewer document"
    $expectedExactContentPaths = @(
        (Join-Path $codexHome "config.toml"),
        (Join-Path $codexHome "hooks.json"),
        (Join-Path $codexHome "agents/independent-reviewer.toml")
    )
    Assert-Equal -Actual (@($preview.Json.previewContract.exactContentPaths | Sort-Object) -join "|") -Expected (@($expectedExactContentPaths | Sort-Object) -join "|") -Message "preview should state the exact AC21 config/hooks/reviewer path set"
    Assert-True -Condition (@($preview.Json.previewContract.boundedGeneratedFields).Count -ge 4) -Message "preview should disclose apply-time generated manifest and backup fields"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $codexHome) -Expected $beforePreview -Message "WhatIf must not mutate fixture CodexHome"

    $install = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-Install", "-ApprovedProposalHash", $preview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $install.ExitCode -Expected 0 -Message "approved fixture install should pass"
    Assert-Equal -Actual $install.Json.status -Expected "installed-awaiting-trust" -Message "install should not claim active hook trust"
    $config = [System.IO.File]::ReadAllText((Join-Path $codexHome "config.toml"))
    Assert-True -Condition ($config -match '(?m)^max_threads\s*=\s*4\s*# preserve this comment on update$') -Message "installer should set max_threads and preserve inline comment"
    Assert-True -Condition ($config -match '(?m)^max_depth\s*=\s*1\s*$') -Message "installer should set max_depth"
    Assert-True -Condition ($config -match 'custom_agent_setting\s*=\s*"keep"') -Message "foreign TOML should survive"
    $hooks = (Get-Content -LiteralPath (Join-Path $codexHome "hooks.json") -Raw) | ConvertFrom-Json -Depth 30
    Assert-Equal -Actual @($hooks.hooks.Notification).Count -Expected 1 -Message "foreign hook event should survive"
    Assert-Equal -Actual @($hooks.hooks.PreToolUse).Count -Expected 1 -Message "exactly one PreToolUse group should be installed"
    Assert-Equal -Actual @($hooks.hooks.PostToolUse).Count -Expected 1 -Message "exactly one PostToolUse group should be installed"
    Assert-True -Condition ([string]$hooks.hooks.PreToolUse[0].hooks[0].commandWindows -match 'versions\\3\.1\.0\\agent-operations-hook\.ps1') -Message "hook should reference immutable versioned runtime"
    Assert-True -Condition ([string]$hooks.hooks.PreToolUse[0].hooks[0].commandWindows -match 'InstallManifestPath') -Message "hook should receive the manifest path for salted telemetry"
    $manifestPath = Join-Path $codexHome "agent-operations/install-manifest.json"
    $manifest = (Get-Content -LiteralPath $manifestPath -Raw) | ConvertFrom-Json -Depth 20
    Assert-Equal -Actual $manifest.state -Expected "awaiting-trust" -Message "manifest trust state"
    Assert-Equal -Actual (Get-FileHash -LiteralPath (Join-Path $codexHome "agent-operations/versions/3.1.0/agent-operations-hook.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() -Expected $manifest.runtimeChecksums.hook -Message "installed runtime bytes should match the approved immutable manifest hash"
    foreach ($requiredManifestField in @("installedAt", "approvedProposalHash", "installerOwnedHookFingerprints", "installerOwnedReviewerFingerprint", "previousAgentSettings", "runtimeChecksums", "telemetrySalt", "activationChallenge")) {
        Assert-True -Condition ($null -ne $manifest.PSObject.Properties[$requiredManifestField]) -Message "manifest should implement approved field '$requiredManifestField'"
    }
    Assert-True -Condition ([string]$manifest.telemetrySalt -match '^[0-9a-f]{64}$') -Message "installer should generate a local random telemetry salt"
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $codexHome "agents/independent-reviewer.toml")) -Message "personal reviewer should be installed"
    $backupCount = @(Get-ChildItem -LiteralPath (Join-Path $codexHome "backups/agent-operations") -Directory).Count

    $activationEvidencePath = Join-Path $codexHome "activation-evidence.json"
    $reviewerEvidencePath = Join-Path $codexHome "reviewer-write-denial.json"
    $reviewerEvidence = [ordered]@{
        schemaVersion = 1
        reviewerFingerprint = $manifest.installerOwnedReviewerFingerprint
        effectiveSandbox = "read-only"
        readSucceeded = $true
        writeDenied = $true
    }
    Write-TestText -Path $reviewerEvidencePath -Content (($reviewerEvidence | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    $installedRuntimePath = Join-Path $codexHome "agent-operations/versions/3.1.0/agent-operations-hook.ps1"
    $activationTelemetryRoot = Join-Path $codexHome "logs"
    $trustedProbePayload = [ordered]@{
        hook_event_name = "PreToolUse"
        session_id = "activation-session"
        cwd = $codexHome
        tool_name = "Bash"
        tool_input = [ordered]@{ command = "Write-Output 'CODEX_AGENT_OPERATIONS_PROBE_$($manifest.activationChallenge)'" }
    } | ConvertTo-Json -Depth 10 -Compress
    $trustedProbeOutput = @($trustedProbePayload | & pwsh -NoProfile -File $installedRuntimePath -TelemetryRoot $activationTelemetryRoot -InstallManifestPath $manifestPath) -join "`n"
    Assert-Equal -Actual @((($trustedProbeOutput | ConvertFrom-Json).PSObject.Properties)).Count -Expected 0 -Message "trusted activation marker should stay warn-free"
    $activationTelemetryRecords = @(Get-Content -LiteralPath (Join-Path $activationTelemetryRoot "agent-operations.jsonl") | ForEach-Object { $_ | ConvertFrom-Json })
    Assert-Equal -Actual @($activationTelemetryRecords | Where-Object { $_.category -eq "activation-probe" }).Count -Expected 1 -Message "installed hook path should record a sanitized activation challenge event"
    $expectedActivationHash = Get-TextSha256 -Text ("$($manifest.telemetrySalt)|activation|$($manifest.activationChallenge)")
    Assert-Equal -Actual ($activationTelemetryRecords | Where-Object { $_.category -eq "activation-probe" } | Select-Object -First 1).sessionHash -Expected $expectedActivationHash -Message "activation telemetry should bind the event to this install without exposing the challenge"
    $probeWithoutManualTrust = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @(
        "-CodexHome", $codexHome,
        "-ReviewerEvidencePath", $reviewerEvidencePath,
        "-OutputFormat", "Json"
    )
    Assert-Equal -Actual $probeWithoutManualTrust.ExitCode -Expected 2 -Message "observed runtime telemetry must not replace the user's manual hook trust confirmation"
    Assert-Equal -Actual $probeWithoutManualTrust.Json.manualHookTrustConfirmed -Expected $false -Message "activation evidence should represent missing manual trust explicitly"
    $probeWithoutHostTask = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @(
        "-CodexHome", $codexHome,
        "-ReviewerEvidencePath", $reviewerEvidencePath,
        "-ManualHookTrustConfirmed",
        "-OutputFormat", "Json"
    )
    Assert-Equal -Actual $probeWithoutHostTask.ExitCode -Expected 2 -Message "direct runtime observation must not replace the controlled host task assertion"
    Assert-Equal -Actual $probeWithoutHostTask.Json.controlledHostTaskConfirmed -Expected $false -Message "activation evidence should expose missing host task confirmation"
    $activationProbe = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @(
        "-CodexHome", $codexHome,
        "-ReviewerEvidencePath", $reviewerEvidencePath,
        "-ManualHookTrustConfirmed",
        "-ControlledHostTaskConfirmed",
        "-OutputPath", $activationEvidencePath,
        "-OutputFormat", "Json"
    )
    if ($activationProbe.ExitCode -ne 0) { Write-Host ("DIAG: activation probe: {0}" -f ($activationProbe.Json | ConvertTo-Json -Depth 20 -Compress)) -ForegroundColor DarkYellow }
    Assert-Equal -Actual $activationProbe.ExitCode -Expected 0 -Message "activation probe should verify the installed runtime, hook definitions, limits, and reviewer evidence"
    Assert-True -Condition ($activationProbe.Json.runtimeChallengeObserved) -Message "activation probe should report install-bound runtime observation without calling it host dispatch attestation"
    Assert-Equal -Actual $activationProbe.Json.activationBindingHash -Expected $expectedActivationHash -Message "activation evidence should retain the current install binding without exposing raw challenge material"
    Assert-True -Condition ($activationProbe.Json.runtimeStillInstalled) -Message "activation evidence should confirm the live runtime still matches captured bytes"
    Assert-True -Condition ($activationProbe.Json.reviewerWriteDenied) -Message "activation probe should bind write denial to the installed reviewer fingerprint"

    $trustedRuntimeBytes = [System.IO.File]::ReadAllBytes($installedRuntimePath)
    $replacementExecutionMarker = Join-Path $testRoot "replacement-runtime-executed.txt"
    $escapedReplacementMarker = $replacementExecutionMarker.Replace("'", "''")
    $replacementRuntimePath = Join-Path $testRoot "replacement-runtime.ps1"
    Write-TestText -Path $replacementRuntimePath -Content ("[System.IO.File]::WriteAllText('{0}', 'executed')`nWrite-Output '{{}}'`n" -f $escapedReplacementMarker)
    $replacementProbe = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @(
        "-CodexHome", $codexHome,
        "-ReviewerEvidencePath", $reviewerEvidencePath,
        "-ManualHookTrustConfirmed",
        "-ControlledHostTaskConfirmed",
        "-SimulateRuntimeReplacementAfterCapturePath", $replacementRuntimePath,
        "-OutputFormat", "Json"
    )
    Assert-Equal -Actual $replacementProbe.ExitCode -Expected 2 -Message "runtime drift after capture must invalidate activation evidence"
    Assert-Equal -Actual $replacementProbe.Json.runtimeStillInstalled -Expected $false -Message "replacement race should be represented explicitly"
    Assert-True -Condition (-not (Test-Path -LiteralPath $replacementExecutionMarker)) -Message "probe must execute captured trusted bytes instead of replacement runtime path"
    [System.IO.File]::WriteAllBytes($installedRuntimePath, $trustedRuntimeBytes)

    $copiedTelemetryHome = Join-Path $testRoot "installer-copied-telemetry"
    Initialize-InstallerFixture -CodexHome $copiedTelemetryHome -WithForeignConfig
    $copiedTelemetryPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $copiedTelemetryHome, "-WhatIf", "-OutputFormat", "Json")
    $copiedTelemetryInstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $copiedTelemetryHome, "-Install", "-ApprovedProposalHash", $copiedTelemetryPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $copiedTelemetryInstall.ExitCode -Expected 0 -Message "cross-install telemetry fixture should install"
    $null = @($trustedProbePayload | & pwsh -NoProfile -File $installedRuntimePath -TelemetryRoot $activationTelemetryRoot -InstallManifestPath $manifestPath)
    $copiedLogsRoot = Join-Path $copiedTelemetryHome "logs"
    Write-TestText -Path (Join-Path $copiedLogsRoot "agent-operations.jsonl") -Content ([System.IO.File]::ReadAllText((Join-Path $activationTelemetryRoot "agent-operations.jsonl")))
    $copiedManifest = ([System.IO.File]::ReadAllText((Join-Path $copiedTelemetryHome "agent-operations/install-manifest.json"))) | ConvertFrom-Json -Depth 20
    $copiedReviewerEvidencePath = Join-Path $copiedTelemetryHome "reviewer-evidence.json"
    $copiedReviewerEvidence = [ordered]@{
        schemaVersion = 1
        reviewerFingerprint = $copiedManifest.installerOwnedReviewerFingerprint
        effectiveSandbox = "read-only"
        readSucceeded = $true
        writeDenied = $true
    }
    Write-TestText -Path $copiedReviewerEvidencePath -Content (($copiedReviewerEvidence | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    $copiedTelemetryProbe = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @(
        "-CodexHome", $copiedTelemetryHome,
        "-ReviewerEvidencePath", $copiedReviewerEvidencePath,
        "-ManualHookTrustConfirmed",
        "-ControlledHostTaskConfirmed",
        "-OutputFormat", "Json"
    )
    Assert-Equal -Actual $copiedTelemetryProbe.ExitCode -Expected 2 -Message "fresh telemetry copied from another install must not establish dispatch evidence"
    Assert-True -Condition ([string]$copiedTelemetryProbe.Json.activationTelemetryReason -match "install-binding-mismatch") -Message "cross-install telemetry rejection should expose the instance-binding reason"

    $traversalProbeHome = Join-Path $testRoot "probe-runtime-traversal"
    $traversalRuntimeDirectory = Join-Path $traversalProbeHome "outside-runtime"
    $traversalExecutionMarker = Join-Path $traversalProbeHome "traversal-executed.txt"
    $escapedTraversalMarker = $traversalExecutionMarker.Replace("'", "''")
    $traversalRuntimePath = Join-Path $traversalRuntimeDirectory "agent-operations-hook.ps1"
    Write-TestText -Path $traversalRuntimePath -Content ("[System.IO.File]::WriteAllText('{0}', 'executed')`nWrite-Output '{{}}'`n" -f $escapedTraversalMarker)
    $traversalRuntimeHash = (Get-FileHash -LiteralPath $traversalRuntimePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $traversalMarkerPath = Join-Path $traversalRuntimeDirectory ".agent-operations-owned.json"
    Write-TestText -Path $traversalMarkerPath -Content "{}`n"
    $traversalManifest = [ordered]@{
        schemaVersion = 1; owner = "agent-operations"; state = "awaiting-trust"; runtimeVersion = "..\..\outside-runtime"
        runtimeChecksums = [ordered]@{ hook = $traversalRuntimeHash; marker = (Get-FileHash -LiteralPath $traversalMarkerPath -Algorithm SHA256).Hash.ToLowerInvariant() }
        telemetrySalt = "a" * 64; activationChallenge = "b" * 64; installedAt = [DateTime]::UtcNow.AddMinutes(-1).ToString("o")
    }
    Write-TestText -Path (Join-Path $traversalProbeHome "agent-operations/install-manifest.json") -Content (($traversalManifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    $traversalProbe = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @("-CodexHome", $traversalProbeHome, "-ManualHookTrustConfirmed", "-ControlledHostTaskConfirmed", "-OutputFormat", "Json")
    Assert-Equal -Actual $traversalProbe.ExitCode -Expected 2 -Message "activation probe must reject traversal runtimeVersion"
    Assert-True -Condition (-not (Test-Path -LiteralPath $traversalExecutionMarker)) -Message "activation probe must not execute traversal-selected runtime"

    $reparseProbeHome = Join-Path $testRoot "probe-runtime-reparse"
    $reparseProbeExternal = Join-Path $testRoot "probe-runtime-reparse-external"
    $reparseProbeRuntimeDirectory = Join-Path $reparseProbeExternal "3.1.0"
    $reparseExecutionMarker = Join-Path $reparseProbeHome "reparse-executed.txt"
    $escapedReparseMarker = $reparseExecutionMarker.Replace("'", "''")
    $reparseProbeRuntimePath = Join-Path $reparseProbeRuntimeDirectory "agent-operations-hook.ps1"
    Write-TestText -Path $reparseProbeRuntimePath -Content ("[System.IO.File]::WriteAllText('{0}', 'executed')`nWrite-Output '{{}}'`n" -f $escapedReparseMarker)
    $reparseProbeRuntimeHash = (Get-FileHash -LiteralPath $reparseProbeRuntimePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $reparseProbeMarkerPath = Join-Path $reparseProbeRuntimeDirectory ".agent-operations-owned.json"
    Write-TestText -Path $reparseProbeMarkerPath -Content "{}`n"
    $reparseProbeManifest = [ordered]@{
        schemaVersion = 1; owner = "agent-operations"; state = "awaiting-trust"; runtimeVersion = "3.1.0"
        runtimeChecksums = [ordered]@{ hook = $reparseProbeRuntimeHash; marker = (Get-FileHash -LiteralPath $reparseProbeMarkerPath -Algorithm SHA256).Hash.ToLowerInvariant() }
        telemetrySalt = "c" * 64; activationChallenge = "d" * 64; installedAt = [DateTime]::UtcNow.AddMinutes(-1).ToString("o")
    }
    Write-TestText -Path (Join-Path $reparseProbeHome "agent-operations/install-manifest.json") -Content (($reparseProbeManifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    [void](New-Item -ItemType Junction -Path (Join-Path $reparseProbeHome "agent-operations/versions") -Target $reparseProbeExternal)
    $reparseProbe = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @("-CodexHome", $reparseProbeHome, "-ManualHookTrustConfirmed", "-ControlledHostTaskConfirmed", "-OutputFormat", "Json")
    Assert-Equal -Actual $reparseProbe.ExitCode -Expected 2 -Message "activation probe must reject reparse ancestors below CodexHome"
    Assert-True -Condition (-not (Test-Path -LiteralPath $reparseExecutionMarker)) -Message "activation probe must not execute reparse-selected runtime"
    [System.IO.Directory]::Delete((Join-Path $reparseProbeHome "agent-operations/versions"), $false)

    $reviewerEvidence.writeDenied = $false
    $badReviewerEvidencePath = Join-Path $codexHome "reviewer-write-allowed.json"
    Write-TestText -Path $badReviewerEvidencePath -Content (($reviewerEvidence | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    $rejectedProbe = Invoke-JsonProcess -ScriptPath $activationProbeScript -Arguments @(
        "-CodexHome", $codexHome,
        "-ReviewerEvidencePath", $badReviewerEvidencePath,
        "-OutputFormat", "Json"
    )
    Assert-Equal -Actual $rejectedProbe.ExitCode -Expected 2 -Message "activation probe must reject writable reviewer evidence"
    Assert-Equal -Actual $rejectedProbe.Json.reviewerWriteDenied -Expected $false -Message "writable reviewer must not satisfy activation evidence"

    $installedConfigText = [System.IO.File]::ReadAllText((Join-Path $codexHome "config.toml"))
    Add-Content -LiteralPath (Join-Path $codexHome "config.toml") -Value "# activation drift" -Encoding utf8
    $staleActivation = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $activationEvidencePath, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $staleActivation.ExitCode -Expected 2 -Message "mark-active must reject evidence after live config drift"
    Write-TestText -Path (Join-Path $codexHome "config.toml") -Content $installedConfigText

    $awaitingManifestText = [System.IO.File]::ReadAllText($manifestPath)
    $invalidStateManifest = $awaitingManifestText | ConvertFrom-Json -Depth 20
    $invalidStateManifest.state = "inactive"
    Write-TestText -Path $manifestPath -Content (($invalidStateManifest | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $invalidStateActivation = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $activationEvidencePath, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $invalidStateActivation.ExitCode -Expected 2 -Message "mark-active must transition only from awaiting-trust"
    Write-TestText -Path $manifestPath -Content $awaitingManifestText

    $expiredEvidencePath = Join-Path $codexHome "expired-activation-evidence.json"
    $expiredEvidence = ([System.IO.File]::ReadAllText($activationEvidencePath)) | ConvertFrom-Json -Depth 20
    $expiredEvidence.expiresAtUtc = [DateTime]::UtcNow.AddMinutes(-1).ToString("o")
    Write-TestText -Path $expiredEvidencePath -Content (($expiredEvidence | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $expiredActivation = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $expiredEvidencePath, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $expiredActivation.ExitCode -Expected 2 -Message "mark-active must reject expired runtime observation evidence"

    $futureEvidencePath = Join-Path $codexHome "future-activation-evidence.json"
    $futureEvidence = ([System.IO.File]::ReadAllText($activationEvidencePath)) | ConvertFrom-Json -Depth 20
    $futureEvidence.runtimeObservationAtUtc = [DateTime]::UtcNow.AddMinutes(10).ToString("o")
    $futureEvidence.evidenceCreatedAtUtc = [DateTime]::UtcNow.AddMinutes(11).ToString("o")
    $futureEvidence.expiresAtUtc = [DateTime]::UtcNow.AddMinutes(20).ToString("o")
    Write-TestText -Path $futureEvidencePath -Content (($futureEvidence | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $futureActivation = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $futureEvidencePath, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $futureActivation.ExitCode -Expected 2 -Message "mark-active must reject future-dated evidence windows"

    $rotatedChallengeManifest = $awaitingManifestText | ConvertFrom-Json -Depth 20
    $rotatedChallengeManifest.activationChallenge = "e" * 64
    Write-TestText -Path $manifestPath -Content (($rotatedChallengeManifest | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $rotatedChallengeActivation = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $activationEvidencePath, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $rotatedChallengeActivation.ExitCode -Expected 2 -Message "mark-active must reject evidence captured before activation challenge rotation"
    Write-TestText -Path $manifestPath -Content $awaitingManifestText

    $commitExpiryEvidencePath = Join-Path $codexHome "commit-expiry-activation-evidence.json"
    $commitExpiryEvidence = ([System.IO.File]::ReadAllText($activationEvidencePath)) | ConvertFrom-Json -Depth 20
    $commitExpiryEvidence.expiresAtUtc = [DateTime]::UtcNow.AddSeconds(5).ToString("o")
    Write-TestText -Path $commitExpiryEvidencePath -Content (($commitExpiryEvidence | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $commitExpiryPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $commitExpiryEvidencePath, "-WhatIf", "-OutputFormat", "Json")
    $commitExpiryApply = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $commitExpiryEvidencePath, "-ApprovedProposalHash", $commitExpiryPreview.Json.proposalHash, "-SimulateActivationDelayMilliseconds", "6000", "-OutputFormat", "Json")
    Assert-Equal -Actual $commitExpiryApply.ExitCode -Expected 3 -Message "mark-active must recheck evidence expiry immediately before commit"
    Assert-Equal -Actual (([System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -Depth 20).state) -Expected "awaiting-trust" -Message "commit-time expiry must leave manifest awaiting trust"

    $activePreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $activationEvidencePath, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $activePreview.ExitCode -Expected 0 -Message "mark-active preview should validate complete pilot evidence"
    Assert-Equal -Actual $activePreview.Json.changes.manifest.after.state -Expected "active" -Message "mark-active preview should disclose state postimage"
    Assert-Equal -Actual $activePreview.Json.changes.manifest.after.lastKnownGoodVersion -Expected $manifest.runtimeVersion -Message "mark-active preview should disclose last-known-good postimage"
    Assert-Equal -Actual $activePreview.Json.changes.manifest.after.activationEvidenceHash -Expected (Get-TextSha256 -Text ([System.IO.File]::ReadAllText($activationEvidencePath))) -Message "mark-active preview should disclose the bound evidence hash"
    Assert-Equal -Actual $activePreview.Json.changes.manifest.after.activatedAt -Expected "apply-time-utc-o" -Message "mark-active preview should disclose the bounded activation timestamp"
    Assert-Equal -Actual $activePreview.Json.changes.manifest.after.runtimeVersion -Expected $manifest.runtimeVersion -Message "mark-active preview should expose the complete preserved manifest, not only changed fields"
    $activate = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-MarkActive", "-ActivationEvidencePath", $activationEvidencePath, "-ApprovedProposalHash", $activePreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $activate.Json.status -Expected "active" -Message "approved evidence should transition the install to active"
    $manifest = (Get-Content -LiteralPath $manifestPath -Raw) | ConvertFrom-Json -Depth 20
    Assert-Equal -Actual $manifest.state -Expected "active" -Message "active state should persist in the install manifest"
    Assert-Equal -Actual $manifest.lastKnownGoodVersion -Expected $manifest.runtimeVersion -Message "first verified runtime should become last-known-good"

    $repeatPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $repeatPreview.Json.status -Expected "no-op" -Message "repeat preview should detect semantic no-op"
    $repeatInstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-Install", "-OutputFormat", "Json")
    Assert-Equal -Actual $repeatInstall.Json.status -Expected "no-op" -Message "repeat install should not require mutation approval"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath (Join-Path $codexHome "backups/agent-operations") -Directory).Count -Expected $backupCount -Message "no-op install should not create backup"

    $uninstallPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-Uninstall", "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $uninstallPreview.ExitCode -Expected 0 -Message "uninstall preview should pass"
    $uninstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $codexHome, "-Uninstall", "-ApprovedProposalHash", $uninstallPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $uninstall.Json.status -Expected "uninstalled" -Message "uninstall should pass"
    $restoredConfig = [System.IO.File]::ReadAllText((Join-Path $codexHome "config.toml"))
    Assert-True -Condition ($restoredConfig -match '(?m)^max_threads\s*=\s*6\s*# preserve this comment on update$') -Message "uninstall should restore previous max_threads"
    Assert-True -Condition ($restoredConfig -notmatch '(?m)^max_depth\s*=') -Message "uninstall should remove previously absent max_depth"
    $restoredHooks = (Get-Content -LiteralPath (Join-Path $codexHome "hooks.json") -Raw) | ConvertFrom-Json -Depth 30
    Assert-Equal -Actual @($restoredHooks.hooks.Notification).Count -Expected 1 -Message "uninstall should preserve foreign hook"
    Assert-True -Condition ($null -eq $restoredHooks.hooks.PSObject.Properties["PreToolUse"]) -Message "uninstall should remove owned PreToolUse group"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $codexHome "agents/independent-reviewer.toml"))) -Message "uninstall should remove fingerprint-matched reviewer"
    Assert-True -Condition (-not (Test-Path -LiteralPath $manifestPath)) -Message "uninstall should remove install manifest"

    $emptyHome = Join-Path $testRoot "installer-empty"
    Initialize-InstallerFixture -CodexHome $emptyHome
    $emptyPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $emptyHome, "-WhatIf", "-OutputFormat", "Json")
    $emptyInstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $emptyHome, "-Install", "-ApprovedProposalHash", $emptyPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $emptyInstall.ExitCode -Expected 0 -Message "empty fixture install should pass"
    $emptyHooksPath = Join-Path $emptyHome "hooks.json"
    $ownedHooksText = [System.IO.File]::ReadAllText($emptyHooksPath)
    $driftedHooks = $ownedHooksText | ConvertFrom-Json -Depth 30
    $driftedHooks.hooks.PreToolUse[0].hooks[0].statusMessage = "drifted managed group"
    Write-TestText -Path $emptyHooksPath -Content (($driftedHooks | ConvertTo-Json -Depth 30) + [Environment]::NewLine)
    $driftedHookUninstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $emptyHome, "-Uninstall", "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $driftedHookUninstall.ExitCode -Expected 2 -Message "drifted managed hook must block uninstall before runtime deletion"
    Write-TestText -Path $emptyHooksPath -Content $ownedHooksText

    $crossEventHooks = $ownedHooksText | ConvertFrom-Json -Depth 30
    $crossEventHooks.hooks | Add-Member -NotePropertyName "Notification" -NotePropertyValue @($crossEventHooks.hooks.PreToolUse[0])
    Write-TestText -Path $emptyHooksPath -Content (($crossEventHooks | ConvertTo-Json -Depth 30) + [Environment]::NewLine)
    $crossEventUninstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $emptyHome, "-Uninstall", "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $crossEventUninstall.ExitCode -Expected 2 -Message "managed runtime reference from an unsupported hook event must block uninstall"
    Write-TestText -Path $emptyHooksPath -Content $ownedHooksText

    $foreignRuntimeFile = Join-Path $emptyHome "agent-operations/versions/3.1.0/foreign.txt"
    Write-TestText -Path $foreignRuntimeFile -Content "foreign"
    $foreignRuntimeUninstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $emptyHome, "-Uninstall", "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $foreignRuntimeUninstall.ExitCode -Expected 2 -Message "unexpected runtime content must block recursive uninstall"
    Assert-True -Condition (Test-Path -LiteralPath $foreignRuntimeFile) -Message "blocked uninstall must preserve foreign runtime content"
    Remove-Item -LiteralPath $foreignRuntimeFile -Force

    $emptyUninstallPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $emptyHome, "-Uninstall", "-WhatIf", "-OutputFormat", "Json")
    $emptyUninstall = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $emptyHome, "-Uninstall", "-ApprovedProposalHash", $emptyUninstallPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $emptyUninstall.ExitCode -Expected 0 -Message "empty fixture uninstall should pass"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $emptyHome "config.toml"))) -Message "uninstall should remove installer-created empty config"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $emptyHome "hooks.json"))) -Message "uninstall should remove installer-created empty hooks document"

    $driftHome = Join-Path $testRoot "installer-drift"
    Initialize-InstallerFixture -CodexHome $driftHome -WithForeignConfig
    $driftPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $driftHome, "-WhatIf", "-OutputFormat", "Json")
    Add-Content -LiteralPath (Join-Path $driftHome "config.toml") -Value "# user drift" -Encoding utf8
    $driftApply = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $driftHome, "-Install", "-ApprovedProposalHash", $driftPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $driftApply.ExitCode -Expected 3 -Message "stale proposal hash should stop apply"
    Assert-Equal -Actual $driftApply.Json.status -Expected "approval-required" -Message "drift should require a new preview"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $driftHome "agent-operations/install-manifest.json"))) -Message "stale proposal must not partially install"

    $missingToEmptyHome = Join-Path $testRoot "installer-missing-to-empty-drift"
    Initialize-InstallerFixture -CodexHome $missingToEmptyHome
    $missingToEmptyPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $missingToEmptyHome, "-WhatIf", "-OutputFormat", "Json")
    Write-TestText -Path (Join-Path $missingToEmptyHome "config.toml") -Content ""
    $missingToEmptyApply = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $missingToEmptyHome, "-Install", "-ApprovedProposalHash", $missingToEmptyPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $missingToEmptyApply.ExitCode -Expected 3 -Message "missing-to-empty file drift should invalidate the approved proposal"
    Assert-Equal -Actual $missingToEmptyApply.Json.status -Expected "approval-required" -Message "missing-to-empty drift should require a new preview"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $missingToEmptyHome "agent-operations/install-manifest.json"))) -Message "missing-to-empty drift must not partially install"

    $reviewerHome = Join-Path $testRoot "installer-foreign-reviewer"
    Initialize-InstallerFixture -CodexHome $reviewerHome -WithForeignConfig
    Write-TestText -Path (Join-Path $reviewerHome "agents/independent-reviewer.toml") -Content "name = `"foreign`"`n"
    $reviewerBefore = Get-FileTreeFingerprint -Root $reviewerHome
    $reviewerPlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $reviewerHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $reviewerPlan.ExitCode -Expected 2 -Message "foreign reviewer should block install"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $reviewerHome) -Expected $reviewerBefore -Message "blocked reviewer preview should not mutate"

    $inlineHome = Join-Path $testRoot "installer-inline"
    Initialize-InstallerFixture -CodexHome $inlineHome
    Write-TestText -Path (Join-Path $inlineHome "config.toml") -Content "[hooks]`nexample = true`n"
    $inlineBefore = Get-FileTreeFingerprint -Root $inlineHome
    $inlinePlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $inlineHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $inlinePlan.ExitCode -Expected 2 -Message "inline hook representation should block install"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $inlineHome) -Expected $inlineBefore -Message "inline hook conflict should be no-mutation"

    $inlineAgentsHome = Join-Path $testRoot "installer-inline-agents"
    Initialize-InstallerFixture -CodexHome $inlineAgentsHome
    Write-TestText -Path (Join-Path $inlineAgentsHome "config.toml") -Content "agents = { max_threads = 8, max_depth = 2 }`n"
    $inlineAgentsBefore = Get-FileTreeFingerprint -Root $inlineAgentsHome
    $inlineAgentsPlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $inlineAgentsHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $inlineAgentsPlan.ExitCode -Expected 2 -Message "inline agents representation should require manual migration"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $inlineAgentsHome) -Expected $inlineAgentsBefore -Message "unsupported agents representation must not mutate"

    $dottedAgentsHome = Join-Path $testRoot "installer-dotted-agents"
    Initialize-InstallerFixture -CodexHome $dottedAgentsHome
    Write-TestText -Path (Join-Path $dottedAgentsHome "config.toml") -Content "agents.max_threads = 8`n"
    $dottedAgentsBefore = Get-FileTreeFingerprint -Root $dottedAgentsHome
    $dottedAgentsPlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $dottedAgentsHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $dottedAgentsPlan.ExitCode -Expected 2 -Message "dotted agents representation should require manual migration"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $dottedAgentsHome) -Expected $dottedAgentsBefore -Message "dotted agents blocker must not mutate"

    $invalidHooksHome = Join-Path $testRoot "installer-invalid-hooks-schema"
    Initialize-InstallerFixture -CodexHome $invalidHooksHome
    Write-TestText -Path (Join-Path $invalidHooksHome "hooks.json") -Content "[]`n"
    $invalidHooksBefore = Get-FileTreeFingerprint -Root $invalidHooksHome
    $invalidHooksPlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $invalidHooksHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $invalidHooksPlan.ExitCode -Expected 2 -Message "non-object hooks root should block install"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $invalidHooksHome) -Expected $invalidHooksBefore -Message "invalid hooks schema must not mutate"

    $foreignManifestHome = Join-Path $testRoot "installer-foreign-manifest"
    Initialize-InstallerFixture -CodexHome $foreignManifestHome
    Write-TestText -Path (Join-Path $foreignManifestHome "agent-operations/install-manifest.json") -Content "{`"owner`":`"foreign`",`"runtimeVersion`":`"3.1.0`"}"
    $foreignManifestBefore = Get-FileTreeFingerprint -Root $foreignManifestHome
    $foreignManifestPlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $foreignManifestHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $foreignManifestPlan.ExitCode -Expected 2 -Message "foreign manifest must block ownership-sensitive install"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $foreignManifestHome) -Expected $foreignManifestBefore -Message "foreign manifest blocker must not mutate"

    $invalidVersionHome = Join-Path $testRoot "installer-invalid-manifest-version"
    Initialize-InstallerFixture -CodexHome $invalidVersionHome
    Write-TestText -Path (Join-Path $invalidVersionHome "agent-operations/install-manifest.json") -Content "{`"owner`":`"agent-operations`",`"runtimeVersion`":`"..\\outside`"}"
    $invalidVersionBefore = Get-FileTreeFingerprint -Root $invalidVersionHome
    $invalidVersionPlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $invalidVersionHome, "-Uninstall", "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $invalidVersionPlan.ExitCode -Expected 2 -Message "invalid manifest runtimeVersion must block path derivation"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $invalidVersionHome) -Expected $invalidVersionBefore -Message "invalid manifest version must not mutate"

    $foreignFingerprintHome = Join-Path $testRoot "installer-foreign-fingerprint"
    Initialize-InstallerFixture -CodexHome $foreignFingerprintHome
    $foreignGroup = [ordered]@{
        matcher = "Bash"
        hooks = @([ordered]@{ type = "command"; command = "pwsh -NoProfile -Command 'foreign'" })
    }
    $foreignFingerprint = Get-TextSha256 -Text ($foreignGroup | ConvertTo-Json -Depth 20 -Compress)
    $foreignHooks = [ordered]@{ hooks = [ordered]@{ PreToolUse = @($foreignGroup) } }
    Write-TestText -Path (Join-Path $foreignFingerprintHome "hooks.json") -Content (($foreignHooks | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $forgedManifest = [ordered]@{ owner = "agent-operations"; runtimeVersion = "3.1.0"; hookFingerprints = [ordered]@{ PreToolUse = $foreignFingerprint } }
    Write-TestText -Path (Join-Path $foreignFingerprintHome "agent-operations/install-manifest.json") -Content (($forgedManifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    $foreignFingerprintBefore = Get-FileTreeFingerprint -Root $foreignFingerprintHome
    $foreignFingerprintPlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $foreignFingerprintHome, "-Uninstall", "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $foreignFingerprintPlan.ExitCode -Expected 2 -Message "manifest fingerprint must not claim a foreign hook group"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $foreignFingerprintHome) -Expected $foreignFingerprintBefore -Message "foreign fingerprint blocker must not mutate"

    $foreignRuntimeHome = Join-Path $testRoot "installer-foreign-runtime"
    Initialize-InstallerFixture -CodexHome $foreignRuntimeHome
    Write-TestText -Path (Join-Path $foreignRuntimeHome "agent-operations/versions/3.1.0/foreign.txt") -Content "foreign"
    $foreignRuntimeBefore = Get-FileTreeFingerprint -Root $foreignRuntimeHome
    $foreignRuntimePlan = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $foreignRuntimeHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $foreignRuntimePlan.ExitCode -Expected 2 -Message "foreign target runtime directory must block install"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $foreignRuntimeHome) -Expected $foreignRuntimeBefore -Message "foreign runtime blocker must not mutate"

    $rollbackHome = Join-Path $testRoot "installer-rollback"
    Initialize-InstallerFixture -CodexHome $rollbackHome -WithForeignConfig
    $rollbackBefore = Get-FileTreeFingerprint -Root $rollbackHome
    $rollbackPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $rollbackHome, "-WhatIf", "-OutputFormat", "Json")
    $rollback = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $rollbackHome, "-Install", "-ApprovedProposalHash", $rollbackPreview.Json.proposalHash, "-SimulateFailure", "-OutputFormat", "Json")
    Assert-Equal -Actual $rollback.ExitCode -Expected 4 -Message "simulated transaction failure should surface"
    Assert-Equal -Actual $rollback.Json.status -Expected "rolled-back" -Message "failed transaction should report rollback"
    Assert-Equal -Actual (Get-FileTreeFingerprint -Root $rollbackHome) -Expected $rollbackBefore -Message "transaction rollback should restore every managed file"

    $collisionHome = Join-Path $testRoot "installer-backup-collision"
    Initialize-InstallerFixture -CodexHome $collisionHome -WithForeignConfig
    $collisionPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $collisionHome, "-WhatIf", "-OutputFormat", "Json")
    $foreignBackupFile = Join-Path $collisionPreview.Json.backupDestination "foreign.txt"
    Write-TestText -Path $foreignBackupFile -Content "foreign backup state"
    $collisionApply = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $collisionHome, "-Install", "-ApprovedProposalHash", $collisionPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $collisionApply.ExitCode -Expected 3 -Message "a backup destination created after preview must invalidate apply"
    Assert-True -Condition (Test-Path -LiteralPath $foreignBackupFile -PathType Leaf) -Message "backup collision handling must preserve foreign state"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $collisionHome "agent-operations/install-manifest.json"))) -Message "backup collision must stop before managed mutation"

    $concurrentInstallHome = Join-Path $testRoot "installer-concurrent"
    Initialize-InstallerFixture -CodexHome $concurrentInstallHome -WithForeignConfig
    $concurrentInstallPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $concurrentInstallHome, "-WhatIf", "-OutputFormat", "Json")
    $installJobs = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt 2; $index++) {
        $installJobs.Add((Start-Job -ScriptBlock {
            param($InstallerScript, $CodexHome, $ProposalHash)
            $output = @(& pwsh -NoProfile -File $InstallerScript -CodexHome $CodexHome -Install -ApprovedProposalHash $ProposalHash -OutputFormat Json 2>&1)
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Raw = (@($output | ForEach-Object { [string]$_ }) -join "`n") }
        } -ArgumentList $installerScript, $concurrentInstallHome, $concurrentInstallPreview.Json.proposalHash))
    }
    try {
        $null = @($installJobs | Wait-Job -Timeout 45)
        $concurrentInstallResults = @($installJobs | Receive-Job)
    }
    finally {
        $installJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    Assert-Equal -Actual @($concurrentInstallResults | Where-Object ExitCode -eq 0).Count -Expected 1 -Message "exactly one concurrent installer should commit the transaction"
    Assert-Equal -Actual @($concurrentInstallResults | Where-Object ExitCode -eq 3).Count -Expected 1 -Message "the serialized loser should observe drift and require a new proposal"
    if (@($concurrentInstallResults | Where-Object ExitCode -eq 0).Count -ne 1 -or @($concurrentInstallResults | Where-Object ExitCode -eq 3).Count -ne 1) {
        foreach ($concurrentResult in $concurrentInstallResults) {
            $diagnosticResult = try { $concurrentResult.Raw | ConvertFrom-Json -Depth 20 } catch { $null }
            Write-Host ("DIAG: concurrent installer exit={0} status={1} blockers={2}" -f $concurrentResult.ExitCode, $diagnosticResult.status, (@($diagnosticResult.blockers) -join "; ")) -ForegroundColor DarkYellow
        }
    }
    Assert-Equal -Actual @($concurrentInstallResults | Where-Object ExitCode -eq 4).Count -Expected 0 -Message "a concurrent loser must not rollback the winner"
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $concurrentInstallHome "agent-operations/install-manifest.json") -PathType Leaf) -Message "concurrent install should leave a complete managed manifest"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath (Join-Path $concurrentInstallHome "backups/agent-operations") -Directory).Count -Expected 1 -Message "concurrent install should create exactly one successful backup"

    $aliasTargetHome = Join-Path $testRoot "installer-alias-target"
    $aliasHome = Join-Path $testRoot "installer-alias-link"
    Initialize-InstallerFixture -CodexHome $aliasTargetHome -WithForeignConfig
    [void](New-Item -ItemType Junction -Path $aliasHome -Target $aliasTargetHome)
    $aliasTargetPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $aliasTargetHome, "-WhatIf", "-OutputFormat", "Json")
    $aliasPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $aliasHome, "-WhatIf", "-OutputFormat", "Json")
    $targetIdentityProperty = $aliasTargetPreview.Json.PSObject.Properties["transactionLockIdentity"]
    $aliasIdentityProperty = $aliasPreview.Json.PSObject.Properties["transactionLockIdentity"]
    Assert-True -Condition ($null -ne $targetIdentityProperty -and $null -ne $aliasIdentityProperty) -Message "preview should expose the physical transaction lock identity for audit"
    Assert-Equal -Actual $(if ($null -eq $aliasIdentityProperty) { $null } else { $aliasIdentityProperty.Value }) -Expected $(if ($null -eq $targetIdentityProperty) { $null } else { $targetIdentityProperty.Value }) -Message "junction and target paths must serialize on one physical CodexHome identity"
    $aliasInstallJobs = @(
        Start-Job -ScriptBlock {
            param($InstallerScript, $CodexHome, $ProposalHash)
            $null = @(& pwsh -NoProfile -File $InstallerScript -CodexHome $CodexHome -Install -ApprovedProposalHash $ProposalHash -OutputFormat Json 2>&1)
            [pscustomobject]@{ ExitCode = $LASTEXITCODE }
        } -ArgumentList $installerScript, $aliasTargetHome, $aliasTargetPreview.Json.proposalHash
        Start-Job -ScriptBlock {
            param($InstallerScript, $CodexHome, $ProposalHash)
            $null = @(& pwsh -NoProfile -File $InstallerScript -CodexHome $CodexHome -Install -ApprovedProposalHash $ProposalHash -OutputFormat Json 2>&1)
            [pscustomobject]@{ ExitCode = $LASTEXITCODE }
        } -ArgumentList $installerScript, $aliasHome, $aliasPreview.Json.proposalHash
    )
    try {
        $null = @($aliasInstallJobs | Wait-Job -Timeout 45)
        $aliasInstallResults = @($aliasInstallJobs | Receive-Job)
    }
    finally {
        $aliasInstallJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    Assert-Equal -Actual @($aliasInstallResults | Where-Object ExitCode -eq 0).Count -Expected 1 -Message "exactly one physical-path alias installer should commit"
    Assert-Equal -Actual @($aliasInstallResults | Where-Object ExitCode -eq 3).Count -Expected 1 -Message "the physical-path alias loser should require a new proposal after live drift"

    $missingAliasTargetParent = Join-Path $testRoot "installer-missing-alias-target"
    $missingAliasParentLink = Join-Path $testRoot "installer-missing-alias-link"
    [void](New-Item -ItemType Directory -Path $missingAliasTargetParent -Force)
    [void](New-Item -ItemType Junction -Path $missingAliasParentLink -Target $missingAliasTargetParent)
    $missingAliasTargetHome = Join-Path $missingAliasTargetParent "new-codex-home"
    $missingAliasHome = Join-Path $missingAliasParentLink "new-codex-home"
    $missingAliasTargetPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $missingAliasTargetHome, "-WhatIf", "-OutputFormat", "Json")
    $missingAliasPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $missingAliasHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $missingAliasPreview.Json.transactionLockIdentity -Expected $missingAliasTargetPreview.Json.transactionLockIdentity -Message "missing CodexHome paths below physical parent aliases should share a lock identity"
    $missingAliasJobs = @(
        Start-Job -ScriptBlock {
            param($InstallerScript, $CodexHome, $ProposalHash)
            $null = @(& pwsh -NoProfile -File $InstallerScript -CodexHome $CodexHome -Install -ApprovedProposalHash $ProposalHash -OutputFormat Json 2>&1)
            [pscustomobject]@{ ExitCode = $LASTEXITCODE }
        } -ArgumentList $installerScript, $missingAliasTargetHome, $missingAliasTargetPreview.Json.proposalHash
        Start-Job -ScriptBlock {
            param($InstallerScript, $CodexHome, $ProposalHash)
            $null = @(& pwsh -NoProfile -File $InstallerScript -CodexHome $CodexHome -Install -ApprovedProposalHash $ProposalHash -OutputFormat Json 2>&1)
            [pscustomobject]@{ ExitCode = $LASTEXITCODE }
        } -ArgumentList $installerScript, $missingAliasHome, $missingAliasPreview.Json.proposalHash
    )
    try {
        $null = @($missingAliasJobs | Wait-Job -Timeout 45)
        $missingAliasResults = @($missingAliasJobs | Receive-Job)
    }
    finally {
        $missingAliasJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    Assert-Equal -Actual @($missingAliasResults | Where-Object ExitCode -eq 0).Count -Expected 1 -Message "exactly one missing-home alias installer should commit"
    Assert-Equal -Actual @($missingAliasResults | Where-Object ExitCode -eq 3).Count -Expected 1 -Message "missing-home alias loser should require a new proposal"

    $commitRaceHome = Join-Path $testRoot "installer-precommit-reparse-race"
    $commitRaceExternal = Join-Path $testRoot "installer-precommit-reparse-external"
    Initialize-InstallerFixture -CodexHome $commitRaceHome -WithForeignConfig
    [void](New-Item -ItemType Directory -Path $commitRaceExternal -Force)
    $commitRaceConfigBefore = [System.IO.File]::ReadAllText((Join-Path $commitRaceHome "config.toml"))
    $commitRacePreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $commitRaceHome, "-WhatIf", "-OutputFormat", "Json")
    $commitRaceSignal = Join-Path $testRoot "commit-race-ready.txt"
    $commitRaceJob = Start-Job -ScriptBlock {
        param($InstallerScript, $CodexHome, $ProposalHash, $SignalPath)
        $output = @(& pwsh -NoProfile -File $InstallerScript -CodexHome $CodexHome -Install -ApprovedProposalHash $ProposalHash -SimulateCommitDelayMilliseconds 4000 -SimulationCommitReadyPath $SignalPath -OutputFormat Json 2>&1)
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output | ForEach-Object { [string]$_ }) -join "`n" }
    } -ArgumentList $installerScript, $commitRaceHome, $commitRacePreview.Json.proposalHash, $commitRaceSignal
    if (-not (Wait-ForTestPath -Path $commitRaceSignal)) { throw "Installer did not reach the simulated commit window." }
    [void](New-Item -ItemType Junction -Path (Join-Path $commitRaceHome "agent-operations") -Target $commitRaceExternal)
    try {
        $null = $commitRaceJob | Wait-Job -Timeout 30
        $commitRaceResult = $commitRaceJob | Receive-Job
    }
    finally {
        $commitRaceJob | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    Assert-Equal -Actual $commitRaceResult.ExitCode -Expected 3 -Message "reparse introduced after approval must invalidate commit"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath $commitRaceExternal -Force).Count -Expected 0 -Message "precommit reparse race must not redirect managed writes"
    Assert-Equal -Actual ([System.IO.File]::ReadAllText((Join-Path $commitRaceHome "config.toml"))) -Expected $commitRaceConfigBefore -Message "precommit reparse race must preserve approved config input"
    [System.IO.Directory]::Delete((Join-Path $commitRaceHome "agent-operations"), $false)

    $contentRaceHome = Join-Path $testRoot "installer-precommit-content-race"
    Initialize-InstallerFixture -CodexHome $contentRaceHome -WithForeignConfig
    $contentRacePreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $contentRaceHome, "-WhatIf", "-OutputFormat", "Json")
    $contentRaceSignal = Join-Path $testRoot "content-race-ready.txt"
    $contentRaceJob = Start-Job -ScriptBlock {
        param($InstallerScript, $CodexHome, $ProposalHash, $SignalPath)
        $output = @(& pwsh -NoProfile -File $InstallerScript -CodexHome $CodexHome -Install -ApprovedProposalHash $ProposalHash -SimulateCommitDelayMilliseconds 4000 -SimulationCommitReadyPath $SignalPath -OutputFormat Json 2>&1)
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output | ForEach-Object { [string]$_ }) -join "`n" }
    } -ArgumentList $installerScript, $contentRaceHome, $contentRacePreview.Json.proposalHash, $contentRaceSignal
    if (-not (Wait-ForTestPath -Path $contentRaceSignal)) { throw "Installer did not reach the simulated content-drift window." }
    $contentRaceConfig = [System.IO.File]::ReadAllText((Join-Path $contentRaceHome "config.toml")) + "# concurrent user edit`n"
    Write-TestText -Path (Join-Path $contentRaceHome "config.toml") -Content $contentRaceConfig
    try {
        $null = $contentRaceJob | Wait-Job -Timeout 30
        $contentRaceResult = $contentRaceJob | Receive-Job
    }
    finally {
        $contentRaceJob | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    Assert-Equal -Actual $contentRaceResult.ExitCode -Expected 3 -Message "content drift after approval must invalidate commit"
    Assert-Equal -Actual ([System.IO.File]::ReadAllText((Join-Path $contentRaceHome "config.toml"))) -Expected $contentRaceConfig -Message "content drift rejection must preserve the concurrent user edit"

    $reparseHome = Join-Path $testRoot "installer-intermediate-reparse"
    $reparseExternal = Join-Path $testRoot "installer-intermediate-external"
    Initialize-InstallerFixture -CodexHome $reparseHome -WithForeignConfig
    [void](New-Item -ItemType Directory -Path $reparseExternal -Force)
    [void](New-Item -ItemType Junction -Path (Join-Path $reparseHome "agent-operations") -Target $reparseExternal)
    $reparsePreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $reparseHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $reparsePreview.ExitCode -Expected 2 -Message "intermediate managed-root reparse point must block install preview"
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath $reparseExternal -Force).Count -Expected 0 -Message "reparse blocker must not write into the external target"
    [System.IO.Directory]::Delete((Join-Path $reparseHome "agent-operations"), $false)

    $staleBackupHome = Join-Path $testRoot "installer-stale-backup"
    Initialize-InstallerFixture -CodexHome $staleBackupHome -WithForeignConfig
    $staleBackupRoot = Join-Path $staleBackupHome "backups/agent-operations"
    $oldBackup = Join-Path $staleBackupRoot "old"
    $newBackup = Join-Path $staleBackupRoot "new"
    foreach ($backup in @($oldBackup, $newBackup)) {
        Write-TestText -Path (Join-Path $backup "backup-manifest.json") -Content "{`"schemaVersion`":1,`"owner`":`"agent-operations`",`"successful`":true,`"files`":[]}`n"
    }
    [System.IO.Directory]::SetLastWriteTimeUtc($oldBackup, [DateTime]::UtcNow.AddDays(-100))
    [System.IO.Directory]::SetLastWriteTimeUtc($newBackup, [DateTime]::UtcNow)
    $staleBackupPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $staleBackupHome, "-WhatIf", "-OutputFormat", "Json")
    Assert-Equal -Actual $staleBackupPreview.ExitCode -Expected 2 -Message "an unprotected age-based backup candidate should block install before the hard cap"
    Assert-True -Condition ($oldBackup -in @($staleBackupPreview.Json.prune.backups)) -Message "stale backup blocker should identify the exact prune candidate"

    $pruneDriftHome = Join-Path $testRoot "installer-prune-drift"
    $pruneDriftRoot = Join-Path $pruneDriftHome "backups/agent-operations"
    $pruneDriftOld = Join-Path $pruneDriftRoot "old"
    $pruneDriftNew = Join-Path $pruneDriftRoot "new"
    foreach ($backup in @($pruneDriftOld, $pruneDriftNew)) {
        Write-TestText -Path (Join-Path $backup "backup-manifest.json") -Content "{`"schemaVersion`":1,`"owner`":`"agent-operations`",`"successful`":true,`"files`":[]}`n"
    }
    [System.IO.Directory]::SetLastWriteTimeUtc($pruneDriftOld, [DateTime]::UtcNow.AddDays(-100))
    [System.IO.Directory]::SetLastWriteTimeUtc($pruneDriftNew, [DateTime]::UtcNow)
    $pruneDriftPreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $pruneDriftHome, "-Prune", "-WhatIf", "-OutputFormat", "Json")
    $pruneDriftForeignFile = Join-Path $pruneDriftOld "foreign-after-preview.txt"
    Write-TestText -Path $pruneDriftForeignFile -Content "foreign"
    $pruneDriftApply = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $pruneDriftHome, "-Prune", "-ApprovedProposalHash", $pruneDriftPreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $pruneDriftApply.ExitCode -Expected 3 -Message "prune candidate content drift after preview must invalidate approval"
    Assert-True -Condition (Test-Path -LiteralPath $pruneDriftForeignFile -PathType Leaf) -Message "prune drift handling must preserve newly foreign content"

    $pruneHome = Join-Path $testRoot "installer-prune"
    [void](New-Item -ItemType Directory -Path $pruneHome -Force)
    $backupRoot = Join-Path $pruneHome "backups/agent-operations"
    for ($index = 0; $index -lt 10; $index++) {
        $backup = Join-Path $backupRoot ("backup-{0:D2}" -f $index)
        Write-TestText -Path (Join-Path $backup "backup-manifest.json") -Content "{`"owner`":`"agent-operations`",`"successful`":true}"
        [System.IO.Directory]::SetLastWriteTimeUtc($backup, [DateTime]::UtcNow.AddDays(-100 + $index))
    }
    $tamperedBackup = Join-Path $backupRoot "backup-00"
    Write-TestText -Path (Join-Path $tamperedBackup "00-config.toml") -Content "tampered"
    Write-TestText -Path (Join-Path $tamperedBackup "backup-manifest.json") -Content "{`"owner`":`"agent-operations`",`"successful`":true,`"files`":[{`"backup`":`"00-config.toml`",`"sha256`":`"0000000000000000000000000000000000000000000000000000000000000000`"}]}"
    [System.IO.Directory]::SetLastWriteTimeUtc($tamperedBackup, [DateTime]::UtcNow.AddDays(-100))
    $versionsRoot = Join-Path $pruneHome "agent-operations/versions"
    foreach ($version in @("2.9.0", "3.0.0", "3.1.0")) {
        $versionDirectory = Join-Path $versionsRoot $version
        $runtimeFile = Join-Path $versionDirectory "agent-operations-hook.ps1"
        Write-TestText -Path $runtimeFile -Content "# $version"
        $hash = (Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-TestText -Path (Join-Path $versionDirectory ".agent-operations-owned.json") -Content ("{`"owner`":`"agent-operations`",`"version`":`"$version`",`"sha256`":`"$hash`"}")
    }
    $mismatchedVersionDirectory = Join-Path $versionsRoot "2.8.0"
    $mismatchedRuntimeFile = Join-Path $mismatchedVersionDirectory "agent-operations-hook.ps1"
    Write-TestText -Path $mismatchedRuntimeFile -Content "# 2.8.0"
    $mismatchedHash = (Get-FileHash -LiteralPath $mismatchedRuntimeFile -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-TestText -Path (Join-Path $mismatchedVersionDirectory ".agent-operations-owned.json") -Content ("{`"owner`":`"agent-operations`",`"version`":`"9.9.9`",`"sha256`":`"$mismatchedHash`"}")
    $manifestProtectedBackup = Join-Path $backupRoot "backup-01"
    $pruneManifest = [ordered]@{
        owner = "agent-operations"
        runtimeVersion = "3.1.0"
        lastKnownGoodVersion = "3.0.0"
        backupPath = $manifestProtectedBackup
    }
    Write-TestText -Path (Join-Path $pruneHome "agent-operations/install-manifest.json") -Content (($pruneManifest | ConvertTo-Json) + [Environment]::NewLine)
    $prunePreview = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $pruneHome, "-Prune", "-WhatIf", "-OutputFormat", "Json")
    Assert-True -Condition (@($prunePreview.Json.prune.backups).Count -ge 1) -Message "prune preview should identify stale/excess backups"
    Assert-Equal -Actual @($prunePreview.Json.prune.runtimes).Count -Expected 1 -Message "prune should select only unprotected excess runtime"
    $prune = Invoke-JsonProcess -ScriptPath $installerScript -Arguments @("-CodexHome", $pruneHome, "-Prune", "-ApprovedProposalHash", $prunePreview.Json.proposalHash, "-OutputFormat", "Json")
    Assert-Equal -Actual $prune.Json.status -Expected "pruned" -Message "approved prune should pass"
    Assert-True -Condition (@(Get-ChildItem -LiteralPath $backupRoot -Directory).Count -le 9) -Message "prune should leave room below backup hard cap"
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $versionsRoot "3.1.0")) -Message "prune should protect active runtime"
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $versionsRoot "3.0.0")) -Message "prune should protect last-known-good runtime"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $versionsRoot "2.9.0"))) -Message "prune should remove only verified unprotected runtime"
    Assert-True -Condition (Test-Path -LiteralPath $tamperedBackup) -Message "prune must preserve a backup whose declared content hash drifted"
    Assert-True -Condition (Test-Path -LiteralPath $manifestProtectedBackup) -Message "prune must protect the exact rollback point recorded in the install manifest"
    Assert-True -Condition (Test-Path -LiteralPath $mismatchedVersionDirectory) -Message "prune must preserve a runtime whose marker version does not match its directory"
}

function Invoke-AnalyzerFixture {
    param(
        [string]$Output,
        [string]$GoldSet,
        [string]$EvidenceMap
    )

    $arguments = @(
        "-Since", "2026-01-01T00:00:00Z",
        "-Until", "2026-01-02T00:00:00Z",
        "-SessionsRoot", (Join-Path $fixtureRoot "analyzer"),
        "-EvidenceSaltPath", (Join-Path $fixtureRoot "analyzer-salt.txt"),
        "-OutputDirectory", $Output,
        "-Quiet"
    )
    if (-not [string]::IsNullOrWhiteSpace($GoldSet)) {
        $arguments += @("-GoldSetPath", $GoldSet)
    }
    if (-not [string]::IsNullOrWhiteSpace($EvidenceMap)) {
        $arguments += @("-EvidenceMapPath", $EvidenceMap)
    }
    return Invoke-JsonProcess -ScriptPath $analyzerScript -Arguments $arguments
}

function Test-Analyzer {
    Write-Host "INFO: analyzer contracts" -ForegroundColor Cyan
    $evidenceMapPath = Join-Path $testRoot "analyzer-evidence-map.json"
    $samplingOutput = Join-Path $testRoot "analyzer-sampling-output"
    $samplingRun = Invoke-AnalyzerFixture -Output $samplingOutput -GoldSet $null -EvidenceMap $evidenceMapPath
    Assert-Equal -Actual $samplingRun.ExitCode -Expected 0 -Message "analyzer sampling run should pass"
    $evidenceMap = (Get-Content -LiteralPath $evidenceMapPath -Raw) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $evidenceMap.samplingAlgorithm -Expected "independent-stratified-v1" -Message "evidence map should declare deterministic independent sampling"
    Assert-True -Condition (@($evidenceMap.entries | Where-Object { -not $_.predicted }).Count -gt 0) -Message "evidence map must include classifier-negative background candidates"
    Assert-True -Condition (@($evidenceMap.entries | Where-Object { $_.selectionReason -eq "high-recall" }).Count -gt 0) -Message "evidence map must include broad high-recall candidates"
    Assert-Equal -Actual @($evidenceMap.entries | Where-Object { $_.category -eq "user-correction" -and $_.selectionReason -eq "strong-signal" }).Count -Expected 1 -Message "evidence sample should include every strong user-correction signal"
    Assert-Equal -Actual @($evidenceMap.entries.evidenceHash | Select-Object -Unique).Count -Expected @($evidenceMap.entries).Count -Message "evidence sample should deduplicate episodes shared by active and archived session storage"

    $privateReview = Invoke-JsonProcess -ScriptPath $analyzerScript -Arguments @(
        "-Since", "2026-01-01T00:00:00Z",
        "-Until", "2026-01-02T00:00:00Z",
        "-SessionsRoot", (Join-Path $fixtureRoot "analyzer"),
        "-EvidenceSaltPath", (Join-Path $fixtureRoot "analyzer-salt.txt"),
        "-OutputDirectory", (Join-Path $testRoot "analyzer-private-review-output"),
        "-EmitPrivateReviewSample",
        "-PrivateReviewCategory", "path-glob",
        "-Quiet"
    )
    Assert-Equal -Actual $privateReview.ExitCode -Expected 0 -Message "explicit private review mode should emit the sampled raw episode only to stdout"
    Assert-True -Condition (@($privateReview.Json.entries).Count -gt 0) -Message "private review output should contain sampled episodes"
    foreach ($privateEntry in @($privateReview.Json.entries)) {
        Assert-True -Condition ($null -eq $privateEntry.PSObject.Properties["predicted"] -and $null -eq $privateEntry.PSObject.Properties["selectionReason"]) -Message "private reviewer input must hide classifier predictions and selection reasons"
    }

    $validGoldPath = Join-Path $testRoot "analyzer-valid-gold.json"
    $validGoldEntries = [ordered]@{}
    $gitFalsePositiveInjected = $false
    foreach ($sampleEntry in @($evidenceMap.entries)) {
        $expected = [bool]$sampleEntry.predicted
        if (-not $gitFalsePositiveInjected -and $sampleEntry.category -eq "git-sandbox" -and $sampleEntry.predicted) {
            $expected = $false
            $gitFalsePositiveInjected = $true
        }
        $validGoldEntries[[string]$sampleEntry.evidenceHash] = [ordered]@{
            category = [string]$sampleEntry.category
            expected = $expected
        }
    }
    $validGold = [ordered]@{
        schemaVersion = 1
        samplingAlgorithm = $evidenceMap.samplingAlgorithm
        seedId = $evidenceMap.seedId
        sampleId = $evidenceMap.sampleId
        entries = $validGoldEntries
    }
    Write-TestText -Path $validGoldPath -Content (($validGold | ConvertTo-Json -Depth 20) + [Environment]::NewLine)

    $output = Join-Path $testRoot "analyzer-output"
    $run = Invoke-AnalyzerFixture -Output $output -GoldSet $validGoldPath -EvidenceMap (Join-Path $testRoot "analyzer-validated-evidence-map.json")
    Assert-Equal -Actual $run.ExitCode -Expected 0 -Message "synthetic analyzer run should pass"
    $summaryPath = Join-Path $output "summary.json"
    Assert-True -Condition (Test-Path -LiteralPath $summaryPath) -Message "analyzer should write summary.json"
    $summary = (Get-Content -LiteralPath $summaryPath -Raw) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $summary.denominators.topLevelTasks -Expected 1 -Message "top-level task denominator"
    Assert-Equal -Actual $summary.denominators.traces -Expected 2 -Message "trace denominator"
    Assert-Equal -Actual $summary.denominators.toolCalls -Expected 7 -Message "legacy-compatible tool-call envelope denominator should include unresolved wrappers"
    Assert-Equal -Actual $summary.denominators.directToolCallEnvelopes -Expected 6 -Message "direct envelope denominator should exclude code-mode wrappers"
    Assert-Equal -Actual $summary.denominators.matchedDirectToolCalls -Expected 6 -Message "matched direct denominator should require an in-window output pair"
    Assert-Equal -Actual $summary.denominators.unresolvedCodeModeWrappers -Expected 1 -Message "code-mode wrapper should be reported separately instead of counted as a direct tool call"
    Assert-Equal -Actual $summary.denominators.otherRecognizedToolCalls -Expected 0 -Message "fixture should not contain additional envelope types"
    Assert-Equal -Actual $summary.comparability.status -Expected "partial" -Message "unresolved code-mode wrappers must prevent a fully comparable report"
    Assert-Equal -Actual $summary.parsing.malformedLines -Expected 1 -Message "malformed line counter"
    Assert-Equal -Actual $summary.parsing.tracesWithRecordsOutsideWindow -Expected 1 -Message "exclusive Until boundary should be reported without counting its records"
    foreach ($category in @("path-glob", "failed-patch", "timeout")) {
        Assert-Equal -Actual $summary.categories.$category.tasks -Expected 1 -Message "$category task incidence"
        Assert-Equal -Actual $summary.goldSet.$category.status -Expected "auto-counted" -Message "$category gold-set threshold"
    }
    Assert-Equal -Actual $summary.categories.'git-sandbox'.tasks -Expected 1 -Message "git-sandbox task incidence"
    Assert-Equal -Actual $summary.goldSet.'git-sandbox'.status -Expected "manual-review-only" -Message "a known false positive must keep Git classification manual-only"
    Assert-Equal -Actual $summary.goldSet.'git-sandbox'.fp -Expected 1 -Message "gold regression should exercise a non-perfect Git confusion matrix"
    Assert-Equal -Actual $summary.categories.'expected-no-match'.events -Expected 1 -Message "rg no-match should be separate"
    Assert-Equal -Actual $summary.categories.'expected-tdd-red'.events -Expected 1 -Message "planned TDD red should be separate"
    Assert-Equal -Actual $summary.categories.'environment-blocker'.tasks -Expected 1 -Message "environment blocker precedence"
    Assert-Equal -Actual $summary.categories.interrupted.tasks -Expected 1 -Message "interrupted trace classification"
    Assert-Equal -Actual $summary.categories.'user-correction'.tasks -Expected 1 -Message "strong correction classification"
    Assert-Equal -Actual $summary.goldSet.'user-correction'.status -Expected "manually-reviewed" -Message "all strong correction signals should receive independent labels"
    Assert-Equal -Actual $summary.followUp.targetsAreImmediateClaims -Expected $false -Message "immediate report must not claim 30-day targets"

    $manualOutput = Join-Path $testRoot "analyzer-manual-output"
    $manualRun = Invoke-AnalyzerFixture -Output $manualOutput -GoldSet $null -EvidenceMap $null
    Assert-Equal -Actual $manualRun.ExitCode -Expected 0 -Message "analyzer should run without private gold set"
    $manualSummary = (Get-Content -LiteralPath (Join-Path $manualOutput "summary.json") -Raw) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $manualSummary.goldSet.'path-glob'.status -Expected "manual-review-only" -Message "missing gold set must disable auto-counted status"

    $invalidGold = $validGold | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
    $firstInvalidGoldEntry = $invalidGold.entries.PSObject.Properties | Select-Object -First 1
    $firstInvalidGoldEntry.Value.expected = "false"
    $invalidGoldPath = Join-Path $testRoot "invalid-gold-set.json"
    Write-TestText -Path $invalidGoldPath -Content (($invalidGold | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $invalidGoldOutput = Join-Path $testRoot "analyzer-invalid-gold-output"
    $invalidGoldRun = Invoke-AnalyzerFixture -Output $invalidGoldOutput -GoldSet $invalidGoldPath -EvidenceMap $null
    Assert-Equal -Actual $invalidGoldRun.ExitCode -Expected 0 -Message "invalid gold labels should produce a bounded report"
    $invalidGoldSummary = (Get-Content -LiteralPath (Join-Path $invalidGoldOutput "summary.json") -Raw) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $invalidGoldSummary.goldSet.'path-glob'.status -Expected "manual-review-only" -Message "string boolean label must not pass the accuracy gate"
    Assert-Equal -Actual $invalidGoldSummary.goldSet.'path-glob'.reason -Expected "invalid-gold-entry" -Message "invalid gold label reason"
    Assert-Equal -Actual $invalidGoldSummary.goldSet.'path-glob'.invalidEntries -Expected 1 -Message "invalid gold entry count"

    $forgedGold = $validGold | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
    $firstForgedGoldEntry = $forgedGold.entries.PSObject.Properties | Select-Object -First 1
    $firstForgedGoldValue = $firstForgedGoldEntry.Value
    $forgedGold.entries.PSObject.Properties.Remove($firstForgedGoldEntry.Name)
    $forgedGold.entries | Add-Member -NotePropertyName ("f" * 64) -NotePropertyValue $firstForgedGoldValue
    $forgedGoldPath = Join-Path $testRoot "forged-gold-set.json"
    Write-TestText -Path $forgedGoldPath -Content (($forgedGold | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
    $forgedGoldOutput = Join-Path $testRoot "analyzer-forged-gold-output"
    $forgedGoldRun = Invoke-AnalyzerFixture -Output $forgedGoldOutput -GoldSet $forgedGoldPath -EvidenceMap $null
    Assert-Equal -Actual $forgedGoldRun.ExitCode -Expected 0 -Message "forged gold evidence should produce a bounded report"
    $forgedGoldSummary = (Get-Content -LiteralPath (Join-Path $forgedGoldOutput "summary.json") -Raw) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $forgedGoldSummary.goldSet.'path-glob'.status -Expected "manual-review-only" -Message "unknown evidence hashes must not inflate true negatives"
    Assert-Equal -Actual $forgedGoldSummary.goldSet.'path-glob'.reason -Expected "gold-sample-mismatch" -Message "forged hash should fail exact sample validation"

    $scenarioIds = @("windows-wildcard", "stale-patch", "tunit-validation", "shared-writers", "git-worktree")
    $validSmoke = [ordered]@{
        runtime = [ordered]@{ surface = "Codex CLI"; model = "gpt-5.6-sol"; reasoning = "xhigh"; sandbox = "workspace-write" }
        scenarios = @($scenarioIds | ForEach-Object {
            [ordered]@{ id = $_; firstAction = "preflight"; sequence = @("inspect", "decide"); stopCondition = "bounded"; userVisibleDecision = "reported" }
        })
    }
    $validReview = [ordered]@{
        effectiveSandbox = "read-only"; writeAttempted = $true; writeDenied = $true; overallPass = $true
        scenarios = @($scenarioIds | ForEach-Object {
            [ordered]@{ id = $_; beforePass = $false; afterPass = $true; improved = $true; evidence = "observed" }
        })
        residualRisks = @("release payload remains external")
    }
    Assert-True -Condition (Test-JsonSchemaDocument -Json ($validSmoke | ConvertTo-Json -Depth 20) -SchemaPath $behavioralSmokeSchema) -Message "behavioral smoke schema should accept the complete ordered scenario set"
    Assert-True -Condition (Test-JsonSchemaDocument -Json ($validReview | ConvertTo-Json -Depth 20) -SchemaPath $smokeReviewSchema) -Message "smoke review schema should accept internally consistent PASS evidence"
    Assert-True -Condition (Test-JsonSchemaDocument -Json ($validGold | ConvertTo-Json -Depth 20) -SchemaPath $goldLabelsSchema) -Message "gold schema should accept hash-keyed unique labels"
    $duplicateSmoke = $validSmoke | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
    $duplicateSmoke.scenarios[1].id = $duplicateSmoke.scenarios[0].id
    Assert-True -Condition (-not (Test-JsonSchemaDocument -Json ($duplicateSmoke | ConvertTo-Json -Depth 20) -SchemaPath $behavioralSmokeSchema)) -Message "behavioral smoke schema must reject duplicate or missing scenario IDs"
    $inconsistentReview = $validReview | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
    $inconsistentReview.writeDenied = $false
    $inconsistentReview.scenarios[0].improved = $false
    Assert-True -Condition (-not (Test-JsonSchemaDocument -Json ($inconsistentReview | ConvertTo-Json -Depth 20) -SchemaPath $smokeReviewSchema)) -Message "overall PASS must require write denial and improvement in every scenario"
    $arrayGold = $validGold | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
    $arrayGold.entries = @([pscustomobject]@{ evidenceHash = "a" * 64; category = "timeout"; expected = $true })
    Assert-True -Condition (-not (Test-JsonSchemaDocument -Json ($arrayGold | ConvertTo-Json -Depth 20) -SchemaPath $goldLabelsSchema)) -Message "gold schema must reject duplicate-prone array representation"

    $hierarchyRoot = Join-Path $testRoot "analyzer-hierarchy"
    $hierarchyParentId = "10000000-0000-0000-0000-000000000001"
    $hierarchyChildId = "10000000-0000-0000-0000-000000000002"
    $hierarchyGrandchildId = "10000000-0000-0000-0000-000000000003"
    Write-TestText -Path (Join-Path $hierarchyRoot "parent-$hierarchyParentId.jsonl") -Content ((@(
        [ordered]@{ timestamp = "2026-01-01T02:00:00Z"; type = "session_meta"; payload = [ordered]@{ id = $hierarchyParentId; thread_source = "user" } },
        [ordered]@{ timestamp = "2026-01-01T02:00:01Z"; type = "event_msg"; payload = [ordered]@{ type = "task_complete" } }
    ) | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) -join "`n")
    Write-TestText -Path (Join-Path $hierarchyRoot "child-$hierarchyChildId.jsonl") -Content ((@(
        [ordered]@{ timestamp = "2026-01-01T02:01:00Z"; type = "session_meta"; payload = [ordered]@{ id = $hierarchyChildId; parent_thread_id = $hierarchyParentId; thread_source = "subagent" } },
        [ordered]@{ timestamp = "2026-01-01T02:01:01Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "child-timeout"; name = "shell_command"; arguments = '{"command":"dotnet test"}' } },
        [ordered]@{ timestamp = "2026-01-01T02:01:02Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "child-timeout"; output = "Operation timed out`nExit code: 124" } }
    ) | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) -join "`n")
    Write-TestText -Path (Join-Path $hierarchyRoot "grandchild-$hierarchyGrandchildId.jsonl") -Content ((@(
        [ordered]@{ timestamp = "2026-01-01T02:02:00Z"; type = "session_meta"; payload = [ordered]@{ id = $hierarchyGrandchildId; parent_thread_id = $hierarchyChildId; thread_source = "subagent" } },
        [ordered]@{ timestamp = "2026-01-01T02:02:01Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "grandchild-path"; name = "shell_command"; arguments = '{"command":"Get-Content missing\\*.md"}' } },
        [ordered]@{ timestamp = "2026-01-01T02:02:02Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "grandchild-path"; output = "Cannot find path 'missing\\*.md' because it does not exist`nExit code: 1" } }
    ) | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) -join "`n")
    $hierarchyOutput = Join-Path $testRoot "analyzer-hierarchy-output"
    $hierarchyRun = Invoke-JsonProcess -ScriptPath $analyzerScript -Arguments @("-Since", "2026-01-01T00:00:00Z", "-Until", "2026-01-02T00:00:00Z", "-SessionsRoot", $hierarchyRoot, "-OutputDirectory", $hierarchyOutput, "-Quiet")
    Assert-Equal -Actual $hierarchyRun.ExitCode -Expected 0 -Message "hierarchy fixture should analyze"
    $hierarchySummary = [System.IO.File]::ReadAllText((Join-Path $hierarchyOutput "summary.json")) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $hierarchySummary.denominators.topLevelTasks -Expected 1 -Message "nested child traces should resolve to one root task"
    Assert-Equal -Actual $hierarchySummary.denominators.traces -Expected 3 -Message "hierarchy fixture trace denominator"
    Assert-Equal -Actual $hierarchySummary.categories.timeout.tasks -Expected 1 -Message "child-only timeout must contribute to root task incidence"
    Assert-Equal -Actual $hierarchySummary.categories.'path-glob'.tasks -Expected 1 -Message "grandchild-only path failure must contribute to root task incidence"

    $duplicateRoot = Join-Path $testRoot "analyzer-duplicates"
    $duplicateTraceId = "20000000-0000-0000-0000-000000000001"
    $duplicateName = "rollout-$duplicateTraceId.jsonl"
    $duplicateContent = ((@(
        [ordered]@{ timestamp = "2026-01-01T03:00:00Z"; type = "session_meta"; payload = [ordered]@{ id = $duplicateTraceId; thread_source = "user" } },
        [ordered]@{ timestamp = "2026-01-01T03:00:01Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "duplicate-timeout"; name = "shell_command"; arguments = '{"command":"dotnet test"}' } },
        [ordered]@{ timestamp = "2026-01-01T03:00:02Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "duplicate-timeout"; output = "Operation timed out`nExit code: 124" } }
    ) | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) -join "`n")
    Write-TestText -Path (Join-Path $duplicateRoot "active/$duplicateName") -Content $duplicateContent
    Write-TestText -Path (Join-Path $duplicateRoot "archive/$duplicateName") -Content $duplicateContent
    $duplicateOutput = Join-Path $testRoot "analyzer-duplicates-output"
    $duplicateRun = Invoke-JsonProcess -ScriptPath $analyzerScript -Arguments @("-Since", "2026-01-01T00:00:00Z", "-Until", "2026-01-02T00:00:00Z", "-SessionsRoot", $duplicateRoot, "-OutputDirectory", $duplicateOutput, "-Quiet")
    Assert-Equal -Actual $duplicateRun.ExitCode -Expected 0 -Message "duplicate trace fixture should analyze"
    $duplicateSummary = [System.IO.File]::ReadAllText((Join-Path $duplicateOutput "summary.json")) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $duplicateSummary.parsing.filesAvailable -Expected 2 -Message "duplicate source files should remain visible in quality counters"
    Assert-Equal -Actual $duplicateSummary.parsing.duplicateTraceFilesExcluded -Expected 1 -Message "active/archive copy should be excluded once"
    Assert-Equal -Actual $duplicateSummary.denominators.traces -Expected 1 -Message "duplicate trace must not inflate trace denominator"
    Assert-Equal -Actual $duplicateSummary.categories.timeout.events -Expected 1 -Message "duplicate trace must not inflate event counts"

    $pairingRoot = Join-Path $testRoot "analyzer-pairing-quality"
    $pairingTraceId = "30000000-0000-0000-0000-000000000001"
    Write-TestText -Path (Join-Path $pairingRoot "rollout-$pairingTraceId.jsonl") -Content ((@(
        [ordered]@{ timestamp = "2025-12-31T23:59:59Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "boundary"; name = "shell_command"; arguments = '{"command":"git status"}' } },
        [ordered]@{ timestamp = "2026-01-01T00:00:00Z"; type = "session_meta"; payload = [ordered]@{ id = $pairingTraceId; thread_source = "user" } },
        [ordered]@{ timestamp = "2026-01-01T00:00:01Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "boundary"; output = "Exit code: 0" } },
        [ordered]@{ timestamp = "2026-01-01T00:00:02Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "unmatched"; name = "shell_command"; arguments = '{"command":"git status"}' } },
        [ordered]@{ timestamp = "2026-01-01T00:00:03Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "unknown"; output = "Exit code: 0" } },
        [ordered]@{ timestamp = "2026-01-01T00:00:04Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "matched"; name = "shell_command"; arguments = '{"command":"git status"}' } },
        [ordered]@{ timestamp = "2026-01-01T00:00:05Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "matched"; output = "Exit code: 0" } },
        [ordered]@{ timestamp = "2026-01-01T00:00:06Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "sequential-duplicate"; name = "shell_command"; arguments = '{"command":"Get-Content missing\\*.md"}' } },
        [ordered]@{ timestamp = "2026-01-01T00:00:07Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "sequential-duplicate"; output = "Cannot find path 'missing\\*.md' because it does not exist`nExit code: 1" } },
        [ordered]@{ timestamp = "2026-01-01T00:00:08Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "sequential-duplicate"; name = "shell_command"; arguments = '{"command":"Get-Content missing\\*.md"}' } },
        [ordered]@{ timestamp = "2026-01-01T00:00:09Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "sequential-duplicate"; output = "Cannot find path 'missing\\*.md' because it does not exist`nExit code: 1" } },
        [ordered]@{ timestamp = "2026-01-01T00:00:10Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "overlapping-duplicate"; name = "shell_command"; arguments = '{"command":"Get-Content missing\\*.md"}' } },
        [ordered]@{ timestamp = "2026-01-01T00:00:11Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "overlapping-duplicate"; name = "shell_command"; arguments = '{"command":"Get-Content missing\\*.md"}' } },
        [ordered]@{ timestamp = "2026-01-01T00:00:12Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "overlapping-duplicate"; output = "Cannot find path 'missing\\*.md' because it does not exist`nExit code: 1" } },
        [ordered]@{ timestamp = "2026-01-01T00:00:13Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "overlapping-duplicate"; output = "Cannot find path 'missing\\*.md' because it does not exist`nExit code: 1" } },
        [ordered]@{ timestamp = "2026-01-01T23:59:59Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "trailing-boundary"; name = "shell_command"; arguments = '{"command":"git status"}' } },
        [ordered]@{ timestamp = "2026-01-02T00:00:00Z"; type = "response_item"; payload = [ordered]@{ type = "function_call"; call_id = "matched"; name = "shell_command"; arguments = '{"command":"Get-Content missing\\*.md"}' } },
        [ordered]@{ timestamp = "2026-01-02T00:00:01Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "matched"; output = "Cannot find path 'missing\\*.md' because it does not exist`nExit code: 1" } },
        [ordered]@{ timestamp = "2026-01-02T00:00:02Z"; type = "response_item"; payload = [ordered]@{ type = "function_call_output"; call_id = "trailing-boundary"; output = "Exit code: 0" } }
    ) | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) -join "`n")
    $pairingOutput = Join-Path $testRoot "analyzer-pairing-output"
    $pairingRun = Invoke-JsonProcess -ScriptPath $analyzerScript -Arguments @("-Since", "2026-01-01T00:00:00Z", "-Until", "2026-01-02T00:00:00Z", "-SessionsRoot", $pairingRoot, "-OutputDirectory", $pairingOutput, "-Quiet")
    Assert-Equal -Actual $pairingRun.ExitCode -Expected 0 -Message "pairing quality fixture should analyze"
    $pairingSummary = [System.IO.File]::ReadAllText((Join-Path $pairingOutput "summary.json")) | ConvertFrom-Json -Depth 50
    Assert-Equal -Actual $pairingSummary.denominators.directToolCallEnvelopes -Expected 5 -Message "direct envelope count should deduplicate repeated call IDs and retain an in-window trailing-boundary call"
    Assert-Equal -Actual $pairingSummary.denominators.matchedDirectToolCalls -Expected 1 -Message "matched direct count should require an in-window pair"
    Assert-Equal -Actual $pairingSummary.parsing.unmatchedDirectToolCalls -Expected 1 -Message "unmatched in-window call quality counter"
    Assert-Equal -Actual $pairingSummary.parsing.outputsWithoutMatchingCall -Expected 1 -Message "unknown output quality counter"
    Assert-Equal -Actual $pairingSummary.parsing.boundaryPairsExcluded -Expected 2 -Message "leading and trailing cross-window pair quality counter"
    Assert-Equal -Actual $pairingSummary.parsing.duplicateCallIds -Expected 2 -Message "overlapping and sequential call ID reuse should be counted"
    Assert-Equal -Actual $pairingSummary.categories.'path-glob'.events -Expected 0 -Message "tainted duplicate pairs must not contribute classifications"
    Assert-Equal -Actual $pairingSummary.denominators.matchedDirectToolCalls -Expected 1 -Message "post-Until duplicate must not retroactively remove an in-window matched pair"

    $largeRoot = Join-Path $testRoot "analyzer-large"
    [void](New-Item -ItemType Directory -Path $largeRoot -Force)
    $largeValue = "x" * 1048576
    $largeRecord = [ordered]@{
        timestamp = "2026-01-01T01:00:00Z"
        type = "response_item"
        payload = [ordered]@{ type = "message"; role = "assistant"; content = $largeValue }
    } | ConvertTo-Json -Depth 10 -Compress
    Write-TestText -Path (Join-Path $largeRoot "rollout-2026-01-01T01-00-00-00000000-0000-0000-0000-000000000003.jsonl") -Content ($largeRecord + [Environment]::NewLine)
    $largeOutput = Join-Path $testRoot "analyzer-large-output"
    $largeRun = Invoke-JsonProcess -ScriptPath $analyzerScript -Arguments @("-Since", "2026-01-01T00:00:00Z", "-Until", "2026-01-02T00:00:00Z", "-SessionsRoot", $largeRoot, "-OutputDirectory", $largeOutput, "-Quiet")
    Assert-Equal -Actual $largeRun.ExitCode -Expected 0 -Message "streaming analyzer should tolerate a one-megabyte line"
}

function Test-Privacy {
    Write-Host "INFO: privacy contracts" -ForegroundColor Cyan
    $telemetry = Join-Path $testRoot "privacy-telemetry"
    $secret = "fixture-super-secret-token"
    $privatePath = "C:\Users\PrivateFixture\secret.txt"
    [void](Invoke-HookFixture -Payload ([pscustomobject]@{
        hook_event_name = "PostToolUse"
        turn_id = "privacy-turn"
        tool_name = "Bash"
        tool_input = [pscustomobject]@{ command = "Get-Content '$privatePath' -Token '$secret'" }
        tool_response = [pscustomobject]@{ exit_code = 1; stderr = "Permission denied" }
    }) -TelemetryRoot $telemetry)
    $telemetryText = @(Get-ChildItem -LiteralPath $telemetry -File -Filter "*.jsonl" | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    foreach ($forbidden in @($secret, $privatePath, "Get-Content", "tool_input", "tool_response")) {
        Assert-True -Condition ($telemetryText -notmatch [regex]::Escape($forbidden)) -Message "telemetry must not contain forbidden raw value '$forbidden'"
    }
    foreach ($record in @(Get-Content -LiteralPath (Join-Path $telemetry "agent-operations.jsonl") | ForEach-Object { $_ | ConvertFrom-Json })) {
        $propertyNames = @(Get-AllPropertyNames -Value $record)
        Assert-True -Condition (@($propertyNames | Where-Object { $_ -in @("prompt", "command", "output", "path", "env", "secret", "tool_input", "tool_response") }).Count -eq 0) -Message "telemetry must not expose raw-content properties"
    }

    $output = Join-Path $testRoot "privacy-analyzer"
    $privacyEvidenceMapPath = Join-Path $testRoot "privacy-evidence-map.json"
    [void](Invoke-AnalyzerFixture -Output $output -GoldSet (Join-Path $fixtureRoot "analyzer/gold-set.json") -EvidenceMap $privacyEvidenceMapPath)
    $summaryText = [System.IO.File]::ReadAllText((Join-Path $output "summary.json"))
    $evidenceMapText = [System.IO.File]::ReadAllText($privacyEvidenceMapPath)
    foreach ($forbidden in @("00000000-0000-0000-0000-000000000001", "dotnet test Sample.Tests", "Invalid Context 4", "scripts/fixtures")) {
        Assert-True -Condition ($summaryText -notmatch [regex]::Escape($forbidden)) -Message "summary must not contain raw session evidence"
        Assert-True -Condition ($evidenceMapText -notmatch [regex]::Escape($forbidden)) -Message "persistent evidence map must not contain raw session evidence"
    }
    $privacyEvidenceMap = $evidenceMapText | ConvertFrom-Json -Depth 30
    $allowedEvidenceProperties = @("schemaVersion", "classifierVersion", "samplingAlgorithm", "seedId", "sampleId", "candidateCount", "entries", "sessionHash", "evidenceHash", "category", "predicted", "selectionReason")
    Assert-Equal -Actual @(Get-AllPropertyNames -Value $privacyEvidenceMap | Where-Object { $_ -notin $allowedEvidenceProperties }).Count -Expected 0 -Message "persistent evidence map should use only privacy-reviewed fields"

    $preflightPass = Invoke-JsonProcess -ScriptPath $preflightScript -Arguments @("-RequiredCommand", "pwsh", "-OptionalCommand", "fixture-command-that-does-not-exist", "-RequiredPath", $repositoryRoot, "-OutputFormat", "Json")
    Assert-Equal -Actual $preflightPass.ExitCode -Expected 0 -Message "read-only preflight should allow missing optional command"
    Assert-Equal -Actual $preflightPass.Json.ok -Expected $true -Message "preflight JSON result"
    $preflightArrayRaw = @(& $preflightScript -RequiredCommand @("git", "pwsh") -OptionalCommand @("fixture-command-that-does-not-exist", "rg") -RequiredPath @($repositoryRoot) -OutputFormat Json) -join "`n"
    $preflightArray = $preflightArrayRaw | ConvertFrom-Json -Depth 10
    Assert-Equal -Actual @($preflightArray.checks | Where-Object { $_.kind -eq "command" -and $_.required }).Count -Expected 2 -Message "documented PowerShell array syntax should preserve every required command"
    Assert-Equal -Actual @($preflightArray.checks | Where-Object { $_.kind -eq "command" -and -not $_.required }).Count -Expected 2 -Message "documented PowerShell array syntax should preserve every optional command"
    $preflightFail = Invoke-JsonProcess -ScriptPath $preflightScript -Arguments @("-RequiredCommand", "fixture-command-that-does-not-exist", "-OutputFormat", "Json")
    Assert-Equal -Actual $preflightFail.ExitCode -Expected 1 -Message "missing required command should fail preflight"
}

function Remove-TestRoot {
    $resolved = [System.IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove test root outside the system temp directory."
    }
    if (Test-Path -LiteralPath $resolved -PathType Container) {
        foreach ($child in @(Get-ChildItem -LiteralPath $resolved -Force)) {
            if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                if ($child.PSIsContainer) { [System.IO.Directory]::Delete($child.FullName, $false) }
                else { [System.IO.File]::Delete($child.FullName) }
            }
        }
        [System.IO.Directory]::Delete($resolved, $true)
    }
}

try {
    if ($Area -in @("All", "Hooks")) { Test-Hooks }
    if ($Area -in @("All", "Installer")) { Test-Installer }
    if ($Area -in @("All", "Analyzer")) { Test-Analyzer }
    if ($Area -in @("All", "Privacy")) { Test-Privacy }
}
catch {
    $script:Failed = $true
    Write-Host ("FAIL: unexpected test exception: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}
finally {
    try { Remove-TestRoot } catch { Write-Host ("WARN: test cleanup failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
}

if ($script:Failed) {
    exit 1
}

Write-Host ("PASS: agent operations contracts ({0} assertions)" -f $script:Passed) -ForegroundColor Green
exit 0
