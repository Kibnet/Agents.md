Set-StrictMode -Version Latest

function Get-CatalogMarkdownStructure {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Markdown)

    $buffer = [System.Text.StringBuilder]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    $fenceCharacter = [char]0
    $fenceLength = 0
    $fenceLine = 0
    $lineNumber = 0
    foreach ($line in ($Markdown -split '\r?\n')) {
        $lineNumber++
        if ($fenceLength -gt 0) {
            $closing = [regex]::Match($line, '^ {0,3}(`+|~+)[ \t]*$')
            if ($closing.Success -and $closing.Groups[1].Value[0] -eq $fenceCharacter -and
                $closing.Groups[1].Length -ge $fenceLength) {
                $fenceLength = 0
            }
            [void]$buffer.AppendLine('')
            continue
        }
        $opening = [regex]::Match($line, '^ {0,3}(`{3,}|~{3,})(.*)$')
        if ($opening.Success -and -not ($opening.Groups[1].Value[0] -eq '`' -and $opening.Groups[2].Value.Contains('`'))) {
            $fenceCharacter = $opening.Groups[1].Value[0]
            $fenceLength = $opening.Groups[1].Length
            $fenceLine = $lineNumber
            [void]$buffer.AppendLine('')
            continue
        }
        [void]$buffer.AppendLine($line)
    }
    if ($fenceLength -gt 0) { $errors.Add("Незакрытый code fence (строка $fenceLine)") }
    $content = $buffer.ToString()
    # Escaping applies to opening delimiters; inside code spans backslashes are literal.
    $masked = $content.ToCharArray()
    $runs = [regex]::Matches($content, '`+')
    for ($runIndex = 0; $runIndex -lt $runs.Count; $runIndex++) {
        $openingRun = $runs[$runIndex]
        $slashes = 0
        for ($offset = $openingRun.Index - 1; $offset -ge 0 -and $content[$offset] -eq '\'; $offset--) { $slashes++ }
        if ($slashes % 2 -eq 1) { continue }
        for ($closingIndex = $runIndex + 1; $closingIndex -lt $runs.Count; $closingIndex++) {
            $closingRun = $runs[$closingIndex]
            $between = $content.Substring($openingRun.Index + $openingRun.Length, $closingRun.Index - $openingRun.Index - $openingRun.Length)
            # Inline code cannot join separate paragraphs or interrupting block constructs.
            if ($between -match '\r?\n[ \t]*\r?\n|\r?\n {0,3}(?:#{1,6}[ \t]|>|[-+*][ \t]|\d+[.)][ \t]|(?:-{3,}|_{3,}|\*{3,})[ \t]*(?:\r?\n|$))') { break }
            if ($closingRun.Length -ne $openingRun.Length) { continue }
            for ($offset = $openingRun.Index; $offset -lt $closingRun.Index + $closingRun.Length; $offset++) {
                if ($masked[$offset] -ne "`r" -and $masked[$offset] -ne "`n") { $masked[$offset] = ' ' }
            }
            $runIndex = $closingIndex
            break
        }
    }
    $linkContent = -join $masked
    [pscustomobject]@{ Content = $content; LinkContent = $linkContent; Errors = @($errors.ToArray()) }
}

function Test-CatalogSection {
    param([string]$Content, [string]$Heading)
    $match = [regex]::Match($Content, '(?m)^' + [regex]::Escape($Heading) + '[ \t]*\r?$')
    if (-not $match.Success) { return $false }
    $tail = $Content.Substring($match.Index + $match.Length)
    $next = [regex]::Match($tail, '(?m)^#{1,2} ')
    if ($next.Success) { $tail = $tail.Substring(0, $next.Index) }
    return -not [string]::IsNullOrWhiteSpace($tail)
}

Export-ModuleMember -Function Get-CatalogMarkdownStructure, Test-CatalogSection
