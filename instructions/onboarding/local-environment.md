# Onboarding: Local Environment

## Когда применять

- При подключении consumer-репозитория, где build/test/run зависит от локального SDK, workload, package manager, browser, native toolchain или внешнего endpoint.
- Когда повторяемые environment failures нужно обнаруживать до реализации.

## Когда не применять

- Для репозитория с уже проверенным эквивалентным local-environment contract.
- Как разрешение скрыто устанавливать зависимости или изменять пользовательскую систему.

## MUST

- Хранить точные repo-specific setup/preflight/action commands рядом с consumer code; central catalog задаёт только contract и шаблон.
- Preflight должен быть read-only по умолчанию и проверять необходимые commands, SDK/runtime/workloads, package/restore/auth reachability, required paths и browser/UI/native dependencies.
- Не устанавливать toolchain, workload, certificate, browser или credential без явного repo policy и пользовательского разрешения.
- Отделять отсутствующую dependency, auth/network blocker и product failure в результате preflight.
- Для long-running actions указывать ожидаемую длительность, progress/log artifact и repo-specific timeout strategy.
- Для Windows использовать PowerShell-safe команды и literal paths.
- Не хранить secrets, tokens, private endpoints и absolute user paths в versioned local-environment template.
- Подключать script через local environment, созданный поддерживаемой Codex Desktop поверхностью; не изобретать undocumented `.codex` schema и не заявлять CLI support без отдельного подтверждённого contract.
- Проверять generated consumer config и smoke flow отдельным repo-specific change set.

## SHOULD

- Предоставлять отдельные actions для restore/setup check, targeted tests, full tests, build и local run.
- Возвращать machine-readable summary наряду с коротким human-readable результатом.
- Делать missing optional dependency warning, а missing required dependency — failing preflight.

## MAY

- Расширять central `preflight.ps1` параметрами consumer repo без копирования общих правил.
- Проверять network endpoints только когда они явно переданы пользователем или repo config.

## Команды

```powershell
& .\templates\codex\local-environment\preflight.ps1 `
  -RequiredCommand @("git", "pwsh", "dotnet") `
  -RequiredPath @(".")
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/onboarding/quick-start.md](./quick-start.md)
- [instructions/core/tool-execution-baseline.md](../core/tool-execution-baseline.md)
- [templates/codex/local-environment/README.md](../../templates/codex/local-environment/README.md)
