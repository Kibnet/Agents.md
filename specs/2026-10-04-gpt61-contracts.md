# GPT-6.1 Sol, EU processing и Astra Ultrafast

## 0. Метаданные

- Профиль: product-system-design; catalog-governance, expanded, medium/public instruction contract.
- Владелец: пользователь; EXEC-поручение 2026-10-04: «Давай внедряй» после конкретного source-backed предложения в этой задаче.
- Behavior baseline: GPT-6 Astra; workload recommendation включает GPT-6.1 Sol, прежние pins сохраняются.
- Поверхности: OpenAI API и Work/Codex описываются отдельно.
- Runtime smoke: Codex App Server stdio, gpt-6-astra/high, read-only/no-network/inert virtual tools; установлен CLI 0.160.0. Effective binding проверяется preflight; модель текущего чата не подменяет smoke metadata.
- Baseline commit: 62ce63992f0e7ba9a72f864f74cf774a084fbe76; active junction указывает на C:\Projects\My\Agents; до работы status чистый.
- Релиз: 6.0.0 из-за замены ошибочного JSON EU field/schema; commit/push/config changes не входят.
- Источники: [6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol), [GPT-6 guide](https://developers.openai.com/api/docs/guides/latest-model), [EU](https://developers.openai.com/api/docs/guides/your-data#which-models-and-features-are-eligible-for-data-residency), [Ultrafast](https://developers.openai.com/api/docs/guides/ultrafast-mode), [Multi-agent](https://developers.openai.com/api/docs/guides/responses-multi-agent), [Work/Codex](https://learn.chatgpt.com/docs/models), [Speed](https://learn.chatgpt.com/docs/agent-configuration/speed), [changelog](https://developers.openai.com/api/docs/changelog), [cache](https://developers.openai.com/api/docs/guides/prompt-caching#summary-of-model-differences).

## 1. Overview / Цель

Исходное поручение: найти новые модели и внедрить необходимые обновления инструкций. Успех: будущий агент различает 6.1 Sol и 6 Sol, верно выбирает EU processing и проверяет Ultrafast/multi-agent applicability. Итог: согласованные owners/JSON/validators/README/fixtures, локальная активация и durable evidence. Stop: обязательные checks и review green; не добавлять unrelated model каталог.

## 2. Текущее состояние (AS-IS)

Каталог 5.1.0 знает Astra/6 Sol/Luna; JSON schemaVersion 1. Sol/Luna допускают none+Chat tools; все EU модели требуют только default. Validator и G08 oracle закрепляют этот запрет. 6.1/Ultrafast отсутствуют. Runner жёстко привязан к CLI 0.154.0, установлен 0.160.0. Авторинг на active owners запрещён rollout контрактом: использовать новый isolated candidate; прежний worktree сохраняет исторические outputs и не сбрасывается.

## 3. Проблема

Документация upstream изменилась; прежние контракты могут породить несовместимые запросы и ложные ограничения.

## 4. Цели дизайна

Один owner на правило; exact ID/capabilities; surface boundaries; сохранение pins; schema migration явная; проверяемая локальная активация.

## 5. Non-Goals

Не менять config/auth/models текущего продукта, external skills, hooks, память. Не коммитить/пушить. Не переписывать исторические SPEC/evidence или прежние model IDs. Не обещать скорость/качество без eval. Retirement/vision guidance применяются только к затронутым поверхностям.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности

Model owner: roles/effort migration. API owner+JSON: exact API contracts. README: summary/links. Validators: positive и negative metadata checks. Fixtures: наблюдаемое поведение. Evidence: full prompts/answers/hashes/runtime/verdicts без auth.

### 6.2 Детальный дизайн

- Add gpt-6.1-sol: low/medium/high/xhigh/max, medium default, Responses tools, Chat function efforts пустой массив, sampling/logprobs запреты как у Astra. Старый Sol остаётся с none-only Chat exception.
- SchemaVersion 2: удалить euRequiredServiceTier. Sol 6.1/6 и Luna: euSupportedProcessingModes standard/flex/batch, euSupportedServiceTiers default/flex; batch является отдельным API workflow, не service_tier. Для Astra confirmed modes standard/batch (Batch явно указан в EU processing table), confirmed tier default. У всех записей euSupportCoverage: confirmed-only: отсутствие режима не доказывает запрет. Fast/priority/ultrafast EU запрещены; Ultrafast Astra поддерживает global/US.
- Добавить machine metadata Astra ultrafast и 6.1 multiAgent beta (enabled только после applicability check); GPT-5.6 beta support подтверждён, не выводить capability всей семьи по одному ID.
- API owner: beta header, hosted action outputs не исполнять в приложении, обычные function calls исполнять; replay сохраняет agent attribution, final root selection; implicit compaction и несовместимые summary/max_tool_calls/configuration_update. Все агенты получают request tools; per-agent authority обеспечивается приложением, не обещать встроенную изоляцию tools.
- API/product speed controls различаются. 6.1 Ultrafast пока не доступен; Work/Codex launch plan/workspace restrictions описываются кратко со ссылкой.
- Cache guidance: текущая модельная стоимость измеряется на успешной задаче; 6.1 cache read 5%, прежний Sol 10%; фиксированные цены в core не копировать.
- Vision bug fix 25 сентября: при смене runtime/исправлении encoder повторять только затронутые visual evals; прежний Astra text smoke не переименовывать в vision evidence.
- GPT-5.5 retirement 14 октября для ChatGPT/Work/Codex с ChatGPT sign-in; API отдельно. Исторические refs не удалять автоматически.
- Runner version update до проверенного 0.160.0; новое fixture pack gpt61-contracts с отдельными oracles. Старые inputs/oracles/evidence не переписывать; старый G08 пометить historical contract в README.
- UI/visual artifact/video: Не применимо, изменяется instruction/API contract, интерфейс не создаётся.

### 6.3 User-Observable Scenarios

| Scenario | Trigger | Expected result | Evidence | AC |
| --- | --- | --- | --- | --- |
| N01 | 6.1 none + Chat function | low + Responses; none/minimal отвергнуты | paired smoke | AC1 |
| N02 | Explicit 6 Sol none Chat pin | pin и исключение сохранены | paired smoke | AC1 |
| N03 | EU Sol/Luna budget processing | Flex/Batch доступны, batch не service_tier | paired smoke | AC2 |
| N04 | Astra Ultrafast EU/US | EU отказ, US/global допустимы; без обещания end-to-end speed | paired smoke | AC2 |
| N05 | 6.1 multi-agent loop | beta/header/hosted vs client calls, compaction и effort границы | paired smoke | AC3 |
| N06 | Work model unavailable | проверить rollout/picker, не переключать pin | paired smoke | AC1 |
| N07 | 6.1 sampling high | убрать unsupported fields | paired smoke | AC1 |
| N08 | 5.5 retirement / old vision failure | surface-aware retirement, затронутый visual re-eval | paired smoke | AC3 |

### 6.4 State / Interaction Matrix

Baseline immutable → candidate authored → checks/smoke/review → drift check → allowlisted activation → active validation. Drift или missing effective runtime блокирует зависимую запись; evidence failures не являются PASS.

### 6.5 Decision Ledger

| Decision | Owner | Chosen | Confidence | Risk | Needs user before EXEC |
| --- | --- | --- | --- | --- | --- |
| Внедрение конкретного предложения | user | «Давай внедряй» — прямое поручение текущего scope; имеет приоритет над формой фразы в repo guideline | 1 | не расширять scope | Нет |
| Schema/version | agent | schema 2/catalog 6.0.0, migration documented | 0.95 | потребители schema1 должны обновиться | Нет |
| Astra EU modes | agent | подтверждённые Standard/Batch по residency table; Flex не выводить из pricing | 0.95 | неполные upstream сведения явно marked confirmed-only | Нет |
| Effective smoke | agent | тот же Astra/high/CLI160 для обеих фаз | 0.9 | preflight может блокировать | Нет |

### 6.6 Runtime / Config / Data Contract Matrix

| Area | Source | Change | Compatibility | Verification |
| --- | --- | --- | --- | --- |
| API metadata | official docs + JSON | schema2/new exact model/modes | explicit breaking migration | positive+negative validator |
| Product controls | Learn docs | 6.1/Ultrafast/retirement guidance | account config untouched | surface smoke |
| Smoke transport | CLI effective response | version160 reviewed binding | historical outputs retained | preflight + audit |

## 7. Бизнес-правила / Алгоритмы

Точный model ID определяет effort и endpoint; family name не переносит none/tools/multi-agent. Нет alias gpt-6/6.1. Batch отделён от service_tier. Requested metadata не заменяет effective runtime.

## 8. Точки интеграции и триггеры

API owner загружается только для API/model routing. Product guidance не переписывает payload. Validators читают новую schema; optional FixtureRoot выбирает новый suite без изменения default runner pack.

## 9. Изменения модели данных / состояния

schemaVersion 2: новые gpt-6.1-sol и model-specific EU processing/tier lists; Astra ultrafast/6.1 beta metadata. Legacy entries/pins сохраняются; лишь неверный required single tier заменяется. Runtime config не меняется.

## 10. Миграция / Rollout / Rollback

Изолированный checkout от active HEAD. Before/after smoke на frozen source snapshots; source+model JSON входят в hashes. До активации active HEAD/dirty/preimage byte hashes должны совпасть; новые файлы не перезаписывать. Применять prepared allowlist через apply_patch, проверять canonical LF content hashes и описать EOL-only variance. Rollback только matching postimages; сохранить concurrent edits. Повторить active critical checks. Не обещать обновление уже загруженного контекста.

## 11. Тестирование и критерии приёмки

AC1: exact 6.1 contract и roles корректны; старый Sol none/pins сохранены. AC2: EU processing и Ultrafast без false tier mapping. AC3: multi-agent/retirement/vision boundaries. AC4: обязательные checks green и same-runtime smoke все candidate PASS. AC5: activation hashes/scope/review/evidence закрыты.

Исключение пользователя 2026-10-04: «Активировать с исключением для hooks». Для этой задачи AC4 допускает сохранённые hook timeout/dedup/native telemetry FAIL и зависимые hook integration prerequisites в Installer/Privacy. Общий governance не меняется. Active `test-validate-instructions.ps1 -SkipAgentOperations` должен пройти; Analyzer выполняется отдельно. Installer/Privacy не объявлять полностью проверенными: после failed hook telemetry prerequisite последующие assertions не выполняются. Остальные обязательные static/runtime/STORM/provenance/semantic/hash проверки сохраняются.

Обязательные команды candidate и active: pwsh -File scripts/validate-instructions.ps1; pwsh -File scripts/test-validate-instructions.ps1; python -B -m unittest discover -s scripts/fixtures/outcome-contracts -p test_runtime.py; git diff --check. На candidate дополнительно python -B -m unittest discover -s scripts/storm/tests -p test_*.py. Active повтор Python при content отличии/новой ошибке; runtime suite повторяется для boundary.

До изменений contract regression: новый schema/model/EU invariant fails на baseline; затем targeted green. Same-runtime paired runner с gpt61-contracts, preflight, audit effective metadata и ручное oracle grading обязательны. Durable pack specs/evidence/2026-10-04-gpt61-contracts/ содержит prompts, final answers, observed runtime, catalog/case/tools/adapter hashes и verdicts. Raw protocol ignored, auth не копируется. Не расширять/повторять green без изменения или нового риска.

### Acceptance-to-Test Matrix

| AC | Automated | Semantic | Evidence | If not tested |
| --- | --- | --- | --- | --- |
| AC1 | JSON assertions/negative effort+tools | N01/N02/N06/N07 | durable paired record | blocker |
| AC2 | EU lists/batch tier/ultrafast mutations | N03/N04 | durable paired record | blocker |
| AC3 | beta metadata assertions | N05/N08 | durable paired record | blocker |
| AC4 | mandatory suites/audit | oracle review all cases | command results + runtime | blocker |
| AC5 | drift/hash/diff | post-EXEC review | activation record | blocker |

## 12. Риски и edge cases

6 Sol и 6.1 смешаны → exact-ID tests. EU batch как tier → отдельный mode list. Product и API ultrafast access → separate source links. CLI protocol drift → preflight блокирует запуск. Writable reviewer не independent: separate adversarial fallback, residual risk explicit.

### Expected User Review Objections

| Objection | Why | Mitigation | Status |
| --- | --- | --- | --- |
| Сменил выбранную модель | новая рекомендация | pins сохраняются, config untouched | mitigated |
| Прошёл lint, но агент ошибается | semantic rules | paired behavioral smoke обязателен | mitigated |
| Сломал старый контракт молча | EU field replacement | schema2/catalog6.0 explicit migration | mitigated |

Rework checklist: исходный сценарий N01–N08; AC→evidence; решения записаны; objections mitigated; роли проверяются §19; runtime missing блокирует activation.

## 13. План выполнения

SPEC review → candidate authoring/preflight → paired smoke/required tests → review/fixes → drift-gated activation → active checks/evidence.

## 14. Открытые вопросы

Существенных user-owned вопросов нет; transport compatibility проверяется preflight.

## 15. Соответствие профилю

product-system-design: цели/non-goals, ownership, exact model API, schema migration, runtime safety, validation/rollback. Stack: routing/model/creator lens/collaboration/tool/quest; document/version/review/linter/rubric; session-insights context; API owner. Full creator-vibe не требуется для factual contract update.

## 16. Таблица изменений файлов

| File | Change | Reason |
| --- | --- | --- |
| instructions/core/model-behavior-baseline.md | 6.1 roles/effort/retirement | current product guidance |
| instructions/governance/openai-responses-api.md | exact model/EU/ultrafast/beta/cache | request correctness |
| schemas/openai-api-model-contract.json | schema2/metadata | machine source |
| scripts/validate-instructions.ps1; scripts/test-validate-instructions.ps1 | assertions/mutations | contract regression |
| scripts/fixtures/outcome-contracts/runtime.py; test_runtime.py; README.md | reviewed CLI160/new-pack docs | runner compatibility |
| scripts/fixtures/gpt6-family-contracts/README.md | historical G08 warning | preserve source evidence |
| scripts/fixtures/gpt61-contracts/ | 8 cases/oracles/manifest/README | current behavior |
| README.md; CHANGELOG.md | summaries/migration | public trace |
| this SPEC; specs/evidence/2026-10-04-gpt61-contracts/ | reviews/evidence | auditable result |

## 17. Таблица соответствий (было → стало)

| Area | Before | After |
| --- | --- | --- |
| Sol | 6 only | 6.1 distinct; 6 pin supported |
| EU | required default | model processing modes + actual tiers |
| Speed | Fast | Astra Ultrafast with region/surface limits |
| Runner | CLI154 | verified CLI160 |

## 18. Альтернативы и компромиссы

Rename old Sol отвергнут: ломает none/Chat contract. Сохранить wrong EU key как authoritative отвергнуто: создаёт противоречие. Полный model registry не нужен. Выбран targeted schema migration и новый pack, historical evidence retained.

## 19. Результат quality gate и review

### SPEC Linter Result

| № | Оценка | Evidence |
| --- | --- | --- |
| 1 | PASS | §1: outcome — различать exact models/EU/beta, локальная активация |
| 2 | PASS | §2: baseline62ce639/schema1/CLI154 против installed160 |
| 3 | PASS | §3: upstream contract drift вызывает неверные запросы |
| 4 | PASS | §4: exact IDs, surfaces, pins, явная migration |
| 5 | PASS | §5: non-goals config/push/исторические outputs |
| 6 | PASS | §6.1: owner/JSON/validator/fixture responsibilities |
| 7 | PASS | §8: API trigger, product boundary, FixtureRoot |
| 8 | PASS | §7: exactID, Batch≠tier, effective runtime |
| 9 | PASS | §12/§10: transport fail/drift блокируют, matching rollback |
| 10 | PASS | §6.2: token speed≠task speed; performance claim только eval |
| 11 | PASS | §9: schema2/new arrays, user state unchanged |
| 12 | PASS | §10/§17: removal field, SemVer6, consumers migrate |
| 13 | PASS | §10: preimages/postimages hashes, concurrent edits protected |
| 14 | PASS | §11: AC1–5 и всеcandidate PASS measurable |
| 15 | PASS | §11 matrix: negative mutations и N01–N08 evidence |
| 16 | PASS | §11/§1: required commands и stop aftergreen |
| 17 | PASS | §13: review→candidate→smoke→drift→activation→active |
| 18 | PASS | §6.5/§14: decisions recorded, no user-owned openquestion |
| 19 | PASS | §0/§12: expanded из-за publicschema migration |
| 20 | PASS | §15: product-system-design и governance stack |

### SPEC Rubric Result

Цель 5; AS-IS 5; дизайн 5; safety/rollback 5; validation 5; autonomy 5. 30/30 — не substitute EXEC evidence.

### Role-Based Review Result

Domain workflow: scope/pins — PASS. Tester: AC/scenarios/negative checks — PASS. Architect: exact IDs/schema migration — PASS. Operations/security: isolated candidate/runtime/drift — PASS. UX: Не применимо, UI не меняется.

### Post-SPEC Review

PASS. Separate reviewer gpt61_spec_review подтвердил exact 6.1/EU/Ultrafast/beta и покрытие eight scenarios. MEDIUM по неполному Astra EU allowlist исправлен: добавлены explicit confirmed-only coverage и Batch по fetched residency table; отсутствие Flex не объявляется отказом. LOW N05 усилен shared-tools/application authorization oracle. Primary Scope/Evidence pass: current owners/JSON/validators/runner/official pages inspected. Contract pass: N01–N08/AC1–5/migration. Adversarial fallback: none migration/old pin/EU batch/unsupported ultrafast/shared agent tools рассмотрены, новых находок нет после fix. Depth checklist: scope/authorization/source provenance/runtime/effective settings/field migration/historical fixture retention/cost and latency claims covered. No-findings justification: exact IDs и подтверждённые положительные/отрицательные условия разделены; meaningful behavioral checks обязательны. Reviewer sandbox danger-full-access, только чтение по дисциплине; этот review не technically independent read-only. Residual risk процедурной reviewer isolation; smoke runtime будет фактически проверен. Stop: PASS, authoring разрешён текущим user request.

### Post-EXEC Review

PASS с прямым task-scoped исключением пользователя для hooks. Исходный полный operational suite остаётся FAIL; этот статус сохранён.

Отдельный final reviewer gpt61_spec_review подтвердил post-EXEC PASS с user hook exception: самостоятельно пересчитал29canonical/19byte и actual hashes, прочитал raw Analyzer77/installerTEMP96, сверил active scope/evidence/coverage. Actual sandbox danger-full-access; technical independent isolation не заявляется.

- Scope reviewed: эта SPEC/AC1–AC5, actual active status/diff11tracked +8case pack/evidence; model/API owners, schema2, validators, runtime, README/CHANGELOG.
- Scope/Evidence pass: нет unrelated tracked changes; active29file prepared change set применён после byte preimage drift PASS. Canonical postimages29/29 равны candidate; raw19/29, десять EOL-only differences. Actual byte hashes записаны для matching-postimage rollback. SPEC/evidence обновлены отдельно от transferable catalog.
- Contract pass: AC1–AC3 PASS, candidate8/8 semantic PASS; baseline1/8 — покрытие новых фактов, N07partially correct. Audit valid8cases/16executions/failures0. AC4 закрыт после прямого override «Активировать с исключением для hooks», остальные обязательные checks green. AC5: activation/hash/scope/evidence/review выполнены; loaded session/runtime config не переключались.
- Adversarial fallback: oldSol none pin,6.1 minimal/Chat tools, EU Batch≠tier/Astra confirmed-only, shared-tool authority, retirement/API boundary проверены. Нет новых semantic findings; source limitations/coverage gaps не спрятаны за PASS.
- Role-based pass: domain pins/availability PASS; architect schema migration PASS; tester relevant static/behavior PASS с explicit hook exception; operations activation/drift/rollback PASS; UX Не применимо — UI не изменён.
- Evidence inspected: exact16final_answer, tool traces/mutations/workspace-final, effective Astra/high/default/CLI160/readOnly/noNetwork/environments[], sources/case/tool/adapter SHA; audit; command results, user reply; canonical operational source hashes; source hook integration lines479/481 и1374.
- Depth checklist: scope/AC/scenarios/objections reviewed; docs/changelog/migration/historical fixtures retained; no unsupported speed/availability claim; no hidden config/authorization change; review isolation and untested integration explicitly bounded.
- Fix and re-review: product N04/N06 facts перенесены из excluded README в owner до candidate snapshot; reviewer PASS и8/8 smoke. Operational canonicalLF evidence/per-case verdicts добавлены и re-reviewed. Installer source failure уточнён как hook-dependent prerequisite, не приписан baseline Installer run. Supplementary installer сначала setup-failed внеTEMP; guard сохранён, правильный TEMP run96/0 PASS.
- Stop decision: закрыть модельную миграцию по разрешённому user exception; hooks не чинить/таймауты не ослаблять без отдельного scope. Не повторять green без нового изменения/risk.
- No-findings justification: touched contracts проверены positive/negative и same-runtime observed behavior; оставшиеся defects принадлежат operational hooks/зависимым checks и явно исключены пользователем для этой задачи.

| Severity | Finding | Disposition | Status |
| --- | --- | --- | --- |
| BLOCKER | Full operational validation FAIL | Прямое «Активировать с исключением для hooks»; FAIL сохранён; static/model/runtime checks не отменены | accepted user exception |
| MEDIUM | Product facts outside snapshot | Перенесены в model owner; N04/N06 и reviewer PASS | fixed |
| MEDIUM | Operational raw hashes/EOL confusion |4 canonicalLF hashes equal,3 CRLF/LF differences; metadata corrected | fixed |
| MEDIUM | Per-case verdicts missing |8pair verdicts/reasons/N07partial durable | fixed |
| MEDIUM | Installer/Privacy downstream assertions unexecuted | source dependency documented; remediation96/Analyzer77 PASS собственные области; полный coverage не утверждается | accepted coverage limitation |

Validation: candidate static37PASS; Markdown43/outcome37guards57negative PASS; runtime14/STORM37 PASS; semantic8/8 and provenance16slots PASS. Active static/runtime14/test-validate(-SkipAgentOperations)/diffcheck PASS. Analyzer77 PASS; standalone installer remediation96checks/0failures PASS в systemTEMP. Full operational tests/retry/baseHooks FAIL — user-scoped exception. General Installer assertions after481 и downstream Privacy assertions after1374 не исполнены; отдельный remediation suite не заменяет их полностью. Reviewer danger-full-access/procedural read-only, не technically independent; primary adversarial fallback выполнен. Actual activation29canonical matches,19byte matches; rollback использует actual byte postimages и сохраняет concurrent drift. Коммит/push/CI publication/runtime settings changes не выполнялись.

## Approval

2026-10-04 пользователь отдельно выбрал «Активировать с исключением для hooks». Это ограниченное разрешение текущей активации с сохранением failed operational evidence, не разрешение переписывать hooks/таймауты или считать Installer/Privacy PASS.

Текущее прямое поручение пользователя «Давай внедряй» разрешает реализацию уже показанного конкретного change set. Оно имеет приоритет над guideline exact phrase для этой задачи; governance-файлы этим не меняются. Ранее утверждённая SPEC 2026-09-25 не используется как разрешение нового scope.

### Уточнение контракта 2026-10-05: границы выбора модели

Исходный симптом: пользователь видит, что текущий чат продолжает работать на выбранной в приложении модели независимо от workload recommendations. Поручение: «Исправляй» после предложения разделить текущую сессию, рекомендации человеку и управляемые запуски. Это конкретизация ранее принятого surface/runtime contract и Non-Goals (config/pins не менять), а не добавление автоматического router или новых полномочий. По quest-mode редакционная конкретизация в том же результате/scope/риске не сбрасывает EXEC; общий exact approval gate не меняется.

Scope: model-behavior-baseline, его README summary, CHANGELOG 6.0.1 и guards/representative fixtures только для этой границы. JSON/API payload и user config остаются прежними. Authoring и проверки — isolated session-model-boundaries checkout от 5c59da2; главный агент единственный writer. SPEC меняется на active пути как журнал разрешённой конкретизации.

Решения: модель текущего turn задаёт host; при отсутствии документированного control tool агент не переключает её инструкцией. Роли моделей и fallback используются только там, где есть разрешённый явный model selection (spawn/отдельный запуск/API). Model/effort override не означает capability/permission. Наследование субагента и фактические metadata проверяются отдельно; full-history fork не переопределять, если tool это запрещает. Рекомендации смены человеку давать по запросу или существенному риску/выигрышу, не на каждой мелкой задаче.

| Scenario / AC | Expected result | Evidence |
| --- | --- | --- |
| R01 / A1 | Обычная задача выполняется на текущей модели; текст про Luna не создаёт переключение, новый чат или config edit; virtual/user model name не выдаётся за actual runtime | baseline/candidate identical-runtime smoke, current tool schema |
| R02 / A2 | Разрешённый child launch использует явный selector; effective model отличается от requested — не объявлять успех выбора | inert launch observation и saved answer; это не live subagent switch |
| R03 / A3 | Явно разрешённый API request model selection остаётся возможным; выбранный root не запрещает другой model в создаваемом payload | virtual request artifact, boundary review |
| A4 | Документы/guards согласованы; реальные настройки неизменны | static/mutation/mandatory suite, drift+canonical hashes, active recheck |

Runtime smoke: CLI0.160.0/gpt-6-astra/high/readOnly/noNetwork, тот же runner/fixture pack в обеих фазах; 3 scenarios/6 executions. Smoke проверяет реакцию и действия в виртуальной среде, не доказывает смену root/child на живом backend. Статическая regression mutation защищает обязательное условие control capability. Следует сохранить complete prompts/answers/provenance и отдельно semantic verdicts.

Обязательные проверки: validate-instructions.ps1, test-validate-instructions.ps1, STORM37 при scripts change, existing runtime units и paired smoke/audit. Исключение hooks от 2026-10-04 было task-scoped: не переносить автоматически на это уточнение. При повторном operational failure записать failure/coverage и предъявить пользователю конкретное решение до активации; подготовленные изменения/evidence не считать активными.

Compatibility: рекомендации остаются advisory, API identifiers/schema2 не меняются. Rollback — сохранить preimages и применить их только при совпадении postimages; drift прерывает активацию. Static checks и semantic smoke не подменяют real routing evidence. UI/visual/video: Не применимо — UI не меняется. Performance: Не применимо — throughput/quality не измеряются.

Expected objections: «снова не переключается» — root switch не является outcome; «запретили выбирать child/API» — conditional control path и R02/R03; «PASS означает реальный routing» — явная граница симуляции; «исключение hooks стало постоянным» — отдельное решение при повторном failure. No new user-owned design decisions; activation gate может потребовать решение после full suite.

Post-SPEC review: PASS. Scope/evidence: addendum, current owner/README/tools, candidate HEAD5c59da2. Contract: A1–A4 соответствуют уже принятой surface/runtime границе и Non-Goals; quest-mode same-scope clarification допускает продолжить EXEC. Adversarial: запрет не блокирует разрешённые child/API launches; requested/effective mismatch не является PASS. Roles: tester — paired smoke + mandatory suite; architect — control capability/authority отдельно; operations — no config mutation, no inherited hook exception; UX copy — no repetitive recommendations. LOW «override» уточнено до model/effort override; relevant re-review — термин теперь однозначен. Stop: authoring разрешён, completion pending. Reviewer фактически danger-full-access/never, procedural read-only; independent technical isolation не утверждается. Primary adversarial fallback: нынешний root нельзя сменить текстом даже при явной просьбе без tool; альтернативный child или API не является root switch.

Post-EXEC intermediate NEEDS-FIX: первые baseline/candidate semantic2/3; R01 в обоих приписал virtual6.1 фактическому runtimeAstra. HIGH/A1 — добавить trusted host metadata/source qualification и повторить smoke без изменения oracle. Исправлено в candidate: workspace/user model field не proof actual model. Final-candidate 3cases rerun идёт с повторным использованием frozen baseline traces; R01 теперь указывает «По вашим данным… фактическую модель независимо подтвердить не могу». Static before-regression: ровно3missingguards; initial candidate staticPASS/runtime14/STORM37. Baseline full-suite attempt discarded как comparison: во время dynamic validator invocations source validator был изменён, старый copied scenario не включал новые anchors. Его failures не являются evidence product regression. Candidate full suite начат после стабилизации validator/scripts и продолжает выполнение; не менять validators до завершения. Добавленная metadata qualification требует повторного semantic и static check, не повторения независимых backend/STORM units.

## 20. Журнал действий агента

| Phase | Decision | Evidence / rest | Next | User decision | Artifacts |
| --- | --- | --- | --- | --- | --- |
| SPEC 2026-10-04 | Record direct implementation scope and reviewed source delta | baseline clean62ce639; candidate/preflight pending | separate review | Давай внедряй | this SPEC |
| SPEC review → EXEC | PASS; confirmed-only Astra metadata и shared-tools boundaries уточнены без расширения scope | Separate reviewer + primary adversarial fallback; runtime preflight ahead | candidate authoring | Давай внедряй | candidate + this SPEC |
| EXEC candidate | CLI160 preflight executed; static PASS; runtime14/STORM37 PASS; product availability fix reviewed | Candidate-only authoring; baseline/candidate 16 slots и full validator ещё выполняются | semantic grading/review перед activation | Давай внедряй | .artifacts/evals/gpt61-20261004/ |
| EXEC gate | Candidate8/8 и provenance16slots PASS; full operational suite FAIL, baseline Hooks reproduces hook failures | Prepared29files, no activation; user exception/repair choice pending | await user scope/gate decision | Не получено | candidate durable evidence + this SPEC |
| EXEC activation | Прямое user exception для hooks записано; drift29PASS, canonical29/29, raw19/29 | Active static/runtime14/diff PASS; Analyzer77 PASS; final active validator pending | active completion/review | Активировать с исключением для hooks | active + durable evidence |
| EXEC complete | Active validation green с явным user hook exception; canonical29/29, bytes19/29 | Analyzer77/installer96, full operational FAIL retained; no config/commit/push | complete current model migration | Активировать с исключением для hooks | activeSPEC + evidence |
| EXEC clarification 2026-10-05 | Surface/runtime scope concretized: root/child/API selection boundaries | Earlier Non-Goals preserved; separate candidate; review/checks pending | bounded authoring after review | Исправляй | addendum + candidate |
| EXEC clarification review/fix | R01 source attribution HIGH found and fixed; 3cases final rerun | first semantic2/3, oracle frozen; trusted metadata clause; candidate suite pending | finish smoke/review/gates before activation | Исправляй | candidate + local raw archive |
| EXEC clarification activation | Final semantic3/3, full candidate suite PASS319; no hook exception | Drift13/13; active canonical13/13, byte9/13(EOL-only4); active staticPASS | final post-EXEC review | Исправляй | active owner + model-control-boundaries evidence |
| EXEC clarification complete | Final post-EXEC PASS: A1–A4 met, HIGH/A1 fixed, no new findings | Reviewer recomputed13actual/13canonical hashes; full suite319, active static/diffPASS; procedural read-only caveat retained | complete; no commit/push | Исправляй | [Evidence](evidence/2026-10-05-model-control-boundaries/README.md) |
