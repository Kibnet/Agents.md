# Profile: Storm Product Development

## Когда применять

- Пользователь вызывает semantic command вида `/storm:*`.
- Нужно восстановить living product specification из существующего кода, тестов, README, API/CLI/UI контрактов и документации.
- Нужно вести продуктовую трассируемость `story -> acceptance criteria -> Gherkin scenario -> tests -> code` и обратные связи `test/code -> scenario/story/constraint`.
- Нужно вывести needs, Product Goal, Product Vision, найти gaps/conflicts, построить dependency-aware ranking или выполнить SDD-реализацию конкретной story.
- Нужно формализовать product behavior через BDD/Gherkin examples, `.feature` files, step definitions или executable specifications.
- Нужно поддерживать canonical product artifact `docs/product/storm.json` и связанные отчёты `docs/product/reports/*` в consumer-репозитории.

## Когда не применять

- Для обычных bugfix/feature delivery задач, где пользователь не просит STORM workflow и нет `docs/product/storm.json`.
- Для задач, где уже есть утверждённая инженерная SPEC и нужен только обычный стековый профиль без product-discovery цикла.
- Для бизнес-процессов формата `AS-IS -> TO-BE -> skill graph`; там применять [business-process-automation](./business-process-automation.md).
- Для изменения центрального каталога инструкций; это `catalog-governance` с QUEST gate.

## MUST

- Начинать STORM-задачу через central stack: `AGENTS.md` -> [routing-matrix](../governance/routing-matrix.md) -> этот профиль; не заменять central `AGENTS.md` standalone инструкциями.
- Для каждой команды `/storm:*` явно определить route:
  - artifact-only analysis/update -> `guided-artifact-workflow`;
  - любые изменения tests, code, behavior, инфраструктуры или canonical project files -> `delivery-task` с `quest-governance`, `testing-baseline` и релевантным stack/testing context.
- `/storm:full-cycle` без QUEST выполнять только в safe analysis mode: product artifacts and reports may change, but tests, code and test annotations must not change.
- Если внутри `/storm:full-cycle` нужен test annotation, новый/изменённый test или code change, остановить текущий guided workflow и перейти к `delivery-task` через QUEST gate.
- Использовать canonical artifact path `docs/product/storm.json`, если пользователь не указал существующее место product docs; альтернативный путь явно фиксировать в `docs/product/README.md` или эквивалентном product-doc index.
- Если `storm.json` отсутствует, создать его из [templates/storm/storm.json](../../templates/storm/storm.json) или восстановить через `/storm:bootstrap`.
- Использовать Gherkin как executable behavior specification layer между Story/Acceptance Criteria и Automated Tests/Code; Gherkin не заменяет acceptance criteria, а делает их проверяемыми на конкретных примерах.
- Хранить canonical `.feature` files по умолчанию в `features/`; если consumer-репозиторий выбирает другой root, зафиксировать его в `metadata.feature_root` внутри `storm.json`.
- Соблюдать расширенную artifact chain: `Vision -> Product Goal -> Need / Constraint -> Story -> Gherkin Rule -> Gherkin Scenario -> Automated Test / Step Definition -> Code`.
- Для каждого product artifact element указывать stable ID, status, provenance, confidence, evidence и при необходимости assumptions/open_questions.
- Использовать ID prefixes:
  - `VS` для Product Vision;
  - `PG` для Product Goal;
  - `ND` для Need;
  - `CN` для Constraint;
  - `ST` для User Story;
  - `AC` для Acceptance Criterion;
  - `GF` для Gherkin Feature;
  - `GR` для Gherkin Rule;
  - `SC` для Gherkin Scenario / Example;
  - `SD` для Step Definition;
  - `TS` для Test Case / Test Suite link;
  - `CU` для Code Unit;
  - `CF` для Cloud Conflict;
  - `EN` для Technical Enabler;
  - `DP` для Dependency.
- Помечать выводы из кода как гипотезы: `provenance = inferred_from_code` или `inferred_from_current_behavior`, `confidence < 1.0`, пока владелец продукта не подтвердил смысл.
- Не смешивать статусы `inferred`, `proposed`, `confirmed`, `active`, `implemented`, `partial`, `deprecated`, `superseded`, `removed`, `blocked`, `needs_review`.
- Для Gherkin Scenario использовать только статусы `draft`, `reviewed`, `automated`, `manual`, `failing`, `passing`, `deprecated`, `superseded`.
- `status = implemented` разрешать только если есть acceptance criteria, связь с needs/constraints, evidence и linked tests либо явная verification strategy `manual`, `observability` или `architecture_review`.
- Не считать Story готовой к реализации, пока для неё нет минимум одного linked Gherkin Scenario или явно зафиксированного `gherkin_exception` с причиной неприменимости.
- Для каждой active Story при `/storm:gherkin`, `/storm:expand`, `/storm:implement` или `/storm:bdd-implement` формировать минимум один happy path scenario; добавлять negative path и constraint scenario, если story затрагивает отказ, ошибку, безопасность, деньги, данные, производительность, доступность или совместимость.
- Каждый Gherkin Scenario обязан иметь stable ID вида `SC-<story-number>-<sequence>`, `@scenario:<id>` tag, `@story:<id>` tag при связи со story, минимум один `@need:<id>` tag или явное contract/constraint основание, `coverage_role`, `automation_status`, observed `Then` outcome и запись в `storm.json`.
- Gherkin Scenario должен описывать один конкретный пример поведения на декларативном языке предметной области; не описывать UI mechanics, HTTP methods, SQL, class names, internal methods или infrastructure details, если это не часть публичного contract.
- В Gherkin: `Given` описывает исходное состояние, `When` описывает событие/действие, `Then` описывает наблюдаемый результат; `Then` не должен проверять скрытое внутреннее состояние вместо observable output.
- Автоматизированный Gherkin Scenario со статусом `automated`, `passing` или `failing` должен иметь связь с test runner output, linked tests или step definitions.
- Deprecated/superseded Story не должна иметь active scenarios, если scenario не поддерживает другую active story, active need или active constraint.
- Разделять functional stories и cross-cutting qualities: безопасность, надежность, производительность, поддерживаемость, совместимость и policy фиксировать как constraints.
- Для продуктово значимых tests указывать связи с story, acceptance criteria или constraint; не добавлять ID механически, если test не проверяет соответствующее поведение.
- Для продуктово значимых BDD tests указывать связь `Scenario -> Test -> Step Definition -> Code`; не создавать Story насильно для технического теста без product behavior, а оформлять его как Constraint, Technical Check или Internal Contract.
- `/storm:bootstrap` восстанавливает текущие stories, AC, constraints, enablers, tests и code units из evidence; не меняет функциональный код.
- `/storm:trace` строит двунаправленную traceability и может добавлять test annotations только если текущий route уже `delivery-task` или пользователь явно подтвердил изменение tests.
- `/storm:cover` всегда считается code/test-changing command, если добавляет или меняет tests; без QUEST допускается только analysis report по coverage gaps.
- `/storm:derive` выводит needs, Product Goal и Product Vision из stories/constraints и помечает выводы как `needs_review`, если они не подтверждены владельцем.
- `/storm:expand` создает proposed needs/stories/constraints/enablers с AC и test strategy; не реализует код.
- `/storm:conflicts` раскладывает угрозы через cloud conflict: common objective, need A, need B, want A, want B, assumptions, injections, decision, changed items.
- `/storm:cleanup` удаляет code/tests только после доказательства, что они не поддерживают active/implemented/proposed story, active constraint или enabler; это всегда `delivery-task`.
- `/storm:rank` строит dependency graph, останавливается на cycles и считает closure-based priority only for acyclic graph.
- `/storm:implement ST-XXXX` выполняет SDD: проверить dependencies/conflicts, уточнить story/AC, добавить/обновить tests, реализовать минимальное изменение, запустить проверки, синхронизировать `storm.json` and reports.
- `/storm:gherkin [ST-XXXX]` формирует или актуализирует Gherkin features, rules и scenarios для всех active stories или одной story; без изменений tests/code это `guided-artifact-workflow`.
- `/storm:bdd-sync` проверяет синхронизацию `storm.json`, `.feature` files, step definitions, tests и code references; без исправлений tests/code это `guided-artifact-workflow`.
- `/storm:bdd-lint` проверяет качество Gherkin: required tags, traceability, declarative style, duplicate steps, orphan scenarios, status/coverage roles and behavior coverage.
- `/storm:bdd-conflicts` ищет конфликты на уровне Story, Rule, Scenario, scenario data и step implementation against needs/constraints.
- `/storm:bdd-implement ST-XXXX` выполняет BDD/SDD: сначала scenario/rule update, затем failing automation, затем production code, затем passing tests and traceability sync; это всегда `delivery-task`.
- `/storm:audit` считать process, quality and outcome metrics и формировать `docs/product/reports/process-audit.md`.
- Любое behavior-changing изменение в PR или task должно синхронизировать Story/Need/Constraint, related `.feature` scenarios, test links and traceability report либо явно фиксировать, почему product behavior не изменился.
- Не удалять deprecated/superseded behavior сразу: сначала проверить traceability, активные связи и tests.
- Не считать line coverage заменой requirements coverage; оценивать coverage по acceptance criteria and constraints.
- Не скрывать неопределенность: low confidence, missing evidence and open questions must be visible in artifacts and final response.
- После любой `/storm:*` команды выдавать итоговый ответ с блоками: что выполнено, какие файлы обновлены, какие проверки запускались, ключевые выводы, риски/вопросы, следующий рекомендуемый шаг.

## SHOULD

- Использовать prompts из [prompts/storm](../../prompts/storm) как command templates, адаптируя их к текущему repository stack and route.
- Для `/storm:bootstrap` начинать с high-signal entry points: README, public APIs, commands, UI routes, tests and domain modules.
- Для `/storm:trace` предпочитать native test framework markers; комментарии использовать только если framework markers отсутствуют или неуместны.
- Для `/storm:cover` сначала добавлять characterization/regression tests for existing behavior; proposed behavior реализовывать только через `/storm:implement`.
- Для `/storm:derive` избегать Product Goal как списка features; формулировать проверяемое целевое состояние продукта.
- Для `/storm:expand` отделять proposed backlog от confirmed requirements.
- Для `/storm:conflicts` фиксировать assumptions and injections, а не только narrative disagreement.
- Для `/storm:rank` оценивать effort как cost of change: architecture blast radius, verification complexity, dependency overhead, scenario automation cost, step reuse penalty, migration/rollout risk.
- Для `/storm:audit` включать top-5 process improvements with expected effect and success metric.
- Для Gherkin предпочитать короткие сценарии: один начальный context, одно событие, один проверяемый outcome; длинные процедурные сценарии разделять на несколько examples.
- Нормализовать повторяющиеся step texts; одинаковый текст шага не должен расходиться по смыслу между `Given`, `When` и `Then`.
- Использовать [schemas/storm-artifacts.schema.json](../../schemas/storm-artifacts.schema.json) как machine-readable reference для структуры `storm.json`.
- Использовать scripts без внешних Python dependencies; если Python runtime недоступен, выполнить logical validation manually and report the limitation.

## MAY

- Завершить workflow на любом STORM-шаге, если пользователь запросил только конкретный artifact or decision.
- Хранить дополнительные reports в `docs/product/reports/*`, если они выводятся из `storm.json` and do not become competing sources of truth.
- Добавлять domain-specific fields в `storm.json`, если они не ломают schema-compatible base model and are explained in metadata.
- Использовать existing product documentation вместо шаблонов, если `storm.json` remains the single machine-readable source of truth.

## Команды

```powershell
# Прочитать профиль и command templates
Get-Content -Raw instructions\profiles\storm-product-development.md
Get-ChildItem prompts\storm

# Создать starter artifact в consumer-репозитории
Copy-Item <AGENTS_ROOT>\templates\storm\storm.json .\docs\product\storm.json

# Проверить STORM artifact
python <AGENTS_ROOT>\scripts\storm\validate-artifacts.py .\docs\product\storm.json

# Построить ranking report
python <AGENTS_ROOT>\scripts\storm\rank-backlog.py .\docs\product\storm.json --out .\docs\product\reports\ranking.md
```

## Канонические команды STORM

| Команда | Route по умолчанию | Output |
|---|---|---|
| `/storm:bootstrap` | `guided-artifact-workflow`, если меняет только product artifacts | `storm.json`, `stories.md`, open questions |
| `/storm:trace` | `guided-artifact-workflow` для анализа; `delivery-task` при test annotation changes | Traceability links and report |
| `/storm:cover` | `delivery-task` при test changes; analysis-only без QUEST | Coverage gaps or updated tests |
| `/storm:derive` | `guided-artifact-workflow` | Needs, Product Goal, Vision |
| `/storm:expand` | `guided-artifact-workflow` | Proposed backlog |
| `/storm:conflicts` | `guided-artifact-workflow`, если меняет только product artifacts | Cloud conflicts and injections |
| `/storm:cleanup` | `delivery-task` | Removed dead code/tests and synchronized spec |
| `/storm:rank` | `guided-artifact-workflow` | Ranked backlog |
| `/storm:implement ST-XXXX` | `delivery-task` | Implemented story, tests, synced artifacts |
| `/storm:gherkin [ST-XXXX]` | `guided-artifact-workflow`, если меняет только product artifacts and `.feature` specs | Gherkin features, rules, scenarios |
| `/storm:bdd-sync` | `guided-artifact-workflow` для анализа/artifact sync; `delivery-task` при test/code changes | Sync report and fixed traceability |
| `/storm:bdd-lint` | `guided-artifact-workflow` | Gherkin quality report |
| `/storm:bdd-conflicts` | `guided-artifact-workflow`, если меняет только product artifacts | Rule/scenario-level conflicts |
| `/storm:bdd-implement ST-XXXX` | `delivery-task` | Scenario-first implementation, tests, synced artifacts |
| `/storm:audit` | `guided-artifact-workflow` | Process audit report |
| `/storm:full-cycle` | Safe analysis `guided-artifact-workflow`; mutations require `delivery-task` | Bootstrap, trace, coverage analysis, Gherkin scenarios, derive, expand, conflicts, rank, audit |

## Artifact Model

Canonical `storm.json` содержит:

```json
{
  "metadata": {},
  "vision": {},
  "product_goal": {},
  "needs": [],
  "constraints": [],
  "stories": [],
  "gherkin_features": [],
  "gherkin_rules": [],
  "gherkin_scenarios": [],
  "step_definitions": [],
  "tests": [],
  "code_units": [],
  "conflicts": [],
  "dependencies": [],
  "ranking": [],
  "process_audit": {}
}
```

Минимальные правила:

- Story без `acceptance_criteria` не ready.
- Story без `supports_needs` не имеет продуктового смысла.
- Story без linked Gherkin Scenario не ready к реализации, если нет явного `gherkin_exception`.
- Story с `threatens_needs` должна иметь conflict record or accepted risk.
- Need должна поддерживать Product Goal или быть помечена как orphan/needs_review.
- Constraint должен иметь verification strategy.
- Gherkin Feature группирует related scenarios by capability and points to `.feature` file.
- Gherkin Rule представляет business rule, acceptance criterion or constraint, не технический implementation detail.
- Gherkin Scenario является executable product behavior example; он должен иметь tags for traceability and one coverage role.
- Step Definition связывает scenario text с automated verification, но не заменяет product wording in `.feature`.
- Test с продуктовым смыслом должен ссылаться на story or constraint.
- Code Unit нужен для traceability significant units, not exhaustive indexing.
- Dependency `from -> to` означает, что `from` должен быть сделан раньше `to`.

## Quality Audit

После `/storm:full-cycle` или `/storm:audit` считать минимум:

- total stories;
- inferred/confirmed/proposed/implemented/deprecated stories;
- stories with at least one linked test;
- acceptance criteria by coverage level;
- behavior coverage by active stories;
- rule coverage by acceptance criteria;
- automation coverage by Gherkin scenarios;
- constraint coverage by scenarios;
- executable specification ratio;
- scenario health and bdd-lint pass ratio;
- orphan scenario rate;
- deprecated drift between stories, scenarios and tests;
- step reuse ratio;
- tests without story/constraint links;
- code units without active supports;
- stories without needs;
- needs without supporting stories;
- constraints without verification strategy;
- unresolved conflicts;
- conflicts without assumptions or injections;
- dependency cycles;
- candidates without RICE or effort decomposition;
- low-confidence item ratio.

Scorecard 0..5:

- Traceability completeness;
- Requirement coverage quality;
- Need/Goal coherence;
- Conflict analysis usefulness;
- Backlog ranking explainability;
- Spec-code synchronization;
- Automation readiness.
- Behavior example quality.

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
- [instructions/core/model-behavior-baseline.md](../core/model-behavior-baseline.md)
- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/core/testing-baseline.md](../core/testing-baseline.md)
- [instructions/profiles/business-process-automation.md](./business-process-automation.md)
- [prompts/storm/00-full-cycle.md](../../prompts/storm/00-full-cycle.md)
- [prompts/storm/01-bootstrap-from-code.md](../../prompts/storm/01-bootstrap-from-code.md)
- [prompts/storm/02-trace-tests.md](../../prompts/storm/02-trace-tests.md)
- [prompts/storm/03-complete-test-coverage.md](../../prompts/storm/03-complete-test-coverage.md)
- [prompts/storm/04-derive-needs-goal.md](../../prompts/storm/04-derive-needs-goal.md)
- [prompts/storm/05-goal-gap-backlog.md](../../prompts/storm/05-goal-gap-backlog.md)
- [prompts/storm/06-cloud-conflicts.md](../../prompts/storm/06-cloud-conflicts.md)
- [prompts/storm/07-deprecate-cleanup.md](../../prompts/storm/07-deprecate-cleanup.md)
- [prompts/storm/08-dependencies-rice-ranking.md](../../prompts/storm/08-dependencies-rice-ranking.md)
- [prompts/storm/09-sdd-implement-story.md](../../prompts/storm/09-sdd-implement-story.md)
- [prompts/storm/10-audit-and-improve-process.md](../../prompts/storm/10-audit-and-improve-process.md)
- [prompts/storm/11-generate-gherkin.md](../../prompts/storm/11-generate-gherkin.md)
- [prompts/storm/12-bdd-sync.md](../../prompts/storm/12-bdd-sync.md)
- [prompts/storm/13-bdd-lint.md](../../prompts/storm/13-bdd-lint.md)
- [prompts/storm/14-bdd-conflicts.md](../../prompts/storm/14-bdd-conflicts.md)
- [prompts/storm/15-bdd-implement-story.md](../../prompts/storm/15-bdd-implement-story.md)
- [schemas/storm-artifacts.schema.json](../../schemas/storm-artifacts.schema.json)
- [templates/storm/feature-template.feature](../../templates/storm/feature-template.feature)
- [templates/storm/storm.json](../../templates/storm/storm.json)
