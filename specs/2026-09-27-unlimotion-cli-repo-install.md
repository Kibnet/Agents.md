# Актуализировать Unlimotion CLI skill под main, разместить в репозитории и описать установку

Expanded SPEC: меняется operational instruction contract и распространяется репозиторный skill с инструкцией установки; форма по `quest-governance`, review по `review-loops`. Предыдущая одобренная `2026-09-26-unlimotion-cli-skill.md` исключала repo-публикацию и README; новое поручение добавило semantic update под текущий `main`, поэтому нужен отдельный SPEC → EXEC gate.

## 0. Метаданные

- Тип: `delivery-task`; task-specific `skill-creator` и `openai-docs`; tool-heavy overlay.
- Владелец: пользователь; реализация: Codex. Масштаб: medium, повышенный риск публичного instruction contract и active personal skill.
- Поверхность: Codex, repository skill и действующая personal установка. Behavior baseline: центральный `model-behavior-baseline`; фактический model/reasoning/client version не раскрыты, поэтому before/after smoke выполняется в одинаковой доступной конфигурации без выдуманной идентичности.
- Eval baseline: текущий personal skill уже прошёл прежний smoke; новая семантика требует новых frozen scenarios до/после: версия/путь бинарника, выбор task-space, поиск, apply recovery, legacy 1.31.1. Raw evidence хранить в SPEC; не обращаться к живому task-space.
- Ветка: текущая `main` без commit/push. Публикация на GitHub не входит в scope.
- Источники: текущий personal skill `C:\Users\Kibnet\.codex\skills\unlimotion-cli`; Unlimotion `origin/main` = local `main` = tag `v1.32.0` = `d1e6702fa37382f57e5a8210313f88b1f8c59d92` (`git ls-remote origin refs/heads/main` 2026-09-27); `src/Unlimotion.Cli/{README.md,CliIntrospection.cs,TaskDirectoryResolver.cs,Program.cs,apply-request-v1.schema.json}` и integration tests; глобально установленный `unlimotion.cli 1.31.1`; [официальная документация Codex](https://learn.chatgpt.com/docs/build-skills) о `.agents/skills`; предыдущая SPEC.

## 1. Overview / Цель

- Исходное поручение: «Скилл закинь в репозиторий и добавь инструкцию как его установить» + «Заодно актуализируй скилл под текущую версию мейна».
- Success means: обновлённый operational skill описывает `main@d1e6702f` / CLI 1.32.0 и безопасный runtime fallback для фактически установленного 1.31.1; он доступен в `.agents/skills/unlimotion-cli/`, README объясняет установку; действующая personal копия обновлена до того же проверенного результата без изменения CLI и задач.
- Output: `.agents/skills/unlimotion-cli/{SKILL.md,agents/openai.yaml,references/apply-v1.31.1.md}`, новая секция `README.md`, точечное обновление `C:\Users\Kibnet\.codex\skills\unlimotion-cli\SKILL.md` после candidate validation.
- Stop: после local + active-path smoke и post-EXEC review; не менять живые задачи, установленный CLI или удалённый репозиторий.

## 2. AS-IS и проблема

- Действующий personal skill находится вне Git-репозитория и уже проверен в предыдущем scope. Его SHA-256 на момент SPEC: `SKILL.md` — `9EB4406290EE1B2E6604A6E062EBA334378049F88592EA61DE71EA115D2044A1`; `openai.yaml` — `F733D9D8CD5F13688F717D25674D161044EB888A7DB261880F9D631A84B9FF1A`; `apply-v1.31.1.md` — `79DB19F9677DF8D5AB417C2642370F4B0E0835F1153F191E51EFEC248C00EA0B`.
- `main@d1e6702f` содержит встроенные `version`, JSON `help`, `context`, `search`, `apply schema/example/inspect` и `details.repeater`. `context` сообщает `tasksPath/sourceKind`; приоритет: `--tasks` → непустой `UNLIMOTION_TASKS` → desktop settings. `apply inspect` различает receipt и текущее desired state; схема `apply` не заменяет dry-run/бизнес-правила. Текущий skill частично описывает эти возможности, но не фиксирует 1.32.0 как verified source, использует global tool list для любой установки и недостаточно отделяет new/legacy capability.
- На компьютере глобально установлен `unlimotion.cli 1.31.1`, не `1.32.0`; версия репозитория не доказывает возможности запущенного бинарника.
- В текущем checkout `.agents/` не содержит skill; README описывает установку каталога и отдельного `creator-vibe`, но не Unlimotion CLI.
- Без repo copy skill нельзя воспроизводимо взять из каталога; текущая инструкция не полностью раскрывает безопасный маршрут для 1.32.0 и fallback 1.31.1.

## 3. Цели, границы и Non-Goals

- Обновить ровно решения, зависящие от версии CLI: определить реально запускаемый binary и его capabilities; для 1.32.0 закрепить resolved `tasksPath`, использовать self-documenting CLI и `apply inspect`; для 1.31.1 сохранить versioned reference и запрет предполагать новые возможности.
- Распространить проверенный обновлённый skill через поддерживаемый repo path `.agents/skills`, затем синхронизировать active personal copy с hash/read-back.
- Документировать личную установку в `$env:USERPROFILE\.agents\skills\unlimotion-cli` из локального checkout; `$env:CODEX_HOME` не считать тем же самым путём без отдельного подтверждения.
- Не удалять существующую `C:\Users\Kibnet\.codex\skills\unlimotion-cli`; её `SKILL.md` обновить только после drift check, candidate validation и сохранения проверяемого rollback. `agents/openai.yaml` и legacy reference оставить неизменными.
- Не разрабатывать CLI, не устанавливать/обновлять CLI, не менять task-space, не создавать release/PR, не commit/push, не переписывать другие разделы README или предыдущую SPEC. Не называть main-функцию установленной в 1.31.1.

## 4. TO-BE / контракт

### 4.1 Файлы и правила

- `.agents/skills/unlimotion-cli/SKILL.md`: сохранить purpose, authorization/lease/read-back rules и обновить version routing. Разрешить фактический исполняемый файл через `Get-Command` до абсолютного пути и вызывать **этот же путь** во всей связанной серии (`& $cliExe ...`), включая version/help/context/read/write/inspect/read-back; при wrapper/alias, который нельзя однозначно привязать, остановиться до записи. Новый маршрут включается по подтверждённым `version --format json`, JSON help и `context` того же бинарника; source `main@d1e6702f` описывает 1.32.0, не подменяет installed evidence. Ветку 1.31.1 сохранить с `references/apply-v1.31.1.md` и ограничениями. `dotnet tool list --global` — fallback только для глобальной установки, для tool-path проверить соответствующий installation scope. Если identity/capability не совпадают, stop before mutation.
- Для verified 1.32.0 явно описать приоритет `--tasks` → непустой `UNLIMOTION_TASKS` → desktop settings, `context` → абсолютный pinned `--tasks` для всей связанной цепочки; `context` не подтверждает целостность графа и возможность будущей записи. Поиск `search` с курсором, фильтрами и all statuses; `task --include details` с `repeater`. Новые возможности не приписывать 1.31.1.
- Для `apply`: брать синтаксис из schema/example и семантику из `help apply`, затем preview и одну запись; `apply inspect` читать с неизменным request после неопределённого результата. `receiptMatched` — receipt для exact hash, не гарантия неизменности текущего состояния; `desiredStatePresent` — только состояние; `readyForPreview` — новый dry-run, не разрешение автоматически повторить запись; `needsReconciliation`/`reconciliationRequired` — сверка и остановка. Для terminal `setStatus` учитывать `justification`/absolute `evidenceLinks` и реальные бизнес-правила. `inspect` может запустить journal recovery при storage access, поэтому это не безусловно side-effect-free read.
- `.agents/skills/unlimotion-cli/agents/openai.yaml` и `references/apply-v1.31.1.md`: точные копии прежних проверенных файлов. Новый большой дублирующий manual/reference не создавать: 1.32.0 self-documents через CLI.
- `README.md`: после шага про `creator-vibe` добавить шаг `Установить Unlimotion CLI skill (при необходимости)` и сдвинуть прежний шаг 4 на 5. Объяснить: в данном репозитории Codex видит skill автоматически; для других проектов — личная установка. Пререквизит: работающая `unlimotion-cli` (`Get-Command unlimotion-cli`; `version --format json` в 1.32.0, `dotnet tool list --global` для legacy global install). Указать, что skill поддерживает verified main 1.32.0 и legacy 1.31.1, но не обновляет сам CLI.
- Предложенная команда из корня клона, без overwrite и без изменений текущего personal skill:

  ```powershell
  $sourceSkill = Join-Path (Get-Location) '.agents\skills\unlimotion-cli'
  $personalSkills = Join-Path $env:USERPROFILE '.agents\skills'
  $targetSkill = Join-Path $personalSkills 'unlimotion-cli'
  if (-not (Test-Path -LiteralPath (Join-Path $sourceSkill 'SKILL.md'))) { throw 'Запустите команды из корня репозитория' }
  if (Test-Path -LiteralPath $targetSkill) { throw "Скилл уже установлен: $targetSkill" }
  New-Item -ItemType Directory -Path $personalSkills -Force | Out-Null
  Copy-Item -LiteralPath $sourceSkill -Destination $targetSkill -Recurse
  ```

  Затем `Test-Path -LiteralPath (Join-Path $targetSkill 'SKILL.md')`; Codex обнаруживает изменения автоматически, а если не видит skill — перезапустить Codex. Отметить, что одновременные repo/user copies с одинаковым `name` могут отображаться обе, поэтому в этом checkout личная копия необязательна.
- UI layout / video: не применимо; меняется Markdown и discoverability skill, а не экран приложения.
- Performance: не применимо; меняются статические инструкции, не код CLI.

### 4.2 User-Observable Scenarios

| Scenario | Trigger | Expected output | Evidence | AC |
| --- | --- | --- | --- | --- |
| Работа из этого репозитория | Codex запущен внутри checkout | Репозиторный skill обнаружим, ссылки внутри skill разрешаются | path/validator, официальный discovery contract | AC1, AC2 |
| Версия main CLI | Пользователь поручает поиск или правку через CLI 1.32.0 | Агент закрепляет task-space и пользуется встроенной схемой/inspection, не расширяя scope | равные before/after scenarios + source/CLI contract | AC1, AC2, AC6 |
| Старый установленный CLI | Пользователь работает с глобальным 1.31.1 | Агент не пытается вызвать `context/search/apply inspect`, использует versioned fallback | legacy scenario + installed tool evidence | AC6 |
| Личная установка | Пользователь исполняет README из корня клона | Skill копируется без перезаписи существующего destination | изолированный install smoke, README check | AC3 |
| Уже установленный skill | Destination существует | Инструкция прерывается до копирования, существующие файлы сохранены | негативный install smoke | AC3 |

### 4.3 State / Interaction Matrix

| State | Trigger | Result | Edge case |
| --- | --- | --- | --- |
| Skill в repo отсутствует | checkout после EXEC | `.agents/skills/unlimotion-cli` содержит обновлённый SKILL и два сохранённых файла | drift source → stop |
| Personal skill 1.31.1-aware | candidate validated | активный `SKILL.md` обновлён до hash repo candidate | drift/partial write → stop, rollback |
| Personal destination отсутствует | README install | создаётся целевой каталог с тремя файлами | нет CLI → установка skill возможна, операции CLI блокируются |
| Personal destination занят | README install | `throw`, без перезаписи | repo copy и personal copy могут быть видны обе |

### 4.4 Decision Ledger

| Decision | Owner | Chosen | Confidence | Risk | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |
| Repo path | agent | `.agents/skills/unlimotion-cli` по официальному discovery contract | 0.99 | неверный путь не обнаружится | Нет |
| Install mode | agent | локальная безопасная копия в `.agents/skills` пользователя | 0.95 | несколько копий одного `name` | Нет; README предупреждает |
| Personal installed copy | agent | обновить только active `SKILL.md` после candidate checks | 0.95 | live-path drift/частичная активация | Нет; пользователь просит актуализировать skill |
| CLI main vs installed | agent | 1.32.0 — verified main contract, 1.31.1 — live binary fallback | 1.0 | ложная команда/не тот task-space | Нет |

### 4.5 Runtime / Config / Data Contract Matrix

| Area | Source of truth | Change | Compatibility | Verification |
| --- | --- | --- | --- | --- |
| Skill discovery | официальная Codex docs | repo `.agents/skills` + README для user `.agents/skills` | active `.codex/skills` обновляется отдельно после validation | path + static check |
| Skill content | personal baseline и Unlimotion main@d1e6702f | SKILL semantic update, два файла exact copy | main/legacy runtime gate | before/after smoke, source contract, hash equality repo/active |
| Unlimotion data | установленный CLI и выбранный task-space | нет изменений | не применимо | не запускать mutating CLI |

## 5. Бизнес-правила, интеграция, состояние, rollout

- Инвариант: никакая `README.md`-команда не должна перезаписывать существующий skill. Правка действующей personal копии — отдельный контролируемый этап этого EXEC после candidate validation, а не часть README-инсталлятора.
- Интеграция: Codex сканирует repo `.agents/skills` при работе в этом checkout; README-команды создают user-scoped copy только при явном действии пользователя. В этой задаче отдельно обновляется уже действующий personal `SKILL.md`.
- Данные: task-space и CLI package не меняются; сохраняются repo skill/README и одна правка active `SKILL.md`.
- Rollback: до активации сохранить исходный active `SKILL.md` как проверенный текст/hash в SPEC/candidate evidence; при провале active-path проверки восстановить только этот файл через `apply_patch` после drift check. Repo-файлы и README-фрагмент откатывать только как точные собственные изменения, не трогая чужие данные.

## 6. Тестирование и Acceptance Criteria

| AC | Проверка | Evidence / stop |
| --- | --- | --- |
| AC1: repo skill соответствует main@d1e6702f, legacy fallback сохранён | сопоставить команды/семантику с `CliIntrospection`, `TaskDirectoryResolver`, README/schema и tests; убедиться, что `openai.yaml`/legacy ref совпадают с baseline hash | неподтверждённую CLI capability не добавлять |
| AC2: candidate и active skill структурно корректны и одинаковы после активации | `quick_validate.py` с `PYTHONUTF8=1` на обоих путях; проверить relative link и SHA-256 repo/active | при drift active до записи — stop; при mismatch после — rollback/fix |
| AC3: README объясняет repo auto-discovery, personal install, prerequisite и no-overwrite | review README + smoke копирования в отдельный temp root и повтор с занятым destination | не запускать install в действующий user path |
| AC4: репозиторий проходит quality gate | `pwsh -File scripts/validate-instructions.ps1`; `pwsh -File scripts/test-validate-instructions.ps1` | FAIL блокирует завершение, если относится к diff |
| AC5: scope соблюдён | `git diff --check`; `git status --short`; inspect relevant diff | прежняя untracked SPEC — отдельное существующее изменение; нет commit/push/CLI mutation |
| AC6: версия маршрутизируется безопасно | frozen before/after behavioral smoke в одинаковой model/surface/reasoning/sandbox конфигурации: 1.32.0 discovery/task-space/apply inspect, 1.31.1 legacy, отрицательный случай PATH/global-list mismatch при закреплённом executable; read-only/synthetic fixtures, без живого task-space | при неверном выборе версии/бинарника или самовольной записи — FAIL; raw evidence в SPEC |

Persistence evidence: проверять repo-файлы, local temp install smoke и active personal path после правки; не утверждать, что CLI 1.32.0 установлен на компьютере или что personal install произведён на другом компьютере. Static validator не заменяет behavioral smoke. Вариант проверки реального бинарника 1.32.0 — изолированная сборка/тест в temp path после approval, если понадобится для контрактных сценариев; не запускать `dotnet tool update --global` и не обращаться к живым задачам.

## 7. Риски и Expected User Review Objections

| Objection | Why | Mitigation | Status |
| --- | --- | --- | --- |
| «Почему не `skills/`?» | Неочевидный discovery path | официальный Codex repo path `.agents/skills` | mitigated |
| «Это установит skill всем?» | Repo и personal scope различаются | README явно разделяет auto-discovery здесь и optional personal copy | mitigated |
| «А старая personal copy?» | Уже существует в `.codex/skills` | обновить контролируемо после candidate smoke; README install её не заменяет | mitigated |
| «Поменялось ли поведение skill?» | Пользователь просит актуализацию | явно перечислить semantic delta и проверить frozen before/after | mitigated |
| «main новее установленного CLI — не сломается ли 1.31.1?» | Runtime и repo version различаются | capability gate + legacy reference, негативный smoke | mitigated |

Rework Prevention Checklist: пользователь видит обновлённый skill/README и active copy; AC1–AC6 покрывают видимые сценарии; решения и no-overwrite зафиксированы; возражения закрыты; применимые роли reviewed ниже; EXEC имеет статические и изолированные проверки.

## 8. План, вопросы, профиль, изменения

- После exact approval: повторить remote/local main и baseline hashes → подготовить repo candidate через `apply_patch` → статическая/behavioral проверка candidate против baseline → добавить README step и проверить temp install → drift check active path → применить тот же `SKILL.md` к active personal copy → active-path validation/smoke → AC1–AC6 и post-EXEC review.
- Открытых вопросов нет. Выполняется `delivery-task` с `quest-governance`, `quest-mode`, `review-loops` и repository quality gate; `skill-creator` обеспечивает минимальную структуру skill.
- Файлы: три новых `.agents/skills/unlimotion-cli/*`, изменение `README.md`, обновление active `C:\Users\Kibnet\.codex\skills\unlimotion-cli\SKILL.md`, этот рабочий SPEC. Иных файлов нет.
- Было → стало: personal-only skill с частичной поддержкой 1.32.0 → обновлённые repo/active copies с verified main contract и legacy fallback; README без инструкции → README с безопасной установкой.
- Альтернатива `skills/unlimotion-cli` не даёт гарантированной repo auto-discovery. GitHub installer потребовал бы доступного remote commit и публикации вне scope. Поэтому локальная копия из checkout.

## 9. SPEC Linter, Rubric и Role-Based Review

| № / блок | Result | Evidence |
| --- | --- | --- |
| 1 / A: outcome | PASS | repo/active skill под main + README install по обеим фразам |
| 2 / A: AS-IS | PASS | personal hashes, installed 1.31.1, remote main@d1e6702f, repo inventory и README проверены |
| 3 / A: проблема | PASS | skill не переносится из personal path и неполно маршрутизирует main/legacy |
| 4 / A: цели | PASS | verified 1.32.0, legacy gate, discoverability, no-overwrite |
| 5 / A: границы | PASS | Non-Goals запрещают CLI/task/Git remote changes |
| 6 / B: ответственности | PASS | обновляемый SKILL, сохранённые ref/metadata, README и active path распределены |
| 7 / B: интеграция | PASS | repo/user Codex scan paths и CLI runtime gate указаны |
| 8 / B: инварианты | PASS | absolute executable + task-space pinning, no blind retry, source hash, no-overwrite |
| 9 / B: ошибки | PASS | wrong cwd, occupied destination, main/installed mismatch, drift и uncertain outcome |
| 10 / B: performance | PASS | неприменимо к статическим инструкциям без кода CLI |
| 11 / C: состояние | PASS | repo/active skill files; task-space/CLI неизменны |
| 12 / C: совместимость | PASS | 1.31.1 reference сохраняется, 1.32.0 gated by installed capability |
| 13 / C: rollback | PASS | active reverse patch + точные repo paths/README section |
| 14 / D: AC | PASS | AC1–AC6 измеримы |
| 15 / D: AC→evidence | PASS | source contract, before/after smoke, hash, validator, temp install, quality gate |
| 16 / D: команды/stop | PASS | проверки и условия остановки указаны |
| 17 / E: план | PASS | source/drift → candidate → smoke → README → active validation → review |
| 18 / E: решения | PASS | ledger заполнен, открытых вопросов нет |
| 19 / E: масштаб | PASS | medium/expanded из-за semantic instruction + repo distribution |
| 20 / F: профиль | PASS | delivery-task и skill-creator применены |

Итог: ГОТОВО. Rubric: цель/границы 5, AS-IS 5, дизайн 5, безопасность 5, проверяемость 5, автономность 5 = 30/30; exact approval всё равно обязателен.

| Role | Applicability | Review question | Verdict | Change |
| --- | --- | --- | --- | --- |
| Business/domain | applicable: agent task workflow | Не подменяется ли порученное task action и safety boundary? | PASS | AC6 |
| UX/copy | applicable: README/skill wording | Понятны ли main-vs-installed и repo-vs-personal? | PASS | AC3 |
| Tester | applicable | Покрыты ли 1.32.0, 1.31.1, recovery и occupied destination? | PASS | AC3, AC6 |
| Developer/architect | applicable | Верны ли CLI contract, discovery path и active/candidate identity? | PASS | AC1–AC2 |
| Delivery/security | applicable | Есть ли overwrite, task mutation или CLI/package update? | PASS | staged activation; no push |

### Post-SPEC Review

- Status/stop: PASS после исправлений и targeted re-review; можно запросить exact approval. Это решение только о SPEC, не о выполненном EXEC.
- Scope/Evidence pass: эта SPEC; ранее утверждённая SPEC и её Non-Goals; три active skill файла и hashes; Unlimotion `main@d1e6702f` (`git ls-remote`, `git rev-parse`, CLI README, source, schema, tests); installed 1.31.1 (`dotnet tool list --global`); README installation section; `quest-governance`, `quest-mode`, `review-loops`, `spec-linter`, `spec-rubric`; официальная Codex skills docs. Planned diff: три repo skill файла + README + active personal SKILL + эта SPEC. `git status --short` до EXEC содержит лишь обе SPEC.
- Contract pass: обе фразы пользователя учтены: semantic update под verified 1.32.0, legacy 1.31.1 guard, repo distribution и install instruction. Не разрешены task mutation, CLI install/update, commit или push. AC1–AC6 покрывают user scenarios и expected objections.
- Adversarial risk pass: main/installed mismatch, local tool-path vs global list, `context` не проверяет граф, `apply inspect` может восстановить journal, receipt vs current state, занятый install destination, дубли `name`, active/source drift и недоступный CLI. План ограничивает мутации и вводит before/after smoke.
- Role-Based pass: таблица выше; domain/workflow, UX/copy, Tester, Developer и Delivery применимы. Active personal SKILL — отдельная стадия после candidate validation.
- Fix and re-review: reviewer нашёл stale review от прежнего byte-copy scope (HIGH) и незафиксированный путь бинарника (MEDIUM). Переписаны Scope/Contract/Adversarial/Role passes под semantic update, AC6 и active-path validation; добавлены absolute executable pin и негативный mismatch smoke. Targeted reviewer повторно прочитал обе поверхности и подтвердил исправление. Sections 1–8, 20 linter items и обе пользовательские фразы повторно сверены.
- Depth checklist: scope drift — новая фраза отражена отдельно, прежняя SPEC не меняется; AC — 1–6 с negative scenarios; pre-approval full catalog tests (316 assertions) были до semantic дополнения SPEC, а static validator текущей SPEC повторно прошёл (exit 0); после EXEC повторить оба quality gates; unsupported claims — main SHA и установленный 1.31.1 проверены отдельно; regression/edge — version mismatch, uncertain write, occupied destination, duplicate skill; docs/changelog — README меняется, CHANGELOG не требуется без release; hidden contract — source-vs-runtime gate; manual challenge — см. ниже.
- Reviewer sandbox: effective `danger-full-access`; reviewer не менял файлы и задачи, но это writable adversarial fallback, **не** технически read-only independent review.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| HIGH | review evidence | Старый post-SPEC review отрицал semantic update, active copy и AC6; не было отдельного no-findings justification | Переписать full review под новую SPEC и провести targeted re-review | fixed, re-review PASS |
| MEDIUM | version safety | После `Get-Command` не закреплялся абсолютный executable для всей цепочки | Закрепить `& $cliExe` и negative PATH/global-list mismatch smoke | fixed, re-review PASS |

- No-findings justification после исправлений: нет оставшихся post-SPEC находок: версия main установлена через `git ls-remote`, legacy 1.31.1 через `dotnet tool list --global`, source contract сверён с CLI README/introspection/schema/tests, AC6 требует одинаковые frozen scenarios, path pinning закрывает смену binary, active path отложен до candidate validation; targeted reviewer подтвердил исправление HIGH/MEDIUM. Это не подтверждает EXEC.
- Residual risk: реальное обнаружение skill в другой Codex installation проверяется там, не заявляется фактом; установленный 1.31.1 не обновляется.
- Manual-review challenge: установленный 1.31.1 не умеет `context/search/apply inspect`, даже если main 1.32.0; `Get-Command` может выбрать не global binary; checksum active copy нужен после активации; README copy не должен перезаписывать занятый destination.

### Post-EXEC Review

Status: PASS в пределах утверждённого scope; технически независимый read-only review недоступен, применён writable adversarial fallback без мутаций reviewer.

- Scope/Evidence pass: `origin/main`, local HEAD и `v1.32.0` Unlimotion совпали на `d1e6702fa37382f57e5a8210313f88b1f8c59d92`; установленный global CLI остался 1.31.1. Проверены `CliIntrospection`, `TaskDirectoryResolver`, `Program`, apply schema и command service; новые возможности не приписаны установленному CLI. `git status --short` ограничен `README.md`, новой `.agents/`, этой SPEC и ранее существовавшей untracked SPEC 2026-09-26; commit/push, CLI update и task mutation не выполнялись.
- Contract pass: AC1 — source-backed 1.32.0 contract и сохранённая 1.31.1 reference; AC2 — `quick_validate.py` на candidate/active и идентичный SHA-256 repo/active `SKILL.md` (`6B92084F351FE4733ACC18EA41FED540D0C03B11BE6F2B9558955FE7CECE16C1`); AC3 — README с repo/personal scopes, prerequisite, no-overwrite, проверкой трёх файлов и temp smoke успешной копии/занятого destination; AC4 — оба обязательных gate на рабочем checkout exit 0, полный test gate 318 assertions; AC5 — `git diff --check` exit 0, только ожидаемые файлы; AC6 — три frozen before/after synthetic scenarios без регрессии плюс active-path synthetic smoke. Ни один smoke не менял задачи.
- Adversarial risk pass: reviewer выявил неполную install-проверку (MEDIUM) и неточность global-list wording (LOW); оба исправлены. Исправленный `Copy-Item` использует `-ErrorAction Stop`, предварительно проверяет три source файла и после операции три target файла; частичный target явно требует ручной проверки и не перезаписывается при повторе. Первый isolated full gate выявил Markdown-ссылку, несовместимую с fixture-копией README, — исправлена. Следующий isolated full gate дал два timing FAIL при параллельном .NET UI-тесте; targeted Hooks после снятия нагрузки прошёл 63 assertions, повторный full gate прошёл 318 assertions. Эти FAIL не скрыты.
- Role-Based pass: task workflow удерживает evidence boundary и no-blind-retry; UX/install разделяет repo и personal scope; tester проверил legacy/new и occupied destination; developer сверил source/active identity; delivery не совершал commit/push. Внешний reviewer не выявил HIGH/BLOCKER в skill semantics, но работал с effective `danger-full-access`, поэтому его оценка не названа технически read-only.
- User-Observable Completion Gate: skill лежит в repo discovery path, README объясняет установку в другой проект, active personal copy обновлена; версия `main` отражена через capability gate, legacy 1.31.1 остаётся безопасным fallback. Реальное auto-discovery в другой установке Codex и live CLI 1.32.0 на task-space не проверялись; установленная 1.31.1 не обновлялась. Synthetic smoke не доказывает улучшение относительно baseline: обе версии прошли три frozen scenarios.
- Process note: junction `C:\Users\Kibnet\.codex\agents` → активный checkout обнаружен уже после первоначального создания repo candidate; отдельный worktree использован для изолированной валидации **до** изменения personal skill, но не до первых repo-правок. Остался временный install-smoke каталог `C:\Users\Kibnet\AppData\Local\Temp\unlimotion-skill-install-53dc3607d8ed4989978c855b6263eb6a`: sandbox заблокировал его рекурсивное удаление; в нём только три скопированных файла skill.

## Approval

Получена точная фраза «Спеку подтверждаю» 2026-09-28; разрешён только EXEC в границах этой SPEC.

2026-09-29 пользователь отдельно поручил: «Отребейзь на актуальный мейн и оформи pr». Это разрешает Git delivery уже проверенного результата (ветка, commit, push, PR), не изменяет контракты скилла и не разрешает merge, CLI update или работу с живыми задачами. Исторические Non-Goals выше относятся к прежнему approval и сохранены для аудита.

## 10. Журнал действий агента

| Фаза / событие | Решение и основание | Evidence / остаток | Следующее действие | Решение человека | Артефакт |
| --- | --- | --- | --- | --- | --- |
| SPEC | Repo packaging расширило предыдущие Non-Goals; выбран expanded gate | repo/README/source inspected | подготовить review | ожидается | эта SPEC |
| SPEC / scope expansion | Пользователь добавил актуализацию под main; `main@d1e6702f` совпал с remote, installed CLI остался 1.31.1 | semantic scope, AC6, active-path gate и version routing внесены; EXEC не начат | завершить post-SPEC review, запросить exact approval | ожидается | эта SPEC |
| SPEC / validation baseline | До semantic дополнения прошёл quality gate | static validator exit 0; test validator exit 0, 316 assertions; новую SPEC ещё нужно статически проверить | relevant recheck | ожидается | эта SPEC |
| SPEC / review closure | Static validator обновлённой SPEC прошёл; writable adversarial fallback подтвердил закрытие HIGH/MEDIUM | `validate-instructions.ps1` exit 0; два targeted findings fixed; EXEC не начат | запросить exact approval | ожидается | эта SPEC |
| EXEC / approval | Пользователь подтвердил эту SPEC точной фразой «Спеку подтверждаю» | 2026-09-28: personal hashes совпали с baseline; Unlimotion HEAD/remote main/tag = `d1e6702f` / `v1.32.0`; repo skill ещё отсутствует | создать candidate в repo, проверить и активировать | подтверждено | SPEC, будущие skill/README |
| EXEC / candidate | Три repo skill файла и README подготовлены; обнаружен junction от active Codex catalog к этому checkout, поэтому создан отдельный worktree для candidate validation перед обновлением personal skill | candidate и active legacy ref/metadata hash совпадают; `quick_validate.py` PASS. Первый full catalog test в worktree выявил, что fixture копирует README без `.agents`, поэтому Markdown-ссылка на новый skill ломала valid scenario; ссылка заменена текстовым путём в обоих checkout без расширения scope. Повторный full test выполняется | завершить candidate validation, сравнить файлы, активировать personal skill | подтверждено ранее | repo skill, README, isolated worktree |
| EXEC / validation incident | После исправления README valid fixture и Markdown-контракты прошли, но общий прогон дал два FAIL в двухсекундном hook/telemetry сценарии при параллельном .NET UI-тесте на хосте | `test-validate-instructions.ps1` exit 1, конкретные FAIL: hook fixture >2 s и duplicate warning. Отдельный `test-agent-operations.ps1 -Area Hooks` после завершения параллельной нагрузки — PASS, 63 assertions. Повторный полный тест запущен; первый FAIL не называем PASS | дождаться полного результата, затем решить gate | подтверждено ранее | isolated worktree, SPEC |
| EXEC / candidate gate | Повторный полный прогон в изолированном worktree завершился успешно после снятия внешней нагрузки | `test-validate-instructions.ps1` exit 0; agent operations contracts — 318 assertions; `quick_validate.py` и `validate-instructions.ps1` тоже PASS | сверить candidate с active, затем повторить gate на рабочем checkout | подтверждено ранее | isolated worktree, repo skill |
| EXEC / active activation | После успешного candidate gate и drift check обновлён прежний personal `SKILL.md`; reference/metadata не менялись | baseline active SHA-256 `9EB4406290EE1B2E6604A6E062EBA334378049F88592EA61DE71EA115D2044A1`; новый active/repo SHA-256 `6B92084F351FE4733ACC18EA41FED540D0C03B11BE6F2B9558955FE7CECE16C1`; active `quick_validate.py` PASS; synthetic active-path smoke PASS без вызовов CLI | завершить repo gate и post-EXEC review | подтверждено ранее | personal/repo skill |
| EXEC / review fix | Независимый writable adversarial reviewer нашёл риск неполной установки и неточность об источнике версии CLI | README проверяет три source/target файла и использует `Copy-Item -ErrorAction Stop`; поясняет occupied partial copy и область `dotnet tool list --global`; active и isolated README имеют одинаковый Git-normalized hash `ba606bcfcb4773fdfd52ef8bd02abdf3cbca3faa` | завершить полный gate и post-EXEC review | подтверждено ранее | README, SPEC |
| EXEC / completion gate | Рабочий checkout прошёл оба обязательных quality gate, diff и AC1–AC6 проверены, post-EXEC review PASS в утверждённых границах | `validate-instructions.ps1` exit 0; `test-validate-instructions.ps1` exit 0, agent operations 318 assertions; `git diff --check` exit 0; CLI/task-space не менялись | передать результат пользователю, без commit/push | подтверждено ранее | repo/active skill, README, SPEC |
| DELIVERY / новое поручение | Пользователь отдельно разрешил перенести проверенный результат на свежий `origin/main` и открыть PR; merge не поручен | 2026-09-29: Agents `origin/main` и local `main` = `62ce63992f0e7ba9a72f864f74cf774a084fbe76`; создана ветка `feat/unlimotion-cli-operational-skill`; исторический запрет commit/push в первоначальном EXEC не переписан | проверить scoped diff, rebase, повторить gate, commit/push и PR | «Отребейзь на актуальный мейн и оформи pr» | эта SPEC, repo skill, README |

### EXEC: frozen behavioral smoke (synthetic, без task-space)

- Две свежие evaluator-сессии без `model`/`thinking` overrides, с одинаковым заданием и одинаковой средой `danger-full-access`; точный model ID/reasoning не раскрыт runtime. Baseline прочитал прежний active `SKILL.md`, candidate — repo candidate. Оба получили только гипотетические наблюдения, не запускали CLI и не открывали задачи.
- Сценарий A: выбранный executable `C:\synthetic\tools\unlimotion-cli.exe` сообщает 1.32.0, global tool list сообщает 1.31.1; пользовательский `--tasks C:\synthetic\tasks`, поиск Completed. Baseline и candidate выбрали бинарник 1.32.0, pinned `--tasks` и `help search` без выдумывания flags; candidate дополнительно явно сформулировал закреплённый `$cliExe` и identity gate до мутации. PASS обоих, новой регрессии нет.
- Сценарий B: потерян ответ `apply`; `inspect` вернул `receiptState=missing`, `assessment=desiredStatePresent`, `postconditionsMatch=all`. Оба запретили blind retry, потребовали read-back и различили текущее desired state от истории применения. PASS обоих.
- Сценарий C: 1.31.1, пользователь требует проверенную сохранность `Repeater` при добавлении строки. Оба остановились до записи: CLI не показывает поле, доказательство невозможно. PASS обоих.
- Вывод ограничен решениями на трёх synthetic prompts; нет проверки фактического CLI 1.32.0 на живом task-space и нет измеренного улучшения относительно baseline в этих сценариях. Новые правила подкреплены `main@d1e6702f` source/help/schema и должны ещё пройти active-path validation.
