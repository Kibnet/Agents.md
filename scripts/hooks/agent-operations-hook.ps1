[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$TelemetryRoot,
    [string]$InstallManifestPath,
    [switch]$NoTelemetry,
    [switch]$SimulateRotationFailureAfterArchiveReplace,
    [switch]$SimulateRotationRollbackFailure,
    [switch]$SimulateRecoveryMarkerDriftBeforeQuarantine,
    [switch]$SimulateRecoveryQuarantineVerificationFailure,
    [switch]$SimulateRecoveryCleanupFailureAfterFirstDelete
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ClassifierVersion = "3.1.0"
$script:MaxLogBytes = 10MB
$script:MaxLogFiles = 3
$script:MaxLogAgeDays = 45
$script:RecoveryAgeDays = 7

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
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-Sha256File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
    }
    finally {
        $stream.Dispose()
    }
}

function Get-TelemetryManifest {
    if ($NoTelemetry -or [string]::IsNullOrWhiteSpace($InstallManifestPath) -or
        -not (Test-Path -LiteralPath $InstallManifestPath -PathType Leaf)) {
        return $null
    }

    try {
        $manifest = [System.IO.File]::ReadAllText($InstallManifestPath) | ConvertFrom-Json -Depth 20
        $salt = [string](Get-PropertyValue -Object $manifest -Names @("telemetrySalt"))
        $challenge = [string](Get-PropertyValue -Object $manifest -Names @("activationChallenge"))
        $runtimeChecksums = Get-PropertyValue -Object $manifest -Names @("runtimeChecksums")
        $expectedHookHash = [string](Get-PropertyValue -Object $runtimeChecksums -Names @("hook"))
        if ((Get-PropertyValue -Object $manifest -Names @("schemaVersion")) -eq 1 -and
            [string](Get-PropertyValue -Object $manifest -Names @("owner")) -eq "agent-operations" -and
            [string](Get-PropertyValue -Object $manifest -Names @("runtimeVersion")) -eq $script:ClassifierVersion -and
            $expectedHookHash -match '^[0-9a-f]{64}$' -and
            (Get-Sha256File -Path $PSCommandPath) -eq $expectedHookHash -and
            $salt -match '^[0-9a-f]{64}$' -and
            $challenge -match '^(?:[0-9a-f]{32}|[0-9a-f]{64})$') {
            return [pscustomobject]@{
                Salt = $salt
                ActivationChallenge = $challenge
            }
        }
    }
    catch {
        # Missing or malformed privacy state disables telemetry without affecting the hook.
    }
    return $null
}

function Get-TelemetryContext {
    param([object]$Payload)

    if ($NoTelemetry -or [string]::IsNullOrWhiteSpace($TelemetryRoot)) {
        return $null
    }
    $telemetryManifest = Get-TelemetryManifest
    if ($null -eq $telemetryManifest) {
        return $null
    }
    $salt = $telemetryManifest.Salt

    $repoValue = [string](Get-PropertyValue -Object $Payload -Names @("cwd", "working_directory", "workingDirectory"))
    if ([string]::IsNullOrWhiteSpace($repoValue)) {
        $repoValue = "unknown"
    }
    else {
        try { $repoValue = [System.IO.Path]::GetFullPath($repoValue) } catch { }
        $repoValue = $repoValue.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ).ToLowerInvariant()
    }

    $sessionValue = [string](Get-PropertyValue -Object $Payload -Names @("session_id", "sessionId"))
    return [pscustomobject]@{
        Salt = $salt
        ActivationChallenge = $telemetryManifest.ActivationChallenge
        ActivationHash = Get-Sha256 -Text ("$salt|activation|$($telemetryManifest.ActivationChallenge)")
        RepoHash = Get-Sha256 -Text ("$salt|repo|$repoValue")
        SessionHash = if ([string]::IsNullOrWhiteSpace($sessionValue)) { $null } else { Get-Sha256 -Text ("$salt|session|$sessionValue") }
    }
}

function Enter-TelemetryMutex {
    param([string]$Root)

    try {
        if (Test-IsReparsePoint -Path $Root) { return $null }
        $lockPath = Join-Path $Root ".agent-operations.lock"
        if (Test-IsReparsePoint -Path $lockPath) { return $null }
        $deadline = [DateTime]::UtcNow.AddMilliseconds(1500)
        do {
            try {
                return [System.IO.File]::Open(
                    $lockPath,
                    [System.IO.FileMode]::OpenOrCreate,
                    [System.IO.FileAccess]::ReadWrite,
                    [System.IO.FileShare]::None
                )
            }
            catch [System.IO.IOException] {
                Start-Sleep -Milliseconds 25
            }
        } while ([DateTime]::UtcNow -lt $deadline)
    }
    catch {
        # Lock acquisition is best-effort; callers skip telemetry when it fails.
    }
    return $null
}

function Exit-TelemetryMutex {
    param([object]$Mutex)

    if ($null -eq $Mutex) { return }
    try { $Mutex.Dispose() } catch { }
}

function Write-TextAtomic {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    $temporary = Join-Path $directory (".{0}.{1}.tmp" -f ([System.IO.Path]::GetFileName($Path)), [guid]::NewGuid().ToString("N"))
    try {
        [System.IO.File]::WriteAllText($temporary, $Content, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
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

function Test-IsReparsePoint {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return ((Get-Item -LiteralPath $Path -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

function Write-RotationRecoveryMarker {
    param(
        [string]$Root,
        [string[]]$RecoveryPaths
    )

    $files = [System.Collections.Generic.List[object]]::new()
    foreach ($recoveryPath in $RecoveryPaths) {
        if ((Test-Path -LiteralPath $recoveryPath -PathType Leaf) -and
            (Test-PathWithinRoot -Path $recoveryPath -Root $Root) -and
            -not (Test-IsReparsePoint -Path $recoveryPath)) {
            $files.Add([ordered]@{
                name = [System.IO.Path]::GetFileName($recoveryPath)
                sha256 = Get-Sha256File -Path $recoveryPath
            })
        }
    }
    if ($files.Count -eq 0) { return }

    $markerPath = Join-Path $Root ("agent-operations-recovery-{0}.json" -f [guid]::NewGuid().ToString("N"))
    $marker = [ordered]@{
        schemaVersion = 1
        owner = "agent-operations"
        createdAtUtc = [DateTime]::UtcNow.ToString("o")
        files = @($files)
    }
    Write-TextAtomic -Path $markerPath -Content (($marker | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
}

function Invoke-RecoveryMaintenance {
    param([string]$Root)

    $cutoff = [DateTimeOffset]::UtcNow.AddDays(-$script:RecoveryAgeDays)
    foreach ($markerFile in @(Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^agent-operations-recovery-[0-9a-f]{32}\.json$'
    })) {
        $quarantinedFiles = [System.Collections.Generic.List[object]]::new()
        $quarantinedMarker = $null
        $cleanupCommitted = $false
        try {
            if ((Test-IsReparsePoint -Path $markerFile.FullName) -or
                -not (Test-PathWithinRoot -Path $markerFile.FullName -Root $Root)) {
                continue
            }
            $markerHash = Get-Sha256File -Path $markerFile.FullName
            $markerText = [System.IO.File]::ReadAllText($markerFile.FullName)
            if ((Get-Sha256File -Path $markerFile.FullName) -ne $markerHash) { continue }
            $marker = $markerText | ConvertFrom-Json -Depth 10
            $createdAt = [DateTimeOffset]::Parse(
                [string](Get-PropertyValue -Object $marker -Names @("createdAtUtc")),
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal
            ).ToUniversalTime()
            $fileEntries = @(Get-PropertyValue -Object $marker -Names @("files"))
            if ((Get-PropertyValue -Object $marker -Names @("schemaVersion")) -ne 1 -or
                [string](Get-PropertyValue -Object $marker -Names @("owner")) -ne "agent-operations" -or
                $createdAt -ge $cutoff -or $fileEntries.Count -lt 1 -or $fileEntries.Count -gt 3) {
                continue
            }

            $verifiedPaths = [System.Collections.Generic.List[object]]::new()
            $roles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $verified = $true
            foreach ($entry in $fileEntries) {
                $name = [string](Get-PropertyValue -Object $entry -Names @("name"))
                $expectedHash = [string](Get-PropertyValue -Object $entry -Names @("sha256"))
                $nameMatch = [regex]::Match($name, '^\.agent-operations\.rollback-(active|one|two)\.[0-9a-f]{32}\.tmp$')
                if (-not $nameMatch.Success -or
                    $expectedHash -notmatch '^[0-9a-f]{64}$') {
                    $verified = $false
                    break
                }
                if (-not $roles.Add($nameMatch.Groups[1].Value)) {
                    $verified = $false
                    break
                }
                $candidatePath = Join-Path $Root $name
                if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf) -or
                    -not (Test-PathWithinRoot -Path $candidatePath -Root $Root) -or
                    (Test-IsReparsePoint -Path $candidatePath) -or
                    (Get-Sha256File -Path $candidatePath) -ne $expectedHash) {
                    $verified = $false
                    break
                }
                $verifiedPaths.Add([pscustomobject]@{ Path = $candidatePath; Hash = $expectedHash })
            }
            if (-not $verified -or -not $roles.Contains("active")) { continue }
            if ($SimulateRecoveryMarkerDriftBeforeQuarantine) {
                [System.IO.File]::AppendAllText($markerFile.FullName, " ", [System.Text.UTF8Encoding]::new($false))
            }
            if ((Test-IsReparsePoint -Path $markerFile.FullName) -or (Get-Sha256File -Path $markerFile.FullName) -ne $markerHash) {
                continue
            }

            foreach ($verifiedPath in $verifiedPaths) {
                if (-not (Test-Path -LiteralPath $verifiedPath.Path -PathType Leaf) -or
                    (Test-IsReparsePoint -Path $verifiedPath.Path) -or
                    (Get-Sha256File -Path $verifiedPath.Path) -ne $verifiedPath.Hash) {
                    throw "Recovery copy changed before quarantine."
                }
                $quarantinePath = Join-Path $Root (".agent-operations.recovery-delete.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
                [System.IO.File]::Move($verifiedPath.Path, $quarantinePath, $false)
                $quarantinedFiles.Add([pscustomobject]@{ Original = $verifiedPath.Path; Quarantine = $quarantinePath })
                if ($SimulateRecoveryQuarantineVerificationFailure -and $quarantinedFiles.Count -eq 1) {
                    throw "Simulated recovery quarantine verification failure."
                }
                if ((Test-IsReparsePoint -Path $quarantinePath) -or (Get-Sha256File -Path $quarantinePath) -ne $verifiedPath.Hash) {
                    throw "Recovery copy changed during quarantine."
                }
            }
            $markerQuarantinePath = Join-Path $Root (".agent-operations.recovery-marker-delete.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
            [System.IO.File]::Move($markerFile.FullName, $markerQuarantinePath, $false)
            $quarantinedMarker = [pscustomobject]@{ Original = $markerFile.FullName; Quarantine = $markerQuarantinePath }
            if ((Test-IsReparsePoint -Path $markerQuarantinePath) -or (Get-Sha256File -Path $markerQuarantinePath) -ne $markerHash) {
                throw "Recovery marker changed during quarantine."
            }
            $cleanupCommitted = $true

            $deletedCount = 0
            foreach ($quarantinedFile in $quarantinedFiles) {
                Remove-Item -LiteralPath $quarantinedFile.Quarantine -Force
                $deletedCount++
                if ($SimulateRecoveryCleanupFailureAfterFirstDelete -and $deletedCount -eq 1) {
                    throw "Simulated recovery cleanup failure after first delete."
                }
            }
            Remove-Item -LiteralPath $quarantinedMarker.Quarantine -Force
        }
        catch {
            if (-not $cleanupCommitted) {
                if ($null -ne $quarantinedMarker -and
                    (Test-Path -LiteralPath $quarantinedMarker.Quarantine -PathType Leaf) -and
                    -not (Test-Path -LiteralPath $quarantinedMarker.Original)) {
                    [System.IO.File]::Move($quarantinedMarker.Quarantine, $quarantinedMarker.Original, $false)
                }
                foreach ($quarantinedFile in @($quarantinedFiles)) {
                    if ((Test-Path -LiteralPath $quarantinedFile.Quarantine -PathType Leaf) -and
                        -not (Test-Path -LiteralPath $quarantinedFile.Original)) {
                        [System.IO.File]::Move($quarantinedFile.Quarantine, $quarantinedFile.Original, $false)
                    }
                }
            }
            # Before commit, state is restored. After commit, remaining quarantine files stay discoverable.
        }
    }
}

function Invoke-LogMaintenance {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        [void](New-Item -ItemType Directory -Path $Root -Force)
    }
    if (Test-IsReparsePoint -Path $Root) {
        throw "Refusing telemetry maintenance through a reparse-point root."
    }

    Invoke-RecoveryMaintenance -Root $Root

    $cutoff = [DateTime]::UtcNow.AddDays(-$script:MaxLogAgeDays)
    Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^agent-operations(?:\.[12])?\.jsonl$' } |
        Where-Object { $_.LastWriteTimeUtc -lt $cutoff } |
        ForEach-Object {
            if ((Test-PathWithinRoot -Path $_.FullName -Root $Root) -and -not (Test-IsReparsePoint -Path $_.FullName)) {
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }

    $activePath = Join-Path $Root "agent-operations.jsonl"
    if ((Test-Path -LiteralPath $activePath) -and (Get-Item -LiteralPath $activePath).Length -ge $script:MaxLogBytes) {
        $onePath = Join-Path $Root "agent-operations.1.jsonl"
        $twoPath = Join-Path $Root "agent-operations.2.jsonl"
        foreach ($ownedPath in @($activePath, $onePath, $twoPath)) {
            if (Test-IsReparsePoint -Path $ownedPath) {
                throw "Refusing telemetry rotation through a reparse point."
            }
        }
        $oneExisted = Test-Path -LiteralPath $onePath -PathType Leaf
        $twoExisted = Test-Path -LiteralPath $twoPath -PathType Leaf
        $stagingPaths = [System.Collections.Generic.List[string]]::new()
        $recoveryPaths = [System.Collections.Generic.List[string]]::new()
        $preserveRecovery = $false
        $newOne = Join-Path $Root (".agent-operations.new-one.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
        $rollbackActive = Join-Path $Root (".agent-operations.rollback-active.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
        $stagingPaths.Add($newOne)
        $recoveryPaths.Add($rollbackActive)
        $newTwo = $null
        $rollbackOne = $null
        $rollbackTwo = $null
        try {
            [System.IO.File]::Copy($activePath, $newOne, $false)
            [System.IO.File]::Copy($activePath, $rollbackActive, $false)
            if ($oneExisted) {
                $newTwo = Join-Path $Root (".agent-operations.new-two.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
                $rollbackOne = Join-Path $Root (".agent-operations.rollback-one.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
                $stagingPaths.Add($newTwo)
                $recoveryPaths.Add($rollbackOne)
                [System.IO.File]::Copy($onePath, $newTwo, $false)
                [System.IO.File]::Copy($onePath, $rollbackOne, $false)
            }
            if ($twoExisted) {
                $rollbackTwo = Join-Path $Root (".agent-operations.rollback-two.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
                $recoveryPaths.Add($rollbackTwo)
                [System.IO.File]::Copy($twoPath, $rollbackTwo, $false)
            }

            if ($oneExisted) {
                [System.IO.File]::Move($newTwo, $twoPath, $true)
            }
            [System.IO.File]::Move($newOne, $onePath, $true)
            if ($SimulateRotationFailureAfterArchiveReplace) {
                throw "Simulated rotation failure after archive replacement."
            }
            if (-not $oneExisted -and $twoExisted) {
                [System.IO.File]::Delete($twoPath)
            }
            [System.IO.File]::WriteAllText($activePath, "", [System.Text.UTF8Encoding]::new($false))
        }
        catch {
            try {
                if ($SimulateRotationRollbackFailure) {
                    throw "Simulated rotation rollback failure."
                }
                [System.IO.File]::Copy($rollbackActive, $activePath, $true)
                if ($oneExisted) {
                    [System.IO.File]::Copy($rollbackOne, $onePath, $true)
                }
                elseif (Test-Path -LiteralPath $onePath) {
                    [System.IO.File]::Delete($onePath)
                }
                if ($twoExisted) {
                    [System.IO.File]::Copy($rollbackTwo, $twoPath, $true)
                }
                elseif (Test-Path -LiteralPath $twoPath) {
                    [System.IO.File]::Delete($twoPath)
                }
            }
            catch {
                $preserveRecovery = $true
                try {
                    Write-RotationRecoveryMarker -Root $Root -RecoveryPaths @($recoveryPaths)
                }
                catch {
                    # Raw recovery copies remain available even if marker publication fails.
                }
            }
            throw
        }
        finally {
            foreach ($temporaryPath in $stagingPaths) {
                if (Test-Path -LiteralPath $temporaryPath) {
                    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
                }
            }
            if (-not $preserveRecovery) {
                foreach ($recoveryPath in $recoveryPaths) {
                    if (Test-Path -LiteralPath $recoveryPath) {
                        Remove-Item -LiteralPath $recoveryPath -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
}

function Write-TelemetryEvent {
    param(
        [string]$Root,
        [object]$Context,
        [string]$EventName,
        [string]$Category,
        [string]$Severity,
        [string]$Action,
        [string]$ExitClass
    )

    if ($NoTelemetry -or [string]::IsNullOrWhiteSpace($Root) -or $null -eq $Context) {
        return
    }

    $mutex = $null
    try {
        if (-not (Test-Path -LiteralPath $Root)) {
            [void](New-Item -ItemType Directory -Path $Root -Force)
        }
        $mutex = Enter-TelemetryMutex -Root $Root
        if ($null -eq $mutex) { return }
        Invoke-LogMaintenance -Root $Root
        $record = [ordered]@{
            schemaVersion = 1
            timestamp = [DateTime]::UtcNow.ToString("o")
            runtimeVersion = $script:ClassifierVersion
            eventName = $EventName
            category = $Category
            severity = $Severity
            action = $Action
            exitClass = $ExitClass
            repoHash = $Context.RepoHash
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$Context.SessionHash)) {
            $record.sessionHash = $Context.SessionHash
        }
        $recordJson = $record | ConvertTo-Json -Compress
        [System.IO.File]::AppendAllText(
            (Join-Path $Root "agent-operations.jsonl"),
            $recordJson + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    catch {
        # Telemetry is best-effort and must never affect the tool call.
    }
    finally {
        Exit-TelemetryMutex -Mutex $mutex
    }
}

function Test-AndRecordDuplicateWarning {
    param(
        [string]$Root,
        [object]$Context,
        [object]$Payload,
        [string]$EventName,
        [string]$Category
    )

    if ($NoTelemetry -or [string]::IsNullOrWhiteSpace($Root) -or $null -eq $Context) {
        return $false
    }
    $turnId = [string](Get-PropertyValue -Object $Payload -Names @("turn_id", "turnId"))
    if ([string]::IsNullOrWhiteSpace($turnId)) {
        return $false
    }

    $mutex = $null
    try {
        if (-not (Test-Path -LiteralPath $Root)) {
            [void](New-Item -ItemType Directory -Path $Root -Force)
        }
        $mutex = Enter-TelemetryMutex -Root $Root
        if ($null -eq $mutex) { return $false }
        $statePath = Join-Path $Root ".agent-operations-warning-state.json"
        $entries = [System.Collections.Generic.List[object]]::new()
        if (Test-Path -LiteralPath $statePath -PathType Leaf) {
            try {
                $state = (Get-Content -LiteralPath $statePath -Raw) | ConvertFrom-Json -Depth 5
                foreach ($entry in @($state.entries)) {
                    $timestampValue = $entry.timestampUtc
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
                    if ($hasTimestamp -and $timestamp -ge [DateTimeOffset]::UtcNow.AddDays(-1)) {
                        $entries.Add($entry)
                    }
                }
            }
            catch {
                $entries.Clear()
            }
        }

        $key = Get-Sha256 -Text ("$($Context.Salt)|warning|$turnId|$EventName|$Category")
        $duplicate = @($entries | Where-Object { $_.key -eq $key }).Count -gt 0
        if (-not $duplicate) {
            $entries.Add([pscustomobject]@{ key = $key; timestampUtc = [DateTimeOffset]::UtcNow.ToString("o") })
        }
        while ($entries.Count -gt 128) {
            $entries.RemoveAt(0)
        }

        $stateJson = [ordered]@{ schemaVersion = 1; entries = @($entries) } | ConvertTo-Json -Depth 5
        Write-TextAtomic -Path $statePath -Content ($stateJson + [Environment]::NewLine)
        return $duplicate
    }
    catch {
        return $false
    }
    finally {
        Exit-TelemetryMutex -Mutex $mutex
    }
}

function Get-ExitClass {
    param(
        [string]$Category,
        [string]$Outcome
    )

    if ($Category -eq "timeout") { return "timeout" }
    switch ($Outcome) {
        "success" { return "success" }
        "expected-no-match" { return "expected-no-match" }
        "real-failure" { return "failure" }
        "environment-blocker" { return "failure" }
        "fail-open" { return "fail-open" }
        default { return "unknown" }
    }
}

function Get-CommandText {
    param([object]$Payload)

    $toolInput = Get-PropertyValue -Object $Payload -Names @("tool_input", "toolInput")
    if ($toolInput -is [string]) {
        return $toolInput
    }

    $command = Get-PropertyValue -Object $toolInput -Names @("command", "cmd", "script")
    if ($command -is [System.Collections.IEnumerable] -and $command -isnot [string]) {
        return (@($command) -join " ")
    }
    if ($command -is [string]) {
        return $command
    }

    return $null
}

function Get-CommandAsts {
    param([string]$Command)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Command,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if (@($parseErrors).Count -gt 0) {
        return @()
    }

    return @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true))
}

function Get-ElementText {
    param([System.Management.Automation.Language.CommandElementAst]$Element)

    if ($Element -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return $Element.Value
    }
    return $Element.Extent.Text.Trim('"', "'")
}

function Test-LiteralPathWildcard {
    param([System.Management.Automation.Language.CommandAst[]]$CommandAsts)

    foreach ($commandAst in $CommandAsts) {
        $elements = @($commandAst.CommandElements)
        for ($index = 0; $index -lt ($elements.Count - 1); $index++) {
            $current = Get-ElementText -Element $elements[$index]
            if ($current -ieq "-LiteralPath") {
                $next = Get-ElementText -Element $elements[$index + 1]
                if ($next -match '[*?\[]') {
                    return $true
                }
            }
        }
    }

    return $false
}

function Test-RgRawPathGlob {
    param([System.Management.Automation.Language.CommandAst[]]$CommandAsts)

    $optionsWithValues = @(
        "-e", "--regexp", "-f", "--file", "-g", "--glob", "-t", "--type",
        "-T", "--type-not", "-A", "--after-context", "-B", "--before-context",
        "-C", "--context", "--encoding", "--engine", "--max-count", "--max-depth",
        "--path-separator", "--replace", "--sort", "--sortr"
    )

    foreach ($commandAst in $CommandAsts) {
        $elements = @($commandAst.CommandElements)
        if ($elements.Count -lt 2) {
            continue
        }

        $commandName = [System.IO.Path]::GetFileNameWithoutExtension((Get-ElementText -Element $elements[0]))
        if ($commandName -ine "rg") {
            continue
        }

        $positionals = [System.Collections.Generic.List[string]]::new()
        $patternProvidedByOption = $false
        for ($index = 1; $index -lt $elements.Count; $index++) {
            $value = Get-ElementText -Element $elements[$index]
            if ($value -in @("-e", "--regexp", "-f", "--file")) {
                $patternProvidedByOption = $true
            }

            if ($value -in $optionsWithValues) {
                $index++
                continue
            }
            if ($value.StartsWith("-")) {
                continue
            }
            $positionals.Add($value)
        }

        $pathStart = if ($patternProvidedByOption) { 0 } else { 1 }
        for ($index = $pathStart; $index -lt $positionals.Count; $index++) {
            $candidate = $positionals[$index]
            $looksLikePath = $candidate -match '[\\/]' -or $candidate -match '^\.[\\/]' -or $candidate -match '\.[A-Za-z0-9]{1,8}$'
            if ($looksLikePath -and $candidate -match '[*?\[]') {
                return $true
            }
        }
    }

    return $false
}

function Test-BashHeredocOnWindows {
    param([string]$Command)

    if (-not $IsWindows) {
        return $false
    }

    return $Command -match '(?im)^\s*(?:python(?:\d+(?:\.\d+)?)?|node|pwsh|powershell)\b[^\r\n]*<<\s*["'']?[A-Za-z_][A-Za-z0-9_]*'
}

function Test-TUnitFilter {
    param(
        [string]$Command,
        [object]$Payload,
        [System.Management.Automation.Language.CommandAst[]]$CommandAsts
    )

    $hasFilter = $false
    $isDotnetTest = $false
    foreach ($commandAst in $CommandAsts) {
        $elements = @($commandAst.CommandElements | ForEach-Object { Get-ElementText -Element $_ })
        if ($elements.Count -lt 2) {
            continue
        }
        if (([System.IO.Path]::GetFileNameWithoutExtension($elements[0]) -ieq "dotnet") -and ($elements[1] -in @("test", "run"))) {
            $isDotnetTest = $true
            $hasFilter = @($elements | Where-Object { $_ -eq "--filter" -or $_ -like "--filter=*" }).Count -gt 0
        }
    }

    if (-not ($isDotnetTest -and $hasFilter)) {
        return $false
    }

    $cwd = Get-PropertyValue -Object $Payload -Names @("cwd", "working_directory", "workingDirectory")
    if ([string]::IsNullOrWhiteSpace([string]$cwd) -or -not (Test-Path -LiteralPath $cwd -PathType Container)) {
        return $false
    }

    try {
        $projectFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        Get-ChildItem -LiteralPath $cwd -File -Filter "*.csproj" -ErrorAction Stop |
            Select-Object -First 16 |
            ForEach-Object { $projectFiles.Add($_) }
        Get-ChildItem -LiteralPath $cwd -Directory -ErrorAction Stop |
            Select-Object -First 16 |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -File -Filter "*.csproj" -ErrorAction SilentlyContinue |
                    Select-Object -First 2 |
                    ForEach-Object { $projectFiles.Add($_) }
            }

        foreach ($projectFile in @($projectFiles | Select-Object -First 32)) {
            $content = Get-Content -LiteralPath $projectFile.FullName -Raw -ErrorAction Stop
            if ($content -match '(?i)(?:PackageReference|ProjectReference)[^>]*(?:Include|Update)\s*=\s*["'']TUnit(?:\.|["''])') {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

function Get-ResponseShape {
    param([object]$Payload)

    $response = Get-PropertyValue -Object $Payload -Names @("tool_response", "toolResponse")
    if ($null -eq $response -or $response -is [string]) {
        return $null
    }

    $exitCodeValue = Get-PropertyValue -Object $response -Names @("exit_code", "exitCode")
    $timedOutValue = Get-PropertyValue -Object $response -Names @("timed_out", "timedOut")
    if ($null -eq $exitCodeValue -and $null -eq $timedOutValue) {
        return $null
    }

    $exitCode = $null
    if ($null -ne $exitCodeValue) {
        $parsedExitCode = 0
        if (-not [int]::TryParse([string]$exitCodeValue, [ref]$parsedExitCode)) {
            return $null
        }
        $exitCode = $parsedExitCode
    }

    $timedOut = $false
    if ($null -ne $timedOutValue) {
        if ($timedOutValue -is [bool]) {
            $timedOut = $timedOutValue
        }
        else {
            $parsedTimedOut = $false
            if (-not [bool]::TryParse([string]$timedOutValue, [ref]$parsedTimedOut)) {
                return $null
            }
            $timedOut = $parsedTimedOut
        }
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        TimedOut = $timedOut
        StdErr = [string](Get-PropertyValue -Object $response -Names @("stderr", "error", "error_message", "errorMessage"))
        Summary = [string](Get-PropertyValue -Object $response -Names @("summary", "message", "status"))
    }
}

function Get-PostClassification {
    param(
        [object]$Payload,
        [string]$ToolName,
        [string]$Command
    )

    $shape = Get-ResponseShape -Payload $Payload
    if ($null -eq $shape) {
        return [pscustomobject]@{ Category = "unclassified"; Outcome = "unknown-shape"; Context = $null }
    }

    $signal = ($shape.StdErr + "`n" + $shape.Summary).Trim()
    if ($shape.TimedOut) {
        return [pscustomobject]@{
            Category = "timeout"
            Outcome = "environment-blocker"
            Context = "The tool timed out. Do not repeat the identical invocation; inspect progress or logs and form a new bounded hypothesis."
        }
    }

    $confirmedFailure = $null -ne $shape.ExitCode -and $shape.ExitCode -ne 0
    if ($confirmedFailure -and $signal -match '(?i)(index\.lock|being used by another process|another git process|cannot access.+used by another process|permission denied|access.+denied|unauthori[sz]ed|authentication|\b401\b|\b403\b|NU1301|unable to load the service index|SSL|certificate)') {
        return [pscustomobject]@{
            Category = if ($signal -match '(?i)(index\.lock|being used by another process|another git process|cannot access.+used by another process)') { "lock" } else { "auth-restore-permission" }
            Outcome = "environment-blocker"
            Context = "This result is an environment, authentication, permission, restore, or lock blocker. Confirm the external state before changing product code or retrying."
        }
    }

    $commandName = $null
    if (-not [string]::IsNullOrWhiteSpace($Command)) {
        $commandAsts = @(Get-CommandAsts -Command $Command)
        if ($commandAsts.Count -gt 0) {
            $firstElements = @($commandAsts[0].CommandElements)
            if ($firstElements.Count -gt 0) {
                $commandName = [System.IO.Path]::GetFileNameWithoutExtension((Get-ElementText -Element $firstElements[0]))
            }
        }
    }

    if (($commandName -ieq "rg") -and $shape.ExitCode -eq 1 -and [string]::IsNullOrWhiteSpace($shape.StdErr)) {
        return [pscustomobject]@{
            Category = "rg-no-match"
            Outcome = "expected-no-match"
            Context = "ripgrep exit code 1 without stderr means expected no-match, not a tool failure. Narrow or broaden the query only if the missing match changes the hypothesis."
        }
    }

    if (($ToolName -ieq "apply_patch") -and $confirmedFailure -and $signal -match '(?i)(invalid context|context.+not found|patch.+failed|does not apply)') {
        return [pscustomobject]@{
            Category = "stale-patch"
            Outcome = "real-failure"
            Context = "The patch context is stale. Re-read the exact current section, confirm file ownership, and retry with a smaller updated hunk rather than repeating the patch."
        }
    }

    if ($null -eq $shape.ExitCode) {
        return [pscustomobject]@{ Category = "unclassified"; Outcome = "unknown-shape"; Context = $null }
    }

    if ($confirmedFailure) {
        return [pscustomobject]@{
            Category = "tool-failure"
            Outcome = "real-failure"
            Context = $null
        }
    }

    return [pscustomobject]@{ Category = "success"; Outcome = "success"; Context = $null }
}

function New-HookOutput {
    param(
        [string]$EventName,
        [string]$AdditionalContext,
        [string]$SystemMessage
    )

    if ([string]::IsNullOrWhiteSpace($AdditionalContext) -and [string]::IsNullOrWhiteSpace($SystemMessage)) {
        return [ordered]@{}
    }

    $output = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace($AdditionalContext)) {
        $output.hookSpecificOutput = [ordered]@{
            hookEventName = $EventName
            additionalContext = $AdditionalContext
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($SystemMessage)) {
        $output.systemMessage = $SystemMessage
    }
    return $output
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$eventName = "unknown"
$category = "unclassified"
$outcome = "no-warning"
$warning = $false
$telemetryContext = $null

try {
    $rawInput = if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        Get-Content -LiteralPath $InputPath -Raw
    }
    else {
        [Console]::In.ReadToEnd()
    }

    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        throw "Hook input is empty."
    }

    $payload = $rawInput | ConvertFrom-Json -Depth 50
    $telemetryContext = Get-TelemetryContext -Payload $payload
    $eventName = [string](Get-PropertyValue -Object $payload -Names @("hook_event_name", "hookEventName", "event"))
    $toolName = [string](Get-PropertyValue -Object $payload -Names @("tool_name", "toolName"))
    $command = Get-CommandText -Payload $payload
    $additionalContext = $null
    $systemMessage = $null

    if ($eventName -eq "PreToolUse") {
        $commandAsts = if ([string]::IsNullOrWhiteSpace($command)) { @() } else { Get-CommandAsts -Command $command }
        $activationMarker = if ($null -eq $telemetryContext) { $null } else { "CODEX_AGENT_OPERATIONS_PROBE_$($telemetryContext.ActivationChallenge)" }
        if (-not [string]::IsNullOrWhiteSpace($activationMarker) -and
            $command -match ("(?<![A-Za-z0-9_]){0}(?![A-Za-z0-9_])" -f [regex]::Escape($activationMarker))) {
            $category = "activation-probe"
            $telemetryContext.SessionHash = $telemetryContext.ActivationHash
        }
        elseif ((-not [string]::IsNullOrWhiteSpace($command)) -and (Test-BashHeredocOnWindows -Command $command)) {
            $category = "bash-heredoc"
            $additionalContext = "This is a Bash heredoc shape in a Windows PowerShell task. Use a PowerShell here-string or a checked temporary input file."
        }
        elseif (Test-LiteralPathWildcard -CommandAsts $commandAsts) {
            $category = "literal-path-wildcard"
            $additionalContext = "A wildcard was passed to -LiteralPath. Inventory the path first, then use -Path/-Filter intentionally or pass the exact literal path."
        }
        elseif (Test-RgRawPathGlob -CommandAsts $commandAsts) {
            $category = "rg-path-glob"
            $additionalContext = "A Windows wildcard appears in a positional ripgrep path. Use a literal scope plus -g for glob filtering."
        }
        elseif ((-not [string]::IsNullOrWhiteSpace($command)) -and (Test-TUnitFilter -Command $command -Payload $payload -CommandAsts $commandAsts)) {
            $category = "tunit-filter"
            $additionalContext = "TUnit evidence is present, so VSTest --filter is unsafe here. Use the repository's TUnit command with --treenode-filter."
        }

        if (-not [string]::IsNullOrWhiteSpace($additionalContext)) {
            $warning = $true
            $outcome = "warn-only"
            $systemMessage = "Known operational hazard detected; the tool call remains allowed."
        }
    }
    elseif ($eventName -eq "PostToolUse") {
        $classification = Get-PostClassification -Payload $payload -ToolName $toolName -Command $command
        $category = $classification.Category
        $outcome = $classification.Outcome
        $additionalContext = $classification.Context
        $warning = -not [string]::IsNullOrWhiteSpace($additionalContext)
    }

    if ($warning -and (Test-AndRecordDuplicateWarning -Root $TelemetryRoot -Context $telemetryContext -Payload $payload -EventName $eventName -Category $category)) {
        $additionalContext = $null
        $systemMessage = $null
        $warning = $false
        $outcome = "duplicate-suppressed"
    }

    $stopwatch.Stop()
    Write-TelemetryEvent -Root $TelemetryRoot -Context $telemetryContext -EventName $eventName -Category $category `
        -Severity $(if ($warning) { "warning" } else { "info" }) `
        -Action $(if ($warning) { "warn" } else { "observe" }) `
        -ExitClass (Get-ExitClass -Category $category -Outcome $outcome)
    New-HookOutput -EventName $eventName -AdditionalContext $additionalContext -SystemMessage $systemMessage |
        ConvertTo-Json -Depth 10 -Compress
}
catch {
    $stopwatch.Stop()
    if ($null -eq $telemetryContext) {
        $telemetryContext = Get-TelemetryContext -Payload $null
    }
    Write-TelemetryEvent -Root $TelemetryRoot -Context $telemetryContext -EventName $eventName -Category "hook-error" `
        -Severity "warning" -Action "observe" -ExitClass "fail-open"
    New-HookOutput -EventName $eventName -AdditionalContext $null -SystemMessage "Operational hook check was skipped; the tool call remains allowed." |
        ConvertTo-Json -Depth 5 -Compress
}
