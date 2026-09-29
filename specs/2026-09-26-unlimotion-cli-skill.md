# Скилл для безопасной работы с Unlimotion CLI

Expanded SPEC: форма выбрана по `quest-governance`, потому что будущий скилл управляет stateful workflow и может инициировать изменения живого task-space. Severity/disposition и review определяет `review-loops`.

## 0. Метаданные

- Тип (профиль): `delivery-task`; change profile — `product-system-design`; task-specific skill — `skill-creator`; context — `session-insights-context`.
- Владелец: пользователь; реализация — Codex.
- Масштаб: medium, operationally high-risk из-за возможных мутаций пользовательского графа задач.
- Целевое семейство / behavior baseline: `GPT-6 Astra` как catalog baseline; сам скилл не закрепляет конкретную модель.
- Поверхность: Work / Codex, персональный discoverable skill.
- Effective runtime: текущая поверхность Codex; фактический model ID, reasoning level и client version не раскрыты runtime и не будут выдумываться.
- Eval baseline / evidence: до/после behavioral smoke в двух свежих изолированных evaluator contexts с одинаковыми model/surface/reasoning/sandbox настройками и без доступа к живому task-space; одинаковые frozen prompts для чтения, узкой мутации, lease lifecycle, lock/outcomeUnknown и validation failure. Baseline evaluator не видит target skill, candidate evaluator получает только realistic request и путь к skill; parent отдельно оценивает raw outputs по decision rubric. Результаты фиксируются в этой SPEC.
- Целевой релиз / ветка: публикация и Git delivery не входят в scope; рабочая SPEC находится в `main` репозитория `C:\Projects\My\Agents`.
- Ограничения: до точной фразы `Спеку подтверждаю` изменяется только эта SPEC; task-space Unlimotion не мутируется при разработке и проверке скилла.
- Связанные источники: установленный `unlimotion.cli 1.31.1`; `unlimotion-cli --help`; release-matched `v1.31.1:src/Unlimotion.Cli/README.md` и `TaskApplicationJson.cs`; более новый checkout README только как drift evidence; memory runbooks про read-back, lock, default storage и scope-preserving updates; `skill-creator/references/openai_yaml.md`.

## 1. Overview / Цель

Создать персональный discoverable skill `$unlimotion-cli`, который помогает Codex безопасно читать и изменять задачи через установленный Unlimotion CLI, сохраняя пользовательский scope, контракт файлового task-space, lease-семантику выполнения и проверяемый read-back.

Outcome contract:

- Исходное поручение / симптом и точка применения результата: «Создай скилл для работы с Unlimotion CLI»; результат должен применяться автоматически к операционным запросам о задачах Unlimotion.
- Success means: новый скилл корректно маршрутизирует read-only и mutating сценарии, использует текущий CLI как source of truth, не смешивает работу с задачами с разработкой/релизом CLI и не допускает опасные автоматические повторы.
- Итоговый артефакт / output: `C:\Users\Kibnet\.codex\skills\unlimotion-cli\SKILL.md`, `agents/openai.yaml` и focused `references/apply-v1.31.1.md`; без лишних scaffold-файлов.
- Stop rules: остановиться после green static validation, before/after behavioral smoke, active-path read-back и post-EXEC review; не запускать живые mutating команды и не менять task-space в рамках проверки скилла.

## 2. Текущее состояние (AS-IS)

- Установлен глобальный `unlimotion.cli 1.31.1`; executable — `C:\Users\Kibnet\.dotnet\tools\unlimotion-cli.exe`.
- `unlimotion-cli --version` не поддерживается и возвращает `Unknown command`; версию нужно получать через `dotnet tool list --global`.
- CLI поддерживает read-only команды `status`, `unlocked`, `candidates`, `task`, `validate` и mutating команды `claim`, `execution ...`, `release`, `create`, `apply`, `set-status`, `complete`, `set-criterion`, `satisfy-criterion`.
- Установленный 1.31.1 и его release-matched README подтверждают только приоритет явного `--tasks` и затем активное локальное пространство desktop из `Settings.json`. `UNLIMOTION_TASKS` добавлен в checkout после tag `v1.31.1` (`v1.31.1-10-gda9af236`) и не должен считаться поддержанным установленным binary без version/capability evidence.
- `apply --request <path|->` и `--dry-run` видны в installed help, но JSON envelope не описан help-ом полностью. Для безопасного использования нужен versioned contract, извлечённый из release-matched source и gated точным installed package version.
- Текущий CLI уже содержит атомарную запись, каталоговый lock, recovery journal, lease-bound execution и `authoritativeTask` для части ошибок.
- В активном наборе skills нет общего операционного скилла для Unlimotion CLI. Memory-derived skills `unlimotion-tunit-ci-validation` и `unlimotion-release-validation` относятся к разработке/CI/релизу и не покрывают повседневную работу с задачами.
- Из прошлых рабочих сессий подтверждены полезные инварианты: после мутации нужен read-back; `.unlimotion.lock` нельзя удалять или обходить; `outcomeUnknown` нельзя автоматически повторять; согласованная правка не разрешает менять соседние поля; completion нельзя выводить только из PR, checkbox, возраста или родительского статуса.

## 3. Проблема

Без специализированного skill Codex должен каждый раз заново восстанавливать неочевидные operational safety rules CLI. Это повышает риск выбрать неверный task-space, расширить мутацию, повторить операцию с неизвестным исходом, проигнорировать active lease или назвать изменение успешным без авторитетного read-back.

## 4. Цели дизайна

- Отделить read-only inspection от state-changing commands.
- Сделать безопасный путь коротким: inspect → exact mutation → read-back.
- Сохранить установленный CLI, его help и release-matched contract источником истины, не подменяя installed behavior README-ом более новой ветки.
- Явно маршрутизировать обычные task operations и lease-bound agent execution.
- Обеспечить проверяемое поведение без доступа теста к живому task-space.
- Не дублировать release/CI/development skills.

## 5. Non-Goals (чего НЕ делаем)

- Не разрабатываем и не изменяем код `Unlimotion.Cli` или desktop-приложения.
- Не создаём release, package, PR, commit, push или публикацию skill.
- Не меняем живые задачи, статусы, критерии, связи, даты или execution state во время реализации и тестирования skill.
- Не создаём helper scripts, assets, README или локальную копию полного CLI manual; допускается один focused versioned reference для недокументированного JSON envelope `apply`.
- Не включаем релизную и TUnit/CI валидацию Unlimotion: для них существуют отдельные специализированные workflows.
- Не разрешаем raw JSON edits как штатный fallback при ошибке CLI.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности

- `C:\Users\Kibnet\.codex\skills\unlimotion-cli\SKILL.md` — routing, operational workflow, authorization boundaries, recovery и evidence rules.
- `C:\Users\Kibnet\.codex\skills\unlimotion-cli\references\apply-v1.31.1.md` — минимальный versioned schema/example для `apply`, включая precondition ETag, dry-run и compatibility stop rule.
- `C:\Users\Kibnet\.codex\skills\unlimotion-cli\agents\openai.yaml` — UI metadata и default prompt; все strings quoted, `short_description` длиной 25–64 символа, `default_prompt` одной фразой и с явным `$unlimotion-cli`; implicit invocation остаётся включённым по умолчанию.
- Установленный `unlimotion-cli` и его `--help` — текущий executable contract.
- Release-matched tag/source, если checkout доступен, — расширенный documentation source; skill не доверяет более новой working-tree документации для установленной версии и не зависит от фиксированного абсолютного checkout path.

### 6.2 Детальный дизайн

SKILL.md будет компактным и outcome-first:

1. Discriminating description: применять для operational task work через Unlimotion CLI; не применять для разработки, тестирования CI или релиза CLI.
2. Preflight: найти executable, определить установленную версию через `dotnet tool list --global`, проверить текущий `--help`, выбрать явный `--tasks` пользователя либо documented desktop default. Environment fallback использовать только если он подтверждён контрактом именно установленной версии; наличие переменной само по себе не является evidence.
3. Read-only flow: по умолчанию использовать `--format json`; начинать с ограниченного `candidates`/`task --include ...`, не claim-ить задачу для просмотра.
4. Authorization boundary: mutating command допускается только в точном scope запроса; предложение, найденный PR, checkbox или inferred completion не расширяют полномочия.
5. Narrow mutation flow: получить before snapshot; выбрать документированную штатную узкую команду. `apply --dry-run` использовать только когда installed version совпадает с versioned reference либо matching schema подтверждена из authoritative source; иначе не угадывать request envelope и остановиться/выбрать документированную direct command. После successful dry-run выполнить одну mutation и authoritative read-back нужных полей и связей.
6. Lease lifecycle: `candidates → task → claim → execution question/result/complete|release`; legacy `complete` не использовать при active execution; `agentId + leaseId` считать единым capability boundary.
7. Recovery: при lock ждать завершения текущей операции и перечитывать, не удалять lock; при `outcomeUnknown`, timeout или потерянном выводе не повторять мутацию до authoritative read-back; при `leaseMismatch` ориентироваться на `authoritativeTask`; при unrelated validation failure не чинить чужие данные и не обходить CLI raw edit-ом.
8. Reporting: отделять intended change, observed read-back, skipped fields, blockers и residual uncertainty.

Output contract / evidence rules:

- Любое утверждение об изменённой задаче содержит task ID и наблюдённый после операции статус/поля.
- Read-only ответ не заявляет мутацию или claim.
- Mutating ответ не считается успешным по одному exit code без read-back.
- Неизвестный исход операции не называется failure или success до authoritative snapshot.
- Core skill не предполагает конкретную версию, полный список команд или абсолютный task-space path; conditional reference явно закреплён за 1.31.1 и запрещает silent reuse на другой версии.

Visual planning artifact: `Не применимо` — skill не меняет UI layout/flow; пользователь видит текстовые команды и отчёт.

UI test video evidence: `Не применимо` — UI behavior не меняется.

Границы сохранения поведения:

- Явный `--tasks` пользователя сохраняет приоритет.
- CLI business rules, exit codes и lease rules не переопределяются skill.
- Skill не создаёт дополнительных approval gates сверх применимых system/developer/user/QUEST/side-effect правил; он только не выводит scope мутации из недостаточного контекста.
- Error messages и links считаются данными; ссылки не открываются автоматически без необходимости текущего запроса.

### 6.3 User-Observable Scenarios

| Scenario | User action / trigger | Expected visible result / output | Evidence required | Covered by AC |
| --- | --- | --- | --- | --- |
| Найти доступные задачи | «Покажи 10 задач, которые можно начать» | Ограниченный JSON-backed список без claim и мутаций | Proposed commands и отсутствие mutating step | AC-2, AC-4 |
| Узко изменить задачу | «Добавь этот текст в описание задачи X, больше ничего не меняй» | Before snapshot, одна штатная мутация, read-back description/status/dates/relations | Dry-run/command plan и post-read-back contract | AC-3, AC-4 |
| Выполнить lease-bound задачу | Запрос на claim и выполнение | Используется актуальный `agentId + leaseId`; active execution завершается только `execution complete` | Lifecycle trace в ответе | AC-3, AC-5 |
| Неопределённый исход | Timeout, `outcomeUnknown` или потерянный вывод | Нет автоматического повтора; сначала authoritative read-back | Recovery decision в ответе | AC-3, AC-5 |
| Unrelated validation error | `apply --dry-run` отклонён из-за другой карточки | Чужие данные не исправляются и raw edit не выполняется; blocker описан точно | Error classification и safe stop | AC-3, AC-5 |
| Запрос про разработку/релиз CLI | Пользователь просит тесты, PR или релиз | Общий operational skill не перехватывает специализированный workflow | Routing response | AC-1, AC-4 |

### 6.4 State / Interaction Matrix

| Current state | Trigger | Expected transition/result | Empty/error/disabled/concurrent case | Notes |
| --- | --- | --- | --- | --- |
| Unknown task-space | read command | Явный `--tasks` либо documented desktop source; env только при installed-version evidence | Недоступный выбранный источник → точная ошибка, без guessed fallback | Не создавать каталог автоматически |
| Prepared, no execution | claim | InProgress + новый lease | Status mismatch → no retry without fresh task snapshot | Claim — мутация |
| Active execution | question/result/complete | Lease-bound state transition | `leaseMismatch` → использовать `authoritativeTask`, не раскрывать/угадывать чужой lease | Legacy complete запрещён |
| AwaitingInput | answer | Active после ответа на все вопросы | Неверный question/lease → authoritative read-back | Scope ответа не расширять |
| Mutation in progress | lock/timeout | Wait/read-back | Lock не удалять, команду не дублировать | Одно mutating invocation |
| Unknown operation outcome | retry temptation | Read authoritative state first | Если состояние всё ещё неясно — stop/report | No blind retry |
| Validation failure | apply/dry-run | `didMutate=false`, report blocker | Не repair unrelated tasks, не bypass raw JSON | Узкий согласованный scope |

### 6.5 Decision Ledger

| Decision | Owner | Default / chosen option | Confidence | Risk if assumed | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |
| Scope skill | agent | Operational task work, не development/release | 0.90 | Неверная маршрутизация широкого запроса | Нет — явно видимо в spec |
| Install location | agent | `%USERPROFILE%\.codex\skills\unlimotion-cli` | 0.98 | Skill не будет discoverable | Нет — default `skill-creator` |
| Invocation policy | agent | Implicit invocation enabled | 0.90 | Skill активируется слишком широко | Нет — description задаёт exclusion |
| Resource structure | agent | `SKILL.md` + `agents/openai.yaml` + один versioned apply reference | 0.95 | Без reference apply небезопасен; полный manual быстро drift-ит | Нет |
| Live mutation in validation | agent | Запрещена; только hypothetical/offline behavior smoke | 0.99 | Повреждение task-space | Нет |
| Raw task-file fallback | agent | Не включать в skill | 0.98 | Обход recovery/business rules | Нет |
| Reviewer evidence | governance | Проверить effective sandbox; если role остаётся `danger-full-access`, считать проход writable adversarial fallback, не read-only review, и зафиксировать residual risk | 0.99 | Ложное заявление независимой read-only проверки | Нет |

### 6.6 Runtime / Config / Data Contract Matrix

| Contract area | Current source of truth | Expected change | Compatibility / migration | Verification |
| --- | --- | --- | --- | --- |
| Skill discovery | `%USERPROFILE%\.codex\skills` + skill metadata | Добавляется `unlimotion-cli` | Новый isolated folder; существующие skills не меняются | `quick_validate.py`, inventory, read-back |
| Invocation | `name`/`description`, `agents/openai.yaml` | Implicit discovery с узкой description | Нет изменения global config | Static inspection + routing smoke |
| CLI executable/version | `Get-Command`, `dotnet tool list --global`, `--help` | Skill требует live preflight, не hardcode | Совместим с будущими версиями при сохранении help/JSON contract | Behavioral scenarios |
| Task-space source | installed help + release-matched docs | Для 1.31.1: `--tasks` > desktop; дополнительные sources только capability-gated | Нет миграции данных/config | Version-drift scenario review |
| Apply request | release-matched source for installed package | Versioned minimal reference + mismatch stop rule | Не переносить schema молча на другую версию | Dry-run positive/negative prompt cases; no live apply |
| Task data | CLI JSON output и authoritative read-back | Skill не создаёт свою модель данных | Нет persisted changes при install | No live mutation + post-install smoke |
| Execution lease | CLI `AgentExecution` | Skill маршрутизирует lease-bound commands | Не меняет protocol | Lifecycle scenario |

## 7. Бизнес-правила / Алгоритмы

- Read-only intent не разрешает `claim`, `create`, `apply`, status/criterion changes, `complete`, `release` или execution mutations.
- Явная просьба изменить задачу разрешает только описанные поля/статус/задачу; соседние данные сохраняются.
- Before snapshot обязателен перед mutating operation, кроме `create`, где ID ещё не существует; для create обязателен read-back созданной задачи.
- После mutation read-back покрывает изменённые поля и поля, которые пользователь потребовал сохранить; для широкого task update по умолчанию используются `details,relations,criteria,history,execution`. Поле, отсутствующее в JSON CLI (например, `Repeater` в 1.31.1), нельзя объявлять проверенным через этот read-back. При явном требовании доказать его сохранность и отсутствии разрешённого источника проверки остановиться до записи.
- `outcomeUnknown`, timeout после отправки mutation и потерянный output — состояния неопределённости, не повод повторять команду.
- Active execution завершается только с правильным lease через `execution complete`; отсутствие lease нельзя обходить legacy `complete`.
- Неисправность одной unrelated task не даёт полномочия чинить её ради прохождения текущей mutation.
- Completion требует пользовательского запроса и соблюдения CLI criteria/business rules; внешние или физические результаты не выводятся из косвенных артефактов.

## 8. Точки интеграции и триггеры

- Автоматическая активация по запросам: посмотреть/найти/создать/изменить/начать/завершить задачу через Unlimotion CLI, проверить task-space, availability, criteria или agent execution.
- Исключения routing: разработка исходников CLI, TUnit/CI validation, NuGet/package/release, desktop UI behavior.
- Runtime integrations: PowerShell shell; global .NET tool; optional local checkout documentation; local file task-space только через CLI.

## 9. Изменения модели данных / состояния

- Новых task fields, settings или persisted data нет.
- Создаётся только skill folder и metadata.
- Во время validation task-space остаётся неизменным.

## 10. Миграция / Rollout / Rollback

- Rollout: author candidate вне active discovery path в уникальном temp/candidate directory; выполнить static validation и candidate behavioral smoke; сохранить SHA-256 каждого файла; повторно проверить отсутствие target folder/drift; применить один точный tested change set в active path; повторить `quick_validate.py`, hashes и read-back уже на active path.
- Активация: каталог является discoverable после создания; если текущая session не обновляет skill catalog динамически, факт доступности в следующей session не выдумывать, а сообщить границу.
- Rollback: удалить только новый проверенный folder `C:\Users\Kibnet\.codex\skills\unlimotion-cli` либо переместить его вне discovery path; существующие skills/config/task-space не затрагиваются.
- Drift: перед write повторно проверить, что folder ещё не существует; если существует, остановиться и изучить ownership вместо reinitialize/overwrite.

## 11. Тестирование и критерии приёмки

Acceptance Criteria:

- AC-1: skill проходит `quick_validate.py`; metadata согласованы; strings в `openai.yaml` quoted, `short_description` имеет 25–64 символа, `default_prompt` явно содержит `$unlimotion-cli`; scaffold placeholders отсутствуют.
- AC-2: skill явно различает operational task work и development/CI/release workflows, а description не является catchall.
- AC-3: skill содержит non-obvious safety invariants: exact scope, before/read-back, lock/outcomeUnknown no-retry, lease boundary, no unrelated repair/raw-edit bypass.
- AC-4: одинаковые frozen representative prompts в свежих baseline/candidate contexts с одинаковой effective конфигурацией показывают улучшение routing и recovery без добавления live side effects; outputs оценивает parent по заранее заданной decision rubric.
- AC-5: adversarial scenarios для active lease, unavailable task-space, validation failure и unknown outcome имеют безопасный stop/recovery.
- AC-6: install evidence разделяет сохранение файлов, active path и реальную доступность в текущей/следующей session.
- AC-7: `git status --short` в `C:\Projects\My\Agents` показывает только текущую SPEC среди изменений этой задачи; live task-space не изменён.

Обязательный набор проверок и основание:

- Static skill validation — обязательна по `skill-creator`.
- Semantic/manual scan description, routing, authorization/recovery — обязательна из-за instruction behavior.
- Before/after behavioral smoke в двух свежих isolated contexts с одинаковой effective configuration — обязателен по `review-loops` для instruction change.
- Reviewer role вызывается post-EXEC; PASS как read-only допустим только при подтверждённом effective `read-only`. При повторном `danger-full-access` это writable adversarial fallback с явной причиной/residual risk, как разрешает `review-loops`.
- Catalog validation scripts репозитория Agents — обязательны по его `AGENTS.md`, хотя target skill находится вне repo.
- Live CLI mutation smoke не выполняется: он создаёт внешний side effect и не нужен для проверки instruction artifact. Read-only `--help`, tool inventory и при необходимости `status` допустимы.

Команды проверки после approval:

```powershell
$candidateSkill = '<unique-candidate-path>\unlimotion-cli'
$activeSkill = 'C:\Users\Kibnet\.codex\skills\unlimotion-cli'
$validator = 'C:\Users\Kibnet\.codex\skills\.system\skill-creator\scripts\quick_validate.py'

python $validator $candidateSkill
$candidateHashes = Get-ChildItem -LiteralPath $candidateSkill -File -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        [pscustomobject]@{
            RelativePath = [System.IO.Path]::GetRelativePath($candidateSkill, $_.FullName)
            Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }

# После проверки target drift и активации exact candidate files:
python $validator $activeSkill
$activeHashes = Get-ChildItem -LiteralPath $activeSkill -File -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        [pscustomobject]@{
            RelativePath = [System.IO.Path]::GetRelativePath($activeSkill, $_.FullName)
            Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
$hashDiff = Compare-Object $candidateHashes $activeHashes -Property RelativePath,Hash
if ($hashDiff) { throw 'Active skill differs from validated candidate.' }

pwsh -File scripts\validate-instructions.ps1
pwsh -File scripts\test-validate-instructions.ps1
git status --short
dotnet tool list --global
unlimotion-cli --help
```

Behavioral smoke не выполняет команды над живым task-space. Два свежих evaluator contexts с одинаковыми effective настройками получают одинаковые frozen prompts: baseline не получает target skill, candidate получает только realistic requests и путь к candidate skill. Evaluators не получают intended answer, findings или grading rubric. Parent вне их контекста сравнивает raw outputs по frozen rubric: routing, task-space source, exact mutation scope, `apply` compatibility gate, lease boundary, no-retry recovery, read-back evidence и stop decision.

### Фактический behavioral smoke (EXEC)

Контексты `/root/baseline_cli_scenarios` и `/root/candidate_cli_scenarios` были свежими (`fork_turns=none`), на той же Codex surface, без model/reasoning overrides; effective sandbox не задавался отдельно. Точный model ID и reasoning level дочерних sessions runtime не сообщил. Обоим даны одинаковые пять scenario texts; candidate дополнительно получил путь к skill, baseline — нет. Evaluators не исполняли CLI и не читали живые задачи. Parent сравнил решения по rubric из абзаца выше.

| Scenario | Baseline без skill | Candidate со skill | Вывод |
| --- | --- | --- | --- |
| 10 стартуемых задач | Выбрал read-only список до 10 и desktop source, но без точной команды | Назвал `candidates --limit 10 --format json`, desktop source и отсутствие `claim` | Более исполнимый read-only план; безопасная граница сохранена |
| Изменить описание, dry-run отклонён | Правильно остановил запись и не трогал чужую задачу | Добавил полный текст `descriptionUserText`, точный preview/read-back и тот же безопасный stop | Улучшен contract detail, нет лишней мутации |
| `leaseMismatch` | Остановил старый lease и перечитал задачу | Различил `execution result` и `execution complete`, потребовал актуальную пару и read-back | Более точный lifecycle |
| Потерян ответ `create` | Не повторял вслепую, но предложил не подтверждённый idempotent retry | Указал lock/unknown-outcome stop; после review уточнено, что в 1.31.1 нет общего поиска по title и без ID исход может остаться неизвестным | Убран риск двойного создания |
| Checkout README против installed help | Верно выбрал installed 1.31.1 contract | Явно сохранил `--tasks`/desktop priority и проверку ID перед мутацией | Нет регрессии; ложный env fallback исключён |

Узкие дополнительные проверки в fresh contexts: `/root/candidate_create_timeout` после первой редакции восстановил unknown outcome, но его raw-file поиск был отклонён review; `/root/skill_recovery_recheck` после исправления подтвердил CLI-only stop без повторного `create`; `/root/active_apply_mismatch` подтвердил version gate 1.32.0 и stop при `validationFailed`; `/root/active_skill_smoke` прочитал именно active path и подтвердил routing/apply/lock; `/root/skill_repeater_final_smoke` подтвердил остановку до записи при обязательном доказательстве сохранности `Repeater`, которого CLI не показывает. Это instruction smoke, не реальная проверка mutation.

### Acceptance-to-Test Matrix

| Acceptance criterion | Automated test | Manual / visual / log check | Evidence artifact | If not tested, why |
| --- | --- | --- | --- | --- |
| AC-1 | `quick_validate.py` candidate и active: PASS с `PYTHONUTF8=1` | `openai.yaml`: quoted strings, short description 48 символов, `$unlimotion-cli` prompt; 3 files без TODO | Active hash/read-back ниже | — |
| AC-2 | Five-scenario routing smoke | Description исключает development/CI/release; `candidates` остаётся read-only | Behavioral table выше | — |
| AC-3 | Scenario 2–4, active smoke и source scan | Exact scope, read-back, lock/outcomeUnknown, lease, no unrelated repair/raw edit присутствуют | Skill diff + reviewer findings/disposition ниже | — |
| AC-4 | Два fresh contexts без overrides на одной surface | Parent сравнил decisions по frozen rubric | Behavioral table выше | Точный model ID/reasoning child runtime не сообщил; наследование использовано без overrides |
| AC-5 | `active_apply_mismatch`, `skill_recovery_recheck`, `skill_repeater_final_smoke`, пять сценариев | Version mismatch, dry-run rejection, lease mismatch, unknown outcome и непроверяемое поле дают safe stop | Scenario results выше; reviewer re-review PASS | — |
| AC-6 | Active path `quick_validate.py` и SHA-256 equality candidate/active | Новый child reviewer увидел skill в Available skills; текущая parent session hot-reload не доказана | Active hash/read-back ниже | Parent session началась до установки, её catalog не обновлялся как evidence |
| AC-7 | `git status --short`: только текущая SPEC; CLI использовался только для help/tool inventory | Живые mutating команды не запускались | Командный журнал этого turn и status ниже | Не утверждается отсутствие чужих параллельных изменений task-space |

Active-path evidence: `C:\Users\Kibnet\.codex\skills\unlimotion-cli` содержит ровно `SKILL.md`, `agents/openai.yaml`, `references/apply-v1.31.1.md`. После review-исправлений `quick_validate.py` дал `Skill is valid!` для candidate и active. Относительные пути и SHA-256 всех трёх файлов совпали (`Compare-Object` пуст): `SKILL.md` `351D40CE...ED1C547FC1F3AE9`, `openai.yaml` `F733D9D8...1A84B9FF1A`, `apply-v1.31.1.md` `B8739934...1E8FF8E`. Полные хеши сохранены в выводе проверки этого turn; reviewer независимо подтвердил `MATCH 3 files`. Каталожные `validate-instructions.ps1` и `test-validate-instructions.ps1` после активации вернули PASS; финальный запуск после записи этого audit также дал PASS.

Stop rules для validation:

- Не повторять successful validation без нового change/failure.
- После failed validator исправить только reported target issue и повторить affected check.
- Если behavioral smoke обнаружил HIGH/BLOCKER, исправить skill и повторить affected scenarios; не расширять scope.
- Если live mutation стала необходима для доказательства claim, остановиться и запросить отдельное разрешение вместо скрытого side effect.

## 12. Риски и edge cases

- Description может быть слишком широкой и перехватывать development/release запросы — mitigated exclusions + routing smoke.
- Hardcoded command list может устареть — skill использует live `--help` и хранит только стабильные invariants.
- Слишком строгий approval language может дублировать/ужесточать platform policies — skill формулирует exact scope и не создаёт новый универсальный gate.
- Skill может предложить legacy `complete` при active execution — отдельный lease scenario и explicit invariant.
- Dry-run может не пройти из-за unrelated invalid task — safe stop, без ремонта/сырого bypass.
- Current session может не увидеть новый skill metadata — active-path evidence отделяется от hot-reload claim.
- Automatic invocation может быть слишком частой — discriminating description и explicit exclusions; policy остаётся стандартной.

### Expected User Review Objections

| Likely objection | Why likely | Mitigation in spec/code plan | Status |
| --- | --- | --- | --- |
| «Скилл должен реально помогать работать, а не пересказывать help» | Пользователь ценит полезный следующий шаг и короткий безопасный путь | В skill остаются только decision-changing invariants и operational flow | mitigated |
| «Не надо спрашивать разрешение на каждую очевидную правку» | Ранее пользователь предпочитал применять конкретно согласованный контракт сразу | Exact request выполняется без повторного вопроса; новый вопрос только при material ambiguity | mitigated |
| «Не меняй соседние поля и не чини весь граф ради одной задачи» | Task-space содержит независимые live данные | Before/read-back, narrow mutation и unrelated-validation stop | mitigated |
| «Не смешивай работу с задачами и разработку CLI» | Уже есть отдельные release/CI workflows | Explicit Non-Goals и routing exclusion | mitigated |

### Rework Prevention Checklist

- [x] Spec называет, что пользователь будет вызывать и видеть.
- [x] Каждый user-visible scenario имеет evidence.
- [x] Зафиксированы решения, принятые агентом.
- [x] Вероятные objections предсказаны и закрыты.
- [x] Релевантные роли включены в review plan.
- [x] Acceptance criteria являются verifiers, а не подготовительными шагами.
- [x] EXEC имеет путь доказать сценарии без live task mutations.

## 13. План выполнения

1. Зафиксировать frozen prompt set/rubric и получить baseline responses в свежем evaluator context без target skill.
2. Проверить отсутствие active target folder; создать candidate вне discovery path и инициализировать `unlimotion-cli` через `skill-creator` с resource directory `references`.
3. Заменить scaffold на compact `SKILL.md`, focused `references/apply-v1.31.1.md` и корректный `agents/openai.yaml`.
4. Запустить candidate static validation, semantic contract scan и SHA-256 фиксацию.
5. В новом evaluator context с той же effective configuration выполнить candidate smoke и сравнить raw outputs с baseline по frozen rubric.
6. Проверить target drift, применить exact hashed change set в active discovery path, затем повторить `quick_validate.py`, hash/read-back и critical routing checks.
7. Выполнить reviewer pass; считать его read-only только при подтверждённом effective sandbox, иначе зафиксировать writable adversarial fallback. Исправить in-scope findings и повторить affected checks.
8. Выполнить mandatory Agents catalog validators и post-EXEC completion gate.

## 14. Открытые вопросы

Нет блокирующих вопросов. Имя, scope, install path и invocation policy выбраны по текущему запросу и `skill-creator`; пользователь может изменить их до approval.

## 15. Соответствие профилю

- Профиль: `product-system-design`.
- Выполненные требования профиля: цели/non-goals выделены; target skill boundaries и public invocation contract описаны; compatibility/config/security aspects зафиксированы; alternatives и rollback определены.
- Task-specific skill `skill-creator`: discoverable path, concise description, минимальный justified reference, `openai.yaml` constraints из `references/openai_yaml.md`, candidate validation и unbiased forward-testing включены.

## 16. Таблица изменений файлов

| Файл | Изменения | Причина |
| --- | --- | --- |
| `C:\Users\Kibnet\.codex\skills\unlimotion-cli\SKILL.md` | Новый operational skill | Основной результат |
| `C:\Users\Kibnet\.codex\skills\unlimotion-cli\agents\openai.yaml` | UI metadata/default prompt | Discoverability и удобный явный вызов |
| `C:\Users\Kibnet\.codex\skills\unlimotion-cli\references\apply-v1.31.1.md` | Минимальный versioned request contract и пример | Безопасно использовать `apply` в установленной версии, не угадывая schema |
| `specs/2026-09-26-unlimotion-cli-skill.md` | SPEC, evidence, review journal | QUEST audit trail |

## 17. Таблица соответствий (было → стало)

| Область | Было | Стало |
| --- | --- | --- |
| Operational CLI workflow | Каждый раз восстанавливается из help/docs/memory | Discoverable `$unlimotion-cli` с компактными invariants |
| Mutation evidence | Зависит от текущего prompt | Before/read-back и unknown-outcome recovery закреплены |
| Lease handling | Нужно заново вспоминать contract | Active execution явно routed через lease commands |
| Development/release routing | Может смешиваться с task operations | Исключено из description/body, остаётся специализированным workflow |

## 18. Альтернативы и компромиссы

- Вариант: скопировать весь CLI README в `references/`.
  - Плюсы: автономная справка.
  - Минусы: быстрый drift, лишний контекст, дублирование authoritative source.
  - Решение: не выбран; skill читает installed help/release-matched docs и хранит только stable safety invariants плюс минимальный versioned `apply` envelope.
- Вариант: добавить PowerShell wrappers/scripts.
  - Плюсы: детерминированные команды.
  - Минусы: отдельная compatibility surface и риск скрытых мутаций; текущий CLI уже предоставляет команды/JSON.
  - Решение: не выбран.
- Вариант: сделать explicit-only skill.
  - Плюсы: меньше false positives.
  - Минусы: теряется помощь в естественных запросах о задачах.
  - Решение: оставить implicit invocation с узкой description и exclusions.

## 19. Результат quality gate и review

### SPEC Linter Result

| № | Блок | Статус | Комментарий / evidence |
|---:|---|---|---|
| 1 | A. Цель и outcome | PASS | Operational skill и наблюдаемый user outcome заданы в sections 1 и 6.3 |
| 2 | A. Проверенный AS-IS | PASS | Installed 1.31.1, installed help, release tag, checkout drift и existing skills проверены |
| 3 | A. Корневая проблема | PASS | Риск повторного восстановления safety rules и ошибочной mutation сформулирован |
| 4 | A. Цели дизайна | PASS | Routing, source-of-truth, lease, evidence и safe testing определены |
| 5 | A. Границы / Non-Goals | PASS | Development/release/live validation mutations/raw fallback исключены |
| 6 | B. Ответственности | PASS | `SKILL.md`, `openai.yaml`, versioned apply reference и external sources разделены |
| 7 | B. Точки интеграции | PASS | Shell, global tool, version-matched docs и discovery triggers заданы |
| 8 | B. Алгоритмы / инварианты | PASS | Inspect→exact mutation→read-back, lease и capability gates формализованы |
| 9 | B. Ошибки / recovery | PASS | Lock, timeout, outcomeUnknown, leaseMismatch, validation failure и version mismatch покрыты |
| 10 | B. Performance | PASS | Runtime CLI performance не меняется; context cost ограничен compact entrypoint и одним conditional reference, full manual не копируется |
| 11 | C. Данные / состояние | PASS | Task-space не меняется при validation; persisted change — только новый skill folder |
| 12 | C. Совместимость / migration | PASS | Installed-version gate, newer-checkout drift и active catalog activation учтены |
| 13 | C. Rollback | PASS | Isolated candidate, exact hashes и удаление только нового target folder определены |
| 14 | D. Измеримые AC | PASS | AC-1..AC-7 наблюдаемы |
| 15 | D. AC→evidence | PASS | Matrix включает static, behavioral, negative/recovery и sandbox evidence |
| 16 | D. Команды / stop rules | PASS | Validation commands и stop conditions зафиксированы |
| 17 | E. План / зависимости | PASS | Candidate→eval→activation→active checks→review последовательность задана по реальным инвариантам |
| 18 | E. Решения / вопросы | PASS | Decision Ledger заполнен, blocking questions отсутствуют |
| 19 | E. Масштаб / форма | PASS | Expanded обоснован stateful/public mutation behavior и version drift |
| 20 | F. Профиль | PASS | `product-system-design` и `skill-creator` requirements отражены |

Итог: ГОТОВО после reviewer pass; если effective sandbox не `read-only`, проход фиксируется как writable adversarial fallback с residual risk.

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Operational scope и exclusions конкретны |
| 2. Понимание текущего состояния | 5 | Проверены installed tool, help, README и existing skills |
| 3. Конкретность целевого дизайна | 5 | Файлы, sections, flows и evidence rules определены |
| 4. Безопасность (миграция, откат) | 5 | Isolated folder, no live mutation, rollback и drift gate |
| 5. Тестируемость | 5 | Static + fresh-context same-configuration before/after + adversarial review |
| 6. Готовность к автономной реализации | 5 | User-owned blocking decisions отсутствуют |

Итоговый балл: 30 / 30.
Зона: готово к автономному выполнению после exact approval.

### Role-Based Review Result

| Role | Applicability | Review question | Verdict | Required spec changes |
| --- | --- | --- | --- | --- |
| Business analyst / domain workflow | applicable | Сохраняет ли workflow точный scope задачи и task lifecycle? | PASS | Нет |
| UX / designer | applicable как artifact-facing text workflow | Короткий ли безопасный путь и понятны ли failure/recovery? | PASS | Нет |
| Tester / validation | applicable | Есть ли AC→evidence и adversarial cases без live side effects? | PASS | Нет |
| Developer / architect | applicable | Согласованы ли public invocation, compatibility и lease/data boundaries? | PASS | Нет |
| Delivery / operations / security | applicable | Безопасны ли install path, rollback, active-path evidence и runtime access? | PASS | Нет |

### Post-SPEC Review

- Статус / stop decision: PASS по финальному reviewer pass; effective sandbox был `danger-full-access`, поэтому evidence классифицирован как writable adversarial fallback, не independent read-only review.
- Scope reviewed: эта SPEC; central stack (`creator-vibe-lens`, full `creator-vibe`, `model-behavior-baseline`, `collaboration-baseline`, `tool-execution-baseline`, `quest-governance`, `quest-mode`, `testing-baseline`, `session-insights-context`, `spec-linter`, `spec-rubric`, `review-loops`); `product-system-design`; `skill-creator` и `references/openai_yaml.md`; installed help; release-matched `v1.31.1` README/source; newer checkout drift; relevant memory sources; planned files из section 16.
- Contract pass: operational scope, Non-Goals, AC, output/evidence contract, version gates и stop rules согласованы.
- Adversarial risk pass: проверены false routing, installed/source version drift, unknown apply schema, active catalog activation, evaluator contamination, active lease, lock/timeout, unknown outcome, unrelated validation, raw-edit bypass и hot-reload claim.
- Role-Based pass: все пять релевантных ролей отражены выше.
- Fix and re-review: исправлены семь findings первого pass и три остаточных findings второго pass; третий targeted pass не нашёл новых BLOCKER/HIGH/MEDIUM и подтвердил closure.
- Evidence inspected: `dotnet tool list --global`, `Get-Command`, `unlimotion-cli --help`, `git describe`, tag `v1.31.1` README/`TaskApplicationJson.cs`/integration examples, newer checkout README, existing active/memory skill inventory, repo/worktree status, `openai_yaml.md`.
- Depth checklist:
  - Scope drift / unrelated changes: target только новый skill folder + эта SPEC.
  - Acceptance criteria: AC-1..AC-7 связаны с evidence.
  - User-observable scenarios / Decision ledger / Expected objections: заполнены.
  - Validation evidence: текущая фаза содержит planned evidence; EXEC evidence ещё отсутствует по design.
  - Unsupported claims: installed version/help сверены с matching tag; newer checkout не выдан за installed contract; future hot-reload не обещан.
  - Regression / edge case: state matrix и adversarial scenarios заданы.
  - Comments/docs/changelog: README/CHANGELOG не нужны; skill files достаточны.
  - Hidden contract change: live task-space/config не меняются.
  - Manual-review challenge: вероятные находки — применение post-tag env fallback или undocumented apply envelope; mitigated installed-version gates и focused reference.
- No-findings justification: финальный targeted pass проверил fresh-context contract, reviewer labeling, candidate/active validation+hash commands и связанные version/apply/metadata контракты; новых BLOCKER/HIGH/MEDIUM не найдено.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER | task-space source | SPEC ошибочно переносила `UNLIMOTION_TASKS` из post-tag checkout на installed 1.31.1 | Опора на installed help/tag; env только capability-gated | fixed, verified |
| HIGH | apply contract | `apply` envelope не был доступен installed-only agent | Добавить focused versioned reference и mismatch stop rule | fixed, verified |
| HIGH | activation | Candidate создавался прямо в active discovery path | Author/validate/hash вне active path, затем exact activation и active recheck | fixed, verified |
| HIGH | behavioral eval | Один conversation context загрязнял after-eval baseline-ом | Два fresh contexts, frozen prompts, parent grading | fixed, verified |
| HIGH | expanded linter | Criteria 1–20 были сгруппированы; performance не обоснован | Индивидуальная таблица 1–20 и context-cost rationale | fixed, verified |
| HIGH | review evidence | Reviewer role фактически имел `danger-full-access` | Не называть pass read-only; применить documented writable adversarial fallback/residual risk | fixed, verified |
| MEDIUM | openai.yaml | Metadata constraints/reference не были явно включены | Добавить reference и AC по quoting/length/default prompt | fixed, verified |
| HIGH | behavioral eval re-review | В двух местах сохранился stale same-agent contract | Везде использовать два fresh contexts с одинаковой configuration | fixed, verified |
| MEDIUM | reviewer labeling re-review | В двух местах writable fallback назывался independent review | Унифицировать reviewer/fallback labeling для SPEC и EXEC | fixed, verified |
| MEDIUM | executable validation re-review | Command block не показывал candidate validation и hash equality | Добавить parameterized candidate/active validate+SHA-256 commands | fixed, verified |

- Fixed before continuing: семь findings выше исправлены в SPEC.
- Checks rerun: targeted scans по version/task-space/apply/candidate/eval/linter/metadata; два fix-and-re-review цикла; финальный writable adversarial fallback PASS; `scripts/validate-instructions.ps1` PASS (37 guards, 0 negative mutations; behavioral smoke ожидаемо отложен до EXEC); `scripts/test-validate-instructions.ps1` PASS.
- Needs human: exact phrase `Спеку подтверждаю` для перехода в EXEC.
- Residual risks / follow-ups: effective read-only child sandbox недоступен в первом reviewer pass; writable adversarial fallback раскрыт. Skill catalog может не hot-reload в текущей session; проверить active path и честно указать границу.

### Post-EXEC Review

- Статус / stop decision: PASS targeted post-EXEC re-review; первый проход был NEEDS-FIX, все 1 BLOCKER evidence и 3 MEDIUM закрыты.
- Scope reviewed: approved SPEC; active/candidate `SKILL.md`, `agents/openai.yaml`, `references/apply-v1.31.1.md`; `git status --short`; installed CLI 1.31.1/help; matching tag source; baseline/candidate и active smoke; candidate/active validator/hash evidence; catalog validators.
- Review passes:
  - Scope/Evidence: вне задачи изменена только новая active skill folder; в repo — только текущая SPEC. User task-space не использовался для mutating smoke.
  - Contract: operational routing, `apply` version gate, lease lifecycle и unknown-outcome stop проверены; после finding уточнены `create` exception, CLI-only recovery и непроверяемость `Repeater`.
  - Adversarial risk: reviewer проверил несоответствие installed/source version, `apply` envelope, поле `Repeater`, потерянный create ID, before-ID exception и discovery.
  - Role-Based: domain workflow — exact task scope; UX — краткий путь и честные ограничения; tester — AC matrix и negative smoke; architect — versioned schema/lease; operations/security — active hashes, sandbox disclosure, отсутствие live mutations.
  - Fix and re-review: три MEDIUM findings исправлены в двух идентичных копиях skill; validator/hash equality повторены; affected behavioral smoke для create/Repeater прошёл; reviewer независимо подтвердил `MATCH 3 files` и отсутствие новых findings.
  - Stop decision: PASS после targeted re-review и completion gate AC-1..AC-7; живые task mutations в scope проверки не входили.
- Evidence inspected: `v1.31.1:src/Unlimotion.Cli/Program.cs` (`TaskDetailsOutput` без `Repeater`), `TaskApplicationJson.cs`, `TaskApplicationCommandService.cs`, installed help/tool list, hashes и evaluator outputs, active skill discovery в новом child context.
- Depth checklist: scope drift — отсутствует; AC — таблица выше; validation — candidate/active skill и catalog PASS, targeted review PASS; unsupported claims — `Repeater` исправлен; edge cases — create timeout/lease/dry-run; comments/docs — только нужные skill files; hidden behavior — установленный CLI/task-space не изменены; manual challenge — нельзя считать неуспех `create` по отсутствию в ограниченной выборке.
- First reviewer findings:

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| BLOCKER | evidence | Post-EXEC/AC evidence ещё не было в SPEC | Записать matrix, active hashes/validator, catalog checks | fixed, verified |
| MEDIUM | read-back | CLI 1.31.1 не выводит `Repeater` | Указать границу и stop при явном требовании доказательства | fixed, verified |
| MEDIUM | recovery | Прямой read-only поиск task files противоречил CLI-only scope | Убрать прямой поиск и фиксировать unknown при потере ID | fixed, verified |
| MEDIUM | create | Before-ID wording не делало исключения для `create` | Ограничить pre-read существующими задачами | fixed, verified |

- No-findings justification: targeted re-review проверил три изменённые строки SKILL, AC/behavior matrix, candidate/active hashes и discovery; новых BLOCKER/HIGH/MEDIUM/LOW не нашёл.
- Unrelated changes: не обнаружены (`git status --short` содержит только эту SPEC).
- Residual risks: reviewer effective sandbox `danger-full-access`, поэтому проход — writable adversarial fallback; parent session не подтверждает hot-reload, но новый child видел skill в Available skills. Reviewer не видел raw evaluator transcripts и опирался на matrix; parent сравнил raw outputs в текущем turn. Instruction smoke не доказывает фактическую мутацию живой задачи.

## Approval

Ожидается фраза: «Спеку подтверждаю».

## 20. Журнал действий агента

| Фаза / событие | Решение и основание | Evidence / остаток работы | Следующее действие | Фактическое решение человека, если требовалось | Затронутые артефакты |
| --- | --- | --- | --- | --- | --- |
| SPEC / старт | Выбрана expanded SPEC: skill управляет public agent behavior и потенциальными task mutations | Central routing/QUEST owners прочитаны; target skill ещё не создан | Исследовать current CLI и historical invariants | Не требовалось | Эта SPEC |
| SPEC / исследование | Scope ограничен operational task work; development/release исключены | Installed 1.31.1, help, README, existing skills и memory runbooks проверены | Подготовить design/AC/review | Не требовалось | Эта SPEC |
| SPEC / self-review | Self-review PASS; public-behavior risk требует reviewer pass с проверкой effective sandbox | Expanded sections, linter, rubric, roles и evidence mapping заполнены | Выполнить reviewer pass; при writable sandbox оформить adversarial fallback | Не требовалось | Эта SPEC |
| SPEC / reviewer pass 1 | Reviewer role сообщил effective `danger-full-access`; pass считается writable adversarial fallback, verdict NEEDS-FIX | 1 BLOCKER, 5 HIGH и 1 MEDIUM finding: version drift, apply schema, active activation, eval contamination, linter, sandbox claim, metadata | Исправить findings и выполнить re-review | Не требовалось | Эта SPEC |
| SPEC / rework | Все семь findings исправлены без изменения requested outcome | Matching tag/source проверены; versioned reference, isolated candidate, fresh evaluators, 20-point linter и sandbox disclosure добавлены | Повторить reviewer pass | Не требовалось | Эта SPEC |
| SPEC / reviewer pass 2 | Writable adversarial fallback закрыл исходные findings, но нашёл 1 HIGH и 2 MEDIUM stale/command inconsistencies | Same-agent формулировки, independent label и hash commands локализованы | Исправить и выполнить финальный re-review | Не требовалось | Эта SPEC |
| SPEC / rework 2 | Три остаточных findings исправлены | Fresh-context contract унифицирован; reviewer labeling исправлен; candidate/active validate+hash commands добавлены | Финальный reviewer pass | Не требовалось | Эта SPEC |
| SPEC / reviewer pass 3 | Writable adversarial fallback PASS; новых BLOCKER/HIGH/MEDIUM нет | Закрыты fresh-context, labeling и executable-validation findings; effective sandbox `danger-full-access` раскрыт | Запросить exact approval | Ожидается | Эта SPEC |
| SPEC / quality gate | Обязательные validators каталога выполнены перед approval | `validate-instructions.ps1` PASS; `test-validate-instructions.ps1` PASS; target skill folder всё ещё отсутствует | Запросить exact approval | Ожидается | Эта SPEC |
| EXEC / разрешение | Пользователь ответил точной фразой «Спеку подтверждаю»; переход SPEC → EXEC разрешён | Target folder перед созданием отсутствовал; baseline в отдельном fresh context зафиксирован | Создать и проверить candidate вне active discovery path | Спеку подтверждаю | Эта SPEC |
| EXEC / candidate | Candidate из трёх файлов создан и прошёл `quick_validate.py`; Python validator потребовал `PYTHONUTF8=1` из-за системной `cp1251` | Frozen five-scenario baseline/candidate smoke выполнен в свежих contexts; узкий timeout сценарий перепроверен после уточнения recovery | Активировать exact hashed candidate files | Не требовалось | Эта SPEC; candidate `SKILL.md`, `openai.yaml`, `apply-v1.31.1.md` |
| EXEC / activation | Candidate активирован после проверки отсутствия target folder; active validator и SHA-256 equality PASS | Ровно 3 файла, active path `C:\Users\Kibnet\.codex\skills\unlimotion-cli`; новый child увидел skill в Available skills | Выполнить post-EXEC review | Не требовалось | Active skill folder |
| EXEC / reviewer pass 1 | Writable adversarial fallback дал NEEDS-FIX: evidence + три MEDIUM контракта | `Repeater` не виден CLI; потерянный create ID нельзя искать raw-file способом; before-ID не относится к create | Исправить skill и записать actual AC evidence | Не требовалось | Candidate/active `SKILL.md`; эта SPEC |
| EXEC / fixes | Три контрактных finding исправлены без расширения scope | Candidate/active hashes совпали; `quick_validate.py` PASS; fresh affected smoke подтвердил CLI-only recovery | Получить targeted reviewer re-review | Не требовалось | Candidate/active `SKILL.md`; эта SPEC |
| EXEC / reviewer pass 2 | Writable adversarial fallback PASS; все четыре findings закрыты, новых нет | Reviewer независимо подтвердил `MATCH 3 files`, active discovery; raw evaluator transcripts для него недоступны, decision matrix проверена | Повторить mandatory catalog validators после SPEC edit и завершить | Не требовалось | Active skill; эта SPEC |
| EXEC / завершение | Все AC-1..AC-7 закрыты в заявленных границах; mandatory validators повторены после финальной SPEC edit | `quick_validate.py` candidate/active PASS; 3/3 hashes равны; instruction smoke и reviewer PASS; catalog validators PASS; `git status --short` — только эта SPEC | Сообщить пользователю установленный skill и границы проверки | Не требовалось | Active skill; эта SPEC |
