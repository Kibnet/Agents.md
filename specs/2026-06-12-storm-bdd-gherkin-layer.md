# BDD/Gherkin layer для STORM product workflow

## 0. Метаданные
- Тип (профиль): `catalog-governance` + `product-system-design`; целевой профиль: `storm-product-development`.
- Владелец: центральный каталог инструкций `Agents`.
- Масштаб: large.
- Целевая модель: gpt-5.5.
- Целевой релиз / ветка: `2.10.0` / текущая ветка `main`.
- Ограничения:
  - До утверждения этой спеки разрешено менять только этот файл в `./specs/`.
  - Переход в EXEC только после точной фразы пользователя `Спеку подтверждаю`.
  - Изменение должно быть SemVer minor: существующие `storm.json` без Gherkin-секций не должны ломаться как hard failure.
  - Не добавлять runtime dependency на Cucumber/Behave/SpecFlow/pytest-bdd или другие BDD-фреймворки в центральный каталог.
  - Не заменять acceptance criteria Gherkin-сценариями; Gherkin добавляется как слой исполняемых примеров между AC и тестами.
- Связанные ссылки:
  - `instructions/profiles/storm-product-development.md`
  - `schemas/storm-artifacts.schema.json`
  - `templates/storm/storm.json`
  - `scripts/storm/validate-artifacts.py`
  - `scripts/storm/rank-backlog.py`
  - `prompts/storm/*`
  - `instructions/governance/routing-matrix.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`

Если секция не применима, явно укажите `Не применимо` и короткую причину, вместо заполнения нерелевантными деталями.

## 1. Overview / Цель
Усилить STORM workflow BDD/Gherkin-слоем: добавить формализованные behavior examples между stories/acceptance criteria и automated tests, чтобы product specification стала не только трассируемой, но и исполняемой через `.feature` сценарии и step definitions.

Outcome contract:
- Success means:
  - `storm-product-development` описывает новую artifact chain: `Vision -> Product Goal -> Need / Constraint -> Story -> Rule -> Gherkin Scenario -> Automated Test / Step Definition -> Code`.
  - `storm.json` starter/schema поддерживают Gherkin features, rules, scenarios and step definitions as optional-compatible top-level sections.
  - Профиль задает quality rules для декларативного Gherkin, tags, scenario IDs, statuses, coverage roles и automation status.
  - Добавлены semantic commands `/storm:gherkin`, `/storm:bdd-sync`, `/storm:bdd-lint`, `/storm:bdd-conflicts`, `/storm:bdd-implement`.
  - Validation/ranking scripts учитывают behavior coverage, scenario automation cost and step reuse penalty без внешних dependencies.
  - README/routing/changelog/validator знают о новых BDD/Gherkin assets.
- Итоговый артефакт / output: versioned изменение центрального STORM workflow с BDD/Gherkin layer.
- Stop rules:
  - На SPEC остановиться после готовой спеки и запросить `Спеку подтверждаю`.
  - На EXEC не делать breaking schema requirement для уже существующих `storm.json`.
  - На EXEC остановиться и запросить решение, если потребуется выбрать конкретный BDD runtime/framework как обязательный dependency.

## 2. Текущее состояние (AS-IS)
- STORM уже интегрирован как профиль `instructions/profiles/storm-product-development.md`.
- Текущая цепочка артефактов: `Vision -> Product Goal -> Needs / Constraints -> Stories -> Acceptance Criteria -> Tests -> Code`.
- `storm.json` содержит top-level sections: `metadata`, `vision`, `product_goal`, `needs`, `constraints`, `stories`, `tests`, `code_units`, `conflicts`, `dependencies`, `ranking`, `process_audit`.
- В schema нет сущностей `gherkin_features`, `gherkin_rules`, `gherkin_scenarios`, `step_definitions`.
- Покрытие описывается через acceptance criteria and tests, но нет отдельной behavior coverage шкалы и executable examples layer.
- Cloud conflict analysis может ссылаться на story/constraint, но не на конкретный Rule/Scenario/example data.
- Ranking effort учитывает architecture blast radius, verification complexity, dependency overhead and migration/rollout risk, но не scenario automation cost or step reuse penalty.
- Есть prompt templates `prompts/storm/00..10`, но нет BDD/Gherkin команд.

## 3. Проблема
Без Gherkin-слоя STORM связывает продуктовый смысл с тестами слишком крупными объектами: story and acceptance criteria не фиксируют конкретные behavior examples, из-за чего покрытие, conflict analysis and SDD implementation могут оставаться абстрактными и слабее проверяться в CI.

## 4. Цели дизайна
- Разделение ответственности:
  - Story отвечает за пользовательскую ценность.
  - Need отвечает за потребность.
  - Constraint защищает системное качество.
  - Acceptance Criteria остаются краткими условиями готовности.
  - Gherkin Rule/Scenario фиксируют конкретные проверяемые примеры поведения.
  - Automated Test / Step Definition исполняют scenario технически.
  - Code реализует поведение.
- Повторное использование: Gherkin layer не привязан к конкретному BDD runtime и может использоваться с Cucumber, Behave, SpecFlow, pytest-bdd или ручной automation mapping.
- Тестируемость: validator проверяет traceability, tags, orphan scenarios and behavior coverage metrics; scripts remain dependency-free.
- Консистентность: new commands and prompts use central stack wording and follow existing STORM route model.
- Обратная совместимость: existing `storm.json` без Gherkin arrays должен быть принят validator как legacy-compatible artifact with warnings/metrics, not fatal error.

## 5. Non-Goals (чего НЕ делаем)
- Не внедряем Cucumber/Behave/SpecFlow/pytest-bdd runtime в этот каталог.
- Не генерируем реальные `.feature` files для репозитория `Agents`.
- Не конвертируем текущие STORM prompts 1:1 в BDD runtime scripts.
- Не удаляем acceptance criteria and test links.
- Не делаем Gherkin обязательным hard failure для всех legacy STORM artifacts в рамках minor release.
- Не строим полноценный parser Gherkin grammar; validator может выполнять lightweight checks по metadata, tags and optional feature text heuristics.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/profiles/storm-product-development.md` -> BDD/Gherkin Layer, commands, DoD, quality rules, metrics.
- `schemas/storm-artifacts.schema.json` -> optional top-level arrays `gherkin_features`, `gherkin_rules`, `gherkin_scenarios`, `step_definitions` and optional story/scenario fields.
- `templates/storm/storm.json` -> starter fields with empty arrays and schema version bump to `1.1.0`.
- `scripts/storm/validate-artifacts.py` -> behavior coverage metrics, orphan scenario checks, tag/link consistency, automation status checks.
- `scripts/storm/rank-backlog.py` -> include `scenario_automation_cost` and `step_reuse_penalty` in agentic effort.
- `prompts/storm/11-generate-gherkin.md` -> `/storm:gherkin`.
- `prompts/storm/12-bdd-sync.md` -> `/storm:bdd-sync`.
- `prompts/storm/13-bdd-lint.md` -> `/storm:bdd-lint`.
- `prompts/storm/14-bdd-conflicts.md` -> `/storm:bdd-conflicts`.
- `prompts/storm/15-bdd-implement-story.md` -> `/storm:bdd-implement`.
- `templates/storm/feature-template.feature` -> minimal declarative Gherkin example with STORM tags.
- `README.md`, `AGENTS.md`, `routing-matrix.md`, `CHANGELOG.md` -> discovery and routing updates.
- `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1` -> new required paths and fixture coverage.

### 6.2 Детальный дизайн
- Потоки данных:
  - `/storm:bootstrap` and `/storm:trace` can infer scenarios from existing tests and code behavior.
  - `/storm:gherkin` creates or updates Gherkin features/rules/scenarios for all active stories or a single story.
  - `/storm:bdd-sync` checks consistency between `storm.json`, `.feature` files, step definitions, tests and code references.
  - `/storm:bdd-lint` checks declarative style, tags, duplicate/orphan scenarios, coverage roles and automation status.
  - `/storm:bdd-conflicts` searches conflicts at Story, Rule, Scenario, scenario data and step implementation levels.
  - `/storm:bdd-implement ST-XXXX` executes BDD/SDD: scenario first, failing automation, production code, passing tests, traceability update.
- Контракты / API:
  - Default feature file root: `features/`.
  - Alternative feature root allowed only if existing project convention requires it; chosen path must be recorded in `storm.json.metadata.feature_root` or equivalent product docs index.
  - Scenario ID format: `SC-<story-number>-<sequence>`, for example `SC-017-001`; if scenario is not story-owned, use stable `SC-<domain>-<sequence>` and explicit linked constraint/need.
  - Feature ID prefix: `GF`; Rule ID prefix: `GR`; Scenario ID prefix: `SC`; Step Definition ID prefix: `SD`.
  - Tags must include `@story:ST-...` and `@need:ND-...` for story scenarios; add `@goal:PG-...`, `@constraint:CN-...`, `@scenario:SC-...`, `@automated`, `@manual`, `@risk:*`, `@coverage:*` where applicable.
- Output contract / evidence rules:
  - Generated scenarios must describe observable business behavior, not UI mechanics or implementation internals, unless those are public contract.
  - `Given` describes initial state; `When` describes event/action; `Then` describes observable outcome.
  - One scenario = one behavior example.
  - Every active story SHOULD have at least one scenario or explicit `gherkin_exception`.
  - Story is not ready for `/storm:bdd-implement` unless key AC are represented by Gherkin Rule/Scenario or the exception is explicit.
- Visual planning artifact для UI-facing изменений: `Не применимо`; изменение инструкционного workflow, не UI.
- UI test video evidence для UI automation задач: `Не применимо`; изменение не в UI automation.
- Границы сохранения поведения:
  - Existing STORM commands remain valid.
  - Acceptance criteria stay as overview layer; Gherkin adds examples, not replacement.
  - Legacy `storm.json` does not fail because Gherkin arrays are absent.
- Обработка ошибок:
  - Missing `.feature` file for a scenario -> validator warning/error depending scenario status: `passing/automated` must have file reference; `draft/manual` can be warning.
  - Scenario without active Story/Need -> orphan scenario warning.
  - Deprecated story with active scenario -> error unless scenario supports another active story/constraint.
  - Duplicate step text with different intent -> bdd-lint warning.
- Производительность:
  - Validator should inspect metadata and optional feature files by path only when available.
  - No recursive full-repo parser required by default; scope from `storm.json` references.

## 7. Бизнес-правила / Алгоритмы (если есть)
- New artifact chain:
  - `Vision -> Product Goal -> Need / Constraint -> Story -> Gherkin Rule -> Gherkin Scenario -> Automated Test / Step Definition -> Code`.
- Scenario statuses:
  - `draft`, `reviewed`, `automated`, `manual`, `failing`, `passing`, `deprecated`, `superseded`.
- Coverage roles:
  - `happy_path`, `negative_path`, `edge_case`, `business_rule`, `constraint_check`, `regression`, `security`, `performance`, `compatibility`, `accessibility`.
- Behavior coverage scale:
  - `0`: no scenarios.
  - `1`: happy path only.
  - `2`: happy path plus basic negative path.
  - `3`: main business rules covered.
  - `4`: business rules, edge cases and constraints covered.
  - `5`: scenarios are automated, linked to tests, passing in CI or equivalent validation, and usable as living documentation.
- New process sequence:
  1. Reverse engineer code and tests.
  2. Recover Stories, Needs, Constraints.
  3. Recover or generate Gherkin Scenarios for each active Story.
  4. Trace `Story <-> Scenario <-> Test <-> Code`.
  5. Assess behavior coverage by examples.
  6. Analyze conflicts at Story / Rule / Scenario level.
  7. Rewrite conflicting Rules and Scenarios.
  8. Generate new Stories and Scenarios from gap analysis.
  9. Rank with scenario automation cost and step reuse penalty.
  10. BDD/SDD implementation: scenario, failing automation, code, passing tests.
- Agentic effort:
  - `architecture_blast_radius + verification_complexity + dependency_overhead + migration_or_rollout_risk + scenario_automation_cost + step_reuse_penalty`.

## 8. Точки интеграции и триггеры
- `storm-product-development.md`: добавить BDD/Gherkin Layer, commands, DoD, quality rules, reverse engineering, gap analysis, conflict analysis, metrics.
- `storm-artifacts.schema.json`: добавить optional Gherkin model.
- `storm.json` template: добавить empty Gherkin arrays and feature root metadata.
- `validate-artifacts.py`: добавить metrics/checks:
  - behavior coverage;
  - rule coverage;
  - automation coverage;
  - constraint scenario coverage;
  - conflict precision;
  - scenario health;
  - traceability completeness;
  - orphan scenario rate;
  - deprecated drift;
  - step reuse ratio;
  - executable specification ratio.
- `rank-backlog.py`: учитывать scenario automation cost and step reuse penalty.
- `prompts/storm`: добавить BDD command prompts.
- `routing-matrix.md`: добавить route examples for `/storm:gherkin`, `/storm:bdd-*`.
- `README.md` and `AGENTS.md`: кратко раскрыть Gherkin layer and command discovery.
- `validate-instructions.ps1`: required paths for new prompts/template.

## 9. Изменения модели данных / состояния
- Add optional top-level sections:
```json
{
  "gherkin_features": [],
  "gherkin_rules": [],
  "gherkin_scenarios": [],
  "step_definitions": []
}
```
- Add optional Story fields:
  - `linked_scenarios`;
  - `behavior_coverage_level`;
  - `gherkin_exception`.
- Add optional Acceptance Criterion fields:
  - `linked_rules`;
  - `linked_scenarios`.
- Add optional Conflict fields:
  - `rule_id`;
  - `scenario_id`;
  - `scenario_data_risk`.
- Add optional priority/agentic_effort fields:
  - `scenario_automation_cost`;
  - `step_reuse_penalty`.
- Add feature file convention:
  - default: `features/<domain>/<capability>.feature`;
  - step definitions: framework-specific, recorded in `step_definitions[].path` / `symbol`.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - Add schema optional fields and starter empty arrays.
  - Update profile/prompts/docs/scripts.
  - Keep existing `storm.json` compatible by treating missing Gherkin arrays as empty.
  - Run validators and STORM script checks.
- Migration for consumer repos:
  - Existing STORM projects can add empty Gherkin arrays on next `/storm:bdd-sync` or `/storm:gherkin`.
  - If no BDD runtime exists, scenarios can start as `manual` or `draft`.
- Rollback:
  - Remove BDD prompt templates, feature template, schema optional fields, profile sections, script metrics and docs/changelog entries.
  - Existing non-Gherkin STORM artifacts remain valid.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - AC1: `storm-product-development.md` describes BDD/Gherkin layer, artifact chain, commands, quality rules and DoD.
  - AC2: `storm-artifacts.schema.json` supports optional `gherkin_features`, `gherkin_rules`, `gherkin_scenarios`, `step_definitions` and optional links from story/AC/conflict/ranking model.
  - AC3: `templates/storm/storm.json` contains empty Gherkin arrays and feature root metadata while staying validateable.
  - AC4: New prompts exist for `/storm:gherkin`, `/storm:bdd-sync`, `/storm:bdd-lint`, `/storm:bdd-conflicts`, `/storm:bdd-implement`.
  - AC5: `validate-artifacts.py` reports BDD/Gherkin metrics and catches orphan/deprecated/automation/link consistency issues without external dependencies.
  - AC6: `rank-backlog.py` includes `scenario_automation_cost` and `step_reuse_penalty`.
  - AC7: `README.md`, `AGENTS.md`, `routing-matrix.md`, `CHANGELOG.md` document the BDD layer and routes.
  - AC8: `validate-instructions.ps1` and `test-validate-instructions.ps1` include new canonical paths.
  - AC9: No central instruction claims Gherkin replaces acceptance criteria.
  - AC10: Existing starter `templates/storm/storm.json` passes `validate-artifacts.py`.
- Какие тесты добавить/изменить:
  - Update catalog validator required paths.
  - Add/update script-level fixtures only if current scripts have local test harness; otherwise smoke via starter template and a minimal temp Gherkin sample.
- Characterization tests / contract checks:
  - Validate old-style storm JSON without Gherkin arrays as compatible.
  - Validate new starter JSON with empty arrays.
  - Validate a sample with one GF/GR/SC/SD chain.
- Visual acceptance: `Не применимо`; нет UI.
- UI video evidence: `Не применимо`; нет UI automation.
- Базовые замеры до/после для performance tradeoff: `Не применимо`; lightweight local scripts.
- Команды для проверки:
```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
python scripts/storm/validate-artifacts.py templates/storm/storm.json
python scripts/storm/rank-backlog.py templates/storm/storm.json --out $env:TEMP\storm-ranking.md
git diff --check
```
- Stop rules для test/retrieval/tool/validation loops:
  - Если Gherkin lint requires external runtime, do not add dependency; keep checks lightweight or report limitation.
  - If schema compatibility check fails old-style JSON, fix before completion.
  - If validator misses orphan/deprecated scenario cases, add local fixture or explicit script check before completion.

## 12. Риски и edge cases
- Риск: Gherkin превратится в UI click-script pseudo-docs.
  - Смягчение: profile quality rules require declarative domain language and observable outcomes.
- Риск: adding required top-level arrays breaks old artifacts.
  - Смягчение: arrays optional in schema and validator treats missing as empty for compatibility.
- Риск: duplicating AC and scenarios creates drift.
  - Смягчение: bdd-sync checks AC/story/scenario/test/code links.
- Риск: BDD commands bypass QUEST when changing tests/code.
  - Смягчение: `/storm:bdd-implement` and automation changes route to `delivery-task` with QUEST/testing gate.
- Риск: writing a real Gherkin parser is too broad.
  - Смягчение: lightweight metadata/link checks now; framework-specific parsing left to consumer test stack.
- Риск: feature root convention conflicts with existing repo layout.
  - Смягчение: default `features/`, override recorded in `storm.json.metadata.feature_root`.

## 13. План выполнения
1. Update `storm-product-development.md` with BDD/Gherkin layer, commands, quality rules, metrics, DoD and route gates.
2. Extend `storm-artifacts.schema.json` and `templates/storm/storm.json` with optional Gherkin model.
3. Add prompt templates:
   - `prompts/storm/11-generate-gherkin.md`
   - `prompts/storm/12-bdd-sync.md`
   - `prompts/storm/13-bdd-lint.md`
   - `prompts/storm/14-bdd-conflicts.md`
   - `prompts/storm/15-bdd-implement-story.md`
4. Add `templates/storm/feature-template.feature`.
5. Update `validate-artifacts.py` for Gherkin metrics and consistency checks.
6. Update `rank-backlog.py` effort calculation.
7. Update `routing-matrix.md`, `AGENTS.md`, `README.md`, `CHANGELOG.md`.
8. Update catalog validator required paths and validator test fixture if needed.
9. Run validation commands and post-EXEC review.

## 14. Открытые вопросы
Нет блокирующих вопросов. Default path `features/` выбран как recommended convention; consumer override допускается через metadata.

## 15. Соответствие профилю
- Профиль: `product-system-design`.
- Выполненные требования профиля:
  - Цели и non-goals зафиксированы.
  - Public artifact/API model (`storm.json`, `.feature`, step definitions, commands) описан.
  - Совместимость и rollback описаны.
  - Validation and safety constraints описаны.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/profiles/storm-product-development.md` | Add BDD/Gherkin layer, commands, DoD, quality rules | Canonical behavior contract |
| `schemas/storm-artifacts.schema.json` | Add optional Gherkin model | Machine-readable traceability |
| `templates/storm/storm.json` | Add empty arrays and metadata | Starter compatibility |
| `templates/storm/feature-template.feature` | New feature template | Gherkin authoring baseline |
| `prompts/storm/11-generate-gherkin.md` | New prompt | `/storm:gherkin` |
| `prompts/storm/12-bdd-sync.md` | New prompt | `/storm:bdd-sync` |
| `prompts/storm/13-bdd-lint.md` | New prompt | `/storm:bdd-lint` |
| `prompts/storm/14-bdd-conflicts.md` | New prompt | `/storm:bdd-conflicts` |
| `prompts/storm/15-bdd-implement-story.md` | New prompt | `/storm:bdd-implement` |
| `scripts/storm/validate-artifacts.py` | Add BDD metrics/checks | Validation |
| `scripts/storm/rank-backlog.py` | Add BDD effort factors | Ranking |
| `instructions/governance/routing-matrix.md` | Add BDD routes | Stack assembly |
| `AGENTS.md` | Add BDD layer pointer | Entry point |
| `README.md` | Add usage and artifacts | User-facing docs |
| `scripts/validate-instructions.ps1` | Add required paths | Quality gate |
| `scripts/test-validate-instructions.ps1` | Update valid fixture if needed | Quality gate tests |
| `CHANGELOG.md` | Add `2.10.0` | Versioning policy |
| `specs/2026-06-12-storm-bdd-gherkin-layer.md` | This spec | QUEST audit |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Artifact chain | Story -> AC -> Tests -> Code | Story -> Rule -> Scenario -> Tests/Steps -> Code |
| Coverage | AC/test coverage | Behavior coverage 0..5 plus automation coverage |
| Conflict analysis | Story/constraint level | Story/rule/scenario/scenario data level |
| Ranking effort | Architecture/verification/dependency/migration | Adds scenario automation cost and step reuse penalty |
| Commands | `/storm:*` 00..10 | Adds `/storm:gherkin` and `/storm:bdd-*` |
| Schema | No BDD sections | Optional Gherkin sections |
| Feature files | Not defined | Default `features/`, override via metadata |

## 18. Альтернативы и компромиссы
- Вариант: replace acceptance criteria with Gherkin.
  - Плюсы: меньше дублирования.
  - Минусы: теряется compact overview layer and easier product review.
  - Почему не выбран: recommendation explicitly says not to replace AC; Gherkin should make AC executable.
- Вариант: require Cucumber runtime in central catalog.
  - Плюсы: stricter executable specification.
  - Минусы: breaks stack-neutral central instructions and adds dependency burden.
  - Почему не выбран: central catalog must stay framework-neutral.
- Вариант: store full scenarios only inside `storm.json`.
  - Плюсы: single file.
  - Минусы: worse authoring/reuse with BDD tools.
  - Почему не выбран: `.feature` files are better executable spec artifacts; `storm.json` stores metadata and links.
- Вариант: default `docs/product/features`.
  - Плюсы: product docs colocated.
  - Минусы: weaker signal as executable specs; harder for BDD tooling conventions.
  - Почему не выбран: default `features/` is better as executable spec convention, with override allowed.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, design goals and non-goals заполнены. |
| B. Качество дизайна | 6-10 | PASS | Responsibility split, data model, routing, compatibility, errors and performance covered. |
| C. Безопасность изменений | 11-13 | PASS | Compatibility, rollout/rollback and risks covered; no external runtime dependency. |
| D. Проверяемость | 14-16 | PASS | AC, commands, fixtures and validation plan defined. |
| E. Готовность к автономной реализации | 17-19 | PASS | Plan concrete; no blocking questions. |
| F. Соответствие профилю | 20 | PASS | Product-system-design requirements covered. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Gherkin layer добавляется без замены AC and without runtime dependency. |
| 2. Понимание текущего состояния | 5 | AS-IS maps current STORM profile/schema/prompts/scripts. |
| 3. Конкретность целевого дизайна | 5 | Data model, commands, metrics and files specified. |
| 4. Безопасность (миграция, откат) | 5 | Optional fields and legacy compatibility prevent breaking minor release. |
| 5. Тестируемость | 5 | Validator, script checks and compatibility fixtures planned. |
| 6. Готовность к автономной реализации | 5 | Step-by-step plan and no open blockers. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Scope reviewed: `specs/2026-06-12-storm-bdd-gherkin-layer.md`, instruction stack `model-behavior-baseline + quest-governance + collaboration-baseline + product-system-design + document-contract + versioning-policy + quest-mode + spec-linter + spec-rubric + review-loops`, selected profile `product-system-design`, open questions, planned changed files.
- Decision: можно запрашивать подтверждение.
- Review passes:
  - Scope/Evidence pass: reviewed current STORM profile, schema, starter template, prompts, quest-mode and user recommendation.
  - Contract pass: planned changes stay within catalog-governance after approval; SPEC-only mutation before approval; document-contract and SemVer constraints included.
  - Adversarial risk pass: checked for breaking schema risk, Gherkin replacing AC, runtime dependency creep, fake UI-script Gherkin, QUEST bypass for BDD implementation.
  - Re-review after fixes / Fix and re-review: no blocking findings requiring spec rewrite.
  - Stop decision: PASS, request approval.
- Evidence inspected:
  - `instructions/profiles/storm-product-development.md`
  - `schemas/storm-artifacts.schema.json`
  - `templates/storm/storm.json`
  - `prompts/storm/*`
  - `instructions/core/quest-mode.md`
  - User-provided Gherkin recommendation
- Depth checklist:
  - Scope drift / unrelated changes: implementation limited to STORM/profile/schema/prompts/scripts/docs/validator/changelog/spec.
  - Acceptance criteria: AC1-AC10 cover profile, schema, prompts, scripts, docs, compatibility and validation.
  - Validation evidence: commands and compatibility checks listed.
  - Unsupported claims: no external Cucumber quotes required in central docs; rules expressed as local workflow contract.
  - Regression / edge case: legacy `storm.json` compatibility and no runtime dependency explicitly protected.
  - Comments/docs/changelog: docs/changelog planned.
  - Hidden contract change: Gherkin optional-compatible for minor release, not replacement for AC.
  - Manual-review challenge: likely objections are schema breaking change, overcoupling to Cucumber runtime and low-quality generated Gherkin; all addressed.
- No-findings justification: SPEC is concrete, compatibility-preserving and validation-focused; remaining choices have a clearly selected default with override.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| LOW | rollout | Actual Gherkin lint quality can be shallow without a real parser. | Keep dependency-free checks now; leave framework-specific parser integration to consumer repos. | accepted-risk |

- Fixed before continuing: Не применимо.
- Checks rerun: Manual spec-linter/spec-rubric/post-SPEC review.
- Needs human: Требуется только утверждение EXEC фразой `Спеку подтверждаю`.
- Residual risks / follow-ups: Future optional integration with project-specific BDD runtime could be a separate profile/context if needed.

### Post-EXEC Review
- Статус: PASS
- Scope reviewed: all planned files from section 16, generated prompts/templates, script behavior, route/docs/changelog sync, validation outputs, git status.
- Decision: можно завершать EXEC; blocking findings не найдено.
- Review passes:
  - Scope/Evidence pass: implemented changes match approved planned files; no unrelated tracked files changed; generated `__pycache__` removed.
  - Contract pass: Gherkin sections are optional-compatible; no BDD runtime dependency introduced; acceptance criteria remain separate from Gherkin.
  - Adversarial risk pass: checked legacy `storm.json` compatibility, minimal GF/GR/SC/SD chain, `/storm:bdd-implement` route through QUEST, automated scenario link enforcement, and scenario ID flexibility.
  - Re-review after fixes / Fix and re-review: fixed scenario ID schema flexibility, BDD test link warning, constraint verification via scenarios, and misleading orphan counting; reran affected checks.
  - Stop decision: PASS.
- Evidence inspected:
  - `instructions/profiles/storm-product-development.md`
  - `schemas/storm-artifacts.schema.json`
  - `templates/storm/storm.json`
  - `templates/storm/feature-template.feature`
  - `prompts/storm/11-generate-gherkin.md`
  - `prompts/storm/12-bdd-sync.md`
  - `prompts/storm/13-bdd-lint.md`
  - `prompts/storm/14-bdd-conflicts.md`
  - `prompts/storm/15-bdd-implement-story.md`
  - `scripts/storm/validate-artifacts.py`
  - `scripts/storm/rank-backlog.py`
  - `AGENTS.md`
  - `README.md`
  - `instructions/governance/routing-matrix.md`
  - `scripts/validate-instructions.ps1`
  - `CHANGELOG.md`
- Depth checklist:
  - Scope drift / unrelated changes: no unrelated tracked files; untracked new files are planned prompts/template/spec.
  - Acceptance criteria: AC1-AC10 covered by profile/schema/template/prompts/scripts/docs/validator updates and checks.
  - Validation evidence: all planned local commands and compatibility checks passed.
  - Unsupported claims: no external Cucumber documentation claims embedded; Gherkin rules are local workflow contract.
  - Regression / edge case: legacy artifact without Gherkin arrays validates; sample GF/GR/SC/SD chain validates.
  - Comments/docs/changelog: docs/changelog/entrypoint/routing updated; no code comments added beyond existing script structure.
  - Hidden contract change: `/storm:bdd-implement` explicitly routes to `delivery-task`; Gherkin does not replace AC.
  - Manual-review challenge: the main risk is shallow lint without a real parser; accepted as intentional dependency-free scope for central catalog.
- No-findings justification: validation, compatibility fixtures and adversarial review did not reveal blocking regressions; remaining limitation is documented as accepted risk.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| LOW | bdd-lint depth | Validator checks metadata/link quality, but does not parse full Gherkin grammar or enforce framework-specific style. | Keep central catalog dependency-free; consumer repositories can add runtime-specific lint later. | accepted-risk |

- Fixed before final report:
  - Schema scenario ID pattern now accepts `SC-017-001`, `SC-0001-001` and domain-like IDs.
  - Tests linked only to scenarios no longer trigger false "no links" warning.
  - Constraints verified by scenarios satisfy verification strategy checks.
  - Orphan scenario metric counts active orphan scenarios only.
- Checks rerun:
  - `python -m py_compile scripts\storm\validate-artifacts.py scripts\storm\rank-backlog.py`
  - `python scripts\storm\validate-artifacts.py templates\storm\storm.json`
  - `python scripts\storm\rank-backlog.py templates\storm\storm.json --out $env:TEMP\storm-ranking.md`
  - `pwsh -File scripts\validate-instructions.ps1`
  - `pwsh -File scripts\test-validate-instructions.ps1`
  - `git diff --check`
  - Legacy `storm.json` without Gherkin arrays compatibility check.
  - Minimal GF/GR/SC/SD chain validation check.
  - JSON syntax parse for schema and starter template.
- Validation evidence:
  - Catalog validator: PASS.
  - Validator test harness: PASS, all 8 scenarios passed.
  - Starter `templates/storm/storm.json`: `OK: 0 errors, 0 warnings`.
  - Legacy old-style temp artifact: `OK: 0 errors, 0 warnings`.
  - Minimal Gherkin temp artifact: `OK: 0 errors, 0 warnings`.
  - Ranking smoke: wrote temp report and ranked 0 items.
  - `git diff --check`: PASS; only line-ending normalization warnings from Git.
- Unrelated changes: none observed in tracked files.
- Needs human: Нет.
- Residual risks / follow-ups: future consumer repositories may add framework-specific Gherkin parser/linter if they standardize on Cucumber/Behave/SpecFlow/pytest-bdd.

## Approval
Получено: пользователь написал "Спеку подтверждаю" перед EXEC.

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Анализ рекомендации и текущего STORM состояния | 0.9 | Нет | Создать рабочую спецификацию | Нет | Нет | Рекомендация меняет canonical STORM instructions/schema/scripts, значит нужен QUEST SPEC gate. | `instructions/profiles/storm-product-development.md`, `schemas/storm-artifacts.schema.json`, `templates/storm/storm.json`, `prompts/storm/*` |
| SPEC | Подготовка SPEC и post-SPEC review | 0.92 | Нет | Запросить утверждение пользователя | Да | Нет | Спека фиксирует optional-compatible BDD/Gherkin layer and validation plan; EXEC запрещён до approval. | `specs/2026-06-12-storm-bdd-gherkin-layer.md` |
| EXEC | Подтверждение SPEC | 1.0 | Нет | Обновить STORM profile, schema и templates | Нет | Да: пользователь написал `Спеку подтверждаю` | QUEST gate открыт, можно менять planned files в рамках спеки. | `specs/2026-06-12-storm-bdd-gherkin-layer.md` |
| EXEC | Реализация BDD/Gherkin layer | 0.88 | Результаты validation ещё не получены | Запустить проверки и исправить findings | Нет | Нет | Planned files обновлены: profile, schema, starter, feature template, prompts, scripts, routing/docs/changelog/validator. | `instructions/profiles/storm-product-development.md`, `schemas/storm-artifacts.schema.json`, `templates/storm/storm.json`, `templates/storm/feature-template.feature`, `prompts/storm/11-generate-gherkin.md`, `prompts/storm/12-bdd-sync.md`, `prompts/storm/13-bdd-lint.md`, `prompts/storm/14-bdd-conflicts.md`, `prompts/storm/15-bdd-implement-story.md`, `scripts/storm/validate-artifacts.py`, `scripts/storm/rank-backlog.py`, `AGENTS.md`, `README.md`, `instructions/governance/routing-matrix.md`, `scripts/validate-instructions.ps1`, `CHANGELOG.md` |
| EXEC | Validation and post-EXEC review | 0.95 | Нет | Финальный отчёт пользователю | Нет | Нет | Catalog checks, STORM script smoke tests, legacy compatibility and Gherkin sample validation passed; only accepted risk is lightweight metadata-level Gherkin lint. | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `scripts/storm/validate-artifacts.py`, `scripts/storm/rank-backlog.py`, `specs/2026-06-12-storm-bdd-gherkin-layer.md` |
