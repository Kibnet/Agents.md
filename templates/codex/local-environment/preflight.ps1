[CmdletBinding()]
param(
    [string[]]$RequiredCommand = @(),
    [string[]]$OptionalCommand = @(),
    [string[]]$RequiredPath = @(),
    [string[]]$Endpoint = @(),
    [ValidateSet("Text", "Json")]
    [string]$OutputFormat = "Text"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$checks = [System.Collections.Generic.List[object]]::new()

foreach ($name in $RequiredCommand) {
    $found = $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
    $checks.Add([pscustomobject]@{ kind = "command"; name = $name; required = $true; ok = $found })
}

foreach ($name in $OptionalCommand) {
    $found = $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
    $checks.Add([pscustomobject]@{ kind = "command"; name = $name; required = $false; ok = $found })
}

foreach ($path in $RequiredPath) {
    $found = Test-Path -LiteralPath $path
    $checks.Add([pscustomobject]@{ kind = "path"; name = $path; required = $true; ok = $found })
}

foreach ($uriText in $Endpoint) {
    $ok = $false
    try {
        $uri = [uri]$uriText
        $port = $uri.Port
        if ($port -lt 1) { throw "Endpoint scheme has no usable default port." }
        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $connect = $client.ConnectAsync($uri.Host, $port)
            $ok = $connect.Wait([TimeSpan]::FromSeconds(3)) -and $client.Connected
        }
        finally {
            $client.Dispose()
        }
    }
    catch {
        $ok = $false
    }
    $checks.Add([pscustomobject]@{ kind = "endpoint"; name = $uriText; required = $true; ok = $ok })
}

$requiredFailures = @($checks | Where-Object { $_.required -and -not $_.ok })
$result = [pscustomobject]@{
    schemaVersion = 1
    ok = $requiredFailures.Count -eq 0
    checks = @($checks)
}

if ($OutputFormat -eq "Json") {
    $result | ConvertTo-Json -Depth 5
}
else {
    foreach ($check in $checks) {
        $status = if ($check.ok) { "PASS" } elseif ($check.required) { "FAIL" } else { "WARN" }
        Write-Host ("{0}: {1} {2}" -f $status, $check.kind, $check.name)
    }
}

if (-not $result.ok) {
    exit 1
}
