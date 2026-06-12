# Интеграция STORM product workflow в центральный каталог

## 0. Метаданные
- Тип (профиль): `catalog-governance` + `product-system-design`; целевой новый сценарный профиль: `storm-product-development`.
- Владелец: центральный каталог инструкций `Agents`.
- Масштаб: medium.
- Целевая модель: gpt-5.5.
- Целевой релиз / ветка: `2.9.0` / текущая ветка `main`.
- Ограничения:
  - До утверждения этой спеки разрешено менять только этот файл в `./specs/`.
  - Переход в EXEC только после точной фразы пользователя `Спеку подтверждаю`.
  - Все новые документы в `instructions/*` должны быть на русском языке, с обязательными секциями из `document-contract.md` и kebab-case именами.
  - Standalone `storm-agent-process-pack/AGENTS.md` нельзя делать новым root entry point каталога и нельзя использовать как замену центрального `AGENTS.md`.
  - Исходную untracked папку `storm-agent-process-pack/` не удалять и не включать в tracked каталог без отдельного решения пользователя.
- Связанные ссылки:
  - `storm-agent-process-pack/README.md`
  - `storm-agent-process-pack/AGENTS.md`
  - `storm-agent-process-pack/storm/PROCESS.md`
  - `storm-agent-process-pack/storm/ARTIFACTS.md`
  - `storm-agent-process-pack/storm/COMMANDS.md`
  - `storm-agent-process-pack/storm/QUALITY_AUDIT.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`

Если секция не применима, явно укажите `Не применимо` и короткую причину, вместо заполнения нерелевантными деталями.

## 1. Overview / Цель
Интегрировать разработанный комплект `storm-agent-process-pack` в единый каталог инструкций так, чтобы STORM можно было использовать через central stack без копирования standalone `AGENTS.md` в consumer-репозитории.

Outcome contract:
- Success means:
  - В каталоге появился канонический сценарный профиль `storm-product-development` для команд `/storm:*`.
  - Routing matrix объясняет, когда подключать STORM как guided workflow, а когда STORM-команда становится delivery-task с QUEST/testing gate.
  - Prompt templates, стартовые templates, JSON schema и Python scripts STORM доступны из центрального каталога по стабильным путям.
  - README и root `AGENTS.md` показывают STORM как поддерживаемый guided workflow.
  - Validator и test suite считают новые STORM assets частью валидного каталога.
  - `CHANGELOG.md` содержит SemVer minor release entry.
- Итоговый артефакт / output: versioned изменение центрального каталога с profile, assets, routing, validation и changelog.
- Stop rules:
  - На SPEC остановиться после готовой спеки и запросить `Спеку подтверждаю`.
  - На EXEC не продолжать, если возникнет неоднозначный выбор между tracking исходной папки и удалением исходной папки; по этой спеки исходная папка остается untouched.
  - На EXEC остановиться и сообщить, если обязательные validation-команды не запускаются по отсутствию runtime или syntax/runtime error в импортированных скриптах.

## 2. Текущее состояние (AS-IS)
- Центральный каталог уже имеет entry point `AGENTS.md`, `routing-matrix.md`, core/context/profile/governance документы, `prompts/business-process-automation/`, `templates/specs/_template.md`, validation scripts и changelog.
- В README описан один guided workflow: `business-process-automation`.
- В `routing-matrix.md` есть тип задачи `guided-artifact-workflow`, но нет сценария для product discovery / living product specification / `/storm:*`.
- В `instructions/profiles/*` нет профиля, который описывает STORM-команды, `docs/product/storm.json`, traceability, cloud-conflict analysis, dependency-aware ranking и SDD implementation.
- `scripts/validate-instructions.ps1` содержит hardcoded список обязательных путей. Новые canonical assets должны быть добавлены туда, иначе каталог может пройти проверку без STORM или valid-catalog test может не скопировать нужные каталоги.
- В рабочем дереве есть untracked source folder `storm-agent-process-pack/` со standalone process pack:
  - `AGENTS.md` с полной инструкцией STORM;
  - `storm/PROCESS.md`, `ARTIFACTS.md`, `COMMANDS.md`, `QUALITY_AUDIT.md`;
  - `storm/prompts/00..10`;
  - `storm/templates/*.md|json`;
  - `storm/schemas/storm-artifacts.schema.json`;
  - `storm/scripts/validate_artifacts.py`, `rank_backlog.py`.
- Standalone installation из pack README предлагает оставить `AGENTS.md` в корне consumer repo. Это конфликтует с текущей архитектурой каталога, где consumer repo должен использовать central stack и только optional `AGENTS.override.md`.

## 3. Проблема
STORM-пакет нельзя безопасно использовать как часть общего каталога, пока он существует только как standalone copy-pack с собственным root `AGENTS.md`: он не участвует в central routing, не покрыт validation-контрактом каталога и провоцирует consumer-репозитории дублировать или заменять центральные инструкции.

## 4. Цели дизайна
- Разделение ответственности:
  - routing matrix выбирает сценарий;
  - `instructions/profiles/storm-product-development.md` задает behavior contract;
  - `prompts/storm/*` хранят step prompts;
  - `templates/storm/*` хранят стартовые product artifacts;
  - `schemas/storm-artifacts.schema.json` задает machine-readable контракт;
  - `scripts/storm/*` выполняют локальные проверки и ranking.
- Повторное использование: consumer repo подключает STORM из central catalog без копирования standalone root `AGENTS.md`.
- Тестируемость: validator проверяет наличие нового профиля и assets; scripts запускаются на starter `templates/storm/storm.json`; общий validator test suite проходит.
- Консистентность: новые markdown-документы соблюдают русский язык, kebab-case и обязательные секции.
- Обратная совместимость: существующие маршруты и `business-process-automation` не меняются; STORM добавляется как новый guided workflow.

## 5. Non-Goals (чего НЕ делаем)
- Не запускаем `/storm:*` для самого репозитория `Agents`.
- Не создаем `docs/product/storm.json` для этого каталога.
- Не меняем QUEST governance, central pointer contract и consumer onboarding semantics.
- Не заменяем root `AGENTS.md` содержимым `storm-agent-process-pack/AGENTS.md`.
- Не удаляем и не трекаем исходную папку `storm-agent-process-pack/`; она остается source input вне planned changed files.
- Не добавляем внешние Python dependencies для STORM scripts.
- Не реализуем отдельный CLI wrapper вокруг семантических `/storm:*` команд.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/profiles/storm-product-development.md` -> канонический профиль STORM workflow.
- `prompts/storm/*.md` -> reusable prompt templates для `/storm:full-cycle`, `/storm:bootstrap`, `/storm:trace`, `/storm:cover`, `/storm:derive`, `/storm:expand`, `/storm:conflicts`, `/storm:cleanup`, `/storm:rank`, `/storm:implement`, `/storm:audit`.
- `templates/storm/storm.json` -> стартовый `docs/product/storm.json`.
- `templates/storm/process-audit.md`, `product-goal.md`, `ranking.md`, `traceability.md` -> стартовые отчетные templates.
- `schemas/storm-artifacts.schema.json` -> JSON schema для STORM artifacts.
- `scripts/storm/validate-artifacts.py` -> консистентность `storm.json`.
- `scripts/storm/rank-backlog.py` -> dependency-aware ranking report.
- `AGENTS.md` -> краткое упоминание STORM как supported guided workflow и owner doc.
- `README.md` -> структура каталога, quick usage и команды проверки для STORM.
- `instructions/governance/routing-matrix.md` -> routing rules для `/storm:*`.
- `scripts/validate-instructions.ps1` -> required paths для STORM assets.
- `scripts/test-validate-instructions.ps1` -> valid catalog fixture копирует новый `schemas/` root.
- `CHANGELOG.md` -> release entry `2.9.0`.

### 6.2 Детальный дизайн
- Потоки данных:
  - Пользователь вызывает `/storm:*` или формулирует задачу product discovery / living specification.
  - Agent читает central `AGENTS.md`, затем `routing-matrix.md`.
  - Routing подключает `model-behavior-baseline + collaboration-baseline + storm-product-development`.
  - Для команд, которые меняют только product artifacts (`bootstrap`, `derive`, `expand`, `conflicts`, `rank`, `audit`, `full-cycle` в safe analysis mode без implementation/cleanup/test/code mutations), задача классифицируется как `guided-artifact-workflow` и не требует QUEST, если не меняются project code/infrastructure/canonical files.
  - `/storm:full-cycle` без QUEST обязан выполнять coverage step только как анализ пробелов и отчет по missing/partial coverage; любые test annotations, новые/измененные tests или code changes внутри full-cycle немедленно переводят работу в `delivery-task` с QUEST/testing gate.
  - Для команд, которые меняют tests/code/behavior (`cover`, `cleanup`, `implement`) или canonical project files, задача классифицируется как `delivery-task` и проходит QUEST/testing gate по обычным правилам.
- Контракты / API:
  - Semantic commands остаются текстовыми `/storm:*`, не CLI.
  - Canonical product artifact в consumer repo: `docs/product/storm.json`, если пользователь не указал существующее место для product docs; альтернативный путь должен быть явно зафиксирован в product docs README.
  - Центральные scripts запускаются как `python <AGENTS_ROOT>\scripts\storm\validate-artifacts.py docs/product/storm.json` и `python <AGENTS_ROOT>\scripts\storm\rank-backlog.py docs/product/storm.json --out docs/product/reports/ranking.md`.
- Output contract / evidence rules:
  - Для каждой STORM-команды итоговый ответ содержит changed artifacts, checks, key findings, risks/questions и next recommended STORM step.
  - Все inferred элементы получают `provenance`, `confidence`, `evidence`, `assumptions` и `open_questions`.
  - `status = implemented` не допускается без linked tests или явной non-automated verification strategy.
- Visual planning artifact для UI-facing изменений: `Не применимо`; изменение добавляет процессный workflow и не меняет UI layout/visual state.
- UI test video evidence для UI automation задач: `Не применимо`; изменение не является UI automation.
- Границы сохранения поведения:
  - Existing catalog routes сохраняются.
  - `business-process-automation` остается отдельным guided workflow.
  - STORM не ослабляет QUEST; при code/test changes он должен работать поверх delivery-task gate.
- Обработка ошибок:
  - Если `storm.json` не найден, profile должен предписывать создать его из `templates/storm/storm.json` или восстановить в ходе `/storm:bootstrap`.
  - Если Python недоступен, агент обязан выполнить логическую проверку вручную и явно указать missing runtime.
  - Если ranking script находит dependency cycles, ranking не считается готовым до разрыва/описания cycles.
- Производительность:
  - Scripts должны оставаться dependency-free и работать локально по одному JSON-файлу.
  - Инструкции должны требовать scoped code/test analysis, а не обязательный exhaustive repository indexing без stop rules.

## 7. Бизнес-правила / Алгоритмы (если есть)
- STORM ID prefixes:
  - `VS`, `PG`, `ND`, `CN`, `ST`, `AC`, `TS`, `CU`, `CF`, `EN`, `DP`.
- Provenance/confidence:
  - Любой вывод из кода считается гипотезой до owner confirmation.
  - Нельзя смешивать `inferred`, `proposed`, `confirmed`, `implemented`.
- Traceability:
  - Story -> AC -> tests -> code и обратные связи test/code -> story/constraint обязательны для продуктово значимых элементов.
- Full-cycle:
  - `/storm:full-cycle` не включает `/storm:cleanup` и `/storm:implement` без явного запроса пользователя.
  - `/storm:full-cycle` без QUEST не меняет tests/code/test annotations; coverage phase в этом режиме только фиксирует coverage gaps и recommended tests.
- Cleanup:
  - Нельзя удалять code/test unit, если он поддерживает active/implemented/proposed story, active constraint или enabler.
- Ranking:
  - `from` в dependency означает prerequisite для `to`.
  - При dependency cycles ranking должен остановиться.
  - `priority* = value* / cost*`, где value/cost считаются по closure.

## 8. Точки интеграции и триггеры
- `AGENTS.md`: добавить STORM в список supported guided workflows / owner-documents.
- `README.md`: добавить STORM в `Guided Workflows`, структуру репозитория и quick usage.
- `routing-matrix.md`:
  - добавить `/storm:*`, product discovery, living product specification, traceability, cloud-conflict, dependency-aware ranking как trigger для `storm-product-development`;
  - добавить route examples для STORM artifact-only, safe full-cycle и STORM code-changing commands.
- `validate-instructions.ps1`: добавить required paths.
- `test-validate-instructions.ps1`: добавить `schemas` в seed paths.

## 9. Изменения модели данных / состояния
- Новые tracked catalog assets:
  - `schemas/storm-artifacts.schema.json`
  - `templates/storm/storm.json`
  - `templates/storm/*.md`
- Persisted product data в consumer repo:
  - `docs/product/storm.json`
  - `docs/product/reports/*.md`
- В самом репозитории `Agents` product data не создается.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - Добавить новые файлы и routing.
  - Обновить validator/test suite.
  - Запустить validation-команды.
  - Проверить STORM scripts на starter template.
- Обратная совместимость:
  - Existing documents and workflows keep their current paths.
  - New workflow is opt-in by `/storm:*` or explicit product workflow request.
- Rollback:
  - Удалить `storm-product-development` profile, prompts/templates/schema/scripts, routing/README/AGENTS mentions, validator required paths и changelog entry.
  - Existing consumers unaffected if they did not opt into STORM.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - AC1: `instructions/profiles/storm-product-development.md` существует, проходит `document-contract.md`, написан по-русски и содержит команды/связанные документы.
  - AC2: profile переносит ключевой behavior contract из source pack: artifact model, semantic commands, DoD, запреты, audit metrics, ranking algorithm, cleanup safety rules, provenance/confidence/status rules и output format.
  - AC3: `routing-matrix.md` явно маршрутизирует `/storm:*`, различает artifact-only guided workflow, safe full-cycle без test/code mutations и code/test changing delivery-task.
  - AC4: `prompts/storm/` содержит 11 prompt templates с kebab-case именами и сохраненным покрытием команд `00..10`.
  - AC5: canonical `prompts/storm/*`, README examples и profile examples используют central stack / routing wording, а не standalone-фразу `Следуй корневому AGENTS.md` или рекомендацию заменить root `AGENTS.md`.
  - AC6: `templates/storm/`, `schemas/`, `scripts/storm/` содержат canonical starter artifacts, schema и scripts.
  - AC7: root `AGENTS.md` и `README.md` описывают STORM без рекомендации заменить central root `AGENTS.md`.
  - AC8: `scripts/validate-instructions.ps1` и `scripts/test-validate-instructions.ps1` проверяют новые canonical paths.
  - AC9: `CHANGELOG.md` содержит `2.9.0` с `Added`/`Changed`.
  - AC10: исходная `storm-agent-process-pack/` остается untracked source input и не попадает в planned changed files.
- Какие тесты добавить/изменить:
  - Обновить required-path scenario в `validate-instructions.ps1`.
  - Обновить valid-catalog fixture в `test-validate-instructions.ps1`.
- Characterization tests / contract checks:
  - Запустить общий validator до/после не требуется; достаточно post-EXEC validation.
  - Проверить STORM scripts на `templates/storm/storm.json`.
- Visual acceptance: `Не применимо`; нет UI.
- UI video evidence: `Не применимо`; нет UI automation.
- Базовые замеры до/после для performance tradeoff: `Не применимо`; scripts dependency-free и запускаются на малом starter JSON.
- Команды для проверки:
```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
python scripts/storm/validate-artifacts.py templates/storm/storm.json
python scripts/storm/rank-backlog.py templates/storm/storm.json --out $env:TEMP\storm-ranking.md
git diff --check
```
- Stop rules для test/retrieval/tool/validation loops:
  - Если `python` недоступен, заменить на найденный Python runtime только если он уже доступен в workspace dependencies; иначе зафиксировать blocker.
  - Если validator падает из-за новых paths, исправить validator/test fixture и повторить.
  - Если scripts падают на starter template, исправить import/path/name issues и повторить.

## 12. Риски и edge cases
- Риск: standalone `AGENTS.md` будет ошибочно скопирован как root catalog entry.
  - Смягчение: переносить правила в profile, а не заменять root `AGENTS.md`.
- Риск: STORM code-changing commands обойдут QUEST.
  - Смягчение: в profile и routing явно разделить artifact-only и code/test changing commands.
- Риск: validator не видит новые canonical assets.
  - Смягчение: required paths + valid-catalog test fixture.
- Риск: неясный `<AGENTS_ROOT>` в consumer repo.
  - Смягчение: использовать такой же placeholder pattern, как onboarding docs; примеры команд давать с `<AGENTS_ROOT>`.
- Риск: исходная untracked папка создает шум в `git status`.
  - Смягчение: не трекать и не удалять; в post-EXEC review явно отделить от planned changed files.

## 13. План выполнения
1. Создать `instructions/profiles/storm-product-development.md` по document contract.
2. Создать canonical STORM assets:
   - `prompts/storm/00-full-cycle.md`
   - `prompts/storm/01-bootstrap-from-code.md`
   - `prompts/storm/02-trace-tests.md`
   - `prompts/storm/03-complete-test-coverage.md`
   - `prompts/storm/04-derive-needs-goal.md`
   - `prompts/storm/05-goal-gap-backlog.md`
   - `prompts/storm/06-cloud-conflicts.md`
   - `prompts/storm/07-deprecate-cleanup.md`
   - `prompts/storm/08-dependencies-rice-ranking.md`
   - `prompts/storm/09-sdd-implement-story.md`
   - `prompts/storm/10-audit-and-improve-process.md`
   - `templates/storm/*`
   - `schemas/storm-artifacts.schema.json`
   - `scripts/storm/validate-artifacts.py`
   - `scripts/storm/rank-backlog.py`
3. Адаптировать prompt/script command examples с standalone `storm/scripts/*` на central `<AGENTS_ROOT>\scripts\storm\*`.
4. Адаптировать prompt/profile/README wording с standalone `Следуй корневому AGENTS.md` на central stack / routing wording.
5. Обновить `routing-matrix.md`, `AGENTS.md`, `README.md`.
6. Обновить `scripts/validate-instructions.ps1` и `scripts/test-validate-instructions.ps1`.
7. Добавить `CHANGELOG.md` entry `2.9.0`.
8. Запустить проверки из раздела 11.
9. Выполнить full post-EXEC review-loop.

## 14. Открытые вопросы
Нет блокирующих вопросов. Выбранный вариант не требует решения пользователя до EXEC, потому что он не удаляет исходную папку и не меняет central pointer contract.

## 15. Соответствие профилю
- Профиль: `product-system-design`.
- Выполненные требования профиля:
  - Цели и non-goals зафиксированы.
  - Целевая архитектура и границы подсистемы описаны.
  - Публичный API workflow (`/storm:*`, `<AGENTS_ROOT>` scripts, `docs/product/storm.json`) описан.
  - Совместимость с central stack и QUEST описана.
  - Security/config impact: external dependencies не добавляются; consumer path uses placeholder.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/profiles/storm-product-development.md` | Новый profile-документ | Канонический behavior contract STORM |
| `prompts/storm/*.md` | Новые prompt templates | Reusable guided workflow steps |
| `templates/storm/storm.json` | Новый starter artifact | Bootstrap для consumer `docs/product/storm.json` |
| `templates/storm/*.md` | Новые report templates | Reusable human-readable reports |
| `schemas/storm-artifacts.schema.json` | Новый JSON schema | Machine-readable artifact contract |
| `scripts/storm/validate-artifacts.py` | Новый script | Проверка `storm.json` |
| `scripts/storm/rank-backlog.py` | Новый script | Dependency-aware ranking |
| `instructions/governance/routing-matrix.md` | Добавить STORM routing | Подключение profile по trigger |
| `AGENTS.md` | Добавить STORM в canonical owner docs/guided workflows | Entry point visibility |
| `README.md` | Добавить usage, structure, commands | User-facing catalog docs |
| `scripts/validate-instructions.ps1` | Добавить required paths | Validation coverage |
| `scripts/test-validate-instructions.ps1` | Добавить `schemas` seed path | Valid catalog test |
| `CHANGELOG.md` | Добавить `2.9.0` | Versioning policy |
| `storm-agent-process-pack/` | Не менять, не трекать | Source input остается вне planned changes |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| STORM usage | Standalone pack с root `AGENTS.md` | Central profile + assets |
| Routing | Нет `/storm:*` route | `/storm:*` подключает `storm-product-development`; safe full-cycle без test/code mutations остается guided workflow, mutations переходят в delivery-task |
| Artifact schema | Только в source pack | `schemas/storm-artifacts.schema.json` |
| Scripts | `storm/scripts/*.py` в source pack | `<AGENTS_ROOT>\scripts\storm\*.py` |
| Prompt templates | `storm/prompts/*.md` в source pack с standalone root AGENTS wording | `prompts/storm/*.md` с central stack / routing wording |
| Validation | New assets не required | New assets required by validator |
| Consumer onboarding | Риск копировать root AGENTS | Central stack remains source of truth |

## 18. Альтернативы и компромиссы
- Вариант: скопировать `storm-agent-process-pack/` целиком в корень каталога.
  - Плюсы: минимальная работа, сохраняет standalone layout.
  - Минусы: дублирует root `AGENTS.md`, слабее интегрируется с routing, validator и существующей структурой.
  - Почему не выбран: нарушает архитектурный принцип central stack как единой точки входа.
- Вариант: добавить только README-ссылку на source pack.
  - Плюсы: самый малый diff.
  - Минусы: STORM не становится canonical reusable workflow, validator не проверяет assets.
  - Почему не выбран: не решает задачу "внедрить в общий каталог".
- Вариант: полностью переписать STORM как core governance.
  - Плюсы: сильная интеграция.
  - Минусы: слишком широкий impact и риск смешать product workflow с обязательными правилами всех задач.
  - Почему не выбран: STORM должен быть opt-in scenario profile.
- Выбранный вариант:
  - Плюсы: сохраняет central architecture, opt-in semantics, validation coverage и reusable assets.
  - Минусы: требует адаптации путей и нескольких документов.
  - Почему выбранное решение лучше в контексте этой задачи: оно делает STORM usable через общий каталог без ослабления существующих QUEST/consumer contracts.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, дизайн-цели и non-goals заполнены. |
| B. Качество дизайна | 6-10 | PASS | Ответственность, интеграция, правила, ошибки и perf описаны. |
| C. Безопасность изменений | 11-13 | PASS | Модель данных, rollout/rollback и риски покрыты. |
| D. Проверяемость | 14-16 | PASS | Acceptance criteria, проверки и planned file table заданы. |
| E. Готовность к автономной реализации | 17-19 | PASS | План, вопросы и review заполнены; блокирующих вопросов нет. |
| F. Соответствие профилю | 20 | PASS | `product-system-design` требования отражены. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Указано, что интегрируем STORM в central catalog без standalone root AGENTS. |
| 2. Понимание текущего состояния | 5 | Описаны текущий catalog layout, validator behavior и source pack contents. |
| 3. Конкретность целевого дизайна | 5 | Даны точные target paths, routing semantics и command contracts. |
| 4. Безопасность (миграция, откат) | 5 | Rollout/rollback описаны, source folder не удаляется, QUEST сохраняется. |
| 5. Тестируемость | 5 | Есть validator, validator tests, script smoke checks и `git diff --check`. |
| 6. Готовность к автономной реализации | 5 | План пошаговый, нет блокирующих вопросов. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Scope reviewed: `specs/2026-06-12-integrate-storm-product-workflow.md`, instruction stack `model-behavior-baseline + quest-governance + collaboration-baseline + product-system-design + document-contract + versioning-policy + quest-mode + spec-linter + spec-rubric + review-loops`, selected profile `product-system-design`, open questions, planned changed files.
- Decision: можно запрашивать подтверждение.
- Review passes:
  - Scope/Evidence pass: просмотрены source pack file list, key STORM docs, current README/AGENTS/routing, document contract, versioning, validation scripts, git status.
  - Contract pass: спека меняет только planned central catalog files после approval; на SPEC изменен только текущий spec; mandatory sections and validation are planned.
  - Adversarial risk pass: проверены риски standalone AGENTS replacement, QUEST bypass для code-changing STORM commands, validator blind spots и source folder deletion.
  - Re-review after fixes / Fix and re-review: не требовался; findings с однозначным исправлением не обнаружены.
  - Stop decision: PASS, можно запросить `Спеку подтверждаю`.
- Evidence inspected:
  - `storm-agent-process-pack/README.md`
  - `storm-agent-process-pack/AGENTS.md`
  - `storm-agent-process-pack/storm/PROCESS.md`
  - `storm-agent-process-pack/storm/ARTIFACTS.md`
  - `storm-agent-process-pack/storm/COMMANDS.md`
  - `storm-agent-process-pack/storm/QUALITY_AUDIT.md`
  - `storm-agent-process-pack/storm/prompts/*.md`
  - `storm-agent-process-pack/storm/templates/storm.json`
  - `storm-agent-process-pack/storm/schemas/storm-artifacts.schema.json`
  - `storm-agent-process-pack/storm/scripts/validate_artifacts.py`
  - `storm-agent-process-pack/storm/scripts/rank_backlog.py`
  - `instructions/governance/routing-matrix.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`
  - `scripts/validate-instructions.ps1`
  - `scripts/test-validate-instructions.ps1`
  - `git status --short`
- Depth checklist:
  - Scope drift / unrelated changes: source folder is related input but excluded from planned tracked changes.
  - Acceptance criteria: AC1-AC10 cover profile completeness, routing, safe full-cycle, prompt wording, assets, validation, changelog and source folder handling.
  - Validation evidence: exact post-EXEC commands listed.
  - Unsupported claims: claims are based on inspected files and current repository layout.
  - Regression / edge case: QUEST bypass and standalone AGENTS risks explicitly covered.
  - Comments/docs/changelog: README, AGENTS, routing and changelog planned.
  - Hidden contract change: STORM is opt-in profile, not global core behavior.
  - Manual-review challenge: отдельное ревью нашло риск обхода QUEST через full-cycle, риск тонкого профиля и риск standalone wording в prompts; спека исправлена и пересмотрена.
- No-findings justification: После исправлений спека фиксирует целевую структуру, ограничения, safe full-cycle routing, полноту переноса STORM-правил, prompt wording, проверки и rollback; неоднозначные destructive actions исключены.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| HIGH | routing | `/storm:full-cycle` мог трактоваться как guided workflow без QUEST, хотя включает coverage step, способный менять tests/annotations. | Явно разделить safe analysis mode и любые test/code mutations как `delivery-task` с QUEST/testing gate. | fixed |
| MEDIUM | acceptance | AC для профиля не гарантировал перенос ключевых правил из source pack. | Добавить AC на artifact model, commands, DoD, запреты, audit metrics, ranking/cleanup safety, provenance/status/output rules. | fixed |
| MEDIUM | prompt-quality | План адаптировал script paths, но не требовал убрать standalone root `AGENTS.md` wording из prompts/examples. | Добавить AC и плановый шаг для central stack / routing wording. | fixed |
| LOW | scope | Source folder останется untracked и будет виден в `git status`; это осознанный выбор, чтобы не удалять пользовательский input. | Указать в post-EXEC review как unrelated/untracked source input; не stage. | accepted-risk |

- Fixed before continuing: Уточнен safe-mode для `/storm:full-cycle`; усилен AC профиля; добавлен AC и плановый шаг по central stack wording.
- Checks rerun: Ручная проверка по spec-linter/spec-rubric/review-loop после внесения review-fix.
- Needs human: Требуется только утверждение EXEC фразой `Спеку подтверждаю`.
- Residual risks / follow-ups: После EXEC можно отдельной задачей решить, нужен ли packaged distribution artifact для STORM.

### Post-EXEC Review
- Статус: PASS
- Scope reviewed: approved spec, `git status --short`, `git diff --stat`, `git diff --name-only`, untracked files, relevant diff for `AGENTS.md`, `README.md`, `CHANGELOG.md`, `routing-matrix.md`, validator scripts, new STORM profile/assets, validation outputs.
- Decision: можно завершать.
- Review passes:
  - Scope/Evidence pass: inspected changed tracked files, new untracked canonical files, unchanged source input folder, validator outputs and STORM script smoke outputs.
  - Contract pass: AC1-AC10 satisfied; new profile has required document-contract sections; routing distinguishes safe full-cycle and code/test mutations; prompts/README/profile use central stack wording; validator required paths include STORM assets.
  - Adversarial risk pass: checked for old standalone wording/path markers, missing required profile sections, validator blind spots, script smoke failures and unrelated source folder staging risk.
  - Re-review after fixes / Fix and re-review: after detecting old standalone usage in Python script docstrings, updated `scripts/storm/validate-artifacts.py` and `scripts/storm/rank-backlog.py`, reran targeted STORM checks and full validators.
  - Stop decision: PASS; no blocker/high findings remain.
- Evidence inspected:
  - `instructions/profiles/storm-product-development.md`
  - `prompts/storm/*`
  - `templates/storm/*`
  - `schemas/storm-artifacts.schema.json`
  - `scripts/storm/validate-artifacts.py`
  - `scripts/storm/rank-backlog.py`
  - `AGENTS.md`
  - `README.md`
  - `instructions/governance/routing-matrix.md`
  - `scripts/validate-instructions.ps1`
  - `scripts/test-validate-instructions.ps1`
  - `CHANGELOG.md`
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `python scripts/storm/validate-artifacts.py templates/storm/storm.json`
  - `python scripts/storm/rank-backlog.py templates/storm/storm.json --out $env:TEMP\storm-ranking.md`
  - `git diff --check`
  - `rg -n "Следуй корневому|storm/scripts|storm\\scripts|validate_artifacts|rank_backlog" AGENTS.md README.md instructions prompts templates schemas scripts CHANGELOG.md`
- Depth checklist:
  - Scope drift / unrelated changes: planned files changed; `storm-agent-process-pack/` remains untracked source input and is intentionally not staged/tracked by this change.
  - Acceptance criteria: AC1-AC10 covered by profile, routing, assets, prompt wording, validator paths, changelog and untracked source handling.
  - Validation evidence: all required commands passed; targeted STORM scripts pass on starter template.
  - Unsupported claims: README/changelog claims map to actual created paths and routing/profile changes.
  - Regression / edge case: safe full-cycle cannot mutate tests/code without QUEST; `/storm:cover`, `/storm:cleanup`, `/storm:implement` are delivery-task routes.
  - Comments/docs/changelog: changelog `2.9.0` added; docs mention central stack; Python script usage comments updated to canonical paths.
  - Hidden contract change: STORM is opt-in profile, not global core behavior; existing workflows remain.
  - Manual-review challenge: a reviewer would likely check validator coverage and old standalone prompt wording; both were explicitly checked and fixed.
- No-findings justification: Final diff matches approved scope, validators pass, STORM scripts run, old standalone wording is absent from canonical docs/assets, and no destructive handling of the source input folder occurred.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| LOW | comments | Python script docstrings still referenced standalone `storm/scripts/*` and underscore script names after import. | Update usage strings to canonical `<AGENTS_ROOT>/scripts/storm/*` paths and rerun STORM script checks. | fixed |
| LOW | unrelated changes | `storm-agent-process-pack/` remains untracked and visible in `git status`. | Treat as source input; do not stage/delete in this task. | accepted-risk |

- Fixed before final report: Python script usage strings updated to canonical path/name.
- Checks rerun: `python scripts/storm/validate-artifacts.py templates/storm/storm.json`, `python scripts/storm/rank-backlog.py templates/storm/storm.json --out $env:TEMP\storm-ranking.md`, `pwsh -File scripts/validate-instructions.ps1`, `pwsh -File scripts/test-validate-instructions.ps1`, `git diff --check`, old-marker `rg`.
- Validation evidence:
  - `validate-instructions.ps1`: PASS.
  - `test-validate-instructions.ps1`: PASS, all scenarios.
  - `validate-artifacts.py`: OK, 0 errors, 0 warnings.
  - `rank-backlog.py`: wrote temp ranking report, ranked 0 starter items.
  - `git diff --check`: PASS; only line-ending warnings from Git.
- Unrelated changes: `storm-agent-process-pack/` is untracked source input from the user and intentionally left untouched.
- Needs human: Нет.
- Residual risks / follow-ups: Later packaging decision for the original source pack can be a separate task if desired.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Классификация задачи и routing | 0.95 | Нет | Изучить source pack и текущий каталог | Нет | Нет | Задача меняет канонический каталог, значит нужен QUEST SPEC gate. | `AGENTS.md`, `instructions/governance/routing-matrix.md`, `instructions/core/quest-governance.md`, `instructions/core/quest-mode.md` |
| SPEC | Анализ STORM source pack и validator | 0.9 | Нет | Создать рабочую спецификацию | Нет | Нет | Source pack содержит standalone workflow; нужно разложить его по central catalog zones и покрыть validator. | `storm-agent-process-pack/*`, `README.md`, `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1` |
| SPEC | Подготовка SPEC и post-SPEC review | 0.92 | Нет | Запросить утверждение пользователя | Да | Нет | Спека готова к автономной реализации, но EXEC запрещен до фразы `Спеку подтверждаю`. | `specs/2026-06-12-integrate-storm-product-workflow.md` |
| SPEC | Исправления по ревью спеки | 0.95 | Нет | Запросить утверждение пользователя | Да | Да: пользователь попросил внести исправления | Уточнены full-cycle gate, полнота переноса STORM-правил и запрет standalone prompt wording. | `specs/2026-06-12-integrate-storm-product-workflow.md` |
| EXEC | Подтверждение SPEC | 1.0 | Нет | Создать STORM profile и canonical assets | Нет | Да: пользователь написал `Спеку подтверждаю` | QUEST gate открыт, можно менять planned files в рамках спеки. | `specs/2026-06-12-integrate-storm-product-workflow.md` |
| EXEC | Создание STORM profile и assets | 0.9 | Нет | Обновить routing, README, AGENTS и changelog | Нет | Нет | Source pack перенесен в canonical paths; prompts адаптированы на central stack wording; профиль создан по document contract. | `instructions/profiles/storm-product-development.md`, `prompts/storm/*`, `templates/storm/*`, `schemas/storm-artifacts.schema.json`, `scripts/storm/*` |
| EXEC | Обновление routing/docs/validator | 0.9 | Нет | Запустить проверки | Нет | Нет | STORM добавлен в entry point, README, routing, changelog и validator required paths. | `AGENTS.md`, `README.md`, `instructions/governance/routing-matrix.md`, `CHANGELOG.md`, `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1` |
| EXEC | Проверки и post-EXEC review | 0.95 | Нет | Завершить отчет | Нет | Нет | Все обязательные проверки прошли; old standalone markers в canonical files отсутствуют; source pack оставлен untracked. | `specs/2026-06-12-integrate-storm-product-workflow.md`, validation commands |
