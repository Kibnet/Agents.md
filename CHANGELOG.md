# Changelog

All notable changes to this instruction catalog are documented in this file.

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
