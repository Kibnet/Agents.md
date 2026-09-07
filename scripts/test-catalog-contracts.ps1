[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/Catalog.Markdown.psm1') -Force
$script:Assertions = 0
function Assert-Contract([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:Assertions++
}
$nl = "`n"
$cases = @(
    @{ Name='backticks'; Text=('```text'+$nl+'## MUST'+$nl+'[bad](missing.md)'+$nl+'```'); Errors=0 },
    @{ Name='tildes'; Text=('~~~'+$nl+'## MUST'+$nl+'[bad](missing.md)'+$nl+'~~~'); Errors=0 },
    @{ Name='longer outer'; Text=('````markdown'+$nl+'```'+$nl+'## MUST'+$nl+'```'+$nl+'````'); Errors=0 },
    @{ Name='longer closing'; Text=('```'+$nl+'## MUST'+$nl+'`````'); Errors=0 },
    @{ Name='mixed cannot close'; Text=('```'+$nl+'## MUST'+$nl+'~~~'); Errors=1 },
    @{ Name='shorter cannot close'; Text=('````'+$nl+'## MUST'+$nl+'```'); Errors=1 },
    @{ Name='trailing text cannot close'; Text=('```'+$nl+'## MUST'+$nl+'``` invalid'); Errors=1 },
    @{ Name='EOF'; Text=('```'+$nl+'## MUST'); Errors=1 },
    @{ Name='three spaces'; Text=('   ~~~'+$nl+'## MUST'+$nl+'   ~~~'); Errors=0 }
)
foreach ($case in $cases) {
    $parsed = Get-CatalogMarkdownStructure -Markdown $case.Text
    Assert-Contract ($parsed.Errors.Count -eq $case.Errors) "$($case.Name): fence diagnostics"
    Assert-Contract (-not (Test-CatalogSection -Content $parsed.Content -Heading '## MUST')) "$($case.Name): code heading must not satisfy document contract"
    Assert-Contract (-not $parsed.LinkContent.Contains('[bad]')) "$($case.Name): code link hidden"
}
$inline = Get-CatalogMarkdownStructure -Markdown ('Text `[bad](missing.md)` then [real](real.md)'+$nl+'``a`b [bad2](missing.md)``')
Assert-Contract (-not $inline.LinkContent.Contains('[bad]')) 'Inline code is not a link'
Assert-Contract (-not $inline.LinkContent.Contains('[bad2]')) 'Equal-length multi-backtick inline code'
Assert-Contract ($inline.LinkContent.Contains('[real]')) 'Real link stays visible'
foreach ($slashCount in 1..4) {
    $escaped = Get-CatalogMarkdownStructure -Markdown (('\' * $slashCount) + '`[private](C:/Users/Kibnet/private.md)`')
    Assert-Contract ($escaped.LinkContent.Contains('[private]') -eq ($slashCount % 2 -eq 1)) "Opening backtick escape parity $slashCount"
}
$literalSlash = Get-CatalogMarkdownStructure -Markdown '`[hidden](missing.md)\` [real](real.md)'
Assert-Contract (-not $literalSlash.LinkContent.Contains('[hidden]') -and $literalSlash.LinkContent.Contains('[real]')) 'Backslash inside code does not escape closing delimiter'
foreach ($boundary in @("`n`n", "`n   `n", "`n# Heading ", "`n- List ")) {
    $separateBlocks = Get-CatalogMarkdownStructure -Markdown ('First unmatched `' + $boundary + '[private](C:/Users/Kibnet/private.md)' + $boundary + 'Last unmatched `')
    Assert-Contract ($separateBlocks.LinkContent.Contains('[private]')) 'Unmatched delimiters cannot span block boundaries'
}
$multiline = Get-CatalogMarkdownStructure -Markdown ('`code' + "`n" + '[hidden](missing.md)`')
Assert-Contract (-not $multiline.LinkContent.Contains('[hidden]')) 'A soft newline inside a paragraph remains code'
$valid = '## MUST'+$nl+'- Rule'+$nl+'## Связанные документы'+$nl+'- [Owner](owner.md)'
Assert-Contract (Test-CatalogSection -Content $valid -Heading '## MUST') 'Nonempty section passes'
Assert-Contract (-not (Test-CatalogSection -Content ('## MUST'+$nl+$nl+'## Other') -Heading '## MUST')) 'Empty section fails'
$notFence = Get-CatalogMarkdownStructure -Markdown ('``text'+$nl+'## MUST'+$nl+'- Rule')
Assert-Contract (Test-CatalogSection -Content $notFence.Content -Heading '## MUST') 'Two delimiters are not a fence'
Write-Host "PASS: catalog Markdown contracts ($script:Assertions assertions)"
