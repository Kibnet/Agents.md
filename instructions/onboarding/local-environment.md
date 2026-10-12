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

- Использовать central текстовый checklist для выбора repo-specific preflight commands; каталог не поставляет executable preflight.
- Проверять network endpoints только когда они явно переданы пользователем или repo config.

## Команды

Проверить фактические команды/SDK/paths проекта по [текстовому preflight checklist](../../templates/codex/local-environment/README.md), затем выполнить read-only команды из его локального environment contract. Отчёт должен отличать missing required dependency, optional warning, auth/network blocker и product failure.


## Состояния ранее установленной внешней интеграции

Следующие правила относятся только к реально существующему и отдельно согласованному operational runtime. Каталог не поставляет installer/probe/analyzer/hook implementation и их config. Удаление исходников из поставки не удаляет и не мигрирует installed integration. При source-script dependency active обновление требует отдельного reference preflight и migration scope.

### Состояния и область активации

| Действие | Согласованный scope / evidence | Результат |
| --- | --- | --- |
| Применить каталог | Approved repository change set, isolated validation, drift/backup | Новый central catalog; installed runtime не меняется |
| Установить runtime | Отдельно approved exact installer proposal/hash | installed-awaiting-trust |
| Доверить hooks | Пользователь проверил exact definition в host `/hooks` | Manual trust, ещё не active |
| Probe / MarkActive | Current install/config/runtime + свежие controlled runtime/reviewer observations, полный approved postimage | active |

Разрешение действует внутри указанного scope и не запрашивается повторно для того же действия. Смена external side effects требует соответствующего scope. Reviewer evidence v1 не принимается для новой активации; существующий active manifest не дезактивируется автоматически. Предсуществующий reviewer installer не принимает под lifecycle ownership; uninstall его сохраняет.

Telemetry runtime 3.2.0 использует только Windows local NTFS. Unsupported filesystem/API, reparse/hardlink/ownership conflict или deadline приводят к skip telemetry, сохраняя warn-only классификацию. Legacy logs без identity/generation binding не удаляются и не усыновляются автоматически; при конфликте пути нужен отдельно согласованный migration scope. На следующем успешном maintenance owned segments с событиями старше 45 дней удаляются; append срок не продлевает, фонового удаления без запусков hook нет. Для ограничения retention может удаляться целый сегмент вместе с более свежими событиями.

Analyzer metrics относятся к selected-stratified-sample; recall/FPR не являются population estimate и не доказывают причинное снижение ошибок. TCP endpoint preflight имеет `level=tcp-connect`; он не доказывает HTTP/auth/TLS readiness — эти проверки добавляет consumer.

## Локальные pointers для tracker/knowledge

Для workflow Unlimotion задавать private-local task-space, vault root и current profile pointer через пользовательские инструкции или локальный onboarding; переносимый каталог содержит только placeholders. Проверить доступность pointers и установленного `unlimotion-cli` skill/CLI по [task-context](../contexts/unlimotion-task-context.md). Отсутствие pointer не разрешает выбирать другой источник. Установка skill/CLI требует собственного разрешения и не входит в подключение этих owners.

| Pointer | Локальное значение |
| --- | --- |
| Task-space scope | `<absolute-authorized-task-space>` |
| Vault root | `<absolute-private-knowledge-root>` |
| Personal quick context | `<current-user-provided-profile-pointer>` |
| Night protocol, если применим | `<current-user-provided-protocol-pointer>` |

Не переносить заполненные private paths/profile в Git или публичные fixtures.

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/onboarding/quick-start.md](./quick-start.md)
- [instructions/core/tool-execution-baseline.md](../core/tool-execution-baseline.md)
- [templates/codex/local-environment/README.md](../../templates/codex/local-environment/README.md)
