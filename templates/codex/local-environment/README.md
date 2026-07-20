# Local environment template

`preflight.ps1` — read-only PowerShell template для ранней проверки локального toolchain consumer-репозитория.

## Подключение

1. Скопируйте или вызовите script из repo-specific action.
2. Передайте только фактические required/optional commands, paths и endpoints проекта.
3. Создайте local environment через поддерживаемую Codex Desktop поверхность и свяжите его action с script; не создавайте `.codex` config по недокументированной схеме и не предполагайте CLI support.
4. Запустите preflight, targeted tests, full tests и build в отдельном smoke change.

```powershell
& .\preflight.ps1 `
  -RequiredCommand @("git", "pwsh", "dotnet") `
  -OptionalCommand @("node", "rg") `
  -RequiredPath @(".") `
  -OutputFormat Json
```

Template ничего не устанавливает и не меняет конфигурацию машины. Network checks выполняются только для явно переданных `-Endpoint`.
