# Changelog

All notable changes to this instruction catalog are documented in this file.

## [3.1.0] - 2026-07-17

### Added

- Добавлен обязательный [tool-execution-baseline.md](instructions/core/tool-execution-baseline.md) для раннего path/toolchain/Git preflight, Windows-safe PowerShell, нормализации `rg` exit `1`, конечного patch retry и классификации environment blockers.
- Добавлены warn-only `PreToolUse`/`PostToolUse` runtime, non-managed hook template, immutable-version installer с exact `proposalHash`, backup/rollback/uninstall/prune, evidence-bound `-MarkActive`, controlled activation probe и personal [independent-reviewer.toml](templates/codex/agents/independent-reviewer.toml).
- Добавлены потоковый privacy-safe session analyzer, deterministic broad sampling, independent private-gold thresholds, synthetic fixtures и единый `test-agent-operations.ps1` для hooks, installer, analyzer, retention и privacy contracts.
- Добавлены [local-environment.md](instructions/onboarding/local-environment.md) и Windows preflight template для отдельных consumer-repository rollout без скрытой установки toolchain.

### Changed

- Routing подключает operational owner для каждой tool-heavy задачи, не вытесняя task-specific context; session insights остаётся targeted historical retrieval layer.
- Collaboration, testing и review owners теперь требуют one-writer ownership, serial shared-output validation, staged `targeted -> build -> full`, no-blind-retry и effective read-only evidence для independent reviewer.
- Standard validator проверяет новые owner/runtime/CI markers, ровно два поддержанных hook events и не сканирует ignored `.artifacts`/private-local Markdown; Linux job выполняет catalog regressions, а отдельный `windows-latest` job запускает полный набор hook, installer, analyzer и privacy contracts.
- Installer сериализует physical aliases одного Codex home, отвергает intermediate reparse paths до managed reads и перед commit, записывает захваченный byte snapshot runtime и раскрывает exact `config.toml`/`hooks.json`/reviewer postimages с bounded generated fields.
- Activation evidence теперь отдельно фиксирует manual hook trust и controlled host task, связывает runtime observation с install-specific challenge, исполняет hash-verified captured runtime bytes из одноразового staging path, повторно проверяет live runtime, истекает не позднее 15 минут и проверяется непосредственно перед записью полного active manifest postimage.
- Analyzer дедуплицирует active/archive trace copies и repeated call IDs, сворачивает nested child traces в root task и разделяет legacy envelopes, matched pairs, unmatched calls/outputs и cross-window exclusions; post-`Until` records не меняют исторический window.
- Behavioral/gold/review schemas теперь проверяются contract tests: smoke использует полный уникальный набор scenario IDs, PASS review требует write denial и улучшение всех сценариев, gold labels хранятся в hash-keyed map без duplicate evidence IDs.
- Local-environment onboarding ограничен документированной Codex Desktop поверхностью; copy-ready PowerShell examples используют настоящие array arguments и покрыты multi-command regression test.

### Security / Privacy

- Hooks работают только в `warn-only`/`fail-open`, не возвращают block/retry decisions и под межпроцессным lock записывают bounded allowlisted telemetry с локальной случайной salt, без raw command, output, prompt, path, environment или secret fields.
- Telemetry file lock общий для lexical aliases одного physical logs directory; неуспешный rotation rollback оставляет checksum-bound recovery marker/copies, которые удаляются только после 7 дней, повторной проверки ownership/name/hash/reparse и quarantine commit. Частичный cleanup не восстанавливает marker, который ссылался бы на уже удалённые bytes.
- Global sandbox/approval policy и consumer repositories не меняются; versioned implementation не активирует user hooks, reviewer или runtime.

### Migration / Rollback

- Фраза `Спеку подтверждаю` разрешает только repository implementation. Global activation требует delivered active catalog, exact `-WhatIf` proposal, отдельного hash-bound approval и ручного trust non-managed hook definition.
- Installer удаляет только fingerprint-matched managed state, сохраняет foreign TOML/hooks и user drift, ограничивает logs до 10 MB / 3 files / 45 days, backups до 10 и runtime versions до 3 через отдельный previewed prune.
- Состояние `awaiting-trust -> active` требует свежего evidence с manual trust, controlled host task, install-bound runtime challenge и effective reviewer write denial; истёкший между preview и commit evidence оставляет manifest без изменений.

## [3.0.0] - 2026-07-14

### Added

- Добавлен trigger-based owner [openai-responses-api.md](instructions/governance/openai-responses-api.md) для exact GPT-5.6 API routing, persisted reasoning, stateless replay, Programmatic Tool Calling, Responses multi-agent и end-user `safety_identifier`.
- В [README.md](README.md) добавлена датированная Surface Contract Matrix, которая разделяет standard ChatGPT, Work/Codex и OpenAI API и не переносит availability, aliases, Pro/Ultra semantics между поверхностями.
- Validator получил semantic contracts для GPT-5.6 target, API owner, surface metadata и обязательного before/after behavioral smoke; test suite покрывает отсутствие API owner и возврат stale declared target `GPT-5.5`.

### Changed

- **BREAKING:** целевая optimization baseline каталога переведена с `GPT-5.5` на семейство `GPT-5.6`; consumer workflows, которые проверяют старые target markers или полагаются на GPT-5.5-specific prompt duplication, должны перейти на surface-aware contract.
- [model-behavior-baseline.md](instructions/core/model-behavior-baseline.md) теперь разделяет target family и effective runtime, задаёт Sol/Terra/Luna workload guidance, lean prompt rules и evidence-based escalation reasoning/tier/Pro/Ultra.
- [collaboration-baseline.md](instructions/core/collaboration-baseline.md) стал единственным owner communication preamble и явно разделяет read-only requests, разрешённые in-scope implementation actions и операции, требующие нового полномочия.
- [routing-matrix.md](instructions/governance/routing-matrix.md), [AGENTS.md](AGENTS.md), [templates/specs/_template.md](templates/specs/_template.md) и [review-loops.md](instructions/governance/review-loops.md) синхронизированы с GPT-5.6 surface/effective-runtime evidence и обязательным same-profile behavior regression smoke.

### Migration / Rollback

- Для model-sensitive validation нужно фиксировать реальную surface, exact model/tier, reasoning level/mode и fallback; API alias `gpt-5.6` не считается универсальной гарантией для product/CLI surfaces.
- Rollback выполняется единым откатом change set `3.0.0`; частичный возврат только model marker без API owner, routing, template и validator недопустим.

## [2.11.0] - 2026-07-10

### Changed

- Усилен `QUEST` workflow против поздних доработок после approval/EXEC:
  - [templates/specs/_template.md](templates/specs/_template.md) теперь содержит preventive sections `User-Observable Scenarios`, `State / Interaction Matrix`, `Decision Ledger`, `Runtime / Config / Data Contract Matrix`, `Acceptance-to-Test Matrix`, `Expected User Review Objections` и `Role-Based Review Result`;
  - [quest-mode.md](instructions/core/quest-mode.md) и [quest-governance.md](instructions/core/quest-governance.md) теперь требуют `Pre-Approval Rework Prevention Gate` перед запросом `Спеку подтверждаю` и `User-Observable Completion Gate` перед финальным EXEC-отчётом;
  - [review-loops.md](instructions/governance/review-loops.md) теперь добавляет `Role-Based pass` и применимость ролей business analyst, UX/designer, tester, developer/architect и delivery/operations/security;
  - [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md) и [quest-prompt-exec.md](instructions/core/quest-prompt-exec.md) синхронизированы с preventive gates и user-observable evidence checks.

## [2.10.0] - 2026-06-13

### Added

- Добавлен BDD/Gherkin слой в [storm-product-development.md](instructions/profiles/storm-product-development.md):
  - новая artifact chain `Vision -> Product Goal -> Need / Constraint -> Story -> Gherkin Rule -> Gherkin Scenario -> Automated Test / Step Definition -> Code`;
  - правила `.feature` files, tags, scenario statuses, coverage roles, behavior coverage и scenario quality;
  - команды `/storm:gherkin`, `/storm:bdd-sync`, `/storm:bdd-lint`, `/storm:bdd-conflicts`, `/storm:bdd-implement ST-XXXX`.
- Добавлены canonical BDD assets:
  - [feature-template.feature](templates/storm/feature-template.feature);
  - prompt templates [11-generate-gherkin.md](prompts/storm/11-generate-gherkin.md), [12-bdd-sync.md](prompts/storm/12-bdd-sync.md), [13-bdd-lint.md](prompts/storm/13-bdd-lint.md), [14-bdd-conflicts.md](prompts/storm/14-bdd-conflicts.md), [15-bdd-implement-story.md](prompts/storm/15-bdd-implement-story.md).

### Changed

- [storm-artifacts.schema.json](schemas/storm-artifacts.schema.json) расширена опциональными секциями `gherkin_features`, `gherkin_rules`, `gherkin_scenarios` и `step_definitions`.
- [validate-artifacts.py](scripts/storm/validate-artifacts.py) теперь проверяет Gherkin traceability, required tags, automation links, orphan scenarios, deprecated drift and behavior coverage metrics.
- [rank-backlog.py](scripts/storm/rank-backlog.py) учитывает `scenario_automation_cost` и `step_reuse_penalty` в agentic effort.
- [AGENTS.md](AGENTS.md), [README.md](README.md), [routing-matrix.md](instructions/governance/routing-matrix.md) и [validate-instructions.ps1](scripts/validate-instructions.ps1) синхронизированы с BDD/Gherkin командами STORM.

## [2.9.0] - 2026-06-12

### Added

- Добавлен сценарный профиль [storm-product-development.md](instructions/profiles/storm-product-development.md) для STORM product workflow и команд `/storm:*`:
  - фиксирует artifact model `docs/product/storm.json`, ID/status/provenance/confidence rules и traceability `story -> acceptance criteria -> tests -> code`;
  - разделяет safe artifact-only full-cycle и команды с изменениями tests/code/behavior, которые должны идти через `delivery-task` и `QUEST`;
  - описывает bootstrap, trace, coverage, derive, expand, conflicts, cleanup, ranking, implementation и audit contracts.
- Добавлены canonical STORM assets:
  - prompt templates в [prompts/storm](prompts/storm);
  - starter templates в [templates/storm](templates/storm);
  - JSON schema [storm-artifacts.schema.json](schemas/storm-artifacts.schema.json);
  - scripts [validate-artifacts.py](scripts/storm/validate-artifacts.py) и [rank-backlog.py](scripts/storm/rank-backlog.py).

### Changed

- [routing-matrix.md](instructions/governance/routing-matrix.md) теперь маршрутизирует `/storm:*`, living product specification, cloud-conflict analysis и dependency-aware ranking на `storm-product-development`.
- [AGENTS.md](AGENTS.md), [README.md](README.md), [validate-instructions.ps1](scripts/validate-instructions.ps1) и [test-validate-instructions.ps1](scripts/test-validate-instructions.ps1) обновлены для STORM как поддерживаемого guided workflow центрального каталога.

## [2.8.0] - 2026-06-11

### Added

- Добавлен context-документ [session-insights-context.md](instructions/contexts/session-insights-context.md) для безопасной on-demand загрузки session-derived lessons, runbooks и workflow preferences:
  - фиксирует trigger-based lookup через `session-insights/README.md`;
  - ограничивает загрузку 1-3 релевантными источниками по умолчанию;
  - требует проверять drift-prone факты в текущем workspace;
  - запрещает stage/commit `private-local` артефактов без явного решения пользователя.
- Добавлен sanitized operational каталог [session-insights](session-insights/README.md) с частыми ошибками агента, command/validation cookbooks, UI rubric, repo runbooks и backlog улучшений.

### Changed

- [routing-matrix.md](instructions/governance/routing-matrix.md) теперь маршрутизирует прошлые Codex-сессии, known repo runbooks, повторяющиеся ошибки агента и workflow preferences на `session-insights-context`.
- [validate-instructions.ps1](scripts/validate-instructions.ps1) и [test-validate-instructions.ps1](scripts/test-validate-instructions.ps1) считают новый context и sanitized session-insights subset частью валидного каталога.

## [2.7.0] - 2026-05-15

### Changed

- Усилен обязательный `QUEST` review-loop против поверхностного `PASS`:
  - [review-loops.md](instructions/governance/review-loops.md) теперь требует full review-loop с `Scope/Evidence pass`, `Contract pass`, `Adversarial risk pass`, `Fix and re-review`, `Stop decision`, no-evidence/no-pass rules, depth checklist и manual-review challenge;
  - [templates/specs/_template.md](templates/specs/_template.md) теперь содержит audit fields `Review passes`, `Evidence inspected`, `Depth checklist`, `Re-review after fixes` / `Fix and re-review` и `No-findings justification`;
  - [quest-governance.md](instructions/core/quest-governance.md), [quest-mode.md](instructions/core/quest-mode.md), [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md) и [quest-prompt-exec.md](instructions/core/quest-prompt-exec.md) теперь требуют full review-loop вместо single-pass review summary.

## [2.6.0] - 2026-05-14

### Changed

- Зафиксированы конкретные процедуры и формат вывода обязательных `QUEST` review:
  - [review-loops.md](instructions/governance/review-loops.md) теперь задаёт severity/status contract, обязательный `Scope reviewed`, actionable findings table, validation evidence, unrelated changes и residual risks для `post-SPEC review` и `post-EXEC review`;
  - [templates/specs/_template.md](templates/specs/_template.md) теперь содержит готовые блоки `SPEC Linter Result`, `SPEC Rubric Result`, `Post-SPEC Review` и `Post-EXEC Review`;
  - [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md) и [quest-prompt-exec.md](instructions/core/quest-prompt-exec.md) теперь явно направляют агента к формату review из owner-документа.

## [2.5.0] - 2026-05-14

### Changed

- Усилен evidence contract для UI-facing фич и багфиксов:
  - [ui-automation-testing.md](instructions/profiles/ui-automation-testing.md) теперь требует `до`/`после` video evidence из автоматизированных UI test runs, когда есть релевантный UI suite и безопасная запись видео поддерживается;
  - для багфиксов `до` evidence должно показывать failing/repro run; characterization video допустимо только если deterministic failing assertion невозможен и само видео демонстрирует дефект;
  - [templates/specs/_template.md](templates/specs/_template.md) теперь подсказывает планировать команды и artifact paths/links для UI video evidence;
  - [review-loops.md](instructions/governance/review-loops.md) и [github-delivery-policy.md](instructions/governance/github-delivery-policy.md) теперь проверяют и публикуют UI test video evidence или явный fallback с причиной и next-best evidence.

## [2.4.0] - 2026-05-14

### Changed

- Усилен planning contract для UI-facing визуальных изменений:
  - [model-behavior-baseline.md](instructions/core/model-behavior-baseline.md) теперь требует на этапе планирования/SPEC фиксировать visual planning artifact для изменений layout, visual state, navigation flow или UI-facing behavior;
  - [templates/specs/_template.md](templates/specs/_template.md) теперь содержит подсказки для wireframe/render/storyboard/annotated screenshot и visual acceptance;
  - [review-loops.md](instructions/governance/review-loops.md) теперь проверяет наличие visual artifact или explicit `Не применимо` на post-SPEC review;
  - [ui-automation-testing.md](instructions/profiles/ui-automation-testing.md) связывает visual planning artifact с e2e/smoke acceptance сценариями.

## [2.3.0] - 2026-05-14

### Added

- Добавлен governance-документ [github-delivery-policy.md](instructions/governance/github-delivery-policy.md) для GitHub delivery workflow:
  - правила именования веток;
  - минимальный контракт PR title/body, draft readiness, validation evidence и issue links;
  - правила GitHub Release tags, release notes и связи с changelog.

### Changed

- Синхронизированы routing и связанные governance-документы:
  - [routing-matrix.md](instructions/governance/routing-matrix.md) теперь маршрутизирует ветки, pull request и GitHub Releases на новый policy;
  - [commit-message-policy.md](instructions/governance/commit-message-policy.md) и [versioning-policy.md](instructions/governance/versioning-policy.md) теперь ссылаются на новый delivery policy;
  - [validate-instructions.ps1](scripts/validate-instructions.ps1) считает новый governance-документ обязательной частью каталога.

## [2.2.1] - 2026-05-09

### Changed

- Уточнен рабочий communication contract агента:
  - [model-behavior-baseline.md](instructions/core/model-behavior-baseline.md) теперь требует короткий lead-style preamble перед началом значимой работы, запуском инструментов, мутациями файлов или внешними side effects;
  - [collaboration-baseline.md](instructions/core/collaboration-baseline.md) теперь явно связывает такие preamble с объяснением намерения, причины действия и ожидаемого результата.

## [2.2.0] - 2026-04-27

### Added

- Добавлен core owner-документ [model-behavior-baseline.md](instructions/core/model-behavior-baseline.md) для ближайшего использования каталога с `gpt-5.5`:
  - фиксирует outcome-first contract, критерии успеха, ограничения, output contract и stop rules;
  - задаёт правила для verbosity/reasoning guidance, progress updates, validation loops, retrieval/tool budgets, current date и `phase` handling.

### Changed

- Синхронизирован central stack под GPT-5.5:
  - [routing-matrix.md](instructions/governance/routing-matrix.md), [AGENTS.md](AGENTS.md), [README.md](README.md) и [collaboration-baseline.md](instructions/core/collaboration-baseline.md) теперь подключают `model-behavior-baseline` как обязательный core baseline;
  - [validate-instructions.ps1](scripts/validate-instructions.ps1) считает новый core-документ обязательной частью каталога.
- Обновлены `QUEST` prompt wrappers и quality gates:
  - [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md) и [quest-prompt-exec.md](instructions/core/quest-prompt-exec.md) теперь используют структуру `Goal / Success criteria / Constraints / Output / Stop rules`, сохраняя строгие `SPEC`/`EXEC` инварианты;
  - [templates/specs/_template.md](templates/specs/_template.md) теперь содержит целевую модель, outcome contract, stop rules и правило `Не применимо` для нерелевантных секций;
  - [review-loops.md](instructions/governance/review-loops.md) теперь проверяет prompt-quality риски GPT-5.5: лишние абсолютные правила, отсутствие output/evidence contract, stop rules и validation evidence.

## [2.1.2] - 2026-04-24

### Changed

- Уточнен эксплуатационный routing/onboarding contract:
  - [AGENTS.md](AGENTS.md), [routing-matrix.md](instructions/governance/routing-matrix.md), [quick-start.md](instructions/onboarding/quick-start.md), [AGENTS.consumer.template.md](instructions/onboarding/AGENTS.consumer.template.md) и [AGENTS.override.template.md](instructions/onboarding/AGENTS.override.template.md) теперь явно формулируют, что локальный `AGENTS.override.md` применяется только после central stack как дополнительные локальные инструкции поверх него, а не заменяет центральные правила.
- Усилен UI testing contract для UI-поведения:
  - [ui-automation-testing.md](instructions/profiles/ui-automation-testing.md) теперь применяется к багфиксам и фичам, затрагивающим UI behavior, visual flows и UI-facing state changes при наличии существующего UI test suite, требует обновлять/добавлять релевантное покрытие и запускать релевантные UI tests или явно объяснять, почему запуск невозможен;
  - [routing-matrix.md](instructions/governance/routing-matrix.md) синхронизирован с этим overlay.
- Добавлен явный `.NET` workflow для `TUnit`:
  - [testing-dotnet.md](instructions/contexts/testing-dotnet.md) теперь различает VSTest-совместимые проекты и `TUnit`/`Microsoft.Testing.Platform`, требует для `TUnit` использовать `--treenode-filter` и `--list-tests`, а не VSTest `--filter`, и показывает примеры targeted/full runs.
- Усилен MCP-first debug contract:
  - [debug-dotnet-mcp-coreclr.md](instructions/contexts/debug-dotnet-mcp-coreclr.md) теперь явно требует использовать MCP для runtime/test-debug и отлова исключений и приводит `Killer Bug` как пример предпочтительного entry point, если такой инструмент доступен в среде.

## [2.1.1] - 2026-04-17

### Changed

- Уточнен контракт языка комментариев:
  - [commenting-policy.md](instructions/governance/commenting-policy.md) теперь требует перед массовым комментированием или переписыванием комментариев определить принятый язык комментариев в репозитории и приводит новые/изменяемые комментарии к этой конвенции;
  - [AGENTS.override.template.md](instructions/onboarding/AGENTS.override.template.md) теперь показывает минимальный пример локального `MUST` для явной фиксации языка комментариев в consumer-репозитории.

## [2.1.0] - 2026-04-16

### Added

- Добавлены cross-cutting owner-документы:
  - [commenting-policy.md](instructions/governance/commenting-policy.md) для правил полезного комментирования, cleanup комментариев и doc-comments;
  - [refactoring-policy.md](instructions/governance/refactoring-policy.md) для общего процесса рефакторинга;
  - [refactor-local.md](instructions/profiles/refactor-local.md) как overlay-профиль локального структурного рефакторинга.

### Changed

- Усилен baseline и routing catalog:
  - [collaboration-baseline.md](instructions/core/collaboration-baseline.md) теперь явно требует не оставлять ложные комментарии и кратко фиксирует правила самодокументируемого кода, полезных комментариев и локального refactor;
  - [routing-matrix.md](instructions/governance/routing-matrix.md) теперь маршрутизирует `commenting-policy` и `refactoring-policy`, а также знает новый overlay `refactor-local`.
- Усилен `QUEST` review/spec contract:
  - [review-loops.md](instructions/governance/review-loops.md) теперь требует в `post-EXEC review` отдельно проверять устаревшие комментарии, скрытые functional changes под видом refactor и неподтверждённые performance tradeoff;
  - [templates/specs/_template.md](templates/specs/_template.md) теперь подсказывает фиксировать скрытые зависимости, characterization tests и baseline-замеры там, где это релевантно.
- Синхронизированы профильные и quality-gate документы:
  - [refactor-architecture.md](instructions/profiles/refactor-architecture.md) и [refactor-mechanical.md](instructions/profiles/refactor-mechanical.md) теперь явно опираются на общий [refactoring-policy.md](instructions/governance/refactoring-policy.md);
  - [validate-instructions.ps1](scripts/validate-instructions.ps1) теперь считает новые owner-documents и `refactor-local.md` обязательной частью каталога.

## [2.0.0] - 2026-04-01

### Changed

- Расширен canonical `QUEST` spec contract:
  - [templates/specs/_template.md](templates/specs/_template.md) теперь заканчивается обязательным разделом `Журнал действий агента` с инкрементально заполняемой таблицей;
  - журнал теперь различает ожидаемую передачу решения человеку и фактическое human-in-the-loop обращение / решение человека;
  - [quest-governance.md](instructions/core/quest-governance.md) и [quest-mode.md](instructions/core/quest-mode.md) теперь явно требуют вести этот журнал после каждого значимого блока работ на фазах `SPEC` и `EXEC`.

## [1.2.3] - 2026-04-01

### Changed

- Нормализован routing contract:
  - [routing-matrix.md](instructions/governance/routing-matrix.md) теперь явно разделяет `Stack Assembly Order` и `Conflict Resolution Model`;
  - [AGENTS.md](AGENTS.md) и [README.md](README.md) сведены к роли summary/entry-point и больше не формулируют конкурирующий точный приоритет правил.
- Синхронизирован `QUEST` contract:
  - [quest-mode.md](instructions/core/quest-mode.md) теперь является явным owner-документом фазового поведения `SPEC` и `EXEC`;
  - на фазе `SPEC` разрешено менять только рабочую spec в локальном `./specs/`, остальные файлы до подтверждения пользователя запрещены;
  - [quest-governance.md](instructions/core/quest-governance.md), [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md) и [quest-prompt-exec.md](instructions/core/quest-prompt-exec.md) синхронизированы с этим owner-контрактом и больше не дублируют полную фазовую механику.
- Синхронизирован документный контракт и validator:
  - [document-contract.md](instructions/governance/document-contract.md) теперь явно требует секцию `## Команды` для всех документов `instructions/*`;
  - [validate-instructions.ps1](scripts/validate-instructions.ps1) теперь считает отсутствие `## Команды` ошибкой;
  - [test-validate-instructions.ps1](scripts/test-validate-instructions.ps1) получил regression scenario на отсутствие секции `## Команды`.

## [1.2.2] - 2026-04-01

### Changed

- Canonical template спецификации перенесён из `specs/_template.md` в `templates/specs/_template.md`, чтобы развести namespace рабочих spec-файлов и source template.
- Обновлены [quest-governance.md](instructions/core/quest-governance.md), [quest-mode.md](instructions/core/quest-mode.md), [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md), onboarding-документы и [README.md](README.md):
  - `specs/` теперь означает только каталог рабочих спецификаций;
  - для `QUEST` template всегда берётся из central `templates/specs/_template.md`;
  - local override `./specs/_template.md` больше не является частью контракта.
- Обновлены validator и его тесты:
  - canonical template path теперь обязателен;
  - active references на старый путь `specs/_template.md` в `AGENTS.md`, `README.md` и `instructions/*` считаются ошибкой.

## [1.2.1] - 2026-03-31

### Changed

- Уточнен cross-repo contract резолва spec template для consumer-репозиториев:
  - в [quest-governance.md](instructions/core/quest-governance.md), [quest-mode.md](instructions/core/quest-mode.md) и [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md) теперь явно разделены локальный путь сохранения рабочей спеки и источник шаблона;
  - в [quick-start.md](instructions/onboarding/quick-start.md) и [AGENTS.consumer.template.md](instructions/onboarding/AGENTS.consumer.template.md) добавлен canonical fallback с локального `./specs/_template.md` на центральный `<AGENTS_ROOT>/specs/_template.md`;
  - [README.md](README.md) синхронизирован с onboarding-контрактом, чтобы агент не ожидал обязательный локальный `_template.md` в consumer-репозитории.

## [1.2.0] - 2026-03-31

### Added

- Добавлен новый governance-документ [review-loops.md](instructions/governance/review-loops.md):
  - обязателен `post-SPEC review` до запроса подтверждения спеки;
  - обязателен `post-EXEC review` до финального отчёта;
  - зафиксировано правило выбора: агент сам принимает uniquely best option и спрашивает человека только при реальной неоднозначности.

### Changed

- Обновлены [quest-mode.md](instructions/core/quest-mode.md) и [quest-governance.md](instructions/core/quest-governance.md):
  - post-review loops стали обязательной частью `QUEST` workflow;
  - после review агент обязан автоматически вносить объективно лучшие правки и повторять затронутые проверки.
- Обновлены prompt templates [quest-prompt-spec.md](instructions/core/quest-prompt-spec.md) и [quest-prompt-exec.md](instructions/core/quest-prompt-exec.md):
  - `spec`-prompt теперь требует цикл `draft -> lint/rubric -> review -> refine`;
  - `exec`-prompt теперь требует цикл `implement -> test -> review -> fix/retest`;
  - исправлена ссылка на секцию результатов quality gate в шаблоне спеки: с `15` на `19`;
  - финальный `EXEC`-отчёт теперь включает блок `Review`.
- Обновлены [routing-matrix.md](instructions/governance/routing-matrix.md), template спеки, [README.md](README.md) и [scripts/validate-instructions.ps1](scripts/validate-instructions.ps1):
  - новый governance overlay подключён в маршрутизации `QUEST`;
  - шаблон спеки теперь явно фиксирует `Post-SPEC Review`;
  - validator считает `review-loops.md` обязательным документом каталога;
  - README синхронизирован с новым каноническим workflow.

## [1.1.2] - 2026-03-30

### Changed

- Обновлен [business-process-automation.md](instructions/profiles/business-process-automation.md):
  - Mermaid-артефакты шагов 2, 4 и 5 теперь обязаны проходить через `Mermaid lint/validator`;
  - добавлен обязательный цикл автоисправления `lint -> fix -> relint` до успешной проверки;
  - запрещена выдача Mermaid-артефакта как готового результата, если validator недоступен или проверка не пройдена.
- Обновлены prompt templates:
  - [02-as-is-process-modeling.md](prompts/business-process-automation/02-as-is-process-modeling.md);
  - [04-to-be-process-design.md](prompts/business-process-automation/04-to-be-process-design.md);
  - [05-ai-agent-skill-graph.md](prompts/business-process-automation/05-ai-agent-skill-graph.md).
  Для всех Mermaid-генерирующих шагов зафиксирован обязательный внешний lint/validation и повторное автоматическое исправление ошибок до корректной диаграммы.

## [1.1.1] - 2026-03-29

### Changed

- Уточнен [quest-governance.md](instructions/core/quest-governance.md):
  - `SPEC gate` больше не применяется к исполнению существующего guided workflow с пользовательскими артефактами, если агент не меняет код, инфраструктуру и канонические файлы проекта.
- Обновлена [routing-matrix.md](instructions/governance/routing-matrix.md):
  - добавлен тип задачи `guided-artifact-workflow`;
  - для guided workflow базовым стеком стал `collaboration-baseline` без `quest-governance`.
- Уточнен [business-process-automation.md](instructions/profiles/business-process-automation.md):
  - выполнение workflow теперь явно идет без spec;
  - пошаговые артефакты должны отдаваться отдельными файлами и ждать подтверждения пользователя.

## [1.1.0] - 2026-03-29

### Added

- Добавлен новый профиль [business-process-automation](instructions/profiles/business-process-automation.md) для задач анализа и проектирования автоматизации бизнес-процессов.
- Добавлен каталог prompt templates `prompts/business-process-automation/` для канонической цепочки:
  - интервью с экспертом;
  - моделирование `AS-IS`;
  - анализ точек автоматизации;
  - проектирование `TO-BE`;
  - построение skill graph ИИ-агента.

### Changed

- Обновлена [routing-matrix.md](instructions/governance/routing-matrix.md):
  - добавлен маршрут `business-process-automation`;
  - разрешен сценарный профиль без `stack profile` для аналитических задач без технологической привязки.
- Обновлен `scripts/validate-instructions.ps1`:
  - новые профиль и prompt templates включены в обязательный quality gate.

## [1.0.1] - 2026-03-05

### Changed

- Актуализирован [README.md](README.md):
  - синхронизирован с текущей маршрутизацией через `AGENTS.md` и `instructions/governance/routing-matrix.md`;
  - обновлено описание структуры каталога;
  - уточнены секции quick start, quality gate и CI.
