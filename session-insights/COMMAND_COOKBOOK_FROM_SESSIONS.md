# Command Cookbook From Sessions

Дата подготовки: 2026-06-05.

Назначение: практические командные паттерны, которые уменьшают вероятность повторяющихся ошибок в Windows/PowerShell, .NET, GitHub, Android и artifact workflows.

## PowerShell Basics

### Inline Python

Не использовать:

```powershell
python - <<'PY'
print("bad in PowerShell")
PY
```

Использовать:

```powershell
@'
print("ok")
'@ | python -
```

### File Line Output

Не использовать:

```powershell
"$file:$($_.LineNumber)"
```

Использовать:

```powershell
"{0}:{1}" -f $file, $_.LineNumber
"${file}:$($_.LineNumber)"
```

### Ranges

Не использовать:

```powershell
Select-Object -Index 200..245
```

Использовать:

```powershell
Select-Object -Index (200..245)
Select-Object -Skip 200 -First 46
```

### Multiple Pattern Search

Prefer:

```powershell
rg -n -e "pattern1" -e "pattern2" src tests
```

This avoids broken regex/quoting when patterns include `|` or `--`.

## Repository Discovery

```powershell
rg --files -g "*.sln" -g "*.csproj" -g "package.json" -g "pyproject.toml" -g "global.json" -g "AGENTS*.md"
rg -n "TUnit|xunit|NUnit|Microsoft.Testing.Platform|Playwright|FlaUI|Avalonia.Headless" . -g "*.csproj" -g "*.props" -g "*.targets" -g "*.md"
```

Exclude heavy folders when needed:

```powershell
rg -n "SearchTerm" src tests specs docs .github -g "!bin" -g "!obj" -g "!artifacts" -g "!TestResults"
```

## .NET Build And Test

### Basic

```powershell
dotnet build
dotnet test
```

### Targeted Project

```powershell
dotnet test .\tests\<Project>.csproj --no-restore
```

Use `--no-restore` only if restore is known current.

### TUnit Targeted

```powershell
dotnet run --project <test-project>.csproj -- --treenode-filter "/*/*/<ClassName>/*<TestName>*" --no-progress
```

### TUnit Direct Executable

```powershell
.\path\to\TestProject.exe --treenode-filter "/*/*/<ClassName>/*" --maximum-parallel-tests 1 --parallelism-strategy fixed --no-ansi --no-progress --timeout 45m
```

### Build Server Cleanup

Use when stale build/testhost processes look likely:

```powershell
dotnet build-server shutdown
```

## Agents Repository Validation

```powershell
pwsh -File scripts\validate-instructions.ps1
pwsh -File scripts\test-validate-instructions.ps1
```

## Git / GitHub

### Local State

```powershell
git status --short
git branch --show-current
git log --oneline -n 20
git diff --stat
```

### Branch / Remote Safety

```powershell
git remote -v
git ls-remote --heads origin <branch-name>
```

### GitHub CLI Auth

```powershell
gh auth status
```

Prefer GitHub connector tools when available. Use `gh` only after auth is confirmed.

## Android

### Preflight

```powershell
Get-Command adb -ErrorAction SilentlyContinue
adb devices
```

### Logcat

```powershell
adb logcat -c
adb shell monkey -p <package-name> 1
adb logcat -d
```

### Build With Explicit SDK/JDK

```powershell
$env:ANDROID_SDK_ROOT = '<ANDROID_SDK_ROOT>'
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:JAVA_HOME = '<JAVA_HOME>'
dotnet build <android-project>.csproj -c Debug -t:Package -p:RuntimeIdentifier=android-arm64
```

## Python / Node Tooling

### Python Package Check

```powershell
@'
import importlib.util
for name in ["yaml", "playwright", "PIL"]:
    print(name, bool(importlib.util.find_spec(name)))
'@ | python -
```

### Node Package Check

```powershell
node -e "for (const m of ['playwright','@playwright/test']) { try { require.resolve(m); console.log(m, 'ok') } catch { console.log(m, 'missing') } }"
```

### npx Network/API

If `npx` installs a package but API call fails, separate package availability from endpoint connectivity/auth.

## Screenshot / Visual Evidence

Use the available skill/tool for the environment:

- local app screenshot: Browser/Computer Use/screenshot skill depending on target;
- existing image file: `view_image`;
- web app: Playwright/browser screenshot if dependencies exist;
- generated docs/presentation: render pages/slides first.

Do not finish UI polish without looking at the result.

## Secret Safety

Before commit:

```powershell
git diff --cached
rg -n "token|secret|apiKey|password|ssh|private" . -g "!bin" -g "!obj" -g "!artifacts"
```

This is a heuristic; it does not replace careful review.

## Handling Timeouts

When a command times out:

1. Check if partial output already contains the answer.
2. Narrow scope.
3. Increase timeout only if the command is necessary and bounded.
4. Consider direct executable over `dotnet test` if runner startup is expensive.
5. Report timeout and next-best evidence.
