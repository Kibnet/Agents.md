[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Prune,
    [switch]$MarkActive,
    [string]$CodexHome = (Join-Path $HOME ".codex"),
    [string]$ApprovedProposalHash,
    [string]$ActivationEvidencePath,
    [switch]$WhatIf,
    [ValidateSet("Json", "Text")]
    [string]$OutputFormat = "Json",
    [switch]$SimulateFailure,
    [ValidateRange(0, 60000)]
    [int]$SimulateActivationDelayMilliseconds = 0,
    [ValidateRange(0, 60000)]
    [int]$SimulateCommitDelayMilliseconds = 0,
    [string]$SimulationCommitReadyPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RuntimeVersion = "3.1.0"
$script:MaxBackups = 10
$script:BackupAgeDays = 90
$script:MaxRuntimeVersions = 3

function Get-Sha256Text {
    param([AllowNull()]$Text)

    if ($null -eq $Text) {
        return $null
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
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

function Get-Sha256Bytes {
    param([byte[]]$Bytes)

    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function New-RandomSalt {
    $bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
    return [Convert]::ToHexString($bytes).ToLowerInvariant()
}

function Get-CanonicalDirectoryIdentity {
    param([string]$Path)

    $requestedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $existingPath = $requestedPath
    $unresolvedSegments = [System.Collections.Generic.List[string]]::new()
    while (-not (Test-Path -LiteralPath $existingPath -PathType Container)) {
        $leaf = [System.IO.Path]::GetFileName($existingPath)
        $parent = [System.IO.Path]::GetDirectoryName($existingPath)
        if ([string]::IsNullOrWhiteSpace($leaf) -or [string]::IsNullOrWhiteSpace($parent) -or $parent -eq $existingPath) {
            return Get-Sha256Text -Text ("directory|$($requestedPath.ToLowerInvariant())")
        }
        $unresolvedSegments.Insert(0, $leaf)
        $existingPath = $parent
    }

    if ($IsWindows -and $null -eq ("AgentOperations.NativeDirectoryIdentity" -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace AgentOperations {
    public static class NativeDirectoryIdentity {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(
            string fileName,
            uint desiredAccess,
            FileShare shareMode,
            IntPtr securityAttributes,
            FileMode creationDisposition,
            uint flagsAndAttributes,
            IntPtr templateFile);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(
            SafeFileHandle file,
            StringBuilder path,
            uint pathLength,
            uint flags);

        public static string GetFinalPath(string path) {
            const uint FileFlagBackupSemantics = 0x02000000;
            using (SafeFileHandle handle = CreateFileW(
                path,
                0,
                FileShare.ReadWrite | FileShare.Delete,
                IntPtr.Zero,
                FileMode.Open,
                FileFlagBackupSemantics,
                IntPtr.Zero)) {
                if (handle.IsInvalid) {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                StringBuilder buffer = new StringBuilder(1024);
                uint length = GetFinalPathNameByHandleW(handle, buffer, (uint)buffer.Capacity, 0);
                if (length == 0) {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                if (length >= buffer.Capacity) {
                    buffer = new StringBuilder((int)length + 1);
                    length = GetFinalPathNameByHandleW(handle, buffer, (uint)buffer.Capacity, 0);
                    if (length == 0) {
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }
                }
                string result = buffer.ToString();
                if (result.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) {
                    return @"\\" + result.Substring(8);
                }
                if (result.StartsWith(@"\\?\", StringComparison.OrdinalIgnoreCase)) {
                    return result.Substring(4);
                }
                return result;
            }
        }
    }
}
'@
    }

    try {
        if ($IsWindows) {
            $existingPath = [AgentOperations.NativeDirectoryIdentity]::GetFinalPath($existingPath)
        }
        else {
            $directoryInfo = Get-Item -LiteralPath $existingPath -Force
            $resolvedTarget = $directoryInfo.ResolveLinkTarget($true)
            if ($null -ne $resolvedTarget) { $existingPath = $resolvedTarget.FullName }
        }
    }
    catch {
        $directoryInfo = Get-Item -LiteralPath $existingPath -Force
        $resolvedTarget = $directoryInfo.ResolveLinkTarget($true)
        if ($null -ne $resolvedTarget) { $existingPath = $resolvedTarget.FullName }
    }
    $identityPath = $existingPath
    foreach ($segment in $unresolvedSegments) {
        $identityPath = Join-Path $identityPath $segment
    }
    $normalized = [System.IO.Path]::GetFullPath($identityPath).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ).ToLowerInvariant()
    return Get-Sha256Text -Text ("directory|$normalized")
}

function Enter-InstallerTransactionMutex {
    param([string]$DirectoryIdentity)

    try {
        $lockPath = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-agent-operations-{0}.lock" -f $DirectoryIdentity)
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
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
                Start-Sleep -Milliseconds 50
            }
        } while ([DateTime]::UtcNow -lt $deadline)
    }
    catch {
        # Apply callers convert lock failures into approval-required without mutation.
    }
    return $null
}

function Exit-InstallerTransactionMutex {
    param([object]$Mutex)

    if ($null -eq $Mutex) { return }
    try { $Mutex.Dispose() } catch { }
}

function Read-TextFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return [System.IO.File]::ReadAllText($Path)
}

function Write-TextAtomic {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }
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

function Write-BytesAtomic {
    param(
        [string]$Path,
        [byte[]]$Bytes
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }
    $temporary = Join-Path $directory (".{0}.{1}.tmp" -f ([System.IO.Path]::GetFileName($Path)), [guid]::NewGuid().ToString("N"))
    try {
        [System.IO.File]::WriteAllBytes($temporary, $Bytes)
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
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

    return @($Paths | Where-Object { -not (Test-ManagedPathWithoutReparseAncestors -CodexHomePath $CodexHomePath -Path $_) }).Count -eq 0
}

function Remove-SafeTree {
    param(
        [string]$Path,
        [string]$Root
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    if (-not (Test-PathWithinRoot -Path $Path -Root $Root)) {
        throw "Refusing recursive delete outside the managed root."
    }
    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing recursive delete through a reparse point."
    }
    Remove-Item -LiteralPath $Path -Recurse -Force
}

function Remove-EmptyManagedDirectory {
    param(
        [string]$Path,
        [string]$Root
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    if (-not (Test-PathWithinRoot -Path $Path -Root $Root)) {
        throw "Refusing to remove an empty directory outside the managed root."
    }
    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to remove an empty reparse-point directory."
    }
    if (@(Get-ChildItem -LiteralPath $Path -Force).Count -eq 0) {
        [System.IO.Directory]::Delete($Path, $false)
    }
}

function ConvertTo-StableJson {
    param([object]$Value)

    return $Value | ConvertTo-Json -Depth 50 -Compress
}

function Get-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
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

function Get-ManifestProperty {
    param(
        [object]$Manifest,
        [string]$Name,
        [string[]]$LegacyNames = @()
    )

    $value = Get-ObjectProperty -Object $Manifest -Name $Name
    if ($null -ne $value) { return $value }
    foreach ($legacyName in $LegacyNames) {
        $value = Get-ObjectProperty -Object $Manifest -Name $legacyName
        if ($null -ne $value) { return $value }
    }
    return $null
}

function Set-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
    else {
        $property.Value = $Value
    }
}

function Get-AgentValues {
    param([AllowNull()][string]$Content)

    $result = [ordered]@{
        max_threads = $null
        max_depth = $null
    }
    if ([string]::IsNullOrWhiteSpace($Content)) {
        return [pscustomobject]$result
    }

    $inAgents = $false
    foreach ($line in ($Content -split "\r?\n")) {
        if ($line -match '^\s*\[([^\]]+)\]\s*(?:#.*)?$') {
            $inAgents = $Matches[1] -eq "agents"
            continue
        }
        if (-not $inAgents) {
            continue
        }
        if ($line -match '^\s*(max_threads|max_depth)\s*=\s*([^#\r\n]+?)\s*(?:#.*)?$') {
            $result[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return [pscustomobject]$result
}

function Set-AgentValues {
    param(
        [AllowNull()][string]$Content,
        [AllowNull()][object]$MaxThreads,
        [AllowNull()][object]$MaxDepth
    )

    $original = if ($null -eq $Content) { "" } else { $Content }
    $newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($original -split "\r?\n")) {
        $lines.Add($line)
    }
    if ($lines.Count -eq 1 -and $lines[0] -eq "") {
        $lines.Clear()
    }

    $start = -1
    $end = $lines.Count
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*\[([^\]]+)\]\s*(?:#.*)?$') {
            if ($Matches[1] -eq "agents") {
                $start = $index
                for ($next = $index + 1; $next -lt $lines.Count; $next++) {
                    if ($lines[$next] -match '^\s*\[[^\]]+\]\s*(?:#.*)?$') {
                        $end = $next
                        break
                    }
                }
                break
            }
        }
    }

    if ($start -lt 0) {
        if ($null -eq $MaxThreads -and $null -eq $MaxDepth) {
            return $original
        }
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne "") {
            $lines.Add("")
        }
        $lines.Add("[agents]")
        if ($null -ne $MaxThreads) { $lines.Add("max_threads = $MaxThreads") }
        if ($null -ne $MaxDepth) { $lines.Add("max_depth = $MaxDepth") }
        return ($lines -join $newline).TrimEnd("`r", "`n") + $newline
    }

    $section = [System.Collections.Generic.List[string]]::new()
    for ($index = $start + 1; $index -lt $end; $index++) {
        $section.Add($lines[$index])
    }

    foreach ($entry in @(
        [pscustomobject]@{ Name = "max_threads"; Value = $MaxThreads },
        [pscustomobject]@{ Name = "max_depth"; Value = $MaxDepth }
    )) {
        $found = -1
        for ($index = 0; $index -lt $section.Count; $index++) {
            if ($section[$index] -match ("^\s*" + [regex]::Escape($entry.Name) + "\s*=")) {
                $found = $index
                break
            }
        }

        if ($null -eq $entry.Value) {
            if ($found -ge 0) {
                $section.RemoveAt($found)
            }
        }
        elseif ($found -ge 0) {
            $comment = ""
            if ($section[$found] -match '(\s+#.*)$') {
                $comment = $Matches[1]
            }
            $indent = ([regex]::Match($section[$found], '^\s*')).Value
            $section[$found] = "${indent}$($entry.Name) = $($entry.Value)$comment"
        }
        else {
            $section.Add("$($entry.Name) = $($entry.Value)")
        }
    }

    $result = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -le $start; $index++) { $result.Add($lines[$index]) }
    foreach ($line in $section) { $result.Add($line) }
    for ($index = $end; $index -lt $lines.Count; $index++) { $result.Add($lines[$index]) }
    return ($result -join $newline).TrimEnd("`r", "`n") + $newline
}

function Test-ConfigHasOnlyEmptyAgents {
    param([AllowNull()][string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $true
    }
    $meaningful = @($Content -split "\r?\n" | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ -ne "" })
    return $meaningful.Count -eq 1 -and $meaningful[0] -eq "[agents]"
}

function Test-UnsupportedAgentConfiguration {
    param([AllowNull()][string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) { return $false }
    if ($Content -match '(?im)^\s*agents\s*=\s*\{' -or
        $Content -match '(?im)^\s*(?:agents|["'']agents["''])\s*\.' -or
        $Content -match '(?im)^\s*\[\[\s*agents\s*\]\]' -or
        $Content -match '(?im)^\s*\[\s*["'']agents["'']\s*\]') {
        return $true
    }
    $semanticHeaders = [regex]::Matches($Content, '(?im)^\s*\[\s*agents\s*\]\s*(?:#.*)?$')
    $headers = [regex]::Matches($Content, '(?im)^\s*\[agents\]\s*(?:#.*)?$')
    if ($semanticHeaders.Count -ne $headers.Count) { return $true }
    if ($headers.Count -gt 1) { return $true }
    if ($headers.Count -eq 0) { return $false }

    $start = $headers[0].Index + $headers[0].Length
    $tail = $Content.Substring($start)
    $nextHeader = [regex]::Match($tail, '(?im)^\s*\[[^\]]+\]\s*(?:#.*)?$')
    $section = if ($nextHeader.Success) { $tail.Substring(0, $nextHeader.Index) } else { $tail }
    if ($section -match '(?im)^\s*["''](?:max_threads|max_depth)["'']\s*=' -or
        $section -match '(?im)^\s*(?:max_threads|max_depth)\s*\.') {
        return $true
    }
    foreach ($name in @("max_threads", "max_depth")) {
        if ([regex]::Matches($section, ("(?im)^\s*" + [regex]::Escape($name) + "\s*=")).Count -gt 1) {
            return $true
        }
    }
    return $false
}

function Test-HooksDocumentEmpty {
    param([AllowNull()][string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $true
    }
    try {
        $root = $Content | ConvertFrom-Json -Depth 50
        $rootProperties = @($root.PSObject.Properties.Name)
        if (@($rootProperties | Where-Object { $_ -ne "hooks" }).Count -gt 0) {
            return $false
        }
        $hooks = Get-ObjectProperty -Object $root -Name "hooks"
        return $null -eq $hooks -or @($hooks.PSObject.Properties).Count -eq 0
    }
    catch {
        return $false
    }
}

function Get-HookFingerprint {
    param([object]$Group)

    return Get-Sha256Text -Text (ConvertTo-StableJson -Value $Group)
}

function Read-JsonObject {
    param(
        [AllowNull()][string]$Content,
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return [pscustomobject]@{}
    }
    try {
        $value = $Content | ConvertFrom-Json -Depth 50
        if ($value -isnot [pscustomobject]) {
            throw "$Description root must be a JSON object."
        }
        return $value
    }
    catch {
        if ($_.Exception.Message -eq "$Description root must be a JSON object.") {
            throw
        }
        throw "$Description is not valid JSON."
    }
}

function Get-HookTemplate {
    param(
        [string]$TemplatePath,
        [string]$Command
    )

    $template = Read-JsonObject -Content (Read-TextFile -Path $TemplatePath) -Description "Hook template"
    $hooks = Get-ObjectProperty -Object $template -Name "hooks"
    foreach ($eventName in @("PreToolUse", "PostToolUse")) {
        foreach ($group in @(Get-ObjectProperty -Object $hooks -Name $eventName)) {
            foreach ($handler in @(Get-ObjectProperty -Object $group -Name "hooks")) {
                Set-ObjectProperty -Object $handler -Name "command" -Value $Command
                Set-ObjectProperty -Object $handler -Name "commandWindows" -Value $Command
            }
        }
    }
    return $template
}

function Merge-HookConfiguration {
    param(
        [AllowNull()][string]$CurrentContent,
        [object]$Template,
        [string[]]$RemoveFingerprints = @(),
        [switch]$RemoveOnly
    )

    $root = Read-JsonObject -Content $CurrentContent -Description "hooks.json"
    $hooks = Get-ObjectProperty -Object $root -Name "hooks"
    if ($null -eq $hooks) {
        $hooks = [pscustomobject]@{}
        Set-ObjectProperty -Object $root -Name "hooks" -Value $hooks
    }
    $templateHooks = Get-ObjectProperty -Object $Template -Name "hooks"
    $installedFingerprints = [ordered]@{}

    foreach ($eventName in @("PreToolUse", "PostToolUse")) {
        $currentGroups = [System.Collections.Generic.List[object]]::new()
        foreach ($group in @(Get-ObjectProperty -Object $hooks -Name $eventName)) {
            if ($null -eq $group) {
                continue
            }
            if ((Get-HookFingerprint -Group $group) -notin $RemoveFingerprints) {
                $currentGroups.Add($group)
            }
        }

        if (-not $RemoveOnly) {
            foreach ($templateGroup in @(Get-ObjectProperty -Object $templateHooks -Name $eventName)) {
                if ($null -eq $templateGroup) {
                    continue
                }
                $fingerprint = Get-HookFingerprint -Group $templateGroup
                if (@($currentGroups | Where-Object { (Get-HookFingerprint -Group $_) -eq $fingerprint }).Count -eq 0) {
                    $currentGroups.Add($templateGroup)
                }
                $installedFingerprints[$eventName] = $fingerprint
            }
        }

        if ($currentGroups.Count -gt 0) {
            Set-ObjectProperty -Object $hooks -Name $eventName -Value @($currentGroups)
        }
        elseif ($null -ne $hooks.PSObject.Properties[$eventName]) {
            $hooks.PSObject.Properties.Remove($eventName)
        }
    }

    $json = $root | ConvertTo-Json -Depth 50
    return [pscustomobject]@{
        Content = $json.TrimEnd() + [Environment]::NewLine
        Fingerprints = [pscustomobject]$installedFingerprints
    }
}

function Get-ManifestFingerprints {
    param([object]$Manifest)

    if ($null -eq $Manifest) {
        return @()
    }
    $fingerprints = Get-ManifestProperty -Manifest $Manifest -Name "installerOwnedHookFingerprints" -LegacyNames @("hookFingerprints")
    if ($null -eq $fingerprints) {
        return @()
    }
    return @($fingerprints.PSObject.Properties | ForEach-Object { [string]$_.Value })
}

function Get-HookGroupInventory {
    param(
        [AllowNull()][string]$Content,
        [string]$ManagedRoot
    )

    if ([string]::IsNullOrWhiteSpace($Content)) { return @() }
    $root = Read-JsonObject -Content $Content -Description "hooks.json"
    $hooks = Get-ObjectProperty -Object $root -Name "hooks"
    if ($null -eq $hooks) { return @() }
    if ($hooks -isnot [pscustomobject]) {
        throw "hooks.json 'hooks' must be a JSON object."
    }

    $inventory = [System.Collections.Generic.List[object]]::new()
    foreach ($eventProperty in @($hooks.PSObject.Properties)) {
        $eventName = $eventProperty.Name
        if ($eventProperty.Value -isnot [System.Array]) {
            throw "hooks.json event '$eventName' must be an array."
        }
        foreach ($group in @($eventProperty.Value)) {
            if ($group -isnot [pscustomobject]) {
                throw "hooks.json event '$eventName' contains a non-object group."
            }
            $handlersProperty = $group.PSObject.Properties["hooks"]
            if ($null -eq $handlersProperty -or $handlersProperty.Value -isnot [System.Array]) {
                throw "hooks.json event '$eventName' group must contain a hooks array."
            }
            $handlers = $handlersProperty.Value
            $referencesManagedRoot = $false
            foreach ($handler in @($handlers)) {
                if ($handler -isnot [pscustomobject]) {
                    throw "hooks.json event '$eventName' contains a non-object handler."
                }
                foreach ($propertyName in @("command", "commandWindows")) {
                    $command = [string](Get-ObjectProperty -Object $handler -Name $propertyName)
                    if (-not [string]::IsNullOrWhiteSpace($command) -and $command.IndexOf($ManagedRoot, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $referencesManagedRoot = $true
                    }
                }
            }
            $inventory.Add([pscustomobject]@{
                EventName = $eventName
                Fingerprint = Get-HookFingerprint -Group $group
                ReferencesManagedRoot = $referencesManagedRoot
            })
        }
    }
    return @($inventory)
}

function New-FileSnapshot {
    param([string[]]$Paths)

    $snapshots = [System.Collections.Generic.List[object]]::new()
    foreach ($path in $Paths | Select-Object -Unique) {
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        $bytes = if ($exists) { [System.IO.File]::ReadAllBytes($path) } else { $null }
        $snapshots.Add([pscustomobject]@{ Path = $path; Exists = $exists; Bytes = $bytes })
    }
    return @($snapshots)
}

function Restore-FileSnapshot {
    param([object[]]$Snapshots)

    foreach ($snapshot in $Snapshots) {
        if ($snapshot.Exists) {
            $directory = Split-Path -Parent $snapshot.Path
            if (-not (Test-Path -LiteralPath $directory)) {
                [void](New-Item -ItemType Directory -Path $directory -Force)
            }
            [System.IO.File]::WriteAllBytes($snapshot.Path, $snapshot.Bytes)
        }
        elseif (Test-Path -LiteralPath $snapshot.Path -PathType Leaf) {
            Remove-Item -LiteralPath $snapshot.Path -Force
        }
    }
}

function Write-Backup {
    param(
        [string]$BackupPath,
        [object[]]$Snapshots,
        [string]$Action
    )

    if (Test-Path -LiteralPath $BackupPath) {
        throw "Backup destination already exists; refusing to overwrite unverified state."
    }

    [void](New-Item -ItemType Directory -Path $BackupPath)
    try {
        $index = 0
        $files = [System.Collections.Generic.List[object]]::new()
        foreach ($snapshot in $Snapshots) {
            if (-not $snapshot.Exists) {
                continue
            }
            $name = "{0:D2}-{1}" -f $index, ([System.IO.Path]::GetFileName($snapshot.Path))
            $backupFile = Join-Path $BackupPath $name
            [System.IO.File]::WriteAllBytes($backupFile, $snapshot.Bytes)
            $files.Add([ordered]@{ source = $snapshot.Path; backup = $name; sha256 = Get-Sha256File -Path $backupFile })
            $index++
        }
        $metadata = [ordered]@{
            schemaVersion = 1
            owner = "agent-operations"
            action = $Action
            createdAtUtc = [DateTime]::UtcNow.ToString("o")
            successful = $false
            files = @($files)
        }
        Write-TextAtomic -Path (Join-Path $BackupPath "backup-manifest.json") -Content (($metadata | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    }
    catch {
        if (Test-Path -LiteralPath $BackupPath -PathType Container) {
            Remove-SafeTree -Path $BackupPath -Root (Split-Path -Parent $BackupPath)
        }
        throw
    }
}

function Complete-Backup {
    param([string]$BackupPath)

    $path = Join-Path $BackupPath "backup-manifest.json"
    $metadata = (Read-TextFile -Path $path) | ConvertFrom-Json -Depth 20
    Set-ObjectProperty -Object $metadata -Name "successful" -Value $true
    Write-TextAtomic -Path $path -Content (($metadata | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
}

function Get-ManagedBackups {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object {
        $directoryPath = $_.FullName
        $manifestPath = Join-Path $directoryPath "backup-manifest.json"
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $false }
        try {
            $metadata = (Read-TextFile -Path $manifestPath) | ConvertFrom-Json -Depth 20
            $successful = Get-ObjectProperty -Object $metadata -Name "successful"
            if ($metadata.owner -ne "agent-operations" -or $successful -isnot [bool] -or -not $successful) { return $false }
            $fileEntries = @((Get-ObjectProperty -Object $metadata -Name "files") | Where-Object { $null -ne $_ })
            $backupNames = @($fileEntries | ForEach-Object { [string](Get-ObjectProperty -Object $_ -Name "backup") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $expectedNames = @("backup-manifest.json") + $backupNames
            $actualNames = @(Get-ChildItem -LiteralPath $directoryPath -Force | ForEach-Object { $_.Name })
            if (@($actualNames | Where-Object { $_ -notin $expectedNames }).Count -gt 0 -or
                @($expectedNames | Where-Object { $_ -notin $actualNames }).Count -gt 0) {
                return $false
            }
            foreach ($entry in $fileEntries) {
                $backupName = [string](Get-ObjectProperty -Object $entry -Name "backup")
                $expectedHash = [string](Get-ObjectProperty -Object $entry -Name "sha256")
                $backupFile = Join-Path $directoryPath $backupName
                if ([string]::IsNullOrWhiteSpace($backupName) -or
                    $backupName -ne [System.IO.Path]::GetFileName($backupName) -or
                    [string]::IsNullOrWhiteSpace($expectedHash) -or
                    (Get-Sha256File -Path $backupFile) -ne $expectedHash) {
                    return $false
                }
            }
            return $true
        }
        catch { return $false }
    } | Sort-Object LastWriteTimeUtc)
}

function Get-ManagedRuntimeDirectories {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object {
        $directoryPath = $_.FullName
        $markerPath = Join-Path $directoryPath ".agent-operations-owned.json"
        $scriptPath = Join-Path $directoryPath "agent-operations-hook.ps1"
        if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf) -or -not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            return $false
        }
        try {
            $marker = (Read-TextFile -Path $markerPath) | ConvertFrom-Json
            $actualNames = @(Get-ChildItem -LiteralPath $directoryPath -Force | ForEach-Object { $_.Name })
            $expectedNames = @(".agent-operations-owned.json", "agent-operations-hook.ps1")
            return $marker.owner -eq "agent-operations" -and
                [string]$marker.version -eq $_.Name -and
                $marker.sha256 -eq (Get-Sha256File -Path $scriptPath) -and
                @($actualNames | Where-Object { $_ -notin $expectedNames }).Count -eq 0 -and
                @($expectedNames | Where-Object { $_ -notin $actualNames }).Count -eq 0
        }
        catch { return $false }
    } | Sort-Object LastWriteTimeUtc)
}

function Get-RuntimeDirectoryState {
    param(
        [string]$Directory,
        [string]$ExpectedVersion,
        [AllowNull()][string]$ExpectedHash
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return [pscustomobject]@{ Exists = $false; Owned = $false; Reason = "missing" }
    }
    $runtimeFile = Join-Path $Directory "agent-operations-hook.ps1"
    $markerFile = Join-Path $Directory ".agent-operations-owned.json"
    $actualNames = @(Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object { $_.Name })
    $expectedNames = @(".agent-operations-owned.json", "agent-operations-hook.ps1")
    if (@($actualNames | Where-Object { $_ -notin $expectedNames }).Count -gt 0 -or @($expectedNames | Where-Object { $_ -notin $actualNames }).Count -gt 0) {
        return [pscustomobject]@{ Exists = $true; Owned = $false; Reason = "unexpected directory contents" }
    }
    try {
        $marker = (Read-TextFile -Path $markerFile) | ConvertFrom-Json -Depth 10
        $actualHash = Get-Sha256File -Path $runtimeFile
        $owned = $marker.owner -eq "agent-operations" -and
            [string]$marker.version -eq $ExpectedVersion -and
            [string]$marker.sha256 -eq $actualHash -and
            ([string]::IsNullOrWhiteSpace($ExpectedHash) -or $actualHash -eq $ExpectedHash)
        return [pscustomobject]@{ Exists = $true; Owned = $owned; Reason = if ($owned) { $null } else { "marker or runtime fingerprint mismatch" } }
    }
    catch {
        return [pscustomobject]@{ Exists = $true; Owned = $false; Reason = "invalid ownership marker" }
    }
}

function Get-DirectoryFingerprint {
    param([string]$Directory)

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return $null }
    $entries = @(Get-ChildItem -LiteralPath $Directory -Force | Sort-Object Name | ForEach-Object {
        [ordered]@{
            name = $_.Name
            kind = if ($_.PSIsContainer) { "directory" } else { "file" }
            sha256 = if ($_.PSIsContainer) { $null } else { Get-Sha256File -Path $_.FullName }
        }
    })
    return Get-Sha256Text -Text (ConvertTo-StableJson -Value $entries)
}

function Get-DirectoryTreeFingerprint {
    param([string]$Directory)

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return $null }
    $root = [System.IO.Path]::GetFullPath($Directory)
    $entries = [System.Collections.Generic.List[object]]::new()
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($root)
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        foreach ($item in @(Get-ChildItem -LiteralPath $current -Force | Sort-Object Name)) {
            $relative = [System.IO.Path]::GetRelativePath($root, $item.FullName)
            $isReparsePoint = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            $entries.Add([ordered]@{
                path = $relative
                kind = if ($item.PSIsContainer) { "directory" } else { "file" }
                reparsePoint = $isReparsePoint
                length = if ($item.PSIsContainer) { $null } else { $item.Length }
                sha256 = if ($item.PSIsContainer -or $isReparsePoint) { $null } else { Get-Sha256File -Path $item.FullName }
            })
            if ($item.PSIsContainer -and -not $isReparsePoint) {
                $pending.Enqueue($item.FullName)
            }
        }
    }
    return Get-Sha256Text -Text (ConvertTo-StableJson -Value @($entries))
}

function Test-DirectoryTreeContainsReparsePoint {
    param([string]$Directory)

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return $false }
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue([System.IO.Path]::GetFullPath($Directory))
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        $currentItem = Get-Item -LiteralPath $current -Force
        if (($currentItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
        foreach ($child in @(Get-ChildItem -LiteralPath $current -Force)) {
            if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
            if ($child.PSIsContainer) { $pending.Enqueue($child.FullName) }
        }
    }
    return $false
}

function Remove-SafeTreeWithoutReparsePoints {
    param(
        [string]$Path,
        [string]$Root
    )

    if (-not (Test-PathWithinRoot -Path $Path -Root $Root)) {
        throw "Refusing recursive delete outside the managed root."
    }
    $directories = [System.Collections.Generic.List[string]]::new()
    $files = [System.Collections.Generic.List[string]]::new()
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue([System.IO.Path]::GetFullPath($Path))
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        $currentItem = Get-Item -LiteralPath $current -Force
        if (($currentItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing recursive delete through a reparse point."
        }
        $directories.Add($current)
        foreach ($child in @(Get-ChildItem -LiteralPath $current -Force)) {
            if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing recursive delete through a reparse point."
            }
            if ($child.PSIsContainer) { $pending.Enqueue($child.FullName) } else { $files.Add($child.FullName) }
        }
    }
    foreach ($file in $files) {
        $item = Get-Item -LiteralPath $file -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "File changed to a reparse point during prune." }
        Remove-Item -LiteralPath $file -Force
    }
    foreach ($directory in @($directories | Sort-Object { $_.Length } -Descending)) {
        $item = Get-Item -LiteralPath $directory -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Directory changed to a reparse point during prune." }
        Remove-Item -LiteralPath $directory -Force
    }
}

function Get-RetentionStateFingerprint {
    param(
        [string]$BackupsRoot,
        [string]$VersionsRoot
    )

    $roots = [ordered]@{}
    foreach ($entry in @(
        [pscustomobject]@{ Name = "backups"; Path = $BackupsRoot },
        [pscustomobject]@{ Name = "runtimes"; Path = $VersionsRoot }
    )) {
        $items = if (Test-Path -LiteralPath $entry.Path -PathType Container) {
            @(Get-ChildItem -LiteralPath $entry.Path -Force | Sort-Object Name | ForEach-Object {
                [ordered]@{
                    name = $_.Name
                    kind = if ($_.PSIsContainer) { "directory" } else { "file" }
                    reparsePoint = ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
                    lastWriteTimeUtcTicks = $_.LastWriteTimeUtc.Ticks
                    fingerprint = if ($_.PSIsContainer) { Get-DirectoryTreeFingerprint -Directory $_.FullName } else { Get-Sha256File -Path $_.FullName }
                }
            })
        }
        else { @() }
        $roots[$entry.Name] = $items
    }
    return Get-Sha256Text -Text (ConvertTo-StableJson -Value $roots)
}

function Remove-VerifiedPruneCandidate {
    param(
        [string]$Path,
        [string]$Root,
        [string]$ExpectedFingerprint
    )

    if (-not (Test-PathWithinRoot -Path $Path -Root $Root) -or
        [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($Path)) -ne [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')) {
        throw "Prune candidate is not a direct child of the managed root."
    }
    if (Test-DirectoryTreeContainsReparsePoint -Directory $Path) {
        throw "Prune candidate contains a reparse point."
    }
    if ((Get-DirectoryTreeFingerprint -Directory $Path) -ne $ExpectedFingerprint) {
        throw "Prune candidate changed after approval."
    }

    $quarantinePath = Join-Path $Root (".agent-operations-prune-{0}" -f [guid]::NewGuid().ToString("N"))
    Move-Item -LiteralPath $Path -Destination $quarantinePath
    try {
        if ((Test-DirectoryTreeContainsReparsePoint -Directory $quarantinePath) -or
            (Get-DirectoryTreeFingerprint -Directory $quarantinePath) -ne $ExpectedFingerprint) {
            throw "Prune candidate changed during quarantine."
        }
        Remove-SafeTreeWithoutReparsePoints -Path $quarantinePath -Root $Root
    }
    catch {
        if ((Test-Path -LiteralPath $quarantinePath -PathType Container) -and -not (Test-Path -LiteralPath $Path)) {
            Move-Item -LiteralPath $quarantinePath -Destination $Path -ErrorAction SilentlyContinue
        }
        throw
    }
}

function New-PrunePlan {
    param(
        [string]$BackupsRoot,
        [string]$VersionsRoot,
        [object]$Manifest
    )

    $backups = @(Get-ManagedBackups -Root $BackupsRoot)
    $backupCandidates = [System.Collections.Generic.List[string]]::new()
    $manifestBackupPath = [string](Get-ManifestProperty -Manifest $Manifest -Name "backupPath")
    $manifestBackup = @()
    if (-not [string]::IsNullOrWhiteSpace($manifestBackupPath)) {
        try {
            $resolvedManifestBackupPath = [System.IO.Path]::GetFullPath($manifestBackupPath)
            if (Test-PathWithinRoot -Path $resolvedManifestBackupPath -Root $BackupsRoot) {
                $manifestBackup = @($backups | Where-Object { $_.FullName -eq $resolvedManifestBackupPath } | Select-Object -First 1)
            }
        }
        catch {
            $manifestBackup = @()
        }
    }
    $protectedBackup = if ($manifestBackup.Count -gt 0) { $manifestBackup[0].FullName } elseif ($backups.Count -gt 0) { $backups[-1].FullName } else { $null }
    $cutoff = [DateTime]::UtcNow.AddDays(-$script:BackupAgeDays)
    foreach ($backup in $backups) {
        if ($backup.FullName -ne $protectedBackup -and $backup.LastWriteTimeUtc -lt $cutoff) {
            $backupCandidates.Add($backup.FullName)
        }
    }
    $remainingBackupCount = $backups.Count - $backupCandidates.Count
    foreach ($backup in $backups) {
        if ($remainingBackupCount -lt $script:MaxBackups) { break }
        if ($backup.FullName -ne $protectedBackup -and $backup.FullName -notin $backupCandidates) {
            $backupCandidates.Add($backup.FullName)
            $remainingBackupCount--
        }
    }

    $activeVersion = [string](Get-ObjectProperty -Object $Manifest -Name "runtimeVersion")
    $lastKnownGood = [string](Get-ObjectProperty -Object $Manifest -Name "lastKnownGoodVersion")
    $protectedVersions = @($activeVersion, $lastKnownGood) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    $runtimes = @(Get-ManagedRuntimeDirectories -Root $VersionsRoot)
    $runtimeCandidates = [System.Collections.Generic.List[string]]::new()
    $remainingRuntimeCount = $runtimes.Count
    foreach ($runtime in $runtimes) {
        if ($remainingRuntimeCount -lt $script:MaxRuntimeVersions) { break }
        if ($runtime.Name -notin $protectedVersions) {
            $runtimeCandidates.Add($runtime.FullName)
            $remainingRuntimeCount--
        }
    }

    return [pscustomobject]@{
        backups = @($backupCandidates)
        runtimes = @($runtimeCandidates)
        candidates = @(
            @($backupCandidates | ForEach-Object { [ordered]@{ kind = "backup"; path = $_; fingerprint = Get-DirectoryTreeFingerprint -Directory $_ } })
            @($runtimeCandidates | ForEach-Object { [ordered]@{ kind = "runtime"; path = $_; fingerprint = Get-DirectoryTreeFingerprint -Directory $_ } })
        )
        protectedBackup = $protectedBackup
        protectedRuntimeVersions = @($protectedVersions)
    }
}

function Invoke-InstalledSelfTest {
    param(
        [string]$RuntimeScript,
        [string]$ReviewerPath
    )

    $payload = [ordered]@{
        hook_event_name = "PreToolUse"
        tool_name = "Bash"
        tool_input = [ordered]@{ command = "rg TODO . -g '*.md'" }
    } | ConvertTo-Json -Depth 5 -Compress
    $output = $payload | & pwsh -NoProfile -File $RuntimeScript -NoTelemetry
    if ($LASTEXITCODE -ne 0) {
        throw "Installed hook self-test failed."
    }
    try {
        $parsed = $output | ConvertFrom-Json
    }
    catch {
        throw "Installed hook self-test returned invalid JSON."
    }
    if (@($parsed.PSObject.Properties).Count -ne 0) {
        throw "Safe hook self-test produced a warning."
    }

    $reviewer = Read-TextFile -Path $ReviewerPath
    foreach ($marker in @('name = "independent-reviewer"', 'developer_instructions =', 'sandbox_mode = "read-only"')) {
        if ($reviewer -notmatch [regex]::Escape($marker)) {
            throw "Reviewer self-test failed."
        }
    }
}

function Write-Result {
    param([object]$Result)

    if ($OutputFormat -eq "Json") {
        $Result | ConvertTo-Json -Depth 50
        return
    }
    Write-Host ("Action: {0}" -f $Result.action)
    Write-Host ("Status: {0}" -f $Result.status)
    Write-Host ("Proposal hash: {0}" -f $Result.proposalHash)
    if ($null -ne $Result.backupDestination) {
        Write-Host ("Backup: {0}" -f $Result.backupDestination)
    }
    foreach ($message in @($Result.messages)) {
        Write-Host $message
    }
}

$actionSwitches = @(@($Install.IsPresent, $Uninstall.IsPresent, $Prune.IsPresent, $MarkActive.IsPresent) | Where-Object { $_ })
if ($actionSwitches.Count -gt 1) {
    throw "Use only one of -Install, -Uninstall, -Prune, or -MarkActive."
}
$action = if ($Uninstall) { "uninstall" } elseif ($Prune) { "prune" } elseif ($MarkActive) { "mark-active" } else { "install" }
$isPreview = [bool]$WhatIf

$codexHomePath = [System.IO.Path]::GetFullPath($CodexHome)
$transactionLockIdentity = Get-CanonicalDirectoryIdentity -Path $codexHomePath
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceRuntimePath = Join-Path $repositoryRoot "scripts/hooks/agent-operations-hook.ps1"
$hookTemplatePath = Join-Path $repositoryRoot "templates/codex/agent-operations-hooks.json"
$reviewerTemplatePath = Join-Path $repositoryRoot "templates/codex/agents/independent-reviewer.toml"

$configPath = Join-Path $codexHomePath "config.toml"
$hooksPath = Join-Path $codexHomePath "hooks.json"
$reviewerPath = Join-Path $codexHomePath "agents/independent-reviewer.toml"
$operationsRoot = Join-Path $codexHomePath "agent-operations"
$versionsRoot = Join-Path $operationsRoot "versions"
$runtimeDirectory = Join-Path $versionsRoot $script:RuntimeVersion
$runtimePath = Join-Path $runtimeDirectory "agent-operations-hook.ps1"
$runtimeMarkerPath = Join-Path $runtimeDirectory ".agent-operations-owned.json"
$manifestPath = Join-Path $operationsRoot "install-manifest.json"
$backupsRoot = Join-Path $codexHomePath "backups/agent-operations"
$logsRoot = Join-Path $codexHomePath "logs"
$transactionMutex = $null

if (-not $isPreview -and -not [string]::IsNullOrWhiteSpace($ApprovedProposalHash)) {
    $transactionMutex = Enter-InstallerTransactionMutex -DirectoryIdentity $transactionLockIdentity
    if ($null -eq $transactionMutex) {
        Write-Result -Result ([pscustomobject][ordered]@{
            schemaVersion = 1; action = $action; preview = $false; status = "approval-required"
            proposalHash = $null; codexHome = $codexHomePath; transactionLockIdentity = $transactionLockIdentity
            backupDestination = $null; changes = $null; messages = @("Another installer transaction did not release the CodexHome lock in time."); blockers = @()
        })
        exit 3
    }
    if ((Get-CanonicalDirectoryIdentity -Path $codexHomePath) -ne $transactionLockIdentity) {
        Write-Result -Result ([pscustomobject][ordered]@{
            schemaVersion = 1; action = $action; preview = $false; status = "approval-required"
            proposalHash = $null; codexHome = $codexHomePath; transactionLockIdentity = $transactionLockIdentity
            backupDestination = $null; changes = $null; messages = @("Physical CodexHome identity changed after preview."); blockers = @()
        })
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
}

foreach ($requiredSource in @($sourceRuntimePath, $hookTemplatePath, $reviewerTemplatePath)) {
    if (-not (Test-Path -LiteralPath $requiredSource -PathType Leaf)) {
        throw "Required versioned source is missing: $requiredSource"
    }
}

$managedPaths = @(
    $configPath, $hooksPath, $reviewerPath, $operationsRoot, $versionsRoot,
    $runtimeDirectory, $runtimePath, $runtimeMarkerPath, $manifestPath,
    $backupsRoot, $logsRoot
)
if (-not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths)) {
    Write-Result -Result ([pscustomobject][ordered]@{
        schemaVersion = 1; action = $action; preview = $isPreview; status = "blocked"
        proposalHash = $null; codexHome = $codexHomePath; transactionLockIdentity = $transactionLockIdentity
        backupDestination = $null; changes = $null; messages = @(); blockers = @("A managed path contains an intermediate reparse point.")
    })
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 2
}

$currentConfig = Read-TextFile -Path $configPath
$currentHooks = Read-TextFile -Path $hooksPath
$currentReviewer = Read-TextFile -Path $reviewerPath
$currentManifestText = Read-TextFile -Path $manifestPath
$manifest = if ([string]::IsNullOrWhiteSpace($currentManifestText)) { $null } else { Read-JsonObject -Content $currentManifestText -Description "Install manifest" }
$existingTelemetrySalt = [string](Get-ManifestProperty -Manifest $manifest -Name "telemetrySalt")
$manifestRuntimeVersion = [string](Get-ObjectProperty -Object $manifest -Name "runtimeVersion")
$manifestRuntimeVersionValid = $null -eq $manifest -or $manifestRuntimeVersion -match '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$'
if ($action -in @("uninstall", "mark-active") -and $manifestRuntimeVersionValid -and -not [string]::IsNullOrWhiteSpace($manifestRuntimeVersion)) {
    $runtimeDirectory = Join-Path $versionsRoot $manifestRuntimeVersion
    $runtimePath = Join-Path $runtimeDirectory "agent-operations-hook.ps1"
    $runtimeMarkerPath = Join-Path $runtimeDirectory ".agent-operations-owned.json"
}
$managedPaths = @(
    $configPath, $hooksPath, $reviewerPath, $operationsRoot, $versionsRoot,
    $runtimeDirectory, $runtimePath, $runtimeMarkerPath, $manifestPath,
    $backupsRoot, $logsRoot
)
if (-not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths)) {
    Write-Result -Result ([pscustomobject][ordered]@{
        schemaVersion = 1; action = $action; preview = $isPreview; status = "blocked"
        proposalHash = $null; codexHome = $codexHomePath; transactionLockIdentity = $transactionLockIdentity
        backupDestination = $null; changes = $null; messages = @(); blockers = @("A manifest-selected managed path contains an intermediate reparse point.")
    })
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 2
}
$messages = [System.Collections.Generic.List[string]]::new()
$blockers = [System.Collections.Generic.List[string]]::new()

if ($null -ne $manifest -and [string](Get-ObjectProperty -Object $manifest -Name "owner") -ne "agent-operations") {
    $blockers.Add("The install manifest is foreign; managed ownership cannot be proven.")
}
if (-not $manifestRuntimeVersionValid) {
    $blockers.Add("The install manifest contains an invalid runtimeVersion.")
}
if (-not [string]::IsNullOrWhiteSpace($existingTelemetrySalt) -and $existingTelemetrySalt -notmatch '^[0-9a-f]{64}$') {
    $blockers.Add("The install manifest contains an invalid telemetrySalt.")
}

if ($action -eq "mark-active") {
    $evidenceExpiresAt = $null
    if ($null -eq $manifest) {
        $blockers.Add("Install manifest is missing; awaiting-trust state cannot be verified.")
    }

    $activationEvidenceText = if ([string]::IsNullOrWhiteSpace($ActivationEvidencePath)) { $null } else { Read-TextFile -Path $ActivationEvidencePath }
    $activationEvidence = $null
    if ([string]::IsNullOrWhiteSpace($activationEvidenceText)) {
        $blockers.Add("Activation evidence is required before marking the runtime active.")
    }
    else {
        try { $activationEvidence = Read-JsonObject -Content $activationEvidenceText -Description "Activation evidence" }
        catch { $blockers.Add($_.Exception.Message) }
    }

    $manifestState = [string](Get-ObjectProperty -Object $manifest -Name "state")
    $isAlreadyActive = $null -ne $manifest -and $manifestState -eq "active"
    if ($null -ne $manifest -and $manifestState -notin @("awaiting-trust", "active")) {
        $blockers.Add("Activation can transition only from awaiting-trust.")
    }

    $runtimeChecksums = Get-ManifestProperty -Manifest $manifest -Name "runtimeChecksums"
    $manifestRuntimeHash = [string](Get-ObjectProperty -Object $runtimeChecksums -Name "hook")
    $manifestRuntimeMarkerHash = [string](Get-ObjectProperty -Object $runtimeChecksums -Name "marker")
    if ([string]::IsNullOrWhiteSpace($manifestRuntimeHash)) {
        $manifestRuntimeHash = [string](Get-ObjectProperty -Object $manifest -Name "runtimeHash")
    }
    $manifestReviewerFingerprint = [string](Get-ManifestProperty -Manifest $manifest -Name "installerOwnedReviewerFingerprint" -LegacyNames @("reviewerHash"))
    $manifestActivationChallenge = [string](Get-ObjectProperty -Object $manifest -Name "activationChallenge")
    $manifestTelemetrySalt = [string](Get-ObjectProperty -Object $manifest -Name "telemetrySalt")
    if ($manifestActivationChallenge -notmatch '^[0-9a-f]{64}$') {
        $blockers.Add("Install manifest contains an invalid activation challenge.")
    }
    $expectedActivationBindingHash = if ($manifestActivationChallenge -match '^[0-9a-f]{64}$' -and $manifestTelemetrySalt -match '^[0-9a-f]{64}$') {
        Get-Sha256Text -Text ("$manifestTelemetrySalt|activation|$manifestActivationChallenge")
    }
    else { $null }

    $currentConfigHash = Get-Sha256File -Path $configPath
    $currentHooksHash = Get-Sha256File -Path $hooksPath
    $currentReviewerHash = Get-Sha256File -Path $reviewerPath
    $currentRuntimeHash = Get-Sha256File -Path $runtimePath
    $currentRuntimeMarkerHash = Get-Sha256File -Path $runtimeMarkerPath
    $activationAgentValues = Get-AgentValues -Content $currentConfig
    if ($activationAgentValues.max_threads -ne "4" -or $activationAgentValues.max_depth -ne "1") {
        $blockers.Add("Live agent limits do not match the reviewed 4/1 activation baseline.")
    }
    if ($currentRuntimeHash -ne $manifestRuntimeHash -or
        $currentRuntimeMarkerHash -ne $manifestRuntimeMarkerHash -or
        $currentReviewerHash -ne $manifestReviewerFingerprint) {
        $blockers.Add("Installed runtime, marker, or reviewer drifted after installation.")
    }

    try {
        $activationHookInventory = @(Get-HookGroupInventory -Content $currentHooks -ManagedRoot $operationsRoot)
        $expectedHookFingerprints = Get-ManifestProperty -Manifest $manifest -Name "installerOwnedHookFingerprints"
        foreach ($eventName in @("PreToolUse", "PostToolUse")) {
            $expectedFingerprint = [string](Get-ObjectProperty -Object $expectedHookFingerprints -Name $eventName)
            $matches = @($activationHookInventory | Where-Object {
                $_.EventName -eq $eventName -and $_.Fingerprint -eq $expectedFingerprint -and $_.ReferencesManagedRoot
            })
            if ([string]::IsNullOrWhiteSpace($expectedFingerprint) -or $matches.Count -ne 1) {
                $blockers.Add("Installed $eventName hook definition does not match the manifest fingerprint.")
            }
        }
    }
    catch {
        $blockers.Add($_.Exception.Message)
    }

    if ($null -ne $activationEvidence) {
        if ((Get-ObjectProperty -Object $activationEvidence -Name "schemaVersion") -ne 1 -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "runtimeVersion") -ne $manifestRuntimeVersion -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "runtimeHash") -ne $manifestRuntimeHash -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "runtimeMarkerHash") -ne $currentRuntimeMarkerHash -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "configHash") -ne $currentConfigHash -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "hooksHash") -ne $currentHooksHash -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "reviewerHash") -ne $currentReviewerHash -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "reviewerFingerprint") -ne $manifestReviewerFingerprint -or
            [string](Get-ObjectProperty -Object $activationEvidence -Name "activationBindingHash") -ne $expectedActivationBindingHash) {
            $blockers.Add("Activation evidence fingerprints do not match the live config, hooks, runtime, marker, and reviewer.")
        }
        foreach ($requiredCheck in @("manualHookTrustConfirmed", "controlledHostTaskConfirmed", "runtimeChallengeObserved", "runtimeStillInstalled", "safeCallPassed", "knownBadPreToolUsePassed", "postToolUsePassed", "failOpenPassed", "agentLimitsPassed", "reviewerWriteDenied")) {
            $checkValue = Get-ObjectProperty -Object $activationEvidence -Name $requiredCheck
            if ($checkValue -isnot [bool] -or -not $checkValue) {
                $blockers.Add("Activation evidence check '$requiredCheck' is missing or not true.")
            }
        }
        try {
            $runtimeObservationAt = ConvertTo-DateTimeOffsetValue -Value (Get-ObjectProperty -Object $activationEvidence -Name "runtimeObservationAtUtc")
            $evidenceCreatedAt = ConvertTo-DateTimeOffsetValue -Value (Get-ObjectProperty -Object $activationEvidence -Name "evidenceCreatedAtUtc")
            $evidenceExpiresAt = ConvertTo-DateTimeOffsetValue -Value (Get-ObjectProperty -Object $activationEvidence -Name "expiresAtUtc")
            $evidenceValidationNow = [DateTimeOffset]::UtcNow
            $futureTolerance = $evidenceValidationNow.AddMinutes(1)
            if ($runtimeObservationAt -gt $evidenceCreatedAt -or
                $evidenceCreatedAt -gt $evidenceExpiresAt -or
                $runtimeObservationAt -gt $futureTolerance -or
                $evidenceCreatedAt -gt $futureTolerance -or
                ($evidenceExpiresAt - $runtimeObservationAt).TotalMinutes -gt 15.1 -or
                $evidenceValidationNow -gt $evidenceExpiresAt) {
                $blockers.Add("Activation evidence timestamps are inconsistent or expired.")
            }
        }
        catch {
            $blockers.Add("Activation evidence timestamps are missing or invalid.")
        }
    }

    $activationProposalMaterial = [ordered]@{
        schemaVersion = 1
        action = "mark-active"
        runtimeVersion = $manifestRuntimeVersion
        codexHome = $codexHomePath
        inputs = [ordered]@{
            managedPathSafety = $true
            manifest = Get-Sha256Text -Text $currentManifestText
            activationEvidence = Get-Sha256Text -Text $activationEvidenceText
            config = $currentConfigHash
            hooks = $currentHooksHash
            reviewer = $currentReviewerHash
            runtime = $currentRuntimeHash
            runtimeMarker = $currentRuntimeMarkerHash
        }
        outputs = [ordered]@{
            state = "active"
            lastKnownGoodVersion = $manifestRuntimeVersion
            activationEvidenceHash = Get-Sha256Text -Text $activationEvidenceText
            activatedAt = "apply-time-utc-o"
        }
        blockers = @($blockers)
    }
    $activationProposalHash = Get-Sha256Text -Text (ConvertTo-StableJson -Value $activationProposalMaterial)
    $manifestBeforePreview = if ($null -eq $manifest) { $null } else { Read-JsonObject -Content $currentManifestText -Description "Install manifest" }
    $manifestAfterPreview = if ($null -eq $manifest) { $null } else { Read-JsonObject -Content $currentManifestText -Description "Install manifest" }
    if ($null -ne $manifestAfterPreview) {
        Set-ObjectProperty -Object $manifestAfterPreview -Name "state" -Value "active"
        Set-ObjectProperty -Object $manifestAfterPreview -Name "lastKnownGoodVersion" -Value $manifestRuntimeVersion
        Set-ObjectProperty -Object $manifestAfterPreview -Name "activatedAt" -Value "apply-time-utc-o"
        Set-ObjectProperty -Object $manifestAfterPreview -Name "activationEvidenceHash" -Value $activationProposalMaterial.inputs.activationEvidence
    }
    $activationResult = [ordered]@{
        schemaVersion = 1
        action = "mark-active"
        preview = $isPreview
        status = if ($blockers.Count -gt 0) { "blocked" } elseif ($isAlreadyActive) { "no-op" } elseif ($isPreview) { "proposed" } else { "pending" }
        proposalHash = $activationProposalHash
        codexHome = $codexHomePath
        transactionLockIdentity = $transactionLockIdentity
        backupDestination = $null
        changes = [ordered]@{
            state = [ordered]@{ before = Get-ObjectProperty -Object $manifest -Name "state"; after = "active" }
            manifest = [ordered]@{
                path = $manifestPath
                beforeHash = Get-Sha256Text -Text $currentManifestText
                before = $manifestBeforePreview
                after = $manifestAfterPreview
            }
        }
        messages = @($messages)
        blockers = @($blockers)
    }
    if (-not $isPreview -and -not [string]::IsNullOrWhiteSpace($ApprovedProposalHash) -and $ApprovedProposalHash -ne $activationProposalHash) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "ApprovedProposalHash is stale; run -MarkActive -WhatIf again."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
    if ($isPreview -or $blockers.Count -gt 0 -or $isAlreadyActive) {
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        if ($blockers.Count -gt 0) { exit 2 }
        exit 0
    }
    if ([string]::IsNullOrWhiteSpace($ApprovedProposalHash) -or $ApprovedProposalHash -ne $activationProposalHash) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "ApprovedProposalHash is missing or stale; run -MarkActive -WhatIf again."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
    if ($null -eq $transactionMutex) { $transactionMutex = Enter-InstallerTransactionMutex -DirectoryIdentity $transactionLockIdentity }
    if ($null -eq $transactionMutex) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "Another installer transaction did not release the CodexHome lock in time."
        Write-Result -Result ([pscustomobject]$activationResult)
        exit 3
    }
    if ((Get-CanonicalDirectoryIdentity -Path $codexHomePath) -ne $transactionLockIdentity) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "Physical CodexHome identity changed after preview."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
    if (-not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths)) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "Managed path safety changed after preview."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
    $liveActivationInputs = [ordered]@{
        managedPathSafety = $true
        manifest = Get-Sha256Text -Text (Read-TextFile -Path $manifestPath)
        activationEvidence = Get-Sha256Text -Text (Read-TextFile -Path $ActivationEvidencePath)
        config = Get-Sha256File -Path $configPath
        hooks = Get-Sha256File -Path $hooksPath
        reviewer = Get-Sha256File -Path $reviewerPath
        runtime = Get-Sha256File -Path $runtimePath
        runtimeMarker = Get-Sha256File -Path $runtimeMarkerPath
    }
    if ((ConvertTo-StableJson -Value $liveActivationInputs) -ne (ConvertTo-StableJson -Value $activationProposalMaterial.inputs)) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "Manifest, evidence, or an activation-bound live artifact changed after preview."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }

    if ($SimulateActivationDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $SimulateActivationDelayMilliseconds
    }
    if ($null -eq $evidenceExpiresAt -or [DateTimeOffset]::UtcNow -gt $evidenceExpiresAt) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "Activation evidence expired before commit; generate fresh evidence and preview again."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
    if ((Get-CanonicalDirectoryIdentity -Path $codexHomePath) -ne $transactionLockIdentity -or
        -not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths)) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "Managed location changed before the final activation read."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
    $finalActivationInputs = [ordered]@{
        managedPathSafety = $true
        manifest = Get-Sha256Text -Text (Read-TextFile -Path $manifestPath)
        activationEvidence = Get-Sha256Text -Text (Read-TextFile -Path $ActivationEvidencePath)
        config = Get-Sha256File -Path $configPath
        hooks = Get-Sha256File -Path $hooksPath
        reviewer = Get-Sha256File -Path $reviewerPath
        runtime = Get-Sha256File -Path $runtimePath
        runtimeMarker = Get-Sha256File -Path $runtimeMarkerPath
    }
    if ((ConvertTo-StableJson -Value $finalActivationInputs) -ne (ConvertTo-StableJson -Value $activationProposalMaterial.inputs) -or
        (Get-CanonicalDirectoryIdentity -Path $codexHomePath) -ne $transactionLockIdentity -or
        -not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths) -or
        [DateTimeOffset]::UtcNow -gt $evidenceExpiresAt) {
        $activationResult.status = "approval-required"
        $activationResult.messages = @($activationResult.messages) + "Activation-bound inputs or managed path safety changed immediately before commit."
        Write-Result -Result ([pscustomobject]$activationResult)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }

    Set-ObjectProperty -Object $manifest -Name "state" -Value "active"
    Set-ObjectProperty -Object $manifest -Name "lastKnownGoodVersion" -Value $manifestRuntimeVersion
    Set-ObjectProperty -Object $manifest -Name "activatedAt" -Value ([DateTime]::UtcNow.ToString("o"))
    Set-ObjectProperty -Object $manifest -Name "activationEvidenceHash" -Value $activationProposalMaterial.inputs.activationEvidence
    $manifestOutputText = ($manifest | ConvertTo-Json -Depth 30) + [Environment]::NewLine
    $activationResult.changes.manifest.after = Read-JsonObject -Content $manifestOutputText -Description "Install manifest"
    $activationResult.changes.manifest.afterHash = Get-Sha256Text -Text $manifestOutputText
    $activationResult.changes.manifest.afterContent = $manifestOutputText
    Write-TextAtomic -Path $manifestPath -Content $manifestOutputText
    $activationResult.status = "active"
    Write-Result -Result ([pscustomobject]$activationResult)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 0
}

if ($action -eq "install") {
    if ($null -eq (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        $blockers.Add("pwsh is unavailable in the effective runtime.")
    }
    if ($currentConfig -match '(?m)^\s*\[{1,2}hooks(?:[.\]])') {
        $blockers.Add("Inline hooks are already present in config.toml; representation migration is intentionally manual.")
    }
    if (Test-UnsupportedAgentConfiguration -Content $currentConfig) {
        $blockers.Add("The agents configuration uses an unsupported or ambiguous TOML representation; migrate it manually before install.")
    }
    if ($currentConfig -match '(?im)^\s*(?:hooks_enabled|enable_hooks)\s*=\s*false\b|^\s*(?:managed_hooks_only|hooks_managed_only)\s*=\s*true\b') {
        $blockers.Add("The effective config disables non-managed hooks or requires managed-only hooks.")
    }
}

$runtimeSourceBytes = [System.IO.File]::ReadAllBytes($sourceRuntimePath)
$runtimeSourceHash = Get-Sha256Bytes -Bytes $runtimeSourceBytes
$reviewerTemplate = Read-TextFile -Path $reviewerTemplatePath
$reviewerTemplateHash = Get-Sha256Text -Text $reviewerTemplate
$priorReviewerHash = [string](Get-ManifestProperty -Manifest $manifest -Name "installerOwnedReviewerFingerprint" -LegacyNames @("reviewerHash"))
if ($action -eq "install" -and $null -ne $currentReviewer) {
    $currentReviewerHash = Get-Sha256Text -Text $currentReviewer
    if ($currentReviewerHash -ne $reviewerTemplateHash -and $currentReviewerHash -ne $priorReviewerHash) {
        $blockers.Add("The personal reviewer file is foreign or drifted and will not be overwritten.")
    }
}
$expectedRuntimeHash = if ($action -in @("uninstall", "mark-active")) {
    $runtimeChecksums = Get-ManifestProperty -Manifest $manifest -Name "runtimeChecksums"
    $newRuntimeHash = [string](Get-ObjectProperty -Object $runtimeChecksums -Name "hook")
    if ([string]::IsNullOrWhiteSpace($newRuntimeHash)) { [string](Get-ObjectProperty -Object $manifest -Name "runtimeHash") } else { $newRuntimeHash }
}
else { $runtimeSourceHash }
$runtimeState = if ($action -eq "prune") {
    [pscustomobject]@{ Exists = $false; Owned = $false; Reason = "not-applicable" }
}
else {
    Get-RuntimeDirectoryState -Directory $runtimeDirectory -ExpectedVersion $(if ($action -eq "uninstall" -and -not [string]::IsNullOrWhiteSpace($manifestRuntimeVersion)) { $manifestRuntimeVersion } else { $script:RuntimeVersion }) -ExpectedHash $expectedRuntimeHash
}
if ($action -ne "prune" -and $runtimeState.Exists -and -not $runtimeState.Owned) {
    $blockers.Add("The target runtime directory is foreign or drifted: $($runtimeState.Reason).")
}

$currentAgentValues = Get-AgentValues -Content $currentConfig
$priorFingerprints = Get-ManifestFingerprints -Manifest $manifest
$hookInventory = @()
if ($action -in @("install", "uninstall")) {
    try {
        $hookInventory = @(Get-HookGroupInventory -Content $currentHooks -ManagedRoot $operationsRoot)
        foreach ($reference in @($hookInventory | Where-Object { $_.ReferencesManagedRoot })) {
            if ($reference.EventName -notin @("PreToolUse", "PostToolUse") -or $reference.Fingerprint -notin $priorFingerprints) {
                $blockers.Add("A hook group references the managed runtime but its fingerprint is foreign or drifted.")
            }
        }
        foreach ($fingerprint in $priorFingerprints) {
            $matches = @($hookInventory | Where-Object { $_.Fingerprint -eq $fingerprint })
            if (@($matches | Where-Object { -not $_.ReferencesManagedRoot }).Count -gt 0) {
                $blockers.Add("A manifest fingerprint matches a hook group that does not reference the managed runtime.")
            }
        }
    }
    catch {
        $blockers.Add($_.Exception.Message)
    }
}
$runtimeCommand = 'pwsh -NoProfile -File "{0}" -TelemetryRoot "{1}" -InstallManifestPath "{2}"' -f $runtimePath, $logsRoot, $manifestPath
$hookTemplate = Get-HookTemplate -TemplatePath $hookTemplatePath -Command $runtimeCommand
$proposedConfig = $currentConfig
$proposedHooks = $currentHooks
$proposedReviewer = $currentReviewer
$hookFingerprints = [pscustomobject]@{}
$previousAgents = $null
$createdFiles = if ($null -ne $manifest -and $null -ne (Get-ObjectProperty -Object $manifest -Name "createdFiles")) {
    Get-ObjectProperty -Object $manifest -Name "createdFiles"
}
else {
    [pscustomobject]@{
        config = $null -eq $currentConfig
        hooks = $null -eq $currentHooks
        reviewer = $null -eq $currentReviewer
    }
}
$prunePlan = New-PrunePlan -BackupsRoot $backupsRoot -VersionsRoot $versionsRoot -Manifest $manifest
$retentionStateFingerprint = Get-RetentionStateFingerprint -BackupsRoot $backupsRoot -VersionsRoot $versionsRoot

if ($action -eq "install") {
    $previousAgents = if ($null -ne $manifest) {
        Get-ManifestProperty -Manifest $manifest -Name "previousAgentSettings" -LegacyNames @("previousAgents")
    }
    else {
        [pscustomobject]@{
            max_threads = $currentAgentValues.max_threads
            max_depth = $currentAgentValues.max_depth
        }
    }
    $proposedConfig = Set-AgentValues -Content $currentConfig -MaxThreads "4" -MaxDepth "1"
    try {
        $mergedHooks = Merge-HookConfiguration -CurrentContent $currentHooks -Template $hookTemplate -RemoveFingerprints $priorFingerprints
        $proposedHooks = $mergedHooks.Content
        $hookFingerprints = $mergedHooks.Fingerprints
    }
    catch {
        $blockers.Add($_.Exception.Message)
    }
    $proposedReviewer = $reviewerTemplate

    $managedBackups = @(Get-ManagedBackups -Root $backupsRoot)
    $managedRuntimes = @(Get-ManagedRuntimeDirectories -Root $versionsRoot)
    $runtimeAlreadyManaged = @($managedRuntimes | Where-Object { $_.Name -eq $script:RuntimeVersion }).Count -gt 0
    if ($managedBackups.Count -ge $script:MaxBackups) {
        $blockers.Add("Backup hard cap reached; run previewed -Prune before activation.")
    }
    if (-not $runtimeAlreadyManaged -and $managedRuntimes.Count -ge $script:MaxRuntimeVersions) {
        $blockers.Add("Runtime hard cap reached; run previewed -Prune before activation.")
    }
    if (@($prunePlan.backups).Count -gt 0 -or @($prunePlan.runtimes).Count -gt 0) {
        $blockers.Add("Managed retention candidates exist; run previewed -Prune before install.")
    }
}
elseif ($action -eq "uninstall") {
    if ($null -eq $manifest) {
        $blockers.Add("Install manifest is missing; ownership cannot be proven.")
    }
    else {
        $previousAgents = Get-ManifestProperty -Manifest $manifest -Name "previousAgentSettings" -LegacyNames @("previousAgents")
        if ($currentAgentValues.max_threads -eq "4" -and $currentAgentValues.max_depth -eq "1") {
            $restoreThreads = if ($null -eq $previousAgents.max_threads) { $null } else { [string]$previousAgents.max_threads }
            $restoreDepth = if ($null -eq $previousAgents.max_depth) { $null } else { [string]$previousAgents.max_depth }
            $proposedConfig = Set-AgentValues -Content $currentConfig -MaxThreads $restoreThreads -MaxDepth $restoreDepth
            if ([bool]$createdFiles.config -and (Test-ConfigHasOnlyEmptyAgents -Content $proposedConfig)) {
                $proposedConfig = $null
            }
        }
        else {
            $messages.Add("Agent limits drifted; uninstall preserves current values.")
        }
        try {
            $mergedHooks = Merge-HookConfiguration -CurrentContent $currentHooks -Template $hookTemplate -RemoveFingerprints $priorFingerprints -RemoveOnly
            $proposedHooks = $mergedHooks.Content
            if ([bool]$createdFiles.hooks -and (Test-HooksDocumentEmpty -Content $proposedHooks)) {
                $proposedHooks = $null
            }
        }
        catch {
            $blockers.Add($_.Exception.Message)
        }
        if ($null -ne $currentReviewer -and (Get-Sha256Text -Text $currentReviewer) -ne $priorReviewerHash) {
            $blockers.Add("Reviewer fingerprint drifted; uninstall will not delete it.")
        }
        else {
            $proposedReviewer = $null
        }
        $manifestRuntimeChecksums = Get-ManifestProperty -Manifest $manifest -Name "runtimeChecksums"
        $manifestRuntimeHash = [string](Get-ObjectProperty -Object $manifestRuntimeChecksums -Name "hook")
        if ([string]::IsNullOrWhiteSpace($manifestRuntimeHash)) {
            $manifestRuntimeHash = [string](Get-ObjectProperty -Object $manifest -Name "runtimeHash")
        }
        if ((Test-Path -LiteralPath $runtimePath -PathType Leaf) -and (Get-Sha256File -Path $runtimePath) -ne $manifestRuntimeHash) {
            $blockers.Add("Runtime fingerprint drifted; uninstall will not delete it.")
        }
    }
}

$previewContract = [ordered]@{
    exactContentPaths = @($configPath, $hooksPath, $reviewerPath)
    immutableHashPaths = @($runtimePath)
    boundedGeneratedFields = @(
        "backup-manifest.createdAtUtc=apply-time",
        "install-manifest.installedAt=apply-time",
        "install-manifest.telemetrySalt=preserved-or-cryptographic-random-256-bit",
        "install-manifest.activationChallenge=cryptographic-random-256-bit"
    )
}

$proposalMaterial = [ordered]@{
    schemaVersion = 1
    action = $action
    runtimeVersion = $script:RuntimeVersion
    codexHome = $codexHomePath
    proposalDateUtc = [DateTime]::UtcNow.ToString("yyyyMMdd")
    inputs = [ordered]@{
        managedPathSafety = $true
        config = Get-Sha256Text -Text $currentConfig
        hooks = Get-Sha256Text -Text $currentHooks
        reviewer = Get-Sha256Text -Text $currentReviewer
        manifest = Get-Sha256Text -Text $currentManifestText
        runtime = Get-Sha256File -Path $runtimePath
        runtimeMarker = Get-Sha256File -Path $runtimeMarkerPath
        runtimeDirectory = Get-DirectoryFingerprint -Directory $runtimeDirectory
        retentionState = $retentionStateFingerprint
    }
    outputs = [ordered]@{
        config = Get-Sha256Text -Text $proposedConfig
        hooks = Get-Sha256Text -Text $proposedHooks
        reviewer = Get-Sha256Text -Text $proposedReviewer
        runtime = if ($action -eq "install") { $runtimeSourceHash } elseif ($action -eq "uninstall") { $null } else { Get-Sha256File -Path $runtimePath }
        previewContract = $previewContract
    }
    prune = $prunePlan
    blockers = @($blockers)
}
$proposalHash = Get-Sha256Text -Text (ConvertTo-StableJson -Value $proposalMaterial)
$backupName = "{0}-{1}" -f $proposalMaterial.proposalDateUtc, $proposalHash.Substring(0, 16)
$backupDestination = if ($action -in @("install", "uninstall")) { Join-Path $backupsRoot $backupName } else { $null }

$changes = [ordered]@{
    config = [ordered]@{
        path = $configPath
        beforeHash = Get-Sha256Text -Text $currentConfig
        afterHash = Get-Sha256Text -Text $proposedConfig
        beforeContent = $currentConfig
        afterContent = $proposedConfig
        beforeAgents = $currentAgentValues
        afterAgents = Get-AgentValues -Content $proposedConfig
    }
    hooks = [ordered]@{
        path = $hooksPath
        beforeHash = Get-Sha256Text -Text $currentHooks
        afterHash = Get-Sha256Text -Text $proposedHooks
        beforeContent = $currentHooks
        afterContent = $proposedHooks
        installedGroups = if ($action -eq "install") { (Get-ObjectProperty -Object $hookTemplate -Name "hooks") } else { $null }
        removedFingerprints = if ($action -eq "uninstall") { @($priorFingerprints) } else { @() }
    }
    reviewer = [ordered]@{
        path = $reviewerPath
        beforeHash = Get-Sha256Text -Text $currentReviewer
        afterHash = Get-Sha256Text -Text $proposedReviewer
        beforeContent = $currentReviewer
        afterContent = $proposedReviewer
        content = if ($action -eq "install") { $proposedReviewer } else { $null }
    }
    runtime = [ordered]@{
        path = $runtimePath
        sha256 = if ($action -eq "uninstall") { $expectedRuntimeHash } else { $runtimeSourceHash }
        immutableVersion = if ($action -eq "uninstall" -and -not [string]::IsNullOrWhiteSpace($manifestRuntimeVersion)) { $manifestRuntimeVersion } else { $script:RuntimeVersion }
    }
}

$isNoOpInstall = $action -eq "install" -and
    $null -ne $manifest -and
    (Get-Sha256Text -Text $currentConfig) -eq (Get-Sha256Text -Text $proposedConfig) -and
    (Get-Sha256Text -Text $currentHooks) -eq (Get-Sha256Text -Text $proposedHooks) -and
    (Get-Sha256Text -Text $currentReviewer) -eq $reviewerTemplateHash -and
    (Get-Sha256File -Path $runtimePath) -eq $runtimeSourceHash -and
    [string](Get-ObjectProperty -Object $manifest -Name "runtimeVersion") -eq $script:RuntimeVersion

$result = [ordered]@{
    schemaVersion = 1
    action = $action
    preview = $isPreview
    status = if ($blockers.Count -gt 0) { "blocked" } elseif ($isNoOpInstall) { "no-op" } elseif ($isPreview) { "proposed" } else { "pending" }
    proposalHash = $proposalHash
    codexHome = $codexHomePath
    transactionLockIdentity = $transactionLockIdentity
    previewContract = $previewContract
    backupDestination = $backupDestination
    changes = $changes
    prune = $prunePlan
    trust = [ordered]@{
        stateAfterInstall = "awaiting-trust"
        source = "non-managed user hooks.json"
        review = "/hooks or the current documented equivalent"
        bypassAllowed = $false
    }
    rollbackCommand = "pwsh -NoProfile -File `"$PSCommandPath`" -Uninstall -CodexHome `"$codexHomePath`" -WhatIf"
    messages = @($messages)
    blockers = @($blockers)
}

if ($isPreview -and $null -ne $backupDestination -and (Test-Path -LiteralPath $backupDestination)) {
    $result.status = "blocked"
    $result.blockers = @($result.blockers) + "Backup destination already exists; remove or preserve it manually, then generate a new proposal."
    Write-Result -Result ([pscustomobject]$result)
    exit 2
}

if (-not $isPreview -and -not [string]::IsNullOrWhiteSpace($ApprovedProposalHash) -and $ApprovedProposalHash -ne $proposalHash) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "ApprovedProposalHash is stale; run -WhatIf and obtain approval for the new hash."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}

if ($isPreview -or $blockers.Count -gt 0 -or $isNoOpInstall) {
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    if ($blockers.Count -gt 0) { exit 2 }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ApprovedProposalHash) -or $ApprovedProposalHash -ne $proposalHash) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "ApprovedProposalHash is missing or stale; run -WhatIf and obtain explicit approval for the new hash."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}

if ($null -eq $transactionMutex) { $transactionMutex = Enter-InstallerTransactionMutex -DirectoryIdentity $transactionLockIdentity }
if ($null -eq $transactionMutex) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Another installer transaction did not release the CodexHome lock in time."
    Write-Result -Result ([pscustomobject]$result)
    exit 3
}
if ((Get-CanonicalDirectoryIdentity -Path $codexHomePath) -ne $transactionLockIdentity) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Physical CodexHome identity changed after preview."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}
if (-not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths)) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Managed path safety changed after preview."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}

$liveInputs = [ordered]@{
    managedPathSafety = $true
    config = Get-Sha256Text -Text (Read-TextFile -Path $configPath)
    hooks = Get-Sha256Text -Text (Read-TextFile -Path $hooksPath)
    reviewer = Get-Sha256Text -Text (Read-TextFile -Path $reviewerPath)
    manifest = Get-Sha256Text -Text (Read-TextFile -Path $manifestPath)
    runtime = Get-Sha256File -Path $runtimePath
    runtimeMarker = Get-Sha256File -Path $runtimeMarkerPath
    runtimeDirectory = Get-DirectoryFingerprint -Directory $runtimeDirectory
    retentionState = Get-RetentionStateFingerprint -BackupsRoot $backupsRoot -VersionsRoot $versionsRoot
}
if ((ConvertTo-StableJson -Value $liveInputs) -ne (ConvertTo-StableJson -Value $proposalMaterial.inputs)) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Managed inputs changed during apply; no mutation was attempted. Run a new -WhatIf preview."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}
if ($null -ne $backupDestination -and (Test-Path -LiteralPath $backupDestination)) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Backup destination appeared after preview; no mutation was attempted. Generate a new proposal after resolving the collision."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}
if ($SimulateCommitDelayMilliseconds -gt 0) {
    if (-not [string]::IsNullOrWhiteSpace($SimulationCommitReadyPath)) {
        $simulationSignalPath = [System.IO.Path]::GetFullPath($SimulationCommitReadyPath)
        $systemTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        if (-not (Test-PathWithinRoot -Path $simulationSignalPath -Root $systemTempRoot)) {
            throw "SimulationCommitReadyPath must stay under the system temp directory."
        }
        [System.IO.File]::WriteAllText($simulationSignalPath, "ready", [System.Text.UTF8Encoding]::new($false))
    }
    Start-Sleep -Milliseconds $SimulateCommitDelayMilliseconds
}
if ((Get-CanonicalDirectoryIdentity -Path $codexHomePath) -ne $transactionLockIdentity -or
    -not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths)) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Managed location changed immediately before commit."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}
$finalLiveInputs = [ordered]@{
    managedPathSafety = $true
    config = Get-Sha256Text -Text (Read-TextFile -Path $configPath)
    hooks = Get-Sha256Text -Text (Read-TextFile -Path $hooksPath)
    reviewer = Get-Sha256Text -Text (Read-TextFile -Path $reviewerPath)
    manifest = Get-Sha256Text -Text (Read-TextFile -Path $manifestPath)
    runtime = Get-Sha256File -Path $runtimePath
    runtimeMarker = Get-Sha256File -Path $runtimeMarkerPath
    runtimeDirectory = Get-DirectoryFingerprint -Directory $runtimeDirectory
    retentionState = Get-RetentionStateFingerprint -BackupsRoot $backupsRoot -VersionsRoot $versionsRoot
}
if ((ConvertTo-StableJson -Value $finalLiveInputs) -ne (ConvertTo-StableJson -Value $proposalMaterial.inputs)) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Managed inputs changed during the commit delay. Generate a new preview."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}

if ($action -eq "prune") {
    try {
        foreach ($candidate in @($prunePlan.candidates)) {
            $candidateRoot = if ([string]$candidate.kind -eq "backup") { $backupsRoot } else { $versionsRoot }
            Remove-VerifiedPruneCandidate -Path ([string]$candidate.path) -Root $candidateRoot -ExpectedFingerprint ([string]$candidate.fingerprint)
        }
        $result.status = "pruned"
        Write-Result -Result ([pscustomobject]$result)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 0
    }
    catch {
        $result.status = "approval-required"
        $result.messages = @($result.messages) + "A prune candidate changed during apply; preserved state requires a new preview."
        Write-Result -Result ([pscustomobject]$result)
        Exit-InstallerTransactionMutex -Mutex $transactionMutex
        exit 3
    }
}

$targetFiles = @($configPath, $hooksPath, $reviewerPath, $runtimePath, $runtimeMarkerPath, $manifestPath)
$snapshots = @(New-FileSnapshot -Paths $targetFiles)
$runtimeDirectoryExisted = Test-Path -LiteralPath $runtimeDirectory -PathType Container
$transactionDirectories = @(
    (Split-Path -Parent $reviewerPath),
    $operationsRoot,
    $versionsRoot,
    $runtimeDirectory,
    (Split-Path -Parent $backupsRoot),
    $backupsRoot
)
$transactionDirectoryState = @($transactionDirectories |
    Select-Object -Unique |
    ForEach-Object { [pscustomobject]@{ Path = $_; Existed = Test-Path -LiteralPath $_ -PathType Container } })
$backupCreated = $false

$snapshotByPath = @{}
foreach ($snapshot in $snapshots) { $snapshotByPath[[string]$snapshot.Path] = $snapshot }
$snapshotTextHash = {
    param([object]$Snapshot)
    if ($null -eq $Snapshot -or -not $Snapshot.Exists) { return $null }
    $memory = [System.IO.MemoryStream]::new($Snapshot.Bytes, $false)
    $reader = [System.IO.StreamReader]::new($memory, [System.Text.UTF8Encoding]::new($false), $true)
    try { return Get-Sha256Text -Text $reader.ReadToEnd() }
    finally { $reader.Dispose(); $memory.Dispose() }
}
$snapshotBoundInputs = [ordered]@{
    managedPathSafety = $true
    config = & $snapshotTextHash $snapshotByPath[$configPath]
    hooks = & $snapshotTextHash $snapshotByPath[$hooksPath]
    reviewer = & $snapshotTextHash $snapshotByPath[$reviewerPath]
    manifest = & $snapshotTextHash $snapshotByPath[$manifestPath]
    runtime = if ($snapshotByPath[$runtimePath].Exists) { Get-Sha256Bytes -Bytes $snapshotByPath[$runtimePath].Bytes } else { $null }
    runtimeMarker = if ($snapshotByPath[$runtimeMarkerPath].Exists) { Get-Sha256Bytes -Bytes $snapshotByPath[$runtimeMarkerPath].Bytes } else { $null }
    runtimeDirectory = Get-DirectoryFingerprint -Directory $runtimeDirectory
    retentionState = Get-RetentionStateFingerprint -BackupsRoot $backupsRoot -VersionsRoot $versionsRoot
}

if ((Get-CanonicalDirectoryIdentity -Path $codexHomePath) -ne $transactionLockIdentity -or
    -not (Test-ManagedPathSetSafe -CodexHomePath $codexHomePath -Paths $managedPaths) -or
    (ConvertTo-StableJson -Value $snapshotBoundInputs) -ne (ConvertTo-StableJson -Value $proposalMaterial.inputs)) {
    $result.status = "approval-required"
    $result.messages = @($result.messages) + "Managed location changed after snapshot and before the first mutation."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 3
}

try {
    Write-Backup -BackupPath $backupDestination -Snapshots $snapshots -Action $action
    $backupCreated = $true

    if ($null -eq $proposedConfig) {
        if (Test-Path -LiteralPath $configPath -PathType Leaf) { Remove-Item -LiteralPath $configPath -Force }
    }
    else {
        Write-TextAtomic -Path $configPath -Content $proposedConfig
    }

    if ($SimulateFailure) {
        throw "Simulated transaction failure."
    }

    if ($null -eq $proposedHooks) {
        if (Test-Path -LiteralPath $hooksPath -PathType Leaf) { Remove-Item -LiteralPath $hooksPath -Force }
    }
    else {
        Write-TextAtomic -Path $hooksPath -Content $proposedHooks
    }

    if ($null -eq $proposedReviewer) {
        if (Test-Path -LiteralPath $reviewerPath -PathType Leaf) { Remove-Item -LiteralPath $reviewerPath -Force }
    }
    else {
        Write-TextAtomic -Path $reviewerPath -Content $proposedReviewer
    }

    if ($action -eq "install") {
        Write-BytesAtomic -Path $runtimePath -Bytes $runtimeSourceBytes
        if ((Get-Sha256File -Path $runtimePath) -ne $runtimeSourceHash) {
            throw "Installed runtime bytes do not match the approved immutable hash."
        }
        $runtimeMarker = [ordered]@{
            schemaVersion = 1
            owner = "agent-operations"
            version = $script:RuntimeVersion
            sha256 = $runtimeSourceHash
        }
        Write-TextAtomic -Path $runtimeMarkerPath -Content (($runtimeMarker | ConvertTo-Json) + [Environment]::NewLine)

        $lastKnownGood = if ($null -ne $manifest -and (Get-ObjectProperty -Object $manifest -Name "state") -eq "active") {
            [string](Get-ObjectProperty -Object $manifest -Name "runtimeVersion")
        }
        else {
            [string](Get-ObjectProperty -Object $manifest -Name "lastKnownGoodVersion")
        }
        $telemetrySalt = if ([string]::IsNullOrWhiteSpace($existingTelemetrySalt)) { New-RandomSalt } else { $existingTelemetrySalt }
        $activationChallenge = New-RandomSalt
        $installManifest = [ordered]@{
            schemaVersion = 1
            owner = "agent-operations"
            runtimeVersion = $script:RuntimeVersion
            installedAt = [DateTime]::UtcNow.ToString("o")
            approvedProposalHash = $proposalHash
            installerOwnedHookFingerprints = $hookFingerprints
            installerOwnedReviewerFingerprint = $reviewerTemplateHash
            previousAgentSettings = $previousAgents
            createdFiles = $createdFiles
            backupPath = $backupDestination
            runtimeChecksums = [ordered]@{
                hook = $runtimeSourceHash
                marker = Get-Sha256File -Path $runtimeMarkerPath
            }
            telemetrySalt = $telemetrySalt
            activationChallenge = $activationChallenge
            state = "awaiting-trust"
            lastKnownGoodVersion = $lastKnownGood
        }
        Write-TextAtomic -Path $manifestPath -Content (($installManifest | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
        Invoke-InstalledSelfTest -RuntimeScript $runtimePath -ReviewerPath $reviewerPath
    }
    else {
        if (Test-Path -LiteralPath $runtimeDirectory -PathType Container) {
            Remove-SafeTree -Path $runtimeDirectory -Root $versionsRoot
        }
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            Remove-Item -LiteralPath $manifestPath -Force
        }
    }

    Complete-Backup -BackupPath $backupDestination
    $result.status = if ($action -eq "install") { "installed-awaiting-trust" } else { "uninstalled" }
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 0
}
catch {
    Restore-FileSnapshot -Snapshots $snapshots
    if (-not $runtimeDirectoryExisted -and (Test-Path -LiteralPath $runtimeDirectory -PathType Container)) {
        Remove-SafeTree -Path $runtimeDirectory -Root $versionsRoot
    }
    if ($backupCreated -and (Test-Path -LiteralPath $backupDestination -PathType Container)) {
        Remove-SafeTree -Path $backupDestination -Root $backupsRoot
    }
    foreach ($directoryState in @($transactionDirectoryState | Sort-Object { $_.Path.Length } -Descending)) {
        if (-not $directoryState.Existed) {
            Remove-EmptyManagedDirectory -Path $directoryState.Path -Root $codexHomePath
        }
    }
    $result.status = "rolled-back"
    $result.messages = @($result.messages) + "Transaction failed and all managed targets were restored."
    Write-Result -Result ([pscustomobject]$result)
    Exit-InstallerTransactionMutex -Mutex $transactionMutex
    exit 4
}
