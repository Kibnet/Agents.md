# Agents.md

**Централизованная система инструкций для AI-агентов разработки.**

Перестаньте копировать `AGENTS.md` в каждый репозиторий.

Вместо этого:

* храните инструкции для агентов **в одном месте**
* подключайте их из проектов
* обновляйте правила **один раз → применяются везде**

Проще говоря:

> `Agents.md` — это **`.editorconfig` для AI-агентов**.

---

# Зачем это нужно

При использовании AI-агентов (Codex, Cursor, Claude Code, Copilot и др.)
в проектах обычно появляется файл `AGENTS.md` с правилами работы:

* правила коммитов
* требования к тестам
* правила отладки
* архитектурные ограничения

Со временем возникает проблема:

```
один файл
в 10 репозиториях
с 10 разными версиями
```

Изменение правил превращается в боль.

Этот репозиторий решает проблему с помощью
**централизованного каталога инструкций для агентов**.

---

# Общая архитектура

Portable default: локальный `AGENTS.md` содержит только pointer на каталог. Для Codex также поддерживается global pointer в `~\.codex\AGENTS.md` на `~\.codex\agents\AGENTS.md`, если native loading проверен на текущем host. Тогда local pointer дублировать не нужно; на другом host/CI это не гарантирует подключение. В обеих схемах optional `AGENTS.override.md` только ужесточает central MUST.

Форму SPEC выбирает [quest-governance](instructions/core/quest-governance.md): short для ограниченного low-risk scope, expanded для остальных задач. Оба canonical template живут в `templates/specs/`; локальный `specs/` содержит рабочие спецификации. Exact approval сохраняется; глубину проверки определяет [review-loops](instructions/governance/review-loops.md).

В каталоге 5.0.0 применимость правила проверяется до его строгости по [routing-matrix](instructions/governance/routing-matrix.md). Short использует пять содержательных проверок; обязательный test set выбирается по риску через [testing-baseline](instructions/core/testing-baseline.md). Явные consumer gates и проверки уже утверждённой SPEC сохраняются. Условия перехода и отката описаны в [CHANGELOG](CHANGELOG.md).

```mermaid
flowchart TD

CodexHome[~/.codex/AGENTS.md<br/>global pointer]
Central[~/.codex/agents/AGENTS.md<br/>central catalog]

RepoA[Проект A]
RepoB[Проект B]
RepoC[Проект C]
Override[AGENTS.override.md<br/>optional local strict rules]

Router[routing-matrix.md]

Core[core правила]
CreatorVibe[creator-vibe lightweight lens]
Model[GPT-6 family behavior<br/>Astra baseline]
ToolExecution[tool execution baseline]
Responses[Responses API contract]
Contexts[контекстные правила]
Profiles[технологические профили]
Prompts[prompt templates]
Operations[warn-only hooks and analyzer]
ExternalSkill[~/.codex/skills/creator-vibe<br/>external full skill]

CodexHome --> Central

RepoA --> CodexHome
RepoB --> CodexHome
RepoC --> CodexHome
RepoA -. optional .-> Override

Central --> Router

Router --> Core
Core --> CreatorVibe
Core --> Model
Core --> ToolExecution
CreatorVibe -. creative / human-experience trigger .-> ExternalSkill
Router --> Responses
Router --> Contexts
Router --> Profiles
Router --> Prompts
Central --> Operations
```

---

# Creator Vibe: lightweight lens и полный skill

Central stack применяет [creator-vibe-lens.md](instructions/core/creator-vibe-lens.md) до классификации каждой задачи. Линза помогает сохранить реальный человеческий outcome и авторский замысел, но не переопределяет explicit instructions, factual accuracy, safety, exact-output, authorization, scope, QUEST или более специфичные owners.

Полный [`bish-x/creator-vibe`](https://github.com/bish-x/creator-vibe) является внешним optional skill: он загружается только для задач, где результат зависит от taste, voice, feeling, UX/human experience или недосказанного намерения. Для factual, mechanical, exact-output и fully specified work полный skill не нужен. Если он не установлен, lightweight owner продолжает работать и не должен создавать ложный claim о загрузке skill.

Репозиторий не vendor-ит и не модифицирует upstream-текст. Воспроизводимая локальная интеграция проверена на commit [`58642d69fafc5768627ed16215723c19198c4b4b`](https://github.com/bish-x/creator-vibe/commit/58642d69fafc5768627ed16215723c19198c4b4b).

---

# Surface Contract Matrix для семейства GPT-6

Каталог сохраняет `GPT-6 Astra` как behavior baseline и различает роли GPT-6 Astra/Sol/Luna; явно закреплённые GPT-5.6 Sol/Terra/Luna сохраняются. Baseline не переключает модели в пользовательской конфигурации. Перед model-sensitive validation фиксируйте фактическую поверхность, model ID, effort и версию клиента: доступность зависит от rollout, sign-in, клиента и account. Срез источников для этой матрицы проверен 2026-09-25; перед rollout перепроверяйте его.

| Поверхность | Текущий контракт | Как использовать каталог |
|---|---|---|
| Standard ChatGPT | Его picker и default проверяются отдельно; документация Work/Codex не устанавливает контракт обычного чата. | Применять общие behavior rules без переноса API model IDs или Work tiers в product UI. |
| ChatGPT Work / desktop, Codex CLI / IDE | GPT-6 Sol и Luna выпускаются в Work/Codex; конкретные options зависят от rollout, plan и workspace settings. Product reasoning/speed controls не равны API payload. | Сохранять выбранную модель, проверять picker/effective runtime и начинать с доступного default effort. Для воспроизводимого smoke задавать model ID явно и проверять effective metadata. |
| Codex cloud | Доступность модели и функций проверяется по текущему product contract и workspace settings. | Не выводить cloud availability из API catalog или local model list; проверять отдельно. |
| OpenAI API | `gpt-6-astra`, `gpt-6-sol` и `gpt-6-luna` имеют разные effort/tool/parameter условия; `gpt-5.6` остаётся alias GPT-5.6 Sol. | По API-триггеру подключать [openai-responses-api.md](instructions/governance/openai-responses-api.md); не переносить product Ultra или доступность в API payload. |

Официальные источники: [ChatGPT Work и Codex models](https://learn.chatgpt.com/docs/models), [Using GPT-6](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra), [Astra](https://developers.openai.com/api/docs/models/gpt-6-astra), [Sol](https://developers.openai.com/api/docs/models/gpt-6-sol), [Luna](https://developers.openai.com/api/docs/models/gpt-6-luna). Experimental context management и другие opt-in features автоматически не включаются.

---

# Структура репозитория

```
instructions/
 ├─ core/          # базовые правила и QUEST owner-документы
 ├─ contexts/      # контексты выполнения
 │   ├─ debug-dotnet-mcp-coreclr.md
 │   ├─ performance-optimization.md
 │   ├─ testing-dotnet.md
 │   ├─ testing-frontend.md
 │   └─ visual-feedback.md
 ├─ profiles/      # технологические и сценарные профили
 ├─ governance/    # routing, quality gate и политики каталога
 └─ onboarding/    # шаблоны подключения

prompts/           # канонические prompt templates для guided workflows
 ├─ business-process-automation/
 └─ storm/

schemas/           # JSON Schema для machine-readable workflow artifacts
scripts/           # validator, operational runtime и workflow scripts
 ├─ hooks/
 ├─ fixtures/agent-operations/
 └─ storm/
templates/
 ├─ codex/
 ├─ specs/
 │  └─ _template.md
 └─ storm/
specs/             # рабочие спецификации изменений каталога
```

---

# Канонические точки входа

Основные файлы системы:

* `AGENTS.md` — основная точка входа
* `instructions/governance/routing-matrix.md` — алгоритм маршрутизации инструкций
* `instructions/core/creator-vibe-lens.md` — обязательный lightweight owner intent/human outcome и trigger полного external skill
* `instructions/core/model-behavior-baseline.md` — owner optimization baseline `GPT-6 Astra`: outcome-first, surface-aware model guidance, ясный стиль и stop rules
* `instructions/core/tool-execution-baseline.md` — обязательный owner preflight, paths/globs, PowerShell, patch, Git и failure classification для tool-heavy задач
* `instructions/governance/openai-responses-api.md` — trigger-based owner wire-level контрактов OpenAI Responses API
* `instructions/core/quest-governance.md` — gate `SPEC → EXEC` для инженерных изменений
* `instructions/core/quest-mode.md` — owner фазового поведения `QUEST`
* `instructions/governance/review-loops.md` — обязательные auto-review loops после `SPEC` и `EXEC`
* `instructions/profiles/business-process-automation.md` — сценарный профиль для пошаговой автоматизации бизнес-процессов
* `instructions/profiles/storm-product-development.md` — сценарный профиль для STORM product workflow, BDD/Gherkin behavior layer и команд `/storm:*`

---

# Как работает маршрутизация инструкций

Точный алгоритм выбора документов, порядок сборки stack и модель разрешения конфликтов определены только в [instructions/governance/routing-matrix.md](instructions/governance/routing-matrix.md).

Короткий порядок работы:

1. Прочитать `AGENTS.md`
2. Открыть `routing-matrix.md`
3. Определить тип задачи:
   * `catalog-governance`
   * `consumer-onboarding`
   * `delivery-task`
   * `guided-artifact-workflow`
4. Собрать central stack по `routing-matrix.md`, включая `model-behavior-baseline` и, для tool-heavy задачи, `tool-execution-baseline`
5. Если в consumer-репозитории есть `AGENTS.override.md`, применить только его ужесточающие правила
6. Если задача идёт через `QUEST`, использовать:
   * [instructions/core/quest-governance.md](instructions/core/quest-governance.md) для applicability и quality gate
   * [instructions/core/quest-mode.md](instructions/core/quest-mode.md) для фазового поведения `SPEC` и `EXEC`

Важно:

* `SPEC gate` применяется к инженерным изменениям каталога, кода, инфраструктуры и канонических файлов проекта
* `model-behavior-baseline` применяется ко всем сценариям и задаёт Astra optimization contract: outcome-first цель, surface evidence, критерии успеха, ограничения, output contract и stop rules
* `tool-execution-baseline` применяется до первого значимого tool call и не занимает место task-specific context
* `openai-responses-api` подключается только для API-specific задач; ordinary Markdown review или работа в product UI не должны тянуть wire-level API правила
* на фазе `SPEC` рабочая spec в локальном `./specs/` может обновляться до подтверждения пользователя; остальные файлы менять нельзя
* внутри `QUEST` после черновика спеки обязателен цикл `draft → lint/rubric → post-review → refine`
* внутри `QUEST` после исполнения обязателен цикл `implement → test → post-review → fix/retest → report`
* если review находит uniquely best option, агент обязан выбрать его сам; пользователя спрашивают только при реальной неоднозначности
* guided workflow с пользовательскими артефактами может идти без `SPEC gate`, если агент не меняет канонические файлы
* STORM safe full-cycle может идти как guided workflow только без изменений tests/code/test annotations; любые такие изменения переводят задачу в `delivery-task` с `QUEST`
* STORM BDD/Gherkin команды `/storm:gherkin`, `/storm:bdd-sync`, `/storm:bdd-lint` и `/storm:bdd-conflicts` могут идти как artifact-only guided workflow; `/storm:bdd-implement ST-XXXX` всегда идёт как `delivery-task` через `QUEST`
* для аналитических задач без выраженного стека можно использовать сценарный профиль без `stack profile`

Примеры:

* инженерная задача по каталогу: `model-behavior-baseline + tool-execution-baseline + quest-governance + collaboration-baseline + governance overlays`
* пошаговый анализ бизнес-процесса: `model-behavior-baseline + collaboration-baseline + business-process-automation`
* STORM product discovery без code/test mutations: `model-behavior-baseline + collaboration-baseline + storm-product-development`
* STORM implementation/cleanup/test coverage: `model-behavior-baseline + quest-governance + collaboration-baseline + testing-baseline + stack/testing profile + storm-product-development`

---

# Operational prevention runtime

Каталог содержит versioned candidate механической защиты от повторяемых tool-ошибок:

* `scripts/hooks/agent-operations-hook.ps1` — fail-open dispatcher только для `PreToolUse` и `PostToolUse`, с безопасным Windows local NTFS handle store, ownership binding, bounded maintenance и rollback;
* `scripts/install-agent-operations.ps1` — idempotent preview/install/uninstall/prune и evidence-bound `-MarkActive` с physical-alias transaction lock, intermediate reparse guards, fingerprints, backup и rollback; runtime записывается из захваченного и хешированного byte snapshot;
* `scripts/probe-agent-operations-activation.ps1` — controlled safe/noisy/fail-open probe, проверка agent limits, manual hook trust, подтверждение controlled host task, install-bound runtime challenge и актуальное reviewer evidence v2, связанное с install/config и ожидаемыми host/runtime/session identity; probe исполняет hash-verified captured runtime bytes из одноразового private staging path и повторно проверяет live runtime;
* `scripts/analyze-codex-session-errors.ps1` — потоковый privacy-safe отчёт с дедупликацией trace/call IDs, агрегацией child traces в root task, раздельными task/trace/event и envelope/matched/unmatched/boundary denominators и independently sampled private-local gold gate;
* `templates/codex/agents/independent-reviewer.toml` — read-only reviewer template;
* `templates/codex/local-environment/` — read-only Windows preflight для consumer rollout.

Проверка versioned candidate не меняет пользовательский Codex home:

```powershell
pwsh -File scripts/test-agent-operations.ps1
pwsh -File scripts/install-agent-operations.ps1 -CodexHome <fixture-path> -WhatIf
```

Telemetry включается только при наличии созданной installer-ом случайной salt в local manifest и пишет allowlist `schemaVersion/timestamp/runtimeVersion/eventName/category/severity/action/exitClass/repoHash` плюс optional `sessionHash`; raw command/output/path не сохраняются. Безопасный store сериализует поддерживаемые case/8.3 aliases по physical identity; reparse aliases не поддержаны. Owned segments ограничены числом и размером, state обновляется с rollback через проверенные handles. Legacy recovery artifacts без нового ownership binding сохраняются для отдельной миграции.

Фраза `Спеку подтверждаю` разрешает только repository implementation. Реальная установка в `%USERPROFILE%\.codex` допустима лишь после отдельного Git delivery, проверки active central checkout, предъявления exact `-WhatIf` proposal с `proposalHash` и фразы `Глобальную активацию подтверждаю` для этого hash. Preview раскрывает exact before/after content для `config.toml`, `hooks.json` и reviewer, immutable runtime hash и только явно перечисленные generated fields. После записи non-managed hooks остаются в состоянии `awaiting-trust`, пока пользователь не проверит exact definition через `/hooks` или актуальный документированный эквивалент, не подтвердит запуск controlled host task, probe не увидит install-bound runtime challenge и reviewer write denial, а отдельный approved `-MarkActive` не переведёт полный manifest postimage в `active`. Activation evidence v2 действительно до более раннего из двух сроков: runtime observation +15 минут и reviewer observation +15 минут. Probe получает expected runtime/session identity из фактического controlled run, а MarkActive повторно проверяет весь contract непосредственно перед commit. Это согласованное run evidence, не криптоаттестация sandbox.

---

# Guided Workflows

Каталог поддерживает не только правила для инженерных изменений, но и готовые сценарии пошаговой аналитической работы.

Сейчас в репозитории есть канонические guided workflows:

* `business-process-automation`
* `storm-product-development`

Этот сценарий ведёт агента по цепочке:

1. синтетическое интервью с экспертом
2. моделирование `AS-IS`
3. анализ точек автоматизации
4. проектирование `TO-BE`
5. построение skill graph ИИ-агента

Шаблоны шагов лежат в `prompts/business-process-automation/`.
Если пользователь просит выдавать артефакты по шагам, агент должен сохранять каждый шаг отдельным файлом и ждать подтверждения перед продолжением.

## STORM Product Development

`storm-product-development` ведёт агента по циклу living product specification:

1. восстановить реализованные stories, constraints, tests и code units из текущего продукта;
2. построить traceability `story -> acceptance criteria -> tests -> code`;
3. сформировать Gherkin Rules/Scenarios как executable behavior examples;
4. вывести needs, Product Goal и Product Vision;
5. найти gaps, cloud conflicts и proposed backlog;
6. построить dependency-aware ranking;
7. провести process audit;
8. реализовывать отдельные stories через SDD/BDD только через `/storm:implement ST-XXXX` или `/storm:bdd-implement ST-XXXX`.

Канонический machine-readable artifact в consumer-репозитории:

```text
docs/product/storm.json
```

`.feature` files по умолчанию лежат в:

```text
features/
```

Если consumer-репозиторий использует другой root, он фиксируется в `metadata.feature_root` внутри `storm.json`.

Central assets:

```text
instructions/profiles/storm-product-development.md
prompts/storm/
templates/storm/
schemas/storm-artifacts.schema.json
scripts/storm/validate-artifacts.py
scripts/storm/rank-backlog.py
```

Примеры вызова:

```text
Используй central stack по AGENTS.md и routing-matrix.md, подключи профиль storm-product-development и выполни /storm:full-cycle.
Не меняй tests, code и test annotations.
```

```text
Используй central stack по AGENTS.md и routing-matrix.md, подключи профиль storm-product-development и выполни /storm:implement ST-0007.
```

```text
Используй central stack по AGENTS.md и routing-matrix.md, подключи профиль storm-product-development и выполни /storm:gherkin ST-0007.
```

```text
Используй central stack по AGENTS.md и routing-matrix.md, подключи профиль storm-product-development и выполни /storm:bdd-lint.
```

Проверка artifacts из consumer-репозитория:

```powershell
python <AGENTS_ROOT>\scripts\storm\validate-artifacts.py .\docs\product\storm.json
python <AGENTS_ROOT>\scripts\storm\rank-backlog.py .\docs\product\storm.json --out .\docs\product\reports\ranking.md
```

BDD/Gherkin слой в `storm.json` хранит metadata and traceability, а сами executable examples должны жить в `.feature` files. Acceptance criteria остаются обзорным readiness contract, Gherkin Rules/Scenarios делают их проверяемыми примерами, automated tests and step definitions исполняют эти примеры.

---

# Быстрый старт

## Основной способ: global pointer в Codex home

Для Codex подключите каталог один раз в `C:\Users\<user>\.codex\`.
Проверенная схема:

* центральный каталог доступен как `C:\Users\<user>\.codex\agents`
* `C:\Users\<user>\.codex\AGENTS.md` содержит короткий pointer на центральный `AGENTS.md`
* в рабочих репозиториях локальный `AGENTS.md` больше не нужен
* локальный `AGENTS.override.md` применяется только поверх central stack и может только ужесточать `MUST`
* для `QUEST` рабочие spec-файлы создаются в локальном `.\specs\`, а canonical template выбранной формы берётся из центрального `templates\specs\` по quest-governance
* lightweight `creator-vibe-lens` входит в central stack; полный external skill устанавливается отдельно и остаётся optional

### 1. Подключить каталог как `~\.codex\agents`

Если репозиторий уже клонирован в удобном месте, создайте junction:

```powershell
$codexHome = Join-Path $env:USERPROFILE ".codex"
$agentsRepo = "C:\path\to\Agents.md"

New-Item -ItemType Junction `
  -Path (Join-Path $codexHome "agents") `
  -Target $agentsRepo
```

Если удобнее хранить каталог прямо в Codex home:

```powershell
git clone https://github.com/Kibnet/Agents.md.git "$env:USERPROFILE\.codex\agents"
```

---

### 2. Создать глобальный pointer

Создайте `C:\Users\<user>\.codex\AGENTS.md`:

```
# AGENTS (global pointer)

Необходимо использовать центральный каталог инструкций:

- `C:\Users\<user>\.codex\agents\AGENTS.md`

Порядок применения:
1. Центральный `AGENTS.md` -> central stack
2. Локальный `AGENTS.override.md` -> дополнительные локальные инструкции поверх central stack; только ужесточение MUST

Для QUEST-задач:

- рабочие spec-файлы создаются в локальном `.\specs\` репозитория
- canonical template берется из `C:\Users\<user>\.codex\agents\templates\specs\` по central quest-governance
```

### 3. Опционально установить полный `creator-vibe`

Lightweight owner уже входит в central catalog. Чтобы creative/human-experience задачи могли загрузить полный upstream skill, используйте системный `skill-installer` и pinned commit:

```powershell
python "$env:USERPROFILE\.codex\skills\.system\skill-installer\scripts\install-skill-from-github.py" `
  --repo bish-x/creator-vibe `
  --path . `
  --ref 58642d69fafc5768627ed16215723c19198c4b4b `
  --name creator-vibe
```

Installer не перезаписывает существующий destination. Новый skill становится доступен следующему Codex turn/session.

### 4. Добавлять только локальные ужесточения

В проектах создавайте `AGENTS.override.md` только если нужны дополнительные
локальные ограничения, команды или профиль по умолчанию. Central stack остаётся
источником правил, а override не заменяет центральный `AGENTS.md`.

## Альтернатива: pointer в конкретном репозитории

Для инструментов, которые не читают `~\.codex\AGENTS.md`, можно оставить
локальный pointer в репозитории-потребителе:

```
# AGENTS

Этот репозиторий использует центральный каталог инструкций:

- <AGENTS_ROOT>\AGENTS.md

Для QUEST-задач:

- рабочие spec-файлы создаются в локальном `.\specs\`
- canonical template выбранной формы берётся из `<AGENTS_ROOT>\templates\specs\` по central quest-governance
```

Где `<AGENTS_ROOT>` указывает на каталог с централизованными инструкциями,
например `$env:USERPROFILE\.codex\agents`.

---

# Локальные переопределения

Если проекту нужны дополнительные ограничения, можно создать:

```
AGENTS.override.md
```

В нём можно добавить **локальные правила**,
не дублируя весь набор инструкций.

---

# Проверка качества

Перед завершением изменений можно запустить валидацию:

```
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
pwsh -File scripts/test-agent-operations.ps1
```

---

# CI-валидация

В репозитории настроен workflow:

```
.github/workflows/validate-instructions.yml
```

Он проверяет инструкции при:

* `push`
* `pull request`

Catalog/link/semantic checks выполняются на `ubuntu-latest` без Windows-specific runtime suite. Полные hook/installer/analyzer/privacy contracts выполняются отдельным `windows-latest` job, где доступны NTFS junction/reparse semantics.

---

# Поддерживаемые AI-инструменты

Каталог рассчитан на использование с агентами, которые читают `AGENTS.md`, например:

* Codex CLI
* Cursor
* Claude Code
* GitHub Copilot Agents
* Windsurf

---

# Философия проекта

Цели:

* единый каталог инструкций для AI-агентов
* повторное использование правил между репозиториями
* единый инженерный workflow
* версионирование и управление правилами

---

# Участие в развитии

Приветствуются улучшения:

* алгоритма маршрутизации
* технологических профилей
* контекстных инструкций
* скриптов валидации

---

# Лицензия

MIT


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
