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


## Состояния и область активации

| Действие | Согласованный scope / evidence | Результат |
| --- | --- | --- |
| Применить каталог | Approved repository change set, isolated validation, drift/backup | Новый central catalog; installed runtime не меняется |
| Установить runtime | Отдельно approved exact installer proposal/hash | installed-awaiting-trust |
| Доверить hooks | Пользователь проверил exact definition в host `/hooks` | Manual trust, ещё не active |
| Probe / MarkActive | Current install/config/runtime + свежие controlled runtime/reviewer observations, полный approved postimage | active |

Разрешение действует внутри указанного scope и не запрашивается повторно для того же действия. Смена external side effects требует соответствующего scope. Reviewer evidence v1 не принимается для новой активации; существующий active manifest не дезактивируется автоматически. Предсуществующий reviewer installer не принимает под lifecycle ownership; uninstall его сохраняет.

Telemetry runtime 3.2.0 использует только Windows local NTFS. Unsupported filesystem/API, reparse/hardlink/ownership conflict или deadline приводят к skip telemetry, сохраняя warn-only классификацию. Legacy logs без identity/generation binding не удаляются и не усыновляются автоматически; при конфликте пути нужен отдельно согласованный migration scope. На следующем успешном maintenance owned segments с событиями старше 45 дней удаляются; append срок не продлевает, фонового удаления без запусков hook нет. Для ограничения retention может удаляться целый сегмент вместе с более свежими событиями.

Analyzer metrics относятся к selected-stratified-sample; recall/FPR не являются population estimate и не доказывают причинное снижение ошибок. TCP endpoint preflight имеет `level=tcp-connect`; он не доказывает HTTP/auth/TLS readiness — эти проверки добавляет consumer.

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/onboarding/quick-start.md](./quick-start.md)
- [instructions/core/tool-execution-baseline.md](../core/tool-execution-baseline.md)
- [templates/codex/local-environment/README.md](../../templates/codex/local-environment/README.md)
