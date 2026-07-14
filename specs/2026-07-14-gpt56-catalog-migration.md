# Миграция центрального каталога инструкций на GPT-5.6

## 0. Метаданные
- Тип (профиль): `catalog-governance` + `product-system-design`.
- Владелец: центральный каталог инструкций `C:\Projects\My\Agents`.
- Масштаб: large.
- Оптимизационный target каталога: семейство GPT-5.6; default evaluation profile для сложной агентской работы в Codex/Work/API — Sol / `medium`, если поверхность и план это поддерживают. Это не является утверждением, что стандартный ChatGPT всегда работает на GPT-5.6.
- Целевой релиз / ветка: `3.0.0`; ветка определяется только при отдельном delivery-запросе пользователя.
- Ограничения:
  - до фразы пользователя `Спеку подтверждаю` изменяется только этот spec-файл;
  - исторические specs и опубликованные changelog entries не переписываются;
  - model/runtime/SDK/config migration вне каталога инструкций не выполняется;
  - availability, pricing, plan limits и минимальные версии клиентов не закрепляются как evergreen `MUST`;
  - global multi-agent delegation не включается по умолчанию.
- Связанные ссылки:
  - `https://developers.openai.com/api/docs/guides/latest-model`
  - `https://developers.openai.com/api/docs/models`
  - `https://developers.openai.com/api/docs/models/gpt-5.6-sol`
  - `https://developers.openai.com/api/docs/guides/reasoning`
  - `https://developers.openai.com/api/docs/guides/tools-programmatic-tool-calling`
  - `https://developers.openai.com/api/docs/guides/responses-multi-agent`
  - `https://learn.chatgpt.com/docs/models`
  - `https://learn.chatgpt.com/docs/prompting`
  - `https://help.openai.com/en/articles/20001354-gpt-56-in-chatgpt/`

Если секция не применима, явно указано `Не применимо` и короткая причина.

## 1. Overview / Цель
Актуализировать центральный каталог инструкций с GPT-5.5 на семейство GPT-5.6 так, чтобы active instruction stack отражал новую tier-модель `Sol / Terra / Luna`, eval-based выбор reasoning effort, более lean prompt contract, компактные границы автономности и on-demand правила для новых Responses API возможностей без раздувания обязательного core.

Outcome contract:
- Success means:
  - active owner-документы больше не объявляют GPT-5.5 целевой моделью;
  - `model-behavior-baseline` задаёт GPT-5.6 family contract, tier routing и reasoning migration policy;
  - surface matrix разделяет Standard ChatGPT, Work/Codex и OpenAI API и не переносит API-параметры в общий product contract;
  - общие правила prompt/autonomy сформулированы один раз в правильном owner-документе;
  - Responses API-specific возможности вынесены в отдельный governance overlay и подключаются только по явному триггеру;
  - canonical spec template и review-loop проверяют model/tier/effort assumptions и eval evidence;
  - validators ловят отсутствие нового owner-документа и регрессии active model markers;
  - historical GPT-5.5 artifacts сохранены как аудитная история;
  - changelog фиксирует breaking model-target migration как `3.0.0`.
- Итоговый артефакт / output:
  - согласованный GPT-5.6 central instruction stack;
  - новый `instructions/governance/openai-responses-api.md`;
  - обновлённые routing, template, review и validation contracts;
  - changelog entry и validation evidence.
- Stop rules:
  - на SPEC остановиться после заполнения quality gates, исправления объективных findings и запроса фразы `Спеку подтверждаю`;
  - на EXEC остановиться, когда все AC подтверждены, mandatory behavioral smoke и validators проходят, activation/rollback evidence заполнено, historical artifacts не затронуты и post-EXEC review имеет статус `PASS`;
  - не расширять scope на runtime configs, SDK upgrades, API client code, аккаунты/планы или массовую переработку профильных prompts;
  - не принимать снижение tokens/tool calls/latency как улучшение, если final output не проходит существующие quality gates.

## 2. Текущее состояние (AS-IS)
- Центральный каталог объявляет `gpt-5.5` целевой моделью в обязательном owner-контракте.
- Active GPT-5.5 references вне historical specs/changelog:
  - `AGENTS.md` — 2;
  - `instructions/core/model-behavior-baseline.md` — 3;
  - `instructions/governance/routing-matrix.md` — 1;
  - `README.md` — 4;
  - `templates/specs/_template.md` — 1.
- `model-behavior-baseline.md` уже содержит полезные для GPT-5.6 правила:
  - outcome-first contract;
  - точный процесс только для настоящих workflow/safety/validation invariants;
  - `MUST` / `NEVER` только для инвариантов;
  - stop rules для retrieval/tool/validation loops;
  - evidence и validation requirements;
  - независимое управление reasoning depth и response length;
  - tool-specific guidance в tool descriptions;
  - стабильный prompt prefix для caching;
  - `phase` preservation при manual replay Responses output items.
- Текущий reasoning contract знает `medium`, `low`, `high`, `xhigh`, но не отражает:
  - migration comparison текущего effort и одного уровня ниже;
  - `none` и `max`;
  - независимость standard/pro mode;
  - отличие Ultra/multi-agent orchestration от обычного reasoning effort.
- Правило user-visible preamble повторяется в `model-behavior-baseline.md` и `collaboration-baseline.md`.
- В catalog нет отдельного owner-документа для GPT-5.6 Responses API capabilities.
- В catalog нет global multi-agent policy; это безопасно сохраняется как default.
- `C:\Users\Kibnet\.codex\agents` подключён к рабочему репозиторию через central catalog setup, поэтому изменения репозитория автоматически становятся active после обновления файлов; отдельное копирование central `AGENTS.md` не требуется.
- До изменений обе обязательные проверки проходят:
  - `pwsh -File scripts/validate-instructions.ps1`;
  - `pwsh -File scripts/test-validate-instructions.ps1`.
- Рабочее дерево до создания этой spec было чистым.

## 3. Проблема
Текущий каталог фиксирует устаревший single-model target и смешивает surface-neutral behavior с отдельными Responses API деталями. Простая замена model string не решает новую tier-модель GPT-5.6, reasoning modes, более lean prompt guidance, различия между ChatGPT/Codex/API surfaces и opt-in характер PTC/multi-agent возможностей. Если ограничиться rename, consumer-агенты получат формально новый target, но сохранят неполный или неверно обобщённый execution contract.

## 4. Цели дизайна
- Сохранить один центральный owner для model/prompt behavior.
- Сделать GPT-5.6 family target явным и surface-aware.
- Разделить model tier, reasoning effort, reasoning mode и multi-agent orchestration.
- Сохранить outcome-first, evidence, stop rules и strict QUEST gates.
- Уменьшить повторения общих инструкций без ослабления инвариантов.
- Дать compact autonomy policy, предотвращающую лишние approval pauses и несанкционированные side effects.
- Загружать API-only правила только по явному routing trigger.
- Поддержать rollout через representative evals, а не предположение, что более высокий effort всегда лучше.
- Сохранить аудитную историю GPT-5.5 migration.
- Обеспечить проверяемый rollback и SemVer-согласованность.

## 5. Non-Goals (чего НЕ делаем)
- Не переписываем `specs/2026-04-27-gpt55-prompt-guidance.md` и другие historical specs.
- Не переписываем существующие GPT-5.5 entries в `CHANGELOG.md`.
- Не меняем `.codex/config.toml`, global Codex config, model picker, account plan или workspace admin policy.
- Не обновляем OpenAI SDK, API clients, tool handlers или application schemas в consumer-репозиториях.
- Не создаём API implementation examples, которые требуют ключа или live billing.
- Не фиксируем цены, rate limits, rollout dates, минимальные версии приложений или plan availability как долговечные catalog invariants.
- Не включаем `max`, Pro, Ultra, Programmatic Tool Calling или Multi-agent как default для всех задач.
- Не добавляем blanket-разрешение на subagents.
- Не меняем semantics `QUEST SPEC -> EXEC`, фразу `Спеку подтверждаю`, STORM workflow или существующие stack profiles.
- Не выполняем массовую переработку всех prompts/profiles; меняются только active model contract и прямо связанные quality gates.
- Не переносим visual planning policy из core в рамках этой migration; возможный structural cleanup остаётся отдельным follow-up после GPT-5.6 evals.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности
- `instructions/core/model-behavior-baseline.md` -> surface-neutral GPT-5.6 optimization behavior, task-shape tier/effort semantics, reasoning/verbosity/prompt rules и ссылка на API overlay без API/UI parameter conflation.
- `instructions/core/collaboration-baseline.md` -> единственный owner user-visible preamble и request authorization/autonomy boundaries.
- `instructions/governance/openai-responses-api.md` -> on-demand owner для GPT-5.6 Responses API model/runtime capabilities.
- `instructions/governance/routing-matrix.md` -> trigger подключения Responses API governance overlay и owner mapping.
- `AGENTS.md` -> краткий entry-point marker GPT-5.6 family и ссылка на Responses API overlay по триггеру.
- `README.md` -> архитектурное описание GPT-5.6 family contract и Surface Contract Matrix без превращения drift-prone current product mappings в evergreen `MUST`.
- `templates/specs/_template.md` -> metadata для model family/runtime profile и model migration/eval evidence.
- `instructions/governance/review-loops.md` -> prompt/model migration, surface conflation, behavioral eval и activation-safety review checks.
- `scripts/validate-instructions.ps1` -> required path и active GPT-5.6 semantic markers.
- `scripts/test-validate-instructions.ps1` -> два независимых negative scenario:
  - удаление `instructions/governance/openai-responses-api.md` приводит к fail;
  - замена обязательного GPT-5.6 target marker в `model-behavior-baseline.md` на GPT-5.5 приводит к fail.
- `CHANGELOG.md` -> release `3.0.0`, impact, compatibility и migration summary.
- `specs/2026-07-14-gpt56-catalog-migration.md` -> рабочая QUEST spec и audit trail.

### 6.2 Детальный дизайн

#### 6.2.1 Target model contract
- Объявить GPT-5.6 family оптимизационным target каталога, а не утверждать, что каждая ChatGPT/Codex/API surface фактически исполняет один и тот же model slug.
- Для complex/open-ended/high-value агентской работы считать Sol default tier, если он доступен на выбранной surface.
- Использовать Terra для everyday work, где representative eval не показывает необходимости Sol.
- Использовать Luna для clear/repeatable/high-volume задач с явным definition of done.
- Не считать tier доступным только потому, что он упомянут в каталоге; effective runtime profile должен определяться поверхностью, планом и workspace policy.
- Если желаемый tier недоступен, использовать ближайший доступный runtime вариант, явно фиксировать effective profile в validation/eval evidence и не заявлять непроверенные GPT-5.6-specific guarantees.

Surface Contract Matrix:

| Surface | Durable central rule | Current product/API mapping to verify at EXEC | Forbidden assumption |
| --- | --- | --- | --- |
| Standard ChatGPT conversation | Не объявлять GPT-5.6 universal default; использовать доступный product selector и фиксировать effective option | Current official snapshot: GPT-5.5 Instant остаётся default; GPT-5.6 Sol обслуживает Medium/High/Extra High, а Pro показывается как GPT-5.6 Sol Pro; Terra/Luna не выбираются в standard conversations | API slugs, `reasoning.effort` и `reasoning.mode` нельзя выдавать за ChatGPT UI contract |
| ChatGPT Work / Codex app, CLI, IDE | Применять task-shape routing Sol/Terra/Luna только среди реально доступных options; начать с surface default | Current official snapshot: Sol/medium — рекомендуемый default, UI labels могут быть Light/Medium/High/Extra High/Max/Ultra; Ultra означает delegation | Нельзя предполагать одинаковые labels, entitlements или selector behavior между Work, app, CLI, IDE и cloud |
| OpenAI API | Использовать точные model IDs и request parameters из Responses API owner | `gpt-5.6` aliases `gpt-5.6-sol`; `reasoning.effort=none..max`; `reasoning.mode=pro` независим от effort | API parameter semantics нельзя переносить в product UI; alias нельзя считать immutable snapshot |
| Unknown / unavailable surface | Сначала получить runtime evidence; затем выбрать ближайший доступный profile и описать fallback | Проверить official docs, model picker/config и workspace policy | Нельзя заявлять effective GPT-5.6 runtime без evidence |

- Current product mappings в таблице являются verification snapshot, а не evergreen `MUST`: перед EXEC и будущими model migrations их нужно сверять с official sources.
- В `model-behavior-baseline.md` остаются только surface-neutral task-shape, outcome, effort-selection и evidence rules; точные API поля принадлежат `openai-responses-api.md`, а product selector mapping — информационному README/validation evidence.

#### 6.2.2 Lean prompt contract
- Сохранить outcome-first структуру: goal, context, hard constraints, success criteria, required evidence, output contract, stop rules.
- Удалять повторяющиеся общие правила из downstream docs; каждое общее правило должно иметь один owner, а потребители должны добавлять только specific delta.
- Не предписывать пошаговый процесс, если путь не является invariant.
- Не использовать broad brevity guidance как замену output contract.
- Для short output задавать приоритет сохранения:
  1. conclusion/decision;
  2. required evidence;
  3. material caveats/risks;
  4. next action;
  5. optional background удаляется первым.
- Сохранить tool-specific input/output/error guidance в tool descriptions, а в central instructions — только routing, authorization, retry и stop policy.

#### 6.2.3 Autonomy and approval boundaries
- Перенести user-visible preamble в `collaboration-baseline.md` как единственный owner; `model-behavior-baseline.md` должен ссылаться на него без дублирования текста.
- Добавить compact authorization contract:
  - `answer / explain / review / diagnose / plan` -> read-only inspection и отчёт; изменения не выполняются без отдельного запроса;
  - `change / build / fix` -> разрешены scoped local changes и non-destructive validation, если более специфичный gate не требует approval;
  - `QUEST` остаётся более специфичным gate и блокирует EXEC до `Спеку подтверждаю`;
  - external writes, destructive actions, purchases/costly actions и material scope expansion требуют отдельного разрешения.
- Не повторять blanket `ask first` вне owner/gate, чтобы не создавать лишние approval pauses для безопасной in-scope работы.

#### 6.2.4 Reasoning effort and modes
- Для нового workflow начинать с default reasoning level выбранной surface; для Codex/Work/API, где доступен `medium`, использовать его как balanced starting point.
- При migration с GPT-5.5 сначала сравнивать прежний effort и один уровень ниже на одинаковых representative tasks.
- Surface-neutral guidance использует семантический принцип «lowest available level that passes the quality bar»; exact selector labels и request parameters берутся из Surface Contract Matrix и соответствующего owner.
- В OpenAI API поддерживаемые `reasoning.effort`: `none`, `low`, `medium`, `high`, `xhigh`, `max`; в Codex/Work им могут соответствовать product labels Light/Medium/High/Extra High/Max.
- В API `none` использовать как latency baseline только для задач без существенного reasoning/tool use; при наличии reasoning/tool use сравнить с `low`.
- `high`/`xhigh` применять при измеримом quality gain или повышенном риске.
- `max` резервировать для hardest quality-first workflows и сравнивать с `xhigh`.
- Для OpenAI API Pro является `reasoning.mode=pro`, независимым от effort и без отдельного Pro slug; в standard ChatGPT Pro является product option GPT-5.6 Sol Pro. В обоих случаях использовать Pro только при измеримой reliability benefit.
- В Codex/Work Ultra является multi-agent orchestration option, а не ещё одним single-agent effort level; не включать без явного capability/authorization route.

#### 6.2.5 Responses API governance overlay
Новый `instructions/governance/openai-responses-api.md` должен применяться только к проектированию, реализации или review OpenAI Responses API workflows и содержать:

Normative allocation для будущего owner-документа:
- `MUST`: проверка model/feature support и effective response fields; state/replay integrity; PTC linkage/final-message handling; authorization и root synthesis для multi-agent; conditional `safety_identifier`; safeguard classification.
- `SHOULD`: Responses API для reasoning/tool-calling/multi-turn workflows; `previous_response_id` как простой continuation path; measured tier/effort/caching selection; direct calls для approval/judgment/final validation.
- `MAY`: Pro, `all_turns`, explicit caching, PTC, Multi-agent и `original` image detail только после applicability/eval checks.

- точный выбор `gpt-5.6-sol` / `gpt-5.6-terra` / `gpt-5.6-luna`; `gpt-5.6` документируется как alias Sol, но explicit tier предпочтителен, когда tier является частью contract;
- рекомендацию Responses API для reasoning/tool-calling/multi-turn workflows;
- `reasoning.effort` и `reasoning.mode` как независимые параметры;
- `reasoning.context`:
  - `auto` как default;
  - `all_turns` для стабильных goals/assumptions/priorities при доступе к прошлым response items;
  - `current_turn` при нерелевантности старого reasoning;
  - support является model-dependent; перед использованием non-default value проверять model capability, а на каждом response читать effective `reasoning.context` и не считать requested value фактически применённым без подтверждения;
- state continuation:
  - `previous_response_id` как основной простой путь;
  - при manual history replay сохранять и resend все response output items без реконструкции; `phase` сохранять, если поле присутствует, и не синтезировать его для item/surface, которая его не вернула;
  - при `store: false`/ZDR запрашивать и replay `reasoning.encrypted_content`;
- prompt caching:
  - implicit caching допустим;
  - explicit breakpoints/TTL использовать только при подтверждённой выгоде;
  - измерять cache reads/writes и не создавать лишние cache writes;
  - для GPT-5.6 explicit configuration использовать актуальные `prompt_cache_options`/`ttl`; deprecated cache fields не копировать без official compatibility evidence;
- Programmatic Tool Calling:
  - только для bounded predictable stages, где code уменьшает/структурирует intermediate output;
  - direct tool calls для semantic judgment, approval-sensitive actions, adaptive search, citations/native artifacts и final validation;
  - явные eligible tools, schema, evidence, concurrency, retry и stop limits;
  - подключать `programmatic_tool_calling`, opt-in eligible tools через `allowed_callers`, обрабатывать `program`, program-issued function calls и `program_output`;
  - сохранять `call_id` и `caller` linkage при continuation;
  - `program_output` и final assistant `message` являются разными outputs: продолжать workflow до final message и проверять их отдельно;
- Multi-agent beta:
  - только для concrete independent bounded workstreams;
  - one agent для sequential dependency, small task, contended mutable resource или fixed deterministic graph;
  - root agent отвечает за final synthesis;
  - shared tool availability и write contention входят в risk review;
- `original`/`auto` image detail применять только когда исходное разрешение materially влияет на результат; учитывать token/latency impact;
- для applications, обслуживающих individual end users, передавать стабильный privacy-preserving `safety_identifier`; не применять это условие к workflow без individual end-user identity без отдельного privacy design;
- safeguard intervention классифицировать отдельно от tool/sandbox/runtime failure и не обходить через indirect retry.

#### 6.2.6 Multi-agent boundary for the central catalog
- В mandatory core не добавлять инструкцию автоматически использовать subagents.
- Core должен только фиксировать, что Ultra/API Multi-agent являются opt-in orchestration capabilities.
- Codex delegation допускается только когда пользователь, явно подключённый skill/profile или более специфичная инструкция её запрашивает.
- Создание отдельного reusable multi-agent skill/profile не входит в этот release; его необходимость оценивается после наблюдения GPT-5.6 workloads.

#### 6.2.7 Active vs historical references
- Active semantic scan включает:
  - `AGENTS.md`;
  - `README.md`;
  - `instructions/**`;
  - `templates/specs/_template.md`.
- Historical scan не требует удаления GPT-5.5 из:
  - `specs/**`, кроме текущей migration spec;
  - существующих entries `CHANGELOG.md`;
  - historical eval fixtures, если они появятся.
- Допустимое active упоминание GPT-5.5 — только migration/compatibility wording, но не declaration target model.

#### 6.2.8 Versioning
- Смена mandatory target contract с GPT-5.5 на GPT-5.6 family считается breaking change.
- Целевой release — `3.0.0` согласно `versioning-policy.md`.
- Если в ходе implementation обнаружится требование сохранить formal GPT-5.5 target compatibility, это materially меняет release contract и требует `ASK-HUMAN`, а не молчаливой смены на `2.12.0`.

### 6.3 User-Observable Scenarios

| Scenario | User action / trigger | Expected visible result / output | Evidence required | Covered by AC |
| --- | --- | --- | --- | --- |
| Обычная catalog-governance или delivery task | Consumer загружает central stack | Агент видит GPT-5.6 family target, outcome-first contract и не загружает API-only детали без триггера | Active docs scan, routing review | AC1, AC2, AC6 |
| Standard ChatGPT conversation | Пользователь работает без Work/Codex/API surface | Каталог не утверждает, что GPT-5.6 является universal default, и не предлагает API slugs/parameters как UI controls | Surface matrix review, official product-source refresh | AC1, AC4, AC6 |
| ChatGPT Work / Codex | Доступен product model/reasoning selector | Task-shape routing выбирает Sol/Terra/Luna из реально доступных options; effective profile фиксируется в evidence | Surface/effective-profile evidence, behavioral smoke | AC2, AC4, AC9 |
| Сложная неоднозначная задача | Runtime поддерживает tier selection | Guidance рекомендует Sol; higher effort выбирается по риску/eval, а не автоматически | Baseline text, template/review checks | AC2, AC3, AC4 |
| Повседневная или latency-sensitive задача | Нужно снизить стоимость/latency | Guidance предлагает Terra/low и comparison с baseline без потери quality gates | Tier/effort algorithm, eval matrix | AC2, AC4, AC9 |
| Чёткая массовая задача | Есть repeatable output contract | Luna допустима только при ясном definition of done и representative validation | Baseline text, review evidence | AC2, AC9 |
| OpenAI Responses API workflow | Task явно касается Responses API | Routing подключает on-demand API owner с reasoning/PTC/caching/state/multi-agent rules | Routing semantic check, owner content check | AC5, AC6 |
| Standard ChatGPT/Codex task без API implementation | API capabilities не нужны | API overlay не считается обязательным core и не раздувает prompt | Routing review, no unconditional include | AC6 |
| Исторический аудит GPT-5.5 migration | Пользователь открывает старую spec/changelog | История остаётся неизменной и объясняет прежний target | Git diff/path scan | AC10 |
| Spec для будущего model/prompt change | Агент создаёт QUEST spec | Template просит model family/runtime profile и representative eval evidence | Template inspection | AC7 |

### 6.4 State / Interaction Matrix

| Current state | Trigger | Expected transition/result | Empty/error/disabled/concurrent case | Notes |
| --- | --- | --- | --- | --- |
| Active target `gpt-5.5` | Release `3.0.0` approved | Active target становится GPT-5.6 family | Если runtime не даёт GPT-5.6, фиксируется effective fallback; catalog contract не подменяется | Availability не кодируется как вечный факт |
| Standard ChatGPT default | GPT-5.6 catalog migration | Product runtime определяется фактическим selector/automatic routing, а не API slug из core | Если reasoning option недоступна, не заявлять GPT-5.6 execution | Current product mapping — refreshable snapshot |
| API overlay не подключён | Task не касается Responses API | Только surface-neutral core | Не применимо | Lean default |
| API overlay не подключён | Task касается Responses API | Overlay добавляется через routing trigger | Если feature недоступна, guidance требует bounded fallback/uncertainty | Не менять application API автоматически |
| Single-agent execution | Нет explicit multi-agent route | Single-agent сохраняется | Ultra/API beta unavailable -> single-agent | No global delegation |
| Single-agent execution | Explicit authorized independent workstreams | Возможен multi-agent путь | Shared mutable resource -> отказаться от parallel writes | Root synthesis обязателен |
| Historical GPT-5.5 artifact | Active migration | Artifact остаётся неизменным | Не применимо | Audit history |
| Validation passes | New owner/markers added | Validator сохраняет green state и получает negative tests | Missing owner/marker -> validation fail | Required path + semantic checks |
| Active junction points at main checkout | EXEC implementation starts | Canonical edits выполняются и проверяются в isolated worktree; active root не меняется до prepared activation | Dirty/concurrent active root -> activation stop | После activation немедленно повторить validators и rollback on failure |

### 6.5 Decision Ledger

| Decision | Owner | Default / chosen option | Confidence | Risk if assumed | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |
| Release version | agent | `3.0.0` | 0.94 | `2.12.0` нарушил бы local SemVer rule для смены mandatory target contract | Нет |
| Target naming | agent | `GPT-5.6 family` optimization target; Sol default complex tier, API ID `gpt-5.6-sol` только в API context | 0.98 | Single universal slug скрыл бы tier и surface semantics | Нет |
| Surface semantics | agent | Surface-neutral core + explicit Standard ChatGPT / Work-Codex / API matrix | 0.98 | API parameters в mandatory core исказили бы product UI/default behavior | Нет |
| API-specific placement | agent | Новый governance overlay `openai-responses-api.md` | 0.9 | Размещение в mandatory core увеличит prompt и смешает surfaces; новый stack profile конфликтует с profile-slot model | Нет |
| Autonomy owner | agent | `collaboration-baseline.md` | 0.93 | Дублирование в model baseline продолжит вызывать instruction repetition | Нет |
| Multi-agent default | agent | Не включать; explicit opt-in only | 0.98 | Blanket delegation изменит authorization и создаст write contention | Нет |
| Historical GPT-5.5 records | agent | Не изменять | 0.99 | Потеря audit history | Нет |
| Runtime config migration | agent | Вне scope | 0.99 | Неавторизованные global/project config mutations | Нет |
| Activation strategy | agent | Isolated worktree validation + prepared short activation in junction target | 0.95 | Sequential live edits оставили бы частично обновлённый central stack | Нет |
| Visual planning policy relocation | agent | Не выполнять в этой migration | 0.88 | Scope drift и смешение model migration со structural refactor | Нет |

### 6.6 Runtime / Config / Data Contract Matrix

| Contract area | Current source of truth | Expected change | Compatibility / migration | Verification |
| --- | --- | --- | --- | --- |
| Target model behavior | `instructions/core/model-behavior-baseline.md` | GPT-5.6 family + tier/effort rules | Breaking target change -> 3.0.0 | Active marker scan |
| Surface mapping | Product docs/API docs + effective runtime evidence | Surface-neutral core; product mapping in README/evidence; exact API fields in API owner | Current availability/labels are refreshable, not evergreen MUST | Official-source refresh + surface scenario review |
| Collaboration/autonomy | `instructions/core/collaboration-baseline.md` + duplicated preamble in model baseline | Compact authorization owner + single preamble owner | QUEST remains stricter gate | Manual contract review, semantic scan |
| Responses API features | API-specific bullets inside core, no owner | Новый on-demand governance overlay | Pure ChatGPT/Codex tasks do not load it | Routing review, required path check |
| Spec metadata | `templates/specs/_template.md` hardcodes `gpt-5.5` | Model family + runtime profile/eval fields | Existing specs unchanged | Template inspection |
| Validation | PowerShell validator/test suite | New required path and semantic negative scenarios | Existing scenarios remain green | Both validation commands |
| Central catalog deployment | Junction/global pointer setup documented in README | No deployment mechanism change | Repository update remains source | Path/hash/junction smoke check if needed |
| Activation transaction | Active root is junction target | Build/validate in isolated worktree, then apply one prepared change set to active root | Stop on dirty/concurrent root; prepared reverse change set for rollback | Pre/post tree hash, status, validators |
| Historical documentation | `specs/**`, earlier changelog entries | No change | Full audit compatibility | `git diff` path review |
| Runtime model selection | Codex/ChatGPT/API configuration outside repository | No mutation | Availability handled as runtime evidence | Confirm no config files changed |

## 7. Бизнес-правила / Алгоритмы (если есть)

### 7.1 Tier selection
1. Если задача complex, ambiguous, high-value или требует polish/judgment -> предпочесть Sol.
2. Иначе если задача everyday, tool-using и не требует Sol depth -> оценить Terra.
3. Иначе если задача clear, repeatable, high-volume с проверяемым output schema -> оценить Luna.
4. Если tier недоступен -> выбрать доступный fallback и зафиксировать effective runtime profile.
5. Не снижать tier только ради latency/cost, если representative eval не проходит required quality bar.

### 7.2 Reasoning selection and migration
1. Для нового workflow начать с `medium`.
2. Для GPT-5.5 migration взять прежний effort как baseline.
3. Сравнить baseline effort и один уровень ниже на одинаковых tasks.
4. Повышать до `high`/`xhigh` только по измеримому quality/risk основанию.
5. Сравнить `max` с `xhigh` только для hardest quality-first tasks.
6. Pro включать отдельно от effort только при reliability benefit.
7. Ultra/multi-agent не считать reasoning increment и не включать без authorization route.

### 7.3 Prompt simplification
1. Определить owner каждого общего правила.
2. Удалять одно семейство повторений за раз.
3. После каждого удаления повторять representative eval/semantic validation.
4. Сохранять examples/style guidance только если они кодируют product requirement или закрывают measured gap.
5. Длинный prompt не считать ошибкой сам по себе, если длина состоит из необходимых workflow invariants.

### 7.4 Programmatic Tool Calling route
1. Проверить, что stage bounded и predictable.
2. Проверить, что intermediate results можно уменьшить/агрегировать кодом.
3. Явно определить tools, schema, evidence, concurrency, retry и stop limits.
4. Approval, adaptive judgment, citations/native artifacts и final validation оставить direct.
5. Проверить program output и final assistant message отдельно.

### 7.5 Multi-agent route
1. Требовать explicit authorization через user/skill/profile/specific instruction.
2. Разделить только independent bounded workstreams.
3. Не параллелить sequential dependency или writes в один mutable resource.
4. Root agent обязан синтезировать final answer и проверить conflicts/gaps.
5. Если task small или deterministic graph важнее wall-clock time -> one agent.

## 8. Точки интеграции и триггеры
- Entry point `AGENTS.md` объявляет GPT-5.6 family target.
- `routing-matrix.md` подключает `openai-responses-api` при упоминании/изменении:
  - OpenAI Responses API;
  - `reasoning.context` / `reasoning.mode`;
  - Programmatic Tool Calling;
  - explicit prompt caching GPT-5.6;
  - Responses API Multi-agent;
  - GPT-5.6 API image detail/safety identifiers.
- Pure model/prompt behavior продолжает идти через mandatory `model-behavior-baseline`; exact API fields и current product UI labels в него не дублируются.
- `collaboration-baseline` применяется ко всем interactive tasks и владеет authorization wording.
- `templates/specs/_template.md` переносит model/runtime assumptions в каждый новый QUEST artifact.
- `README.md` документирует Surface Contract Matrix и указывает refreshable характер current product mapping.
- `review-loops.md` проверяет model migration evidence, surface conflation, mandatory behavioral smoke, activation safety, duplicated prompt rules и output completeness.
- Validator проверяет required path и active semantic markers.

## 9. Изменения модели данных / состояния
- Persisted application data: не изменяется.
- Repository state:
  - добавляется один governance markdown owner;
  - изменяются active instruction/docs/template/validator/changelog files;
  - добавляется текущая working spec.
- Public instruction contract:
  - target model меняется с GPT-5.5 на GPT-5.6 family;
  - Responses API rules становятся on-demand overlay;
  - authorization/preamble ownership становится однозначным.
- External runtime state и configs не меняются.

## 10. Миграция / Rollout / Rollback

### Migration
1. Зафиксировать active junction target, current HEAD, `git status --short` и hashes canonical files; текущая approved spec является ожидаемым изменением, любые другие изменения или параллельный catalog update блокируют продолжение.
2. Создать isolated detached worktree вне `C:\Users\Kibnet\.codex\agents` и active junction target; перенести туда approved spec как implementation input.
3. В isolated worktree обновить `model-behavior-baseline.md` и `collaboration-baseline.md`.
4. Добавить `openai-responses-api.md` и routing trigger.
5. Синхронизировать `AGENTS.md`, `README.md`, spec template и review-loop.
6. Добавить required path/semantic checks, negative validator tests и changelog `3.0.0`.
7. В isolated worktree запустить validators, targeted semantic checks и mandatory behavioral smoke suite; подготовить один final patch/change set и обратный rollback patch.
8. Повторно убедиться, что active root не изменился с шага 1, затем применить подготовленный change set к active checkout одним коротким activation step, а не редактировать canonical files там последовательно.
9. Немедленно повторить validators, target/runtime smoke и historical-path check на active root; при fail применить prepared rollback change set и повторить validators.
10. Выполнить post-EXEC review и удалить temporary worktree только после PASS/rollback evidence.

Activation не считается буквально atomic на уровне файловой системы; требуемый safety contract — не держать active junction target в заведомо неполном authoring state, минимизировать activation window и иметь заранее проверенный reverse change set.

### Representative eval rollout
- Mandatory behavior-regression gate выполняется до activation на одном доступном GPT-5.6 target profile и после activation на том же effective profile:
  - before: текущий central stack из active HEAD;
  - after: candidate stack из isolated worktree, затем active stack после activation;
  - минимум три fixed scenarios: read-only review без мутаций; QUEST SPEC с остановкой до approval; approved scoped change с non-destructive validation;
  - дополнительно проверить один API-routing scenario без фактического API вызова: pure ChatGPT/Codex task не загружает overlay, Responses API task загружает его;
  - для каждого scenario сохранить effective surface/model/profile, prompt-stack revision, outcome, gate compliance, required evidence/output completeness и unexpected approval/mutation behavior;
  - before/after считается PASS только при сохранении существующего quality bar и устранении заявленной проблемы; статические marker checks не заменяют этот gate.
- Comparative cross-model baseline, если доступна: GPT-5.5 / прежний effort.
- Optional candidate comparison configurations:
  - GPT-5.6 Sol / прежний effort;
  - GPT-5.6 Sol / один уровень ниже;
  - GPT-5.6 Terra / medium для everyday workload;
  - GPT-5.6 Luna / medium только для clear repeatable workload.
- Extended representative tasks для optional comparison:
  - read-only repository analysis;
  - QUEST SPEC preparation;
  - approved EXEC с tests/validation;
  - tool-heavy retrieval/audit;
  - UI-facing change с visual evidence;
  - STORM artifact-only workflow.
- Metrics:
  - соблюдение MUST/QUEST gates;
  - task success и acceptance completeness;
  - required evidence и caveats;
  - unnecessary approval pauses;
  - tool calls, turns, retries;
  - output tokens, latency и cost, если surface exposes данные.
- Если GPT-5.5 или несколько GPT-5.6 tiers недоступны, comparative cross-model/tier eval не блокирует migration и фиксируется как follow-up без performance claim.
- Если недоступен ни один GPT-5.6 target runtime для mandatory before/after smoke, EXEC не может получить `PASS`: нужен `ASK-HUMAN` либо scope должен быть сокращён до изменений, не меняющих prompt/behavior contract.

### Compatibility
- Existing consumer pointers продолжают работать: пути central stack не меняются.
- Consumer repos, pinned to GPT-5.5 runtime, сохраняют доступ к syntactically compatible instructions, но перестают соответствовать declared target contract `3.0.0`; это должно быть отражено в changelog.
- Historical docs сохраняют прежние model markers.

### Rollback
- До activation подготовить и проверить reverse change set, который удаляет новый governance overlay, возвращает routing/required path/markers и восстанавливает target GPT-5.5 wording.
- При post-activation fail немедленно применить prepared reverse change set к active root; не собирать rollback вручную в частично активированном состоянии.
- После rollback повторно запустить обе validator команды, behavioral smoke на восстановленном effective profile и junction/path check.
- Для опубликованного change set использовать отдельный revert/versioned delivery; не переписывать историю destructive Git operations.
- Historical specs/changelog history не восстанавливать через destructive Git operations; rollback выполняется новым revert/change set.

## 11. Тестирование и критерии приёмки

### Acceptance Criteria
- AC1: Active owner-документы объявляют GPT-5.6 family optimization target, но не утверждают universal GPT-5.6 runtime для standard ChatGPT; GPT-5.5 не остаётся declared catalog target вне surface snapshot/compatibility/historical artifacts.
- AC2: `model-behavior-baseline.md` содержит проверяемый routing Sol/Terra/Luna и availability fallback rule.
- AC3: Lean prompt contract требует single-owner instructions, outcome/evidence/output/stop rules и не навязывает лишний process scaffolding.
- AC4: Surface Contract Matrix разделяет Standard ChatGPT, Work/Codex и OpenAI API; API contract содержит `none/low/medium/high/xhigh/max` и `reasoning.mode=pro`, product surfaces используют собственные labels/options, а Ultra отделён от single-agent effort.
- AC5: Новый `openai-responses-api.md` соответствует document contract, распределяет правила по `MUST/SHOULD/MAY` и покрывает model-dependent/effective reasoning context, lossless replay/conditional `phase`, encrypted replay, caching, PTC `allowed_callers`/`call_id`/`caller`/final message, API multi-agent, image detail и conditional safety identifier.
- AC6: Routing подключает Responses API owner только по явному trigger; pure ChatGPT/Codex tasks не получают его как mandatory core.
- AC7: Canonical spec template фиксирует model family/runtime profile и требует representative eval evidence для model/prompt migrations.
- AC8: Review-loop проверяет duplicated instructions, broad brevity risk, необоснованный `max/pro/ultra`, availability assumptions и final output completeness.
- AC9: До activation и после неё выполнен mandatory before/after behavioral smoke на одном effective GPT-5.6 profile минимум для трёх fixed behavior scenarios и API-routing scenario; static validation не заменяет этот gate, а comparative GPT-5.5/tier eval может быть follow-up без performance claim.
- AC10: Historical specs и прежние changelog entries с GPT-5.5 не изменены.
- AC11: Validator считает новый owner обязательным; test suite отдельно доказывает fail при удалении owner и при замене обязательного GPT-5.6 target marker в `model-behavior-baseline.md` на GPT-5.5.
- AC12: `pwsh -File scripts/validate-instructions.ps1` проходит.
- AC13: `pwsh -File scripts/test-validate-instructions.ps1` проходит.
- AC14: `git diff --check` проходит, broken links отсутствуют, unrelated changes отсутствуют.
- AC15: `CHANGELOG.md` содержит `3.0.0` с impact/compatibility/rollback notes.
- AC16: QUEST approval phrase и SPEC/EXEC mutation boundaries не изменены.
- AC17: Canonical implementation выполняется в isolated worktree; active junction target получает один prepared change set только после pre-activation validation, а dirty/concurrent root или post-activation failure приводит к stop/ prepared rollback.

### Test plan
- Structural validation: existing validator.
- Validator regression tests: existing test suite + два независимых negative scenario из AC11; после каждого scenario seed восстанавливается перед следующей проверкой.
- Semantic scans: active GPT-5.5/GPT-5.6 markers, tier/effort/API feature markers.
- Surface contract review: Standard ChatGPT / Work-Codex / API mappings сверены с official sources в EXEC и exact API parameters не попали в surface-neutral core.
- Diff review: historical specs, old changelog sections, QUEST contracts и unrelated files.
- Link validation: included in catalog validator.
- Mandatory behavioral smoke: одинаковые fixed prompts запускаются before/after на одном effective GPT-5.6 profile; mutation scenarios используют disposable isolated worktree, чтобы не менять active catalog.
- Comparative model/tier eval: выполнить при доступной multi-model runtime; иначе зафиксировать scoped follow-up без ложного performance claim.
- Activation safety: зафиксировать pre-activation HEAD/status/hashes, isolated validation, prepared forward/reverse change sets и post-activation checks.
- Visual acceptance: Не применимо — изменения не затрагивают UI layout, navigation, visual state или generated visual artifact.
- UI test video evidence: Не применимо — UI automation не изменяется.
- Performance baseline: только model eval metrics при доступности; repository script performance не изменяется.

### Команды для проверки

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1

# Active target markers; historical specs/changelog намеренно исключены.
rg -n "GPT-5\.5|gpt-5\.5|GPT-5\.6|gpt-5\.6|Sol|Terra|Luna" `
  AGENTS.md README.md instructions templates/specs/_template.md

# GPT-5.6 behavior/runtime contract.
rg -n "Standard ChatGPT|Work|Codex|OpenAI API|same.*one.*lower|one.*level.*lower|none|low|medium|high|xhigh|max|reasoning\.mode|reasoning\.context|allowed_callers|call_id|caller|programmatic|Multi-agent|phase|encrypted_content|safety_identifier" `
  instructions/core/model-behavior-baseline.md `
  instructions/governance/openai-responses-api.md `
  instructions/governance/review-loops.md `
  templates/specs/_template.md

# Mandatory read-only behavioral smoke example; repeat the same prompt for before/after roots.
$smokePrompt = @'
Проведи read-only review применимых центральных инструкций для задачи изменения API.
Не меняй файлы. Верни выбранный stack, authorization boundary, required evidence и stop condition.
'@
$beforeEvents = codex exec --ephemeral --json -m gpt-5.6 -s read-only -C $beforeRoot $smokePrompt
$afterEvents = codex exec --ephemeral --json -m gpt-5.6 -s read-only -C $afterRoot $smokePrompt
# Сохранить/сопоставить event evidence в post-EXEC review; для mutation scenarios
# использовать отдельный disposable worktree и тот же effective model/profile.

# Historical specs кроме текущей migration spec не должны изменяться.
$changedHistoricalSpecs = git diff --name-only -- specs | Where-Object {
  $_ -ne 'specs/2026-07-14-gpt56-catalog-migration.md'
}
if ($changedHistoricalSpecs) { throw "Historical specs changed: $changedHistoricalSpecs" }

git status --short
git diff --stat
git diff --check
```

### Stop rules для test/retrieval/tool/validation loops
- Не расширять web/docs retrieval, если official model guidance, Codex models, reasoning, PTC и multi-agent pages уже подтверждают требуемые claims.
- Исправлять validator/test failures только в approved scope; unexpected unrelated failure классифицировать отдельно.
- После изменения validator обязательно запускать test-validator suite.
- Не завершать EXEC при active stale target declaration, broken links, historical spec mutation или незакрытом BLOCKER/HIGH review finding.
- Не завершать EXEC без mandatory target-runtime behavioral smoke; отсутствие GPT-5.5 или нескольких GPT-5.6 tiers блокирует только comparative claim, а не migration.
- Не активировать prepared change set, если active HEAD/status/hashes drifted после начала isolated implementation; не пытаться автоматически объединить concurrent catalog changes.

### Acceptance-to-Test Matrix

| Acceptance criterion | Automated test | Manual / visual / log check | Evidence artifact | If not tested, why |
| --- | --- | --- | --- | --- |
| AC1 | Semantic marker scan | Review target wording и standard ChatGPT exception | Command output + surface matrix diff | — |
| AC2 | Semantic marker scan | Contract review | Baseline diff | — |
| AC3 | Partial semantic scan | Prompt-quality review | Post-EXEC review | Semantic duplication требует manual review |
| AC4 | Semantic marker scan | Surface/product/API reasoning mapping review | Command output + diff | — |
| AC5 | Validator required sections/links + protocol marker scan | API owner normative/wire contract review | Validator output + file diff | — |
| AC6 | Semantic marker scan | Routing/stack review | Routing diff | — |
| AC7 | Validator links + marker scan | Template review | Template diff | — |
| AC8 | Marker scan | Review-loop contract review | Review-loop diff | — |
| AC9 | Required reproducible `codex exec --ephemeral --json` before/after smoke; unavailable target runtime -> `ASK-HUMAN` before activation | Compare fixed scenarios, effective profile, gates, output/evidence and mutation behavior | Event logs/task IDs + post-EXEC comparison table | Cross-model performance metrics могут быть недоступны, но target-runtime smoke обязателен |
| AC10 | Git changed-path script | Historical section diff review | `git diff --name-only` | — |
| AC11 | `test-validate-instructions.ps1`: missing owner + stale target marker | Проверить независимость и восстановление seed между сценариями | Два `PASS` scenario в test log | — |
| AC12 | `validate-instructions.ps1` | Не применимо | Command output | — |
| AC13 | `test-validate-instructions.ps1` | Не применимо | Command output | — |
| AC14 | `git diff --check` + validator links | `git status/diff` review | Command output | — |
| AC15 | Semantic/version scan | Changelog review | Changelog diff | — |
| AC16 | Semantic diff/scan | QUEST owner review | Diff of QUEST files or proof unchanged | — |
| AC17 | Pre/post HEAD/status/hash script + both validators | Review isolated worktree, prepared forward/reverse change sets and activation log | Activation evidence in post-EXEC review | — |

## 12. Риски и edge cases
- GPT-5.6 availability может зависеть от surface/plan/workspace policy; mitigation — runtime evidence и fallback wording без hardcoded entitlement.
- Standard ChatGPT, Work, Codex и API используют разные selectors/defaults; mitigation — Surface Contract Matrix, source refresh и запрет переносить API parameters в product UI contract.
- OpenAI docs могут изменить beta API details; mitigation — API-specific on-demand owner и official-doc refresh перед будущими API implementation changes.
- Новый governance overlay может быть ошибочно подключён ко всем задачам; mitigation — явный routing trigger и negative/manual review pure-task scenario.
- Major release может неожиданно затронуть GPT-5.5-pinned consumers; mitigation — changelog impact и явный target compatibility statement.
- Prompt simplification может удалить нужный QUEST invariant; mitigation — не менять QUEST semantics и удалять повторения по одному с validation/review.
- Broad concision может скрыть evidence/caveats; mitigation — content-priority contract и review check.
- Global multi-agent wording может неявно разрешить delegation; mitigation — explicit opt-in only и отсутствие blanket MUST.
- PTC может потерять citations/final fields; mitigation — direct final validation и отдельная проверка program/final outputs.
- Multi-agent может создать concurrent writes; mitigation — запрет на contended mutable resources и root synthesis.
- Validator semantic check может ловить допустимые historical GPT-5.5 mentions; mitigation — ограничить scan active files и различать target declaration от compatibility wording.
- `3.0.0` может показаться слишком крупным для markdown-only diff; mitigation — version определяется изменением mandatory contract, а не числом файлов.
- Central catalog junction может скрыть отличие working repo и active path; mitigation — documented junction/path smoke check без копирования файлов.
- Последовательные canonical edits в junction target могут временно опубликовать неполный stack; mitigation — isolated worktree, prepared forward/reverse change sets, drift check и короткий activation step.
- Target-runtime behavioral smoke может быть недоступен из-за entitlement/client/auth; mitigation — `ASK-HUMAN` до activation либо сокращение scope, но не подмена behavioral evidence статическим validator PASS.

### Expected User Review Objections

| Likely objection | Why likely | Mitigation in spec/code plan | Status |
| --- | --- | --- | --- |
| Почему не ограничиться заменой `5.5` на `5.6`? | Визуально это самый маленький diff | Spec фиксирует tier, effort/mode, lean prompt, autonomy и API surface split как необходимые behavioral differences | mitigated |
| Почему release `3.0.0`, если формат документов не меняется радикально? | Изменение markdown выглядит additive | Mandatory target contract меняется; local versioning policy относит contract break к MAJOR | mitigated |
| Почему Responses API guidance вынесена в governance overlay? | Дополнительный файл усложняет каталог | Overlay не расходует stack profile slot и не загружает API-only детали в каждую задачу | mitigated |
| Почему API reasoning levels нельзя просто записать в общий baseline? | Один список выглядит проще | Standard ChatGPT, Work/Codex и API имеют разные selectors/defaults; общий core хранит semantics, exact fields остаются surface owner | mitigated |
| Почему не включить multi-agent/Ultra по умолчанию? | GPT-5.6 рекламирует orchestration как новую возможность | Default delegation меняет authorization и небезопасна для shared writes; оставлен explicit opt-in | mitigated |
| Почему исторические GPT-5.5 specs остаются? | Поиск продолжит показывать старые markers | Они являются audit record; validator сканирует active docs отдельно | mitigated |
| Почему не добавить цены, limits и минимальные версии клиентов? | Это полезно для выбора tier | Эти данные drift-prone; catalog фиксирует durable decision rules, а live facts проверяются по official docs | mitigated |
| Не станет ли новый API owner слишком большим? | GPT-5.6 добавляет много возможностей | Owner содержит только invariants/routing/eval rules; implementation examples и SDK code остаются вне scope | mitigated |
| Почему visual planning policy остаётся в model baseline? | Lean prompt guidance подсказывает cleanup core | Перенос не нужен для GPT-5.6 correctness и расширил бы scope; выделен отдельным возможным follow-up | accepted-risk |
| Зачем behavioral smoke, если markdown validators проходят? | Изменения выглядят документационными | Central instructions меняют реальное поведение агента; static markers не доказывают authorization, stop и output behavior | mitigated |
| Зачем isolated worktree для локального каталога? | Дополнительный operational step | Junction делает checkout active source; isolated authoring исключает длительное частично обновлённое состояние | mitigated |

### Rework Prevention Checklist
- Does the spec name what the user will see or operate? Да: central target/routing/template/review scenarios описаны.
- Does every user-visible scenario have evidence? Да: каждый scenario привязан к AC и evidence.
- Did the agent list decisions it assumed? Да: Decision Ledger заполнен.
- Did the agent predict likely objections and mitigate them? Да: восемь objections рассмотрены.
- Did role-based review run for the relevant task type? Да: business workflow, tester, developer/architect и delivery/operations/security проверены; UX обоснованно не применим.
- Are acceptance criteria verifiers, not preparation steps? Да.
- Does EXEC have a path to prove the scenarios before final? Да: Acceptance-to-Test Matrix и commands заданы.
- Does the spec distinguish surface semantics and deployment state? Да: Surface Contract Matrix и isolated activation contract заданы.

## 13. План выполнения
1. Зафиксировать active state и создать isolated detached worktree, не являющийся junction target.
2. Обновить model/collaboration core contracts и Surface Contract Matrix без изменения QUEST semantics.
3. Создать Responses API governance owner по document contract и normative/wire requirements.
4. Подключить owner и GPT-5.6 family markers в routing/entry/README.
5. Обновить spec template и review-loop model/prompt checks.
6. Расширить validator required paths/semantic checks и negative test coverage.
7. Добавить changelog `3.0.0` и compatibility notes.
8. Запустить structural/semantic/history/diff validation и mandatory before/after behavioral smoke в isolated environment.
9. Подготовить forward/reverse change sets, выполнить drift check и короткую activation в junction target.
10. Повторить validators/behavioral smoke на active root, исправить findings или rollback, затем выполнить full post-EXEC review.

Точный порядок сохраняется, потому что validator tests зависят от появления нового owner/markers, changelog должен описывать уже зафиксированный final contract, а active junction нельзя использовать как длительную authoring surface.

## 14. Открытые вопросы
- Блокирующих вопросов нет.
- Comparative GPT-5.5/GPT-5.6 или cross-tier eval выполняется только при доступной поверхности; отсутствие comparative surface не блокирует migration, но запрещает claims о фактическом выигрыше.
- Наличие хотя бы одного GPT-5.6 target runtime для mandatory behavioral smoke является EXEC precondition; если его нет, это runtime blocker с `ASK-HUMAN`, а не design question для approval текущей spec.

## 15. Соответствие профилю
- Профиль: `instructions/profiles/product-system-design.md`.
- Выполненные требования профиля:
  - цели и non-goals разделены;
  - target architecture и owner boundaries заданы;
  - public instruction contract и compatibility описаны;
  - Standard ChatGPT, Work/Codex и API semantics разделены Surface Contract Matrix;
  - configuration/API/security aspects разделены по surface и нормативной силе;
  - альтернативы и мотив выбора зафиксированы;
  - migration/rollback и verification определены.

## 16. Таблица изменений файлов

| Файл | Изменения | Причина |
| --- | --- | --- |
| `specs/2026-07-14-gpt56-catalog-migration.md` | Новая working spec и audit journal | QUEST gate |
| `instructions/core/model-behavior-baseline.md` | GPT-5.6 optimization target, surface-neutral tier/effort semantics, lean prompt, API overlay reference | Новый model behavior owner contract без API/UI conflation |
| `instructions/core/collaboration-baseline.md` | Single preamble owner и autonomy boundaries | Убрать дублирование и лишние approvals |
| `instructions/governance/openai-responses-api.md` | Новый on-demand Responses API owner с normative/wire contract | Изолировать API-only capabilities и protocol invariants |
| `instructions/governance/routing-matrix.md` | GPT-5.6 target и API overlay trigger/owner | Корректная stack assembly |
| `instructions/governance/review-loops.md` | Model/prompt migration review checks | Ловить GPT-5.6-specific риски |
| `AGENTS.md` | GPT-5.6 family entry marker и API owner pointer | Центральный entry point |
| `README.md` | Architecture, Surface Contract Matrix, tier и rollout explanation | Consumer documentation |
| `templates/specs/_template.md` | Model family/runtime/eval metadata | Future specs фиксируют assumptions |
| `scripts/validate-instructions.ps1` | Required API owner и active model semantic checks | Structural/semantic gate |
| `scripts/test-validate-instructions.ps1` | Negative regression scenario | Validator contract coverage |
| `CHANGELOG.md` | Release `3.0.0` | SemVer и consumer impact |

## 17. Таблица соответствий (было -> стало)

| Область | Было | Стало |
| --- | --- | --- |
| Target | Один `gpt-5.5` target | GPT-5.6 family с Sol default для complex work |
| Model sizing | Не применимо | Sol/Terra/Luna task-shape routing |
| Reasoning | medium/low/high/xhigh без surface mapping | Surface-neutral selection + API `none..max` + product-specific selector mapping |
| Pro/Ultra | Не описаны | API Pro как `reasoning.mode`; ChatGPT Sol Pro как product option; Ultra как opt-in multi-agent orchestration |
| Prompt style | Outcome-first, но есть дублирование | Lean single-owner contract + specific deltas |
| Preamble | Дублируется в двух core docs | Единственный owner в collaboration baseline |
| Autonomy | Распределена неявно | Compact request-type authorization contract |
| Responses API | Отдельные bullets в mandatory core | On-demand governance owner |
| PTC/multi-agent | Не описаны | Bounded opt-in route с authorization/evidence limits |
| Spec metadata | `Целевая модель: gpt-5.5` | Model family + effective runtime profile/eval |
| Validation | Structural paths/sections/links | Structural + active model semantics + negative regression |
| Activation | Последовательные edits в active junction checkout | Isolated authoring/validation + prepared activation/rollback |
| Version | `2.11.0` | `3.0.0` breaking model-target migration |

## 18. Альтернативы и компромиссы

### Вариант A: механический rename GPT-5.5 -> GPT-5.6
- Плюсы: минимальный diff.
- Минусы: не учитывает tiers, reasoning modes, concise-default behavior, autonomy и API capabilities.
- Почему не выбран: создаёт ложную полноту migration.

### Вариант B: поместить все GPT-5.6 API возможности в mandatory model baseline
- Плюсы: один файл, простой поиск.
- Минусы: раздувает prompt для pure ChatGPT/Codex tasks и смешивает surface-neutral behavior с API implementation contract.
- Почему не выбран: противоречит lean prompt guidance и routing architecture.

### Вариант C: создать `openai-responses-api` как stack/overlay profile
- Плюсы: естественное тематическое имя.
- Минусы: расходует ограниченный profile slot и конфликтует с существующей схемой `stack profile + change overlay` для .NET/frontend consumers.
- Почему не выбран: governance trigger лучше интегрируется без изменения profile cardinality.

### Вариант D: compatibility release `2.12.0`
- Плюсы: мягче для GPT-5.5 consumers.
- Минусы: mandatory target всё равно меняется, а значит contract break маскируется как minor.
- Почему не выбран: противоречит current versioning policy; допустим только после отдельного user-owned решения сохранить dual-target contract.

### Вариант E: глобально рекомендовать multi-agent для всех сложных задач
- Плюсы: потенциальное снижение wall-clock time.
- Минусы: меняет authorization, повышает coordination cost и риск concurrent writes.
- Почему не выбран: official guidance рекомендует только independent bounded workstreams; central default остаётся single-agent.

### Вариант F: завершать migration только по static validators
- Плюсы: быстро, полностью воспроизводимо без model entitlement.
- Минусы: не проверяет фактические authorization, stop, routing и output behaviors после prompt changes.
- Почему не выбран: official lean-prompt guidance требует representative eval; mandatory target-runtime smoke отделён от optional cross-model performance comparison.

### Вариант G: редактировать canonical files прямо в active junction checkout
- Плюсы: минимальный operational overhead.
- Минусы: central consumers могут загрузить частично обновлённый stack между последовательными edits.
- Почему не выбран: isolated worktree и prepared activation существенно уменьшают exposure window и дают проверенный rollback.

## 19. Результат quality gate и review

### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, цели дизайна и Non-Goals заданы и отделяют active migration от истории/runtime config. |
| B. Качество дизайна | 6-10 | PASS | Owner boundaries, Surface Contract Matrix, normative API/wire rules, routing, algorithms и failure/fallback cases определены. |
| C. Безопасность изменений | 11-13 | PASS | Repository/runtime state, breaking compatibility, isolated activation, prepared rollback и historical preservation описаны. |
| D. Проверяемость | 14-16 | PASS | 17 AC связаны с static checks, mandatory behavioral smoke, activation evidence, командами и stop rules. |
| E. Готовность к автономной реализации | 17-19 | PASS | Этапы, isolated worktree/activation order и planned files заданы; блокирующих design questions нет; runtime precondition имеет `ASK-HUMAN` path. |
| F. Соответствие профилю | 20 | PASS | Цели/non-goals, architecture, public contract, config/security, alternatives и rollback соответствуют `product-system-design`. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Outcome/output/stop contract и Non-Goals исключают runtime, account, SDK и historical rewrites. |
| 2. Понимание текущего состояния | 5 | Active references посчитаны, existing strengths/gaps и central junction подтверждены. |
| 3. Конкретность целевого дизайна | 5 | Для каждого owner-файла заданы responsibilities; product/API surfaces разделены; normative и wire-level API contracts проверяемы. |
| 4. Безопасность (миграция, откат) | 5 | Breaking version, pinned-consumer impact, isolated authoring, activation drift gate, prepared rollback и history preservation зафиксированы. |
| 5. Тестируемость | 5 | 17 AC покрыты static validation, two negative validator scenarios, target-runtime behavioral smoke и activation evidence. |
| 6. Готовность к автономной реализации | 5 | Planned files/order, exact CLI smoke path, activation transaction и uniquely chosen decisions достаточны для EXEC после QUEST approval. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Role-Based Review Result

| Role | Applicability | Review question | Verdict | Required spec changes |
| --- | --- | --- | --- | --- |
| Business analyst / domain workflow | applicable | Does the workflow and consumer behavior match the user's goal? | PASS after fix | Standard ChatGPT, Work/Codex и API scenarios разделены Surface Contract Matrix. |
| UX / designer | not applicable | Would the visible UI/layout pass review? | Не применимо | Нет UI-facing change |
| Tester / validation | applicable | Does every AC map to test/check/evidence and are edge cases covered? | PASS after fix | AC9 требует target-runtime before/after smoke; AC11 имеет два negative scenario; AC17 покрывает activation. |
| Developer / architect | applicable | Are contracts, boundaries, migration and maintainability coherent? | PASS after fix | API-only rules изолированы, normative/wire invariants заданы, surface-neutral core не содержит product/API conflation. |
| Delivery / operations / security | applicable | Are versioning, config/runtime, rollout and rollback risks handled? | PASS after fix | Isolated worktree, drift gate, prepared forward/reverse change sets и runtime blocker path добавлены. |

### Post-SPEC Review
- Статус: PASS
- Scope reviewed: `specs/2026-07-14-gpt56-catalog-migration.md`; central stack `model-behavior-baseline + quest-governance + collaboration-baseline`; SPEC overlays `quest-mode`, `document-contract`, `versioning-policy`, `spec-linter`, `spec-rubric`, `review-loops`; profile `product-system-design`; секция открытых вопросов; 11 planned canonical files и одна working spec из секции 16.
- Decision: можно запрашивать обязательное QUEST-подтверждение; canonical-файлы до него не менять.
- Review passes:
  - Scope/Evidence pass: просмотрены working spec, status/diff, active GPT-5.5 markers, current baseline/collaboration/routing/template, validator scripts, version/document contracts, changelog head и central junction target.
  - Contract pass: сверены outcome, Non-Goals, 17 AC, Surface Contract Matrix, scenarios, decision ledger, acceptance mapping, profile requirements, SPEC mutation boundary и validation requirements.
  - Adversarial risk pass: проверены API/product semantic conflation, отсутствие target-runtime evidence, partial activation через junction, underdefined API wire contract, unavailable tier, pinned consumer, historical false positive, PTC final-output loss и concurrent writes.
  - Role-Based pass: business workflow, tester, developer/architect и delivery/operations/security получили прикладной verdict; UX отмечен `Не применимо` из-за отсутствия visible UI/layout change.
  - Re-review after fixes / Fix and re-review: после user-requested review исправлены 2 HIGH, 2 MEDIUM и 1 LOW finding; повторно сверены sections 0, 1, 6-18, AC/matrix, role review и activation/runtime contracts; повторно запущены validators, `git diff --check`, scope/marker scans и CLI capability check.
  - Stop decision: PASS — все HIGH/MEDIUM findings исправлены в spec; remaining risks имеют explicit EXEC gate/fallback и не требуют design choice пользователя.
- Evidence inspected:
  - official GPT-5.6 model, migration, prompting, reasoning, PTC и multi-agent sources из секции 0;
  - `instructions/core/model-behavior-baseline.md`, `instructions/core/collaboration-baseline.md`, `instructions/core/quest-mode.md` и `instructions/core/quest-governance.md`;
  - `instructions/governance/routing-matrix.md`, `document-contract.md`, `versioning-policy.md`, `spec-linter.md`, `spec-rubric.md`, `review-loops.md`;
  - `instructions/profiles/product-system-design.md`, `templates/specs/_template.md`, `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `CHANGELOG.md`;
  - official Standard ChatGPT, ChatGPT Work/Codex, GPT-5.6 model guidance, reasoning, PTC и Multi-agent docs;
  - `codex exec --help`, `rg` semantic scans, `git status --short`, `git diff --check`, оба validation scripts и junction smoke check.
- Depth checklist:
  - Scope drift / unrelated changes: PASS — `git status --short` содержит только новый working spec; canonical/runtime files не менялись.
  - Acceptance criteria: PASS — AC1-AC17 имеют verifier/evidence; behavioral и activation gates больше не подменяются static checks.
  - User-observable scenarios / Decision ledger / Expected objections: PASS — surface, runtime, activation и API protocol cases заполнены и связаны с evidence/mitigation.
  - Validation evidence: PASS — catalog validator, validator regression suite и `git diff --check` завершились с exit code 0; spec-only scope и junction target подтверждены.
  - Unsupported claims: PASS — current product mapping отделён как refreshable snapshot; availability/pricing/version limits не превращены в invariants; performance claim запрещён без data.
  - Regression / edge case: PASS — учтены surface conflation, missing behavioral evidence, partial live activation, missing owner/stale target, historical markers, unavailable runtime, PTC linkage/output loss и shared-write contention.
  - Comments/docs/changelog: PASS — owner/docs/template/changelog impact перечислен; published history не переписывается.
  - Hidden contract change: PASS — breaking target shift и consumer impact объявлены как `3.0.0`; QUEST approval и profile cardinality сохраняются.
  - Manual-review challenge: отдельный reviewer мог бы проверить, не остались ли API-only fields в mandatory core, не объявлен ли static PASS заменой runtime behavior, и возможна ли activation при drifted active root; теперь все три проверки явны.
- No-findings justification: Не применимо — два review passes выявили actionable findings, все исправлены и повторно проверены.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | validation | AC11 допускал альтернативное прочтение `missing owner path или stale marker`, поэтому implementation могла покрыть только один regression case. | Зафиксировать два независимых negative scenario, восстановление seed и отдельное evidence в acceptance matrix. | fixed |
| HIGH | surface contract | API `reasoning.effort`/Pro semantics были перенесены в общий ChatGPT/Codex contract. | Добавить Surface Contract Matrix; оставить exact API fields в API owner; отразить Standard ChatGPT и Work/Codex product options отдельно. | fixed |
| HIGH | validation | Migration могла завершиться только по static validators без проверки изменённого prompt/autonomy behavior. | Сделать target-runtime before/after behavioral smoke обязательным, а cross-model comparison — optional follow-up. | fixed |
| MEDIUM | delivery safety | Sequential edits в active junction target создавали partial activation window. | Выполнять authoring/validation в isolated worktree, подготовить forward/reverse change sets и проверять active drift до activation. | fixed |
| MEDIUM | API contract | Responses API owner не задавал normative levels и обязательные reasoning/PTC wire invariants. | Зафиксировать MUST/SHOULD/MAY, effective context, lossless replay, `allowed_callers`, linkage и final message handling. | fixed |
| LOW | evidence accuracy | Review называл все 12 planned rows canonical files, хотя одна row — working spec. | Указать 11 canonical files + one working spec. | fixed |

- Fixed before continuing: уточнены AC11; добавлены Surface Contract Matrix, normative API/wire contract, mandatory behavioral gate, isolated activation/rollback contract, AC17 и обновлённые scenarios/risks/alternatives/evidence mappings.
- Checks rerun: `pwsh -File scripts/validate-instructions.ps1`; `pwsh -File scripts/test-validate-instructions.ps1`; `git diff --check`; semantic/no-placeholder scans; spec-only `git status`; central junction smoke; `codex exec --help` — все PASS.
- Needs human: только обязательная фраза QUEST `Спеку подтверждаю`; дополнительных design/product/API решений нет.
- Residual risks / follow-ups: comparative GPT-5.5/cross-tier eval может быть недоступен, а product/beta/API details могут drift; mandatory target-runtime smoke и source refresh остаются EXEC gates, неподтверждённые performance/availability claims запрещены.

### Post-EXEC Review
- Статус: PASS after fixes
- Scope reviewed: утверждённая spec; active `git status --short`; `git diff --stat`; relevant diff 10 tracked canonical files + новый `instructions/governance/openai-responses-api.md`; isolated candidate; оба validator scripts; semantic scans; `git diff --check`; normalized candidate/active comparison; before/candidate/active behavioral smoke evidence.
- Decision: реализация соответствует AC1-AC17 и может завершаться без commit/push, которые не запрашивались.
- Review passes:
  - Scope/Evidence pass: проверены все 11 planned canonical paths, рабочая spec, отсутствие runtime/config mutations, status/diff, junction target, isolated worktree base и active/candidate content equality с нормализацией EOL.
  - Contract pass: AC1-AC17, Non-Goals, Surface Contract Matrix, Responses API wire invariants, single-owner preamble, QUEST approval boundary, SemVer `3.0.0`, history preservation и activation/rollback contract выполнены.
  - Adversarial risk pass: проверены stale target, API-owner leakage в ordinary review, missing owner, missing effort levels, surface conflation, lossless reasoning replay, PTC linkage/final message, unavailable alias, partial activation, EOL drift, temporary smoke artifacts и unrelated changes.
  - Role-Based pass: Tester / validation — PASS; Developer / architect — PASS; Delivery / operations / security — PASS after activation fix; UX / designer и Business analyst — `Не применимо`, так как UI и business workflow не менялись.
  - Re-review after fixes / Fix and re-review: API owner дополнен явным `none..max`; validator получил соответствующий semantic marker. После первого transfer hash mismatch удалена лишняя финальная пустая строка во всех 11 activated files, active content повторно сравнён с candidate с нормализацией EOL, validators и behavioral smoke повторены на active junction.
  - Stop decision: PASS — BLOCKER/HIGH отсутствуют, исправления повторно проверены, остаточные ограничения не требуют изменения scope.
- Evidence inspected:
  - official GPT-5.6 ChatGPT/Work/Codex/API, reasoning, PTC и multi-agent sources из секции 0;
  - baseline smoke на explicit `gpt-5.6-sol`, `medium`: ordinary/API routing, QUEST SPEC stop и approved EXEC; короткий alias `gpt-5.6` в текущем CLI/account вернул unsupported-model, explicit Sol был принят;
  - isolated candidate smoke threads: routing `019f60e0-7b92-79f1-ae8e-63de3e249004`, SPEC `019f60e6-fae6-7ad0-b5ff-31fb20a5465c`, EXEC `019f60eb-74b0-79b0-b307-3207965ba942`;
  - active junction smoke threads: routing `019f60f3-b815-7b32-81f2-11eccddbebee`, SPEC `019f60f4-dd06-7cd3-b48c-cf105a7e629f`, EXEC `019f60f9-d3b2-7e93-8787-9beb4bce4c90`;
  - `pwsh -File scripts/validate-instructions.ps1`, `pwsh -File scripts/test-validate-instructions.ps1`, semantic `rg`, `git diff --check`, path/status/hash checks.
- Depth checklist:
  - Scope drift / unrelated changes: PASS — кроме 11 canonical paths и этой working spec изменений нет; temporary smoke specs/output удалены.
  - Acceptance criteria: PASS — AC1-AC17 сопоставлены с owner content, validators, behavioral evidence, history/diff и activation evidence.
  - User-observable scenarios / Acceptance-to-test matrix / Expected objections: PASS — ordinary review не получил API owner; API design получил; QUEST остановился на SPEC; approved EXEC выполнил только заданную мутацию; новый template устранил stale target.
  - Validation evidence: PASS — оба mandatory scripts и 10 regression scenarios зелёные в isolated и active checkouts; static checks не использовались как замена smoke.
  - Unsupported claims: PASS — product availability датирована и отделена от invariants; performance improvement не заявляется; runtime self-report limitation отмечен.
  - Regression / edge case: PASS — alias fallback, dirty worktree, partial activation, EOL normalization, missing owner/marker и API protocol cases проверены.
  - Comments/docs/changelog: PASS — новый owner связан routing/README/baseline/review; changelog `3.0.0` содержит impact/compatibility/rollback; старые entries не менялись.
  - Hidden contract change: PASS — target shift явно breaking; QUEST gate, profile cardinality и runtime configs сохранены.
  - Manual-review challenge: наиболее вероятные находки — неполный effort enum, API leakage и partial activation; первая и activation formatting mismatch были найдены/исправлены, leakage опровергнута behavioral routing smoke.
- No-findings justification: Не применимо — review выявил и исправил два actionable MEDIUM finding; одно LOW ограничение evidence принято как residual risk.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | API contract / validation | Responses API owner первоначально не перечислял полный `reasoning.effort` enum `none..max`. | Добавить enum в owner и обязательный semantic marker; повторить validators и scans. | fixed |
| MEDIUM | activation safety | Первый prepared transfer добавил лишнюю финальную пустую строку и дал byte-hash mismatch из-за EOL representation. | Остановить gate, локализовать diff, удалить лишние строки, сравнить normalized content всех 11 files и повторить active checks. | fixed |
| LOW | runtime evidence | Внутренний agent response не раскрывает exact tier/effort, хотя CLI invocation явно задаёт `gpt-5.6-sol` / `medium`; короткий alias в этой account surface недоступен. | Использовать explicit tier в smoke, хранить command/thread evidence и не заявлять универсальную alias availability. | accepted-risk |

- Fixed before final report: полный effort enum/semantic contract; activation trailing-line mismatch; temporary smoke artifacts.
- Checks rerun: isolated и active validators; 10 validator regression scenarios; semantic scans; `git diff --check`; normalized active/candidate comparison; active routing/SPEC/EXEC smoke.
- Validation evidence: все mandatory checks PASS; behavioral smoke выполнялся на explicit `gpt-5.6-sol`, `medium` до и после activation.
- Unrelated changes: не обнаружены; working spec является обязательным QUEST audit artifact.
- Needs human: нет; commit/push/PR не входят в подтверждённый scope.
- Residual risks / follow-ups: product/API availability может drift; current CLI/account не принимает короткий alias `gpt-5.6`; comparative GPT-5.5/cross-tier performance eval не выполнялся и performance claims не делаются.

## Approval
Подтверждено пользователем фразой: "Спеку подтверждаю"

## 20. Журнал действий агента

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Official guidance и AS-IS анализ | 0.97 | Существенных данных не требуется | Собрать QUEST stack и написать spec | Нет | Нет | Official GPT-5.6/Codex/API docs и live catalog scan дают достаточный design input | `AGENTS.md`, `README.md`, `instructions/*`, `templates/specs/_template.md`, `scripts/*`, `CHANGELOG.md` |
| SPEC | Instruction stack и архитектурные решения | 0.94 | Не хватает только formal post-SPEC review | Создать draft spec и выполнить quality gates | Нет | Нет | Выбран `product-system-design`; API rules вынесены в governance overlay, чтобы не менять profile cardinality | `specs/2026-07-14-gpt56-catalog-migration.md`, central QUEST owner docs |
| SPEC | Draft working specification | 0.93 | Требуется self-review evidence | Выполнить linter, rubric и full post-SPEC review | Нет | Нет | Spec фиксирует target, boundaries, owner files, scenarios, decisions, tests, rollout и rollback | `specs/2026-07-14-gpt56-catalog-migration.md` |
| SPEC | Adversarial и role-based review | 0.96 | Существенных данных не требуется | Уточнить AC11 и повторить relevant passes | Нет | Нет | Найдена неоднозначность между missing-owner и stale-target regression cases; оба сделаны обязательными и независимыми | `specs/2026-07-14-gpt56-catalog-migration.md` |
| SPEC | Quality gates и validation evidence | 0.98 | Ожидается только QUEST approval | Запросить `Спеку подтверждаю` и остановиться до EXEC | Да | Нет | Linter `ГОТОВО`, rubric `30/30`, post-SPEC `PASS`; validators, diff/scope и junction checks прошли | `specs/2026-07-14-gpt56-catalog-migration.md` |
| SPEC | Независимое user-requested review | 0.99 | Существенных данных не требуется | Исправить 2 HIGH, 2 MEDIUM и 1 LOW finding без перехода в EXEC | Нет | Да: пользователь запросил review и затем `Исправь` | Review обнаружил surface conflation, optional behavioral gate, partial activation risk, underdefined API contract и неточность evidence count | `specs/2026-07-14-gpt56-catalog-migration.md`, official GPT-5.6/ChatGPT/Codex/API docs |
| SPEC | Fix and re-review after user findings | 0.97 | Ожидается только QUEST approval | Повторить validators и остановиться на SPEC gate | Да | Да: исправления явно запрошены | Добавлены Surface Contract Matrix, mandatory target-runtime smoke, isolated activation, normative API wire rules и AC17 | `specs/2026-07-14-gpt56-catalog-migration.md` |
| EXEC | Approval и baseline behavioral smoke | 0.98 | Cross-tier comparison недоступен и не обязателен без performance claim | Реализовать change set в isolated worktree | Нет | Да: пользователь подтвердил spec точной фразой | Baseline зафиксировал current API-owner gap, SPEC stop и approved EXEC behavior на explicit Sol/medium | disposable smoke worktrees; без canonical mutations |
| EXEC | Isolated implementation и review | 0.96 | Существенных данных не требуется | Исправить найденный effort-enum gap и повторить checks | Нет | Нет | 11 canonical paths реализованы изолированно; review нашёл отсутствие явного `none..max` | isolated candidate, `AGENTS.md`, `README.md`, `instructions/*`, `templates/*`, `scripts/*`, `CHANGELOG.md` |
| EXEC | Candidate validation и after-smoke | 0.98 | Exact tier не виден внутри agent final, но подтверждён CLI invocation | Выполнить active drift gate и prepared activation | Нет | Нет | Validators, semantic scans, diff check и routing/SPEC/EXEC smoke прошли; новый template не содержит stale target | isolated candidate + smoke threads |
| EXEC | Active activation и fix/re-review | 0.97 | Существенных данных не требуется | Повторить active checks и post-EXEC review | Нет | Нет | Drift gate прошёл; transfer hash mismatch из-за trailing newline остановлен, исправлен и повторно проверен на всех 11 paths | active junction `C:\Projects\My\Agents`, validated candidate |
| EXEC | Final validation и full post-EXEC review | 0.99 | Только optional future drift/performance refresh | Завершить без commit/push | Нет | Нет | AC1-AC17 PASS; temporary smoke artifacts удалены; residual risks не блокируют outcome | full active diff, validators, behavioral evidence, эта spec |
