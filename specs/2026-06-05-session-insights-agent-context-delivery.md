# Session Insights Context Delivery for Agents

## 0. Метаданные
- Тип (профиль): `catalog-governance` + `product-system-design` overlay
- Владелец: пользователь + Codex
- Масштаб: large
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: текущая рабочая ветка репозитория инструкций
- Ограничения:
  - До подтверждения спеки разрешено менять только этот файл.
  - Переход к EXEC только после точной фразы `Спеку подтверждаю`.
  - Session-derived данные считаются подсказками, а не подтверждёнными текущими фактами.
  - Новые правила не должны перекрывать central `AGENTS.md`, routing matrix, developer/system instructions и явный запрос пользователя.
  - Нельзя автоматически подмешивать приватные детали пользователя, если задача не требует персонального контекста.
  - До явного решения пользователя все файлы с персональным профилем, локальными путями, перечнями рабочих проектов и machine-specific командами считаются `private-local`, даже если они лежат в рабочем дереве.
  - В коммит/PR можно продвигать только `sanitized-committable` subset: без абсолютных пользовательских путей, credential paths, приватных endpoint details и лишних персональных выводов.
- Связанные ссылки:
  - `session-insights/README.md`
  - `session-insights/AGENT_SESSION_LESSONS.md`
  - `session-insights/REPO_RUNBOOKS_FROM_SESSIONS.md`
  - `session-insights/VALIDATION_COOKBOOK_FROM_SESSIONS.md`
  - `session-insights/UI_QUALITY_RUBRIC_FROM_SESSIONS.md`
  - `session-insights/COMMAND_COOKBOOK_FROM_SESSIONS.md`
  - `session-insights/FLAKY_SLOW_TESTS_REGISTRY.md`
  - `session-insights/USER_WORKFLOW_PREFERENCES.md`
  - `session-insights/PROJECT_INTEREST_MAP.md`
  - `session-insights/AGENTS_IMPROVEMENT_BACKLOG.md`
  - `session-insights/DO_NOT_REPEAT.md`
  - `USER_PROFILE_FROM_CODEX_SESSIONS.md`

Если секция не применима, это указано явно внутри секции.

## 1. Overview / Цель
Нужно спроектировать, как доносить до агентов знания из новых session-derived файлов так, чтобы:

- агент реально использовал накопленные уроки из сессий;
- контекст не раздувался постоянной загрузкой всех файлов;
- пользователь мог контролировать, какие категории знаний становятся правилами, подсказками или остаются справочным материалом;
- агент понимал, когда читать конкретный файл и как проверять выводы перед действием.

Outcome contract:
- Success means:
  - Есть утверждённая стратегия загрузки session-insights в контекст агента.
  - Для каждого нового файла указан лучший способ доставки: always-on pointer, on-demand retrieval, repo-triggered retrieval, optional helper/skill или не автозагружать.
  - Для каждого нового файла указан publish/storage boundary: `private-local`, `sanitized-committable`, `generated-index`, `future-tooling`.
  - Есть понятные точки участия пользователя до EXEC.
  - Есть критерии проверки, что агент действительно выбирает нужные файлы и не перегружает контекст.
- Итоговый артефакт / output:
  - Утверждённая спека.
  - После EXEC: минимальные изменения в центральных инструкциях/индексе, которые добавляют маршрутизацию session-insights.
- Stop rules:
  - Остановиться до EXEC, если пользователь не выбрал уровень автоматизации и место подключения.
  - Остановиться, если proposed change начинает автоматически раскрывать личные данные без явной задачи.
  - Остановиться, если изменение требует внешней интеграции/RAG/MCP, которую пользователь не подтвердил.

## 2. Текущее состояние (AS-IS)
- В репозитории есть локальные session-derived файлы:
  - `USER_PROFILE_FROM_CODEX_SESSIONS.md`
  - каталог `session-insights/`
- Эти файлы сейчас untracked и должны рассматриваться как generated local artifacts, пока не принято отдельное решение о публикации/sanitization.
- `session-insights/README.md` фиксирует источник анализа:
  - 421 JSONL-сессия;
  - 4099 сообщений;
  - период 2025-11-13..2026-06-05;
  - 11 тематических markdown-артефактов.
- `USER_PROFILE_FROM_CODEX_SESSIONS.md` фиксирует другой проход анализа:
  - 420 JSONL-сессий;
  - 4075 отфильтрованных пользовательских сообщений;
  - период 2025-11-13..2026-06-04.
  Это нужно явно пометить как separate snapshot или синхронизировать при EXEC.
- `AGENT_SESSION_LESSONS.md` содержит top failure clusters:
  - `timeout` 3337;
  - `other_nonzero` 1964;
  - `search_no_match` 1664;
  - `test_failure` 1574;
  - `dotnet_build` 1549;
  - `missing_path` 892;
  - `patch_failure` 621;
  - `network_auth` 612;
  - `git` 498;
  - `powershell` 332;
  - `missing_tool` 292;
  - `dependency` 27.
- `REPO_RUNBOOKS_FROM_SESSIONS.md` содержит repo-specific runbooks и частотность по репозиториям. Самые заметные:
  - `Unlimotion`;
  - `TopLunchBot`;
  - `AppAutomation`;
  - `DotnetDebug`;
  - `Agents`;
  - `Arm.Srv`;
  - `graph-bot`;
  - `ArduinoAndRaspberry`;
  - `PDFAnnotator`;
  - `UTEP/UTEP.Sample`.
- Сейчас эти файлы не являются automatic context. Агент может прочитать их только если сам догадается или пользователь явно попросит.
- В memory уже есть короткая operational note про PowerShell, .NET validation, `apply_patch`, `rg`, Git/GitHub preflight и TUnit, но там нет полноценного профиля пользователя или repo-specific runbooks.
- Центральная инструкция и routing matrix пока не содержат отдельного сценария "используй session-insights при выборе контекста".

Ограничения и проблемы:
- Полная загрузка всех файлов стоит дорого по токенам и смешивает разные типы знания.
- Часть выводов из сессий эвристическая и может быть устаревшей.
- Личные предпочтения пользователя полезны, но не должны превращаться в технические факты.
- Repo-specific runbooks полезны только при совпадении текущего проекта или домена.
- Часть артефактов содержит персональные/локальные сведения и не должна автоматически попадать в repo-published instruction surface.
- Некоторые cookbook команды содержат absolute local paths и должны быть заменены на placeholders перед публикацией.
- Метаданные охвата между profile и session-insights отличаются; это нужно явно объяснить или исправить.
- Нужен способ дать агенту короткий always-on сигнал и при этом оставить глубокие файлы on-demand.

## 3. Проблема
Корневая проблема: накопленные знания из session-insights уже существуют, но у агента нет маршрутизации, которая решает, какую именно информацию загрузить в контекст для текущей задачи, с каким уровнем доверия, с каким token budget и можно ли вообще продвигать конкретный источник в репозиторный/публичный instruction surface.

## 4. Цели дизайна
- Разделение ответственности:
  - central instructions задают правило маршрутизации;
  - `session-insights/README.md` остаётся индексом;
  - тематические файлы остаются источниками деталей;
  - helper/skill, если будет выбран, только ускоряет выбор источников.
- Повторное использование:
  - один router должен работать для разных репозиториев и типов задач.
- Тестируемость:
  - можно проверить dry-run сценариями, какие файлы агент должен выбрать.
- Консистентность:
  - delivery strategy должна уважать central stack и QUEST правила.
- Обратная совместимость:
  - существующие session-insights файлы не нужно переписывать ради MVP.
  - агенты без session-insights просто продолжают обычный workflow.

## 5. Non-Goals (чего НЕ делаем)
- Не загружаем все session-insights файлы всегда.
- Не коммитим full personal profile или raw local session-derived артефакты без sanitization и явного решения пользователя.
- Не оставляем absolute user-specific paths в committable cookbook/runbook примерах.
- Не строим полноценный RAG/MCP/search service в MVP без отдельного подтверждения.
- Не делаем session-derived пользовательский профиль обязательным контекстом для каждой задачи.
- Не считаем статистику сессий доказательством текущего состояния репозитория.
- Не меняем правила памяти напрямую в этой спеке. Memory updates возможны только отдельным явным запросом пользователя.
- Не редактируем исходные JSONL-сессии.
- Не заменяем центральную routing matrix новым механизмом.

## 6. Предлагаемое решение (TO-BE)
Выбранный базовый подход: минимальный always-on router + on-demand retrieval по триггерам.

### 6.1 Распределение ответственности
- `instructions/governance/routing-matrix.md` -> добавить короткий маршрут/overlay: когда задача затрагивает known repo, validation, UI, shell/Git/Patch или улучшение агентов, проверять session-insights.
- Новый возможный документ `instructions/contexts/session-insights-context.md` -> owner-документ с политикой выбора session-insights файлов, уровнем доверия, token budget и safety rules.
- `session-insights/README.md` -> оставить human/agent index; при необходимости добавить ссылку на routing policy.
- `session-insights/*.md` -> оставить source material; читать выборочно.
- `USER_PROFILE_FROM_CODEX_SESSIONS.md` -> по умолчанию `private-local`; не автозагружать для технических задач; использовать только для задач про предпочтения, стиль взаимодействия, планирование и персональные рабочие процессы.
- `.gitignore` или иной ignore policy -> если пользователь выбирает local-private режим, исключить raw/full profile и raw session-derived artifacts из accidental staging.
- Опциональный helper `scripts/select-session-insights.ps1` -> если пользователь выберет автоматизацию, выводит recommended files/sections по `cwd`, task keywords и task type.
- Опциональный skill `session-insights` -> если пользователь хочет переносимый механизм вне этого репозитория, skill описывает тот же router как callable workflow.

### 6.2 Детальный дизайн
Контекст доставляется слоями:

1. Layer 0: always-on pointer.
   - Короткое правило в central stack.
   - Бюджет: до 200-300 токенов.
   - Содержание: "если задача не self-contained и связана с известным repo/task type, прочитай `session-insights/README.md`, затем только релевантные файлы".

2. Layer 1: memory guardrails.
   - Использовать уже существующую memory note для стабильных operational mistakes.
   - Не расширять memory без явного запроса.
   - Бюджет: уже управляется memory subsystem.

3. Layer 2: repo/task-triggered retrieval.
   - Первый шаг: прочитать `session-insights/README.md`.
   - Второй шаг: выбрать 1-3 тематических файла по матрице из секции 7.
   - Третий шаг: читать только нужные секции через `rg`, `Select-String`, line ranges или будущий helper.
   - Бюджет: по умолчанию до 4000-6000 токенов на session-insights lookup.

4. Layer 3: focused deep-dive.
   - Применяется только если задача сложная, повторяет прошлые ошибки или требует проектной стратегии.
   - Можно читать дополнительные файлы, но агент должен объяснить, почему они нужны.

5. Layer 4: automation/RAG future.
   - Не входит в MVP.
   - Возможные формы: skill, MCP resource, SQLite/JSON index, embeddings/RAG.
   - Включать только после отдельного решения.

Output contract / evidence rules:
- Если агент использует session-insights в ответе или EXEC, он должен кратко указать, какие файлы повлияли на выбор.
- Если факт drift-prone, агент должен проверить текущее состояние репозитория перед действием.
- Если используется пользовательский профиль, агент должен явно отделять "предпочтение пользователя" от "технического требования".

Visual planning artifact для UI-facing изменений:
- Не применимо к этой спеке: изменение касается instruction/context routing, а не UI.

UI test video evidence для UI automation задач:
- Не применимо к этой спеке: изменение не добавляет UI automation.

Границы сохранения поведения:
- Central routing остаётся главным механизмом.
- QUEST phase rules не меняются.
- Session-insights не имеют большего приоритета, чем текущие user/developer/system instructions.

Обработка ошибок:
- Если `session-insights/` отсутствует в consumer repo, агент не должен падать; он продолжает обычный workflow.
- Если файл найден, но не содержит релевантной секции, это `no-match`, а не ошибка.
- Если session-insights противоречат текущему repo state, актуальный repo state побеждает.

Производительность:
- Always-on часть минимальная.
- Deep files не загружаются без триггера.
- Для больших файлов предпочтительны section search и line-range reads.

### 6.3 Publish / Storage Boundary
По умолчанию эта спека разделяет файлы не только по способу загрузки в контекст, но и по допустимости публикации в репозитории.

| Артефакт | Boundary | EXEC действие по умолчанию | Комментарий |
| --- | --- | --- | --- |
| `USER_PROFILE_FROM_CODEX_SESSIONS.md` | `private-local` | Не коммитить; при необходимости добавить в ignore policy или перенести в локальный приватный каталог | Содержит персональные выводы, локальные пути, список рабочих тем и окружения |
| `session-insights/README.md` | `sanitized-committable` после проверки | Убрать/обобщить absolute local source paths или явно пометить как local source snapshot | Может быть индексом, но не должен раскрывать приватные session locations без решения пользователя |
| `AGENT_SESSION_LESSONS.md` | `sanitized-committable` | Оставить как operational guardrails после проверки на локальные пути/секреты | Наиболее пригоден для central instruction surface |
| `DO_NOT_REPEAT.md` | `sanitized-committable` | Оставить как compact anti-pattern checklist | Хороший источник для коротких guardrails |
| `COMMAND_COOKBOOK_FROM_SESSIONS.md` | `sanitized-committable` after path placeholder pass | Заменить абсолютные пути на placeholders (`<ANDROID_SDK_ROOT>`, `<JAVA_HOME>`, `<USER_HOME>`) | Иначе агент может копировать machine-specific commands |
| `VALIDATION_COOKBOOK_FROM_SESSIONS.md` | `sanitized-committable` after path placeholder pass | То же path placeholder pass | Полезен для validation routing |
| `REPO_RUNBOOKS_FROM_SESSIONS.md` | `sanitized-committable` or `private-local`, зависит от решения пользователя | Если коммитить, обобщить локальные пути и убрать приватные details | Содержит названия проектов и repo-specific behavior |
| `UI_QUALITY_RUBRIC_FROM_SESSIONS.md` | `sanitized-committable` | Проверить, что это UX/rubric, а не личный профиль | Полезен для UI quality context |
| `USER_WORKFLOW_PREFERENCES.md` | `sanitized-committable` summary или `private-local` full | В MVP лучше коммитить только sanitized summary, если нужен | Может стать скрытой директивой, поэтому требует cautious wording |
| `PROJECT_INTEREST_MAP.md` | `private-local` by default | Не коммитить без явного решения пользователя | Карта интересов/проектов более персональна, чем operational guardrail |
| `AGENTS_IMPROVEMENT_BACKLOG.md` | `sanitized-committable` | Коммитить как improvement backlog после проверки | Прямо относится к этому каталогу инструкций |
| `FLAKY_SLOW_TESTS_REGISTRY.md` | `private-local` или repo-specific sanitized subset | Не коммитить целиком без решения | Может содержать repo-specific operational details и устаревшие timings |

Sanitization rules:
- Absolute Windows user-home paths заменить на `<USER_HOME>\...`, `<CODEX_HOME>\...`, `<ANDROID_SDK_ROOT>` или убрать.
- Credential/token/API/server details не включать в committable docs.
- Метаданные источника писать как "local Codex session snapshot" без раскрытия конкретных приватных session directories, если документ предназначен для repo commit.
- Если full local artifact нужен агенту, но не должен попадать в git, EXEC должен добавить ignore rule и явно показать `git status --short` before/after.

## 7. Бизнес-правила / Алгоритмы (если есть)
### 7.1 Матрица выбора источников
| Сигнал задачи | Что читать | Как доставлять | Уровень доверия | Комментарий |
| --- | --- | --- | --- | --- |
| Любая не self-contained задача в этом repo | `session-insights/README.md` | on-demand index | Medium | Только как индекс доступных источников |
| Текущий `cwd` совпадает с known repo из runbooks | релевантную секцию `REPO_RUNBOOKS_FROM_SESSIONS.md` | repo-triggered retrieval | Medium | После чтения проверить текущий repo |
| Тесты, build, validation, TUnit, .NET, CI | `VALIDATION_COOKBOOK_FROM_SESSIONS.md`, возможно `FLAKY_SLOW_TESTS_REGISTRY.md` | task-triggered retrieval | Medium | Команды из истории сверять с текущими scripts/docs |
| UI/frontend/visual QA | `UI_QUALITY_RUBRIC_FROM_SESSIONS.md`, возможно `USER_WORKFLOW_PREFERENCES.md` | task-triggered retrieval | Medium | Preferences не заменяют явный дизайн-запрос |
| Shell, PowerShell, git, patch, missing tools, timeouts | `AGENT_SESSION_LESSONS.md`, `COMMAND_COOKBOOK_FROM_SESSIONS.md`, `DO_NOT_REPEAT.md` | task-triggered retrieval | High for guardrails, Medium for details | Хороший кандидат для memory/always-on summaries |
| Улучшение Codex/agents/instructions | `AGENTS_IMPROVEMENT_BACKLOG.md`, `AGENT_SESSION_LESSONS.md`, `PROJECT_INTEREST_MAP.md` | task-triggered retrieval | Medium | Нужна фильтрация от слишком широких предложений |
| Вопросы о пользователе, стиле, интересах | `USER_PROFILE_FROM_CODEX_SESSIONS.md`, `USER_WORKFLOW_PREFERENCES.md`, `PROJECT_INTEREST_MAP.md` | explicit-request retrieval only | Low-Medium | Не использовать как скрытую директиву без причины |
| Неизвестный repo и короткий self-contained запрос | ничего из session-insights | skip | Не применимо | Сохраняем token budget |

### 7.2 Рекомендуемая классификация новых файлов
| Файл | Лучший способ донести до агента | Почему |
| --- | --- | --- |
| `session-insights/README.md` | first-hop index on-demand | Коротко объясняет corpus и список источников |
| `AGENT_SESSION_LESSONS.md` | on-demand + compressed guardrails in central doc/memory | Содержит частые ошибки, полезно для предотвращения повторов |
| `REPO_RUNBOOKS_FROM_SESSIONS.md` | repo-triggered retrieval | Ценно только при совпадении проекта |
| `VALIDATION_COOKBOOK_FROM_SESSIONS.md` | task-triggered retrieval | Нужен при build/test/CI, не нужен всегда |
| `UI_QUALITY_RUBRIC_FROM_SESSIONS.md` | task-triggered retrieval | Нужен для UI задач, иначе token waste |
| `COMMAND_COOKBOOK_FROM_SESSIONS.md` | task-triggered retrieval | Полезно при shell/git/tooling задачах |
| `FLAKY_SLOW_TESTS_REGISTRY.md` | task-triggered retrieval | Полезно только при validation/debug loops |
| `USER_WORKFLOW_PREFERENCES.md` | explicit-request или interaction-sensitive retrieval | Может улучшать стиль работы, но не должно скрыто менять требования |
| `PROJECT_INTEREST_MAP.md` | planning/recommendation retrieval | Полезно для roadmap и приоритизации, не для текущих фактов |
| `AGENTS_IMPROVEMENT_BACKLOG.md` | agent-improvement retrieval | Прямо релевантен только задачам про улучшение агентов |
| `DO_NOT_REPEAT.md` | task-triggered + selective always-on summary | Высокая практическая ценность, но полный файл не нужен всегда |
| `USER_PROFILE_FROM_CODEX_SESSIONS.md` | explicit-request retrieval only | Личные выводы требуют осторожности и проверки пользователем |

### 7.3 Token budget policy
- Always-on: до 300 токенов.
- Быстрый lookup: `README.md` + 1 файл или 1 секция.
- Стандартный lookup: `README.md` + 2-3 релевантных файла/секции.
- Deep lookup: больше 3 файлов только если:
  - задача прямо про session analysis;
  - агент повторно столкнулся с ошибкой;
  - пользователь попросил тщательно сравнить накопленные данные.

### 7.4 Dry-Run Routing Matrix
Эти сценарии являются обязательной проверкой даже для markdown-only MVP.

| Сценарий | Входной сигнал | Ожидаемые источники | Не должно загружаться | Pass condition |
| --- | --- | --- | --- | --- |
| Known repo UI task | `cwd` или текст содержит `Unlimotion`, `Avalonia`, `UI`, `скриншоты` | `README.md`, relevant `REPO_RUNBOOKS_FROM_SESSIONS.md` section, `UI_QUALITY_RUBRIC_FROM_SESSIONS.md` | full `USER_PROFILE_FROM_CODEX_SESSIONS.md` | Агент называет UI/runbook источники и проверяет current repo state |
| .NET validation task | `dotnet`, `TUnit`, `tests`, `build`, `CI` | `README.md`, `VALIDATION_COOKBOOK_FROM_SESSIONS.md`, optionally `FLAKY_SLOW_TESTS_REGISTRY.md` | project interest/profile docs | Агент ищет repo-proven commands before running tests |
| Shell/Git/Patch task | `PowerShell`, `apply_patch`, `git`, `PR`, `auth`, `timeout` | `README.md`, `AGENT_SESSION_LESSONS.md`, `DO_NOT_REPEAT.md`, optionally `COMMAND_COOKBOOK_FROM_SESSIONS.md` | UI rubric/profile | Агент применяет prevention checklist без лишних personal facts |
| Unknown repo small task | self-contained edit or one-line command, no known repo/task trigger | none or only current repo instructions | all session-insights | Агент не тратит контекст на session-derived docs |
| Explicit user profile request | пользователь просит "мои предпочтения", "факты обо мне", "как мне лучше отвечать" | `USER_PROFILE_FROM_CODEX_SESSIONS.md`, `USER_WORKFLOW_PREFERENCES.md` | repo runbooks unless needed | Агент отделяет facts/preferences/inferences and marks them as session-derived |
| Agents improvement task | `Agents`, `AGENTS.md`, `routing`, `memory`, `улучшить агента` | `README.md`, `AGENTS_IMPROVEMENT_BACKLOG.md`, `AGENT_SESSION_LESSONS.md`, optionally `DO_NOT_REPEAT.md` | full profile by default | Агент предлагает governance changes and does not overfit to one repo |

### 7.5 Machine-Specific Command Rules
- Cookbook/runbook команды с локальными путями должны быть опубликованы только в форме placeholders.
- Допустимые placeholders:
  - `<USER_HOME>`
  - `<CODEX_HOME>`
  - `<ANDROID_SDK_ROOT>`
  - `<JAVA_HOME>`
  - `<REPO_ROOT>`
- Если команда была взята из конкретной машины и ещё не обобщена, рядом должен быть label `local example, verify before use`.
- Агент не должен копировать absolute user-home paths как универсальную инструкцию.

## 8. Точки интеграции и триггеры
Точки интеграции после EXEC:
- central `AGENTS.md` или routing matrix:
  - добавить pointer на session-insights router.
- новый context owner doc:
  - хранить полную матрицу и правила доверия.
- optional script/skill:
  - использовать при задачах, где агент не знает, какие файлы открыть.

Триггеры:
- пользователь просит "из прошлых сессий", "предпочтения", "память", "частые ошибки", "как улучшить агента";
- текущий `cwd` или repo name совпадает с known repo in `REPO_RUNBOOKS_FROM_SESSIONS.md`;
- задача содержит validation/test/build/CI/debug keywords;
- задача содержит UI/frontend/visual/browser evidence keywords;
- задача содержит PowerShell/git/patch/tooling keywords;
- агент зашёл в repeated failure loop.

## 9. Изменения модели данных / состояния
- Новых persisted data structures в MVP не требуется.
- Возможные будущие изменения:
  - `session-insights/CONTEXT_ROUTING.md` как человекочитаемый index;
  - `session-insights/context-routing.json` как machine-readable mapping;
  - `scripts/select-session-insights.ps1` как command helper.
- Влияние на хранилище: только markdown/script files в репозитории, если пользователь подтвердит соответствующий уровень автоматизации.

## 10. Миграция / Rollout / Rollback
Rollout:
1. Утвердить эту спеку и выбранные ответы из секции 14.
2. Выполнить publish/storage classification для всех untracked session-derived файлов.
3. Санитизировать committable subset:
   - убрать или заменить absolute local paths;
   - убрать приватные source directories;
   - пометить separate snapshots или синхронизировать metadata coverage.
4. Добавить ignore policy для `private-local` файлов, если они остаются в рабочем дереве.
5. Добавить минимальный context owner doc и routing pointer.
6. При выбранной автоматизации добавить helper или skill.
7. Проверить dry-run сценарии.
8. Запустить стандартный instruction quality gate.

Rollback:
- Удалить routing pointer и новый context owner doc.
- Удалить committable sanitized subset, если он был добавлен.
- Оставить private-local файлы вне git или восстановить ignore policy.
- Если добавлен helper/script, удалить его отдельным revert/change.

Обратная совместимость:
- Если session-insights отсутствуют, instruction stack должен работать без них.
- Если session-insights есть, они используются только при триггерах.

## 11. Тестирование и критерии приёмки
Acceptance Criteria:
- AC1: В central stack есть короткий путь, который говорит агенту когда обращаться к session-insights.
- AC2: Есть owner-документ или эквивалентная секция с матрицей `сигнал -> файл -> delivery mode`.
- AC3: Полный `USER_PROFILE_FROM_CODEX_SESSIONS.md` не является always-on контекстом.
- AC4: Repo-specific runbooks грузятся только при совпадении repo/domain или явном запросе.
- AC5: Validation/UI/PowerShell/Git/Patch сценарии ведут к правильным тематическим файлам.
- AC6: Session-derived факты помечены как hints and must be verified when drift-prone.
- AC7: Quality gate каталога проходит.
- AC8: Для каждого session-derived файла есть publish/storage boundary.
- AC9: В committable docs нет абсолютных user-specific paths; они заменены на placeholders или удалены.
- AC10: `USER_PROFILE_FROM_CODEX_SESSIONS.md` и `PROJECT_INTEREST_MAP.md` не попадают в commit без явного решения пользователя.
- AC11: Dry-run routing matrix из секции 7.4 вручную или автоматически проверена и отражена в Post-EXEC review.

Какие тесты добавить/изменить:
- Если изменения только markdown governance:
  - обновить/запустить существующие validation scripts.
  - выполнить manual dry-run routing check по секции 7.4 и зафиксировать результаты в Post-EXEC review.
  - выполнить secret/path heuristic по staged diff:

```powershell
git diff --cached
rg -n "token|secret|apiKey|password|ssh|private|credential|endpoint" <committable-files>
# Also inspect for absolute user-home paths, using a local shell pattern that does not get committed as a raw path example.
```

- Если добавлен helper:
  - добавить tests for:
    - known repo match;
    - unknown repo skip;
    - validation keyword route;
    - UI keyword route;
    - explicit profile request route.

Characterization tests / contract checks:
- Проверить, что existing routing matrix remains valid.
- Проверить, что QUEST approval phrase remains unchanged.

Visual acceptance:
- Не применимо: изменение не UI-facing.

UI video evidence:
- Не применимо: изменение не UI automation.

Базовые замеры performance:
- Не применимо для markdown-only MVP.
- Если helper появится, он должен выполняться за < 1s на локальном repo при обычном количестве файлов.

Команды для проверки:
```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

Stop rules для test/retrieval/tool/validation loops:
- Не пытаться читать все rollout summaries заново в рамках EXEC.
- Не добавлять RAG/MCP/tooling, если выбран markdown-only rollout.
- Не stage/commit `private-local` файлы.
- Не продолжать delivery, если secret/path heuristic нашёл credential-like или user-specific local path в committable docs без явного accepted-risk.
- Если validation script падает из-за unrelated pre-existing issue, зафиксировать evidence и остановиться для решения.

## 12. Риски и edge cases
- Риск: full local profile или raw session artifacts попадут в commit/PR.
  - Смягчение: boundary table, default `private-local`, ignore policy, staged diff review.
- Риск: cookbook/runbook команды содержат absolute local paths and machine-specific assumptions.
  - Смягчение: placeholder pass and `local example, verify before use` label.
- Риск: metadata coverage differs between generated files and creates false precision.
  - Смягчение: mark separate snapshots or synchronize metadata during EXEC.
- Риск: token bloat от слишком широкого lookup.
  - Смягчение: first-hop index + максимум 1-3 файла по умолчанию.
- Риск: stale session-derived advice.
  - Смягчение: mandatory current repo verification before action.
- Риск: пользовательский профиль начинает скрыто влиять на технические решения.
  - Смягчение: explicit-request retrieval only для full profile.
- Риск: central instructions становятся перегруженными.
  - Смягчение: central pointer short, полная матрица в отдельном context doc.
- Риск: helper script дублирует логику и устаревает.
  - Смягчение: helper генерирует рекомендации, а не директивы; source of truth остаётся markdown policy.
- Риск: agent overfits on past frequent errors.
  - Смягчение: frequent errors are prevention checklist, not prediction of current failure.

## 13. План выполнения
Рекомендуемый план EXEC после утверждения:

1. Создать `instructions/contexts/session-insights-context.md` с матрицей доставки, trust levels, token budget и safety rules.
2. Добавить короткий pointer в `instructions/governance/routing-matrix.md` или выбранное пользователем место.
3. При необходимости добавить ссылку из `session-insights/README.md` на новый context owner doc.
4. Если пользователь выберет helper:
   - добавить `scripts/select-session-insights.ps1`;
   - добавить тесты для helper.
5. Прогнать:
   - `pwsh -File scripts/validate-instructions.ps1`
   - `pwsh -File scripts/test-validate-instructions.ps1`
6. Выполнить Post-EXEC review:
   - scope;
   - acceptance criteria;
   - validation evidence;
   - отсутствие unrelated changes.

## 14. Открытые вопросы
Эти вопросы нужны, потому что пользователь хочет быть вовлечённым и контролировать конечное решение.

1. Где лучше держать основной router?
   - Рекомендовано: новый `instructions/contexts/session-insights-context.md` + короткая ссылка в routing matrix.
   - Альтернатива: всё в routing matrix.
   - Компромисс: новый doc меньше раздувает matrix, но требует одного дополнительного перехода.

2. Нужен ли helper script в первом EXEC?
   - Рекомендовано: сначала markdown-only router, затем script после проверки пользы.
   - Альтернатива: сразу добавить `scripts/select-session-insights.ps1`.
   - Компромисс: script повышает воспроизводимость, но добавляет поддержку и tests.

3. Нужно ли делать отдельный Codex skill для session-insights?
   - Рекомендовано: не в MVP; рассмотреть после markdown rollout.
   - Альтернатива: создать skill, если ты хочешь переносить этот механизм между worktrees/repos.
   - Компромисс: skill удобен вне репозитория, но сложнее governance.

4. Как обращаться с пользовательским профилем?
   - Рекомендовано: full profile = `private-local` + explicit-request retrieval only.
   - Альтернатива: короткий sanitized summary как interaction preference в committable docs.
   - Компромисс: profile полезен для стиля работы, но рискует стать скрытой директивой и раскрыть персональные рабочие паттерны.

5. Какой default lookup budget принять?
   - Рекомендовано: README + до 3 релевантных файлов/секций.
   - Альтернатива: только 1 файл для быстрых задач.
   - Компромисс: 3 файла дают лучше recall, 1 файл экономит контекст.

6. Что делать с уже созданными raw session-derived файлами в рабочем дереве?
   - Рекомендовано: в EXEC оставить full/profile/project-map/private-local файлы вне commit через ignore policy, а в repo продвигать только sanitized operational subset.
   - Альтернатива: полностью приватный режим, где все session-insights остаются локальными и в central instructions добавляется только generic router.
   - Компромисс: sanitized subset лучше помогает агентам в этом repo, private-only режим безопаснее для публикации.

## 15. Соответствие профилю
- Профиль: `catalog-governance` + `product-system-design` overlay.
- Выполненные требования профиля:
  - Есть AS-IS и TO-BE.
  - Есть explicit owner docs and integration points.
  - Есть conflict/safety handling.
  - Есть acceptance criteria and validation commands.
  - Есть open questions before approval.
  - Есть rollback path.
  - QUEST phase boundary соблюдён: сейчас меняется только spec.

## 16. Таблица изменений файлов
Планируемые изменения после утверждения:

| Файл | Изменения | Причина |
| --- | --- | --- |
| `specs/2026-06-05-session-insights-agent-context-delivery.md` | Новая рабочая спека | Зафиксировать дизайн и пользовательские решения |
| `.gitignore` или локальный ignore mechanism | Опционально исключить `private-local` artifacts | Не допустить accidental staging full profile/raw insights |
| `instructions/contexts/session-insights-context.md` | Новый owner-документ с router policy | Не раздувать central docs и дать agent-readable правила |
| `instructions/governance/routing-matrix.md` | Короткий pointer / route trigger | Подключить session-insights к central routing |
| `session-insights/README.md` | Опциональная ссылка на context policy; sanitized source metadata | Связать source files с policy без приватных локальных путей |
| `session-insights/*` | Опциональный sanitized subset вместо raw local artifacts | Продвигать только безопасные operational docs |
| `USER_PROFILE_FROM_CODEX_SESSIONS.md` | По умолчанию не коммитить; возможен sanitized summary только по решению пользователя | Содержит personal/session-derived profile |
| `scripts/select-session-insights.ps1` | Не реализуется в MVP | Автоматизацию оставить future option |
| `scripts/validate-instructions.ps1` | Добавить новый context и sanitized session-insights subset в required paths | Зафиксировать их как часть валидного каталога |
| `scripts/test-validate-instructions.ps1` | Копировать `session-insights` в valid-catalog fixture | Сохранить regression coverage validator |
| `CHANGELOG.md` | Добавить версию minor для нового context и sanitized session-insights | Выполнить versioning policy |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Session insights usage | Агент читает только если догадается или пользователь попросит | Агент получает central trigger and retrieval policy |
| Publish/storage boundary | Не определён | Каждый source classified as `private-local` or `sanitized-committable` |
| Machine-specific paths | Могут быть в cookbook examples | Replaced with placeholders before commit |
| Metadata coverage | Profile and insights snapshots differ silently | Difference is documented or synchronized during EXEC |
| Token budget | Нет правил | Always-on pointer минимален, глубокие файлы on-demand |
| User profile | Может быть прочитан вручную | Не автозагружается без explicit/personal-context task |
| Repo runbooks | Лежат отдельным файлом | Загружаются при repo/domain match |
| Validation lessons | Разрозненный файл | Подключаются по test/build/CI trigger |
| Repeated mistakes | Есть в markdown/memory | Используются как prevention checklist |
| Future automation | Не определена | Есть optional helper/skill/RAG ladder |

## 18. Альтернативы и компромиссы
### Вариант A: Always load all session-insights
- Плюсы:
  - Максимальный recall.
  - Агент видит весь accumulated context.
- Минусы:
  - Большой token cost.
  - Высокий риск stale/private context.
  - Трудно отделить релевантные правила от справочных заметок.
- Почему не выбран:
  - Польза не оправдывает постоянную стоимость и риск.

### Вариант B: Minimal central pointer + on-demand files
- Плюсы:
  - Низкий always-on cost.
  - Хороший контроль пользователя.
  - Простая проверка и rollback.
- Минусы:
  - Агенту нужно следовать router discipline.
  - Часть recall теряется, если триггер не сработал.
- Почему выбран:
  - Лучший баланс для текущего репозитория и QUEST governance.

### Вариант C: Memory-only
- Плюсы:
  - Очень компактно.
  - Работает вне репозитория.
- Минусы:
  - Теряются repo runbooks и богатые детали.
  - Memory updates требуют отдельного явного запроса.
- Почему не выбран:
  - Не решает задачу донести разные классы файлов разными способами.

### Вариант D: Skill/helper-first
- Плюсы:
  - Воспроизводимый выбор источников.
  - Можно использовать между задачами.
- Минусы:
  - Больше поддержки, tests и governance.
  - Может стать преждевременной инфраструктурой.
- Почему не выбран как MVP:
  - Сначала нужно проверить, что markdown router работает.

### Вариант E: RAG/MCP/embedding index
- Плюсы:
  - Лучший поиск по большому corpus.
  - Можно ранжировать snippets.
- Минусы:
  - Существенно сложнее.
  - Нужны отдельные privacy, freshness, maintenance rules.
- Почему не выбран:
  - Сейчас достаточно repo-local docs и routing policy.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, границы и outcome contract указаны. |
| B. Качество дизайна | 6-10 | PASS | Есть layered delivery model, responsibility split, trigger matrix и rollback. |
| C. Безопасность изменений | 11-13 | PASS | Учтены privacy, publish/storage boundary, path sanitization, stale facts, central precedence и rollback. |
| D. Проверяемость | 14-16 | PASS | Есть acceptance criteria, validation commands, staged diff heuristic и dry-run routing matrix. |
| E. Готовность к автономной реализации | 17-19 | PARTIAL | Нужны решения пользователя по секции 14 перед EXEC. |
| F. Соответствие профилю | 20 | PASS | Соблюдён QUEST/SPEC boundary и catalog-governance profile. |

Итог: ГОТОВО С ВЫБОРОМ ПОЛЬЗОВАТЕЛЯ

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Определены outcome, non-goals, stop rules. |
| 2. Понимание текущего состояния | 5 | Зафиксированы существующие файлы, corpus и текущий gap. |
| 3. Конкретность целевого дизайна | 5 | Есть layers, source matrix, token budget, trust model and publish/storage boundary. |
| 4. Безопасность (миграция, откат) | 5 | Есть explicit precedence, privacy handling, path sanitization, ignore policy option and rollback. |
| 5. Тестируемость | 5 | Есть acceptance criteria, validation commands, dry-run matrix and secret/path heuristic. |
| 6. Готовность к автономной реализации | 2 | Реализация возможна, но пользовательские решения намеренно оставлены открытыми. |

Итоговый балл: 27 / 30
Зона: под контролем; готово к EXEC после выбора пользователя

### Post-SPEC Review
- Статус: ASK-HUMAN
- Scope reviewed: `specs/2026-06-05-session-insights-agent-context-delivery.md`, central QUEST constraints, session-insights source files, planned changed files
- Decision: нужен выбор пользователя перед `Спеку подтверждаю`
- Review passes:
  - Scope/Evidence pass: PASS; в SPEC phase изменён только spec.
  - Contract pass: PASS; outcome and stop rules explicit.
- Adversarial risk pass: PASS; privacy, accidental commit, local path leakage and token bloat covered.
- Re-review after fixes / Fix and re-review: PASS; review findings from 2026-06-11 were incorporated into the spec.
  - Stop decision: ASK-HUMAN.
- Evidence inspected:
  - central spec template;
  - session-insights index;
  - top failure clusters;
  - repo runbook summary;
  - existing memory summary/registry;
  - review findings from current working tree;
  - `pwsh -File scripts/validate-instructions.ps1`;
  - `pwsh -File scripts/test-validate-instructions.ps1`.
- Depth checklist:
  - Scope drift / unrelated changes: нет изменений вне spec.
  - Acceptance criteria: покрывают delivery strategy, publish/storage boundary, path sanitization, dry-run routing and validation.
  - Validation evidence: validation scripts passed after SPEC fixes; EXEC validation remains required after implementation.
  - Unsupported claims: session-derived facts marked as hints.
  - Regression / edge case: отсутствующий `session-insights/` обработан.
  - Comments/docs/changelog: changelog не требуется до EXEC решения.
  - Hidden contract change: нет; central precedence preserved.
  - Manual-review challenge: пользователь может не согласиться с markdown-only MVP, выбрать helper/skill сразу или выбрать private-only режим для всех session-derived artifacts.
- No-findings justification: найденные review issues перенесены в обязательные acceptance/rollout правила; оставшиеся вопросы являются продуктовым выбором.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| HIGH | privacy / delivery | Не был определён boundary для full profile/raw session artifacts. | Добавить publish/storage boundary, default private-local and ignore policy requirement. | fixed |
| MEDIUM | safety / commands | Cookbook/runbook examples содержали machine-specific local paths. | Добавить placeholder sanitization rules and AC. | fixed |
| MEDIUM | acceptance | Markdown-only MVP не имел dry-run routing checks. | Добавить обязательную dry-run routing matrix and Post-EXEC evidence. | fixed |
| LOW | evidence | Metadata coverage differed between profile and insights. | Добавить separate snapshot/sync requirement. | fixed |
| MEDIUM | design | Нужно выбрать место подключения router и уровень автоматизации. | Ответить на вопросы секции 14. | ask-human |
| LOW | risk | Helper/script может оказаться преждевременным. | Начать с markdown-only или подтвердить script-first. | ask-human |

- Fixed before continuing:
  - Added publish/storage boundary and default `private-local` treatment for full profile/raw local artifacts.
  - Added path placeholder sanitization and staged diff heuristic.
  - Added dry-run routing matrix for markdown-only MVP.
  - Added separate snapshot/sync rule for coverage metadata.
- Checks rerun:
  - `pwsh -File scripts/validate-instructions.ps1` -> PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1` -> PASS.
- Needs human: ответы на секцию 14, особенно пункт 6 про private-local vs sanitized subset.
- Residual risks / follow-ups: после EXEC проверить dry-run scenarios and staged diff path/secret heuristic.

### Post-EXEC Review
- Статус: PASS
- Scope reviewed: approved spec, `git status --short`, `git diff --stat`, routing/context docs, sanitized session-insights subset, validator scripts, changelog, dry-run routing matrix, path/private-local heuristic
- Decision: можно завершать
- Review passes:
  - Scope/Evidence pass: PASS; реализован markdown-only MVP без helper/skill/RAG.
  - Contract pass: PASS; добавлен `session-insights-context`, routing pointer, required paths, changelog and sanitized source index.
  - Adversarial risk pass: PASS; private-local artifacts excluded by `.gitignore`, committable files have no absolute local user/session paths.
  - Re-review after fixes / Fix and re-review: PASS; validator fixture failure fixed by adding `session-insights` to test seed paths and required sanitized docs.
  - Stop decision: PASS.
- Evidence inspected:
  - `instructions/contexts/session-insights-context.md`
  - `instructions/governance/routing-matrix.md`
  - `session-insights/README.md`
  - sanitized command examples in `COMMAND_COOKBOOK_FROM_SESSIONS.md`, `VALIDATION_COOKBOOK_FROM_SESSIONS.md`, `REPO_RUNBOOKS_FROM_SESSIONS.md`
  - `.gitignore`
  - `scripts/validate-instructions.ps1`
  - `scripts/test-validate-instructions.ps1`
  - `CHANGELOG.md`
  - `git status --short --ignored`
  - dry-run routing matrix check
  - path/private-local heuristic
- Depth checklist:
  - Scope drift / unrelated changes: PASS; changes match approved defaults, no helper/skill added.
  - Acceptance criteria: PASS; AC1-AC11 covered.
  - Validation evidence: PASS; validator and validator regression suite passed.
  - Unsupported claims: PASS; session-derived facts remain hints and current-state verification is required.
  - Regression / edge case: PASS; validator fixture updated for new `session-insights` required paths.
  - Comments/docs/changelog: PASS; changelog version `2.8.0` added.
  - Hidden contract change: PASS; routing adds a context trigger but does not override central precedence.
  - Manual-review challenge: review should focus on whether `USER_WORKFLOW_PREFERENCES.md` is acceptable as sanitized committable summary; no secrets or local paths found.
- No-findings justification: реализации соответствует утверждённой spec; найденная test-fixture регрессия исправлена и проверки перезапущены.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | tests | `test-validate-instructions.ps1` initially failed because valid-catalog fixture did not copy `session-insights`. | Add `session-insights` to seed paths and sanitized docs to validator required paths. | fixed |
| LOW | privacy | Credential-like scan reports guardrail words such as token/secret/private. | Manual review confirms these are policy text or search patterns, not secret values. | accepted-risk |

- Fixed before final report:
  - Added `session-insights` to validator test fixture.
  - Added `session-insights-context` and sanitized session-insights required paths to validator.
  - Re-ran validator and validator regression suite successfully.
- Checks rerun:
  - `pwsh -File scripts/validate-instructions.ps1` -> PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1` -> PASS.
- Validation evidence:
  - Dry-run matrix check -> PASS.
  - Absolute local path scan over changed committable files -> PASS.
  - Private-local files excluded from committable candidates -> PASS.
- Unrelated changes:
  - `USER_PROFILE_FROM_CODEX_SESSIONS.md`, `session-insights/PROJECT_INTEREST_MAP.md`, and `session-insights/FLAKY_SLOW_TESTS_REGISTRY.md` remain local ignored artifacts.
- Needs human: нет.
- Residual risks / follow-ups:
  - If the user later wants private-local artifacts committed, they need a separate sanitization/review pass.
  - Helper/script and Codex skill remain future options, not implemented in this EXEC.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | context-routing design | 0.86 | Выбор пользователя по месту подключения и автоматизации | Получить ответы на секцию 14 или подтверждение defaults | Да | Нет | Пользователь явно хочет быть вовлечённым и контролировать решение | `specs/2026-06-05-session-insights-agent-context-delivery.md` |
| SPEC | validation | 0.92 | Нет | Передать пользователю spec и варианты выбора | Да | Нет | Каталог прошёл стандартный quality gate после добавления спеки | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1` |
| SPEC | review-fix | 0.91 | Решение пользователя по publish mode | Передать исправленную spec на подтверждение | Да | Нет | Review findings закрыты в spec без перехода в EXEC | `specs/2026-06-05-session-insights-agent-context-delivery.md` |
| EXEC | markdown-only session insights routing | 0.94 | Нет | Запустить final status/diff checks и завершить | Нет | Да: пользователь подтвердил спеки фразой `Спеку подтверждаю` | Реализован утверждённый default: context owner doc, routing pointer, sanitized subset, private-local ignore boundary | `.gitignore`, `instructions/contexts/session-insights-context.md`, `instructions/governance/routing-matrix.md`, `session-insights/*`, `scripts/*`, `CHANGELOG.md` |
| EXEC | validation and review | 0.98 | Нет | Завершить задачу | Нет | Нет | Validator, regression suite, dry-run routing, path/private-local heuristic and post-EXEC review passed | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `specs/2026-06-05-session-insights-agent-context-delivery.md` |
