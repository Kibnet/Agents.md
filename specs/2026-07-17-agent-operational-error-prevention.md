# Предотвращение повторных операционных ошибок Codex

## 0. Метаданные
- Тип (профиль): `catalog-governance` + `product-system-design`; контекст `session-insights-context`
- Владелец: пользователь / владелец центрального каталога инструкций
- Масштаб: large
- Целевое семейство / behavior baseline: GPT-5.6; `instructions/core/model-behavior-baseline.md`
- Поверхность: Codex Desktop на Windows, PowerShell, локальные Git worktree; правила остаются переносимыми на CLI там, где совпадает hook/config contract
- Effective runtime: `gpt-5.6-sol`, reasoning `xhigh`, Codex Desktop; sandbox `workspace-write` с Windows elevated implementation, approval policy `on-request`, guardian reviewer; фактический runtime повторно фиксируется при behavioral smoke
- Eval baseline / evidence: анализ событий в полуинтервале `[2026-06-17T11:05:24.066Z, 2026-07-17T11:05:24.066Z)`, 25 верхнеуровневых задач, 124 execution traces и 21 955 tool calls; события текущего анализа исключены, `rg` exit code `1` без stderr отделён от реальных отказов
- Целевой релиз / ветка: `3.1.0`; `feat/session-insights-context-routing`
- Ограничения:
  - до фразы `Спеку подтверждаю` меняется только этот spec-файл;
  - сырые prompts, ответы, команды, пути с персональными данными и содержимое файлов не попадают в telemetry и versioned reports;
  - первая версия hooks работает только в `warn-only` и `fail-open` режиме;
  - глобальный `danger-full-access` и расширение writable roots на Git metadata не применяются;
  - consumer-репозитории не изменяются этой спецификацией; для них создаётся проверяемый onboarding/preflight contract;
  - фраза `Спеку подтверждаю` разрешает только versioned implementation в репозитории; любые изменения `%USERPROFILE%\.codex` требуют отдельной фразы `Глобальную активацию подтверждаю` после показа точного `-WhatIf` diff, backup path и active-catalog evidence;
  - перед EXEC worktree HEAD `b689110` отставал от active central main `a19ca21`; branch синхронизирован fast-forward до `a19ca21`, material drift утверждённого scope не обнаружен.
- Связанные ссылки:
  - `specs/2026-06-05-session-insights-agent-context-delivery.md`
  - `specs/2026-06-11-quest-rework-prevention.md`
  - `instructions/contexts/session-insights-context.md`
  - `session-insights/AGENT_SESSION_LESSONS.md`
  - `session-insights/AGENTS_IMPROVEMENT_BACKLOG.md`
  - [Codex hooks](https://learn.chatgpt.com/docs/hooks)
  - [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
  - [Codex local environments](https://learn.chatgpt.com/docs/environments/local-environment)
  - [Codex sandboxing](https://learn.chatgpt.com/docs/sandboxing)

## 1. Overview / Цель
Создать обязательный и компактный operational baseline для tool-heavy задач, дополнить его механическими предупреждениями и измеримой обратной связью, чтобы агент предотвращал повторные ошибки до первого неудачного вызова инструмента, а не вспоминал исторические уроки после сбоя.

Outcome contract:
- Success means:
  - каждый tool-heavy маршрут загружает один канонический owner правил работы с paths, PowerShell, patch, Git, timeouts и классификацией ошибок;
  - параллельная работа соблюдает one-writer ownership, а read-only review отделён от реализации;
  - валидация идёт staged-порядком `targeted -> build -> full`, без бессмысленного повтора timeout-команд и без завершения behavior-changing задачи до successful full run либо repo-approved final-green CI equivalent;
  - Codex hooks предупреждают о высокоуверенных известных ошибках, но не блокируют работу и не раскрывают содержимое сессии;
  - глобальная конфигурация ограничивает fan-out до `agents.max_threads = 4` и сохраняет `agents.max_depth = 1`;
  - повторный 30-дневный анализ можно выполнить одной документированной командой и сопоставить с baseline.
- Итоговый артефакт / output:
  - versioned instruction changes, hook runtime и installer, privacy-safe analyzer, onboarding/preflight contract, tests, changelog;
  - готовый к установке warn-only runtime и installer; фактические изменения внутри `%USERPROFILE%\.codex` выполняются отдельной фазой только после синхронизации active catalog и второго пользовательского approval;
  - before/after behavioral smoke и machine-readable baseline/follow-up reports в ignored artifacts.
- Stop rules:
  - не активировать hooks/config, пока unit/contract tests installer и hook dispatcher не прошли, versioned change set не присутствует в active central checkout и пользователь отдельно не подтвердил exact `-WhatIf` diff;
  - считать установленные user hooks неактивными, пока их exact definitions не прошли Codex trust review; installer не обходит и не подменяет trust gate;
  - при drift глобального config, неизвестной hook schema или невозможности безопасно сохранить существующие настройки остановить внешнюю активацию, не откатывая versioned артефакты;
  - не повторять неизменённую упавшую patch/test/build/Git команду без новой гипотезы;
  - не переводить hooks в blocking mode в рамках этой версии;
  - не объявлять достижение 30-дневных целей в день внедрения: это отдельный follow-up measurement.

## 2. Текущее состояние (AS-IS)
- `session-insights-context` содержит полезные runbooks и правила проверки drift, но является выбираемым context. В обычной .NET/UI задаче его место занимает `testing-dotnet` или `visual-feedback`, поэтому общие операционные уроки часто не попадают в контекст до ошибки.
- `testing-baseline.md` и `testing-dotnet.md` требуют полный локальный прогон перед завершением. `targeted` first задан слабее, а явного progress/timeout diagnosis, границ допустимого CI equivalent и запрета идентичного retry после timeout нет.
- `review-loops.md` хорошо регулирует QUEST post-SPEC/post-EXEC review, но не задаёт независимого read-only reviewer для large/high-risk задач и не распространяет минимальный user-observable review на guided artifact workflows вне QUEST.
- `collaboration-baseline.md` не владеет формальным one-writer contract для subagents и shared integration files.
- В user config нет `[agents]` limits и lifecycle hooks. Дефолтный `agents.max_threads = 6` допускает больший одновременный fan-out.
- В `workspace-write` Git metadata worktree защищены отдельно; добавление writable root не решает запись в `.git`. Сейчас агент часто обнаруживает это только после первого `index.lock`/`FETCH_HEAD` отказа.
- Нет повторяемого privacy-safe анализатора, который одинаково считает task incidence, trace events, expected red tests и false-red `rg` no-match.
- Repo-specific local environment setup существует не как единый onboarding contract, поэтому SDK/workloads/dependencies проверяются поздно и по-разному.

### 2.1 Измеренная базовая линия

| Категория | Затронуто верхнеуровневых задач | Доля из 25 | Дополнительное evidence | Интерпретация |
| --- | ---: | ---: | --- | --- |
| Missing path / неверный Windows glob | 10 | 40% | около 65 missing-path и 22 invalid-glob structural events | Нет обязательного path inventory перед прямым чтением |
| Failed patch | 10 | 40% | 50 unique top-level failures; 83 во всех traces, из них 41 stale context и 40 write/delete conflict | Retry не привязан к перечитыванию контекста и ownership |
| Git/sandbox/index.lock | 8 | 32% | 22 direct episodes | Worktree permission model обнаруживается реактивно |
| Test failure | 8 | 32% | 63 events | Смешаны expected TDD red, regression и неверный runner |
| Build/compile failure | 7 | 28% | 45 events | Preflight и staged validation непоследовательны |
| Timeout | 7 | 28% | 38 top-level, 44 direct shell traces | Полные прогоны запускаются без бюджета/progress strategy |
| Line endings / diff-check | 6 | 24% | 29 events | Не везде зафиксирован text normalization contract |
| PowerShell / quoting | 6 | 24% | 17 events | Bash-паттерны и interpolation ошибки повторяются |
| Network/auth/restore | 6 | 24% | 14 events | Environment blockers поздно отделяются от product defects |
| File/process locks | 6 | 24% | 12 events | Конкурентные writers/builds делят файлы и output dirs |
| Missing environment dependency | 4 | 16% | 11 events | Worktree setup не гарантирует готовность toolchain |
| Git conflict/state | 4 | 16% | отдельные rebase/branch episodes | Недостаточный preflight реального branch state |
| Wrong CLI/runner args | 3 | 12% | в том числе VSTest-style filter для TUnit | Known runner rules не всегда загружены до команды |

Дополнительные сигналы:
- 173 `rg` no-match/chain события в 14 traces являются преимущественно false-red noise, а не фактическими сбоями.
- 75 `turn_aborted` в 29 traces включают короткие subagent interruptions и не должны автоматически считаться ошибками реализации.
- Консервативный поиск нашёл 16 сильных пользовательских correction messages в 6 из 25 задач.
- В 11 задачах было явное `Спеку подтверждаю`; только 4 содержали pre-SPEC review, а 4 из 11 потребовали после EXEC пользовательский цикл `Сделай ревью` -> `Исправь`.
- Часть примеров предшествует релизу preventive QUEST gates `2.11.0`; поэтому baseline не доказывает неэффективность уже внедрённых правил и служит точкой для последующего сравнения.

## 3. Проблема
Корневая проблема не в отсутствии знаний, а в неправильном слое и моменте их доставки: повторные операционные уроки лежат в необязательных historical context files, тогда как обязательные core instructions, runtime hooks, concurrency limits и environment preflight не формируют единый prevention loop `предупредить -> классифицировать -> исправить стратегию -> измерить результат`.

## 4. Цели дизайна
- Один owner на каждый вид правила, без копирования длинных session-derived списков во все профили.
- Минимальный обязательный operational context до первого tool call.
- Механическая защита только для высокоуверенных паттернов; judgement остаётся у агента.
- One-writer concurrency и предсказуемая интеграция результатов subagents.
- Проверяемый staged validation contract с progress/no-blind-retry без ослабления обязательного full-run completion gate.
- Privacy-safe observability с раздельными denominators task/trace/event.
- Idempotent install/rollback глобального runtime.
- Совместимость с Windows/PowerShell и Git worktrees.
- Сохранение строгого QUEST approval gate и существующих owner-документов.

## 5. Non-Goals (чего НЕ делаем)
- Не переписываем все historical session-insights в core instructions.
- Не загружаем пользовательский профиль или полные прошлые сессии в каждую задачу.
- Не блокируем tool calls hooks-ами в `3.1.0`.
- Не включаем `danger-full-access` глобально и не отключаем approval/sandbox governance.
- Не делаем Git metadata writable через broad filesystem roots.
- Не изменяем Unlimotion, GraphBot, TopLunchBot, TOC, Obsidian и другие consumer-репозитории в этом change set.
- Не гарантируем устранение product/design ошибок только техническими hooks.
- Не считаем каждый non-zero exit ошибкой и не считаем каждый красный тест регрессией.
- Не используем raw transcript format как стабильный hook API.
- Не автоматизируем перевод warn-only правил в deny/block; это отдельное решение после telemetry review.
- Не создаём обязательный plugin: versioned PowerShell runtime и installer достаточны для первого rollout.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности

| Компонент/файл | Ответственность |
| --- | --- |
| `instructions/core/tool-execution-baseline.md` | Канонический owner path discovery, PowerShell, `rg`, patch retry, Git/worktree preflight, timeout/error classification и operational stop rules |
| `instructions/governance/routing-matrix.md` и `AGENTS.md` | Обязательное подключение operational baseline для tool-heavy задач; без конкуренции с выбранным context |
| `instructions/core/collaboration-baseline.md` | One-writer ownership, read-only reviewer, shared integration files, последовательность конфликтующих builds/tests |
| `templates/codex/agents/independent-reviewer.toml` | Versioned personal-agent template с required `name`/`description`/`developer_instructions` и explicit `sandbox_mode = "read-only"` |
| `instructions/core/testing-baseline.md` | Общий staged validation contract и evidence rules |
| `instructions/contexts/testing-dotnet.md` | .NET/TUnit-specific команды, repo-specific timeout strategy и допустимый final-green CI equivalent |
| `instructions/governance/review-loops.md` | Independent read-only review для large/high-risk QUEST и минимальный role-based review для guided artifact workflows |
| `instructions/contexts/session-insights-context.md` | Только targeted historical retrieval/runbooks; не owner общих обязательных правил |
| `instructions/onboarding/local-environment.md` | Consumer contract для setup/preflight/actions без repo-specific догадок |
| `templates/codex/local-environment/*` | Windows PowerShell preflight template и инструкция подключения через Desktop-generated `.codex` config |
| `scripts/hooks/agent-operations-hook.ps1` | Единый dispatcher `PreToolUse`/`PostToolUse`, model-visible warn-only context и privacy-safe counters |
| `templates/codex/agent-operations-hooks.json` | Версионируемая lifecycle hook конфигурация с Windows commands и короткими timeout |
| `scripts/install-agent-operations.ps1` | Dry-run, backup, idempotent install/update/uninstall runtime, hooks и `[agents]` limits |
| `scripts/analyze-codex-session-errors.ps1` | Повторяемый агрегированный анализ sessions/archived_sessions без сохранения raw content |
| `scripts/test-agent-operations.ps1` | Hook, installer, analyzer и privacy contract tests на synthetic fixtures |
| `scripts/validate-instructions.ps1` / `scripts/test-validate-instructions.ps1` | Semantic enforcement mandatory owner/routing markers и запуск новых contract tests |
| `.github/workflows/validate-instructions.yml` | Linux catalog regression job и отдельный Windows operational job для NTFS junction/reparse contracts |

### 6.2 Детальный дизайн

#### A. Mandatory operational baseline
`tool-heavy` означает задачу, где ожидается хотя бы одно из: shell/tool invocation, file mutation, patch, build/test, Git, browser/UI automation, external runtime/config operation. Для read-only вопроса без инструментов baseline не обязателен.

Baseline задаёт короткий preflight:
1. Подтвердить workspace root, текущую ветку/worktree и dirty state, если задача затрагивает repository delivery.
2. До прямого чтения неизвестного пути сделать scoped inventory через `rg --files`, `Get-ChildItem -LiteralPath` или `Test-Path -LiteralPath`.
3. В `rg` использовать `-g` для glob filtering; не передавать Windows wildcard как буквальный path argument.
4. Проверить availability runner/SDK/dependency до длинного build/test.
5. Классифицировать environment/auth/lock/permission failure отдельно от product/code defect.

Нормализация shell outcomes:
- `rg` exit `0` = matches, `1` без stderr = expected no-match, `>=2` или stderr = tool failure.
- PowerShell использует here-string вместо Bash heredoc; interpolation с двоеточием оформляется через `${name}` или format operator.
- Команда, ожидающая no-match, не соединяется с дальнейшими действиями так, чтобы code `1` превращал весь diagnostic chain в false failure.

Patch state machine:
1. Первый failed patch: перечитать точный актуальный диапазон и проверить `git diff`/ownership этого файла.
2. Повтор: уменьшить hunk и построить его по свежему контексту; идентичный hunk запрещён.
3. Второй конфликт записи в том же файле: остановить параллельных writers, вернуть ownership main agent и интегрировать последовательно.
4. Третий неразрешённый отказ без новой причины: stop/ASK-HUMAN вместо retry loop.

Git/worktree contract:
- До первой Git mutation определить `git rev-parse --git-dir`, `git rev-parse --show-toplevel`, branch/upstream и наличие worktree.
- В `workspace-write` заранее ожидать scoped approval для write в Git metadata; не ждать первого `index.lock`/`FETCH_HEAD` failure.
- `writable_roots` не предлагается как fix для защищённого Git metadata.
- Для trusted delivery может использоваться отдельный scoped profile/approval, но не глобальное ослабление sandbox.

#### B. Concurrency ownership
- Subagents по умолчанию используются для read-heavy exploration/review либо получают непересекающийся write set.
- Один файл в один момент имеет одного writer.
- Main agent владеет integration files: текущая spec, solution/project manifests, central config, changelog и общие индексы, если явно не передал ownership.
- Reviewer не меняет файлы; findings возвращаются main agent.
- Builds/tests, пишущие в один output directory, выполняются последовательно.
- До fan-out main agent фиксирует ownership map; при отсутствии disjoint write sets работа остаётся последовательной.
- User-level default: `agents.max_threads = 4`, `agents.max_depth = 1`. Это ограничивает случайный fan-out, но не запрещает осознанные четыре независимые read-only задачи.
- Для independent review добавляется versioned template `templates/codex/agents/independent-reviewer.toml`, который при отдельной global activation устанавливается как personal agent `%USERPROFILE%\.codex\agents\independent-reviewer.toml`. Файл содержит required `name`, `description`, `developer_instructions` и explicit `sandbox_mode = "read-only"`. Перед тем как назвать review независимым и read-only, main agent фиксирует фактический sandbox child session; live parent override, сделавший reviewer writable, переводит проверку в обычный reviewer pass и residual risk.
- Controlled contract test запускает reviewer в fixture repository и подтверждает, что чтение разрешено, а file mutation отклоняется. Instruction-only fallback не выдаётся за технически enforced read-only review.

#### C. Staged validation и completion gate
- Порядок по умолчанию: characterization/failing test -> targeted tests -> affected build -> full suite или authoritative CI.
- Repo-specific contract и исторически подтверждённая длительность имеют приоритет. Универсальный time budget не задаётся: при отсутствии repo budget агент запускает полный шаг с видимым progress и обоснованным timeout, а не подменяет его произвольным глобальным лимитом.
- До длинного шага агент сообщает команду, ожидаемую длительность и способ показать progress/log artifact.
- После timeout запрещён идентичный retry. Нужно сузить diagnostic scope, включить progress/output, устранить lock/resource issue либо запустить authoritative CI full-run, если repo contract признаёт его эквивалентной полной проверкой.
- Существующий MUST сохраняется: полный набор тестов должен завершиться успешно до завершения агентом behavior-changing задачи. Если используется authoritative CI, агент ждёт итоговый green status; pending/timeout/cancelled CI не считается evidence. При невозможности получить полный green run задача завершается как incomplete/blocker с явным residual risk, а не как успешно проверенная.
- Expected TDD red считается запланированным evidence, если тест добавлен до fix, причина падения подтверждена и следующий шаг записан. Wrong runner, compile error или unrelated failure ожидаемым red не считается.
- Для TUnit targeted selection используется `--treenode-filter`; VSTest `--filter` запрещён.

#### D. Review coverage
- Для large/high-risk QUEST (`config`, `deploy`, `security`, `multi-module`, public behavior, migration, destructive delivery) post-SPEC и post-EXEC должны включать независимого read-only reviewer, когда subagent facility доступна.
- Read-only статус считается доказанным только при effective child sandbox `read-only`; наличие инструкции без runtime evidence недостаточно.
- Fallback при недоступности reviewer или read-only sandbox: отдельный adversarial pass с зафиксированной причиной; отсутствие независимости отражается residual risk, а не скрывается как полный independent review.
- Для guided artifact workflows вне QUEST, где пользователь видит учебную структуру, product artifact или domain graph, применяется компактный user-observable + role-based review. Для learner-facing TOC обязателен методологический/domain-source pass.
- Review не заменяет acceptance evidence и не имеет права менять файлы параллельно с writer.

#### E. Warn-only hooks
Hook runtime использует только документированный JSON stdin/stdout contract и не читает нестабильный transcript format. Central instructions остаются primary prevention layer: hooks перехватывают не все shell/tool paths и не могут гарантировать соблюдение правил вне фактически поддержанного event payload.

| Event | Поведение `3.1.0` | Ограничение |
| --- | --- | --- |
| `PreToolUse` | Для high-confidence raw Windows glob, Bash heredoc в PowerShell и TUnit `--filter` возвращает model-visible `hookSpecificOutput.additionalContext`; optional `systemMessage` используется только для краткого user-visible warning | Не блокирует и не переписывает tool input; Git-preflight inference без надёжного state в v1 не выполняется |
| `PostToolUse` | По фактически подтверждённой Windows Desktop shape классифицирует `rg` no-match, stale patch context, timeout, index/file lock и auth/restore; через `additionalContext` предлагает модели один следующий шаг | Не возвращает `decision: block`, `continue: false` и не делает retry; unknown payload -> `unclassified`, без warning |

`SessionStart` и `Stop` не входят в `3.1.0`: первый не знает будущий task intent и загрузил бы baseline в non-tool tasks, второй работает на каждом turn, а dirty tree является нормальным промежуточным состоянием. Их возврат возможен только отдельной spec после evidence низкого false-positive rate.

Runtime properties:
- `warn-only`, `fail-open`, no network, no repo mutation;
- PowerShell command input разбирается через `System.Management.Automation.Language.Parser`; generic regex over raw command запрещён. Узкий pre-parse matcher допустим только для заведомо malformed Bash-heredoc signature, а любой иной parse ambiguity даёт no warning;
- target duration <= 2 секунды на hook, config timeout <= 5 секунд;
- безопасный tool call не получает warning;
- hook failure не меняет разрешение tool call и выдаёт короткий diagnostic;
- одинаковые installer-owned user hook entries не дублируются при повторной установке;
- release-specific probe в реальной Windows Desktop task фиксирует только keys/types `tool_name`, `tool_input` и `tool_response` без raw values; synthetic fixtures строятся по этой подтверждённой shape;
- если текущая Codex версия не перехватывает нужный shell path или response shape не содержит надёжного exit/result signal, соответствующий classifier остаётся disabled и не считается покрытым hook evidence.

#### F. Installation and global activation
Versioned source остаётся в репозитории. Installer:
1. Поддерживает `-WhatIf`, `-Install`, `-Uninstall`, `-Prune`, `-CodexHome` для fixture tests; `<CodexHome>` по умолчанию равен effective user Codex home, обычно `%USERPROFILE%\.codex`.
2. Создаёт timestamped backup существующих `config.toml`, `hooks.json`, `<CodexHome>\agents\independent-reviewer.toml` и installer-owned runtime.
3. Копирует dispatcher в `%USERPROFILE%\.codex\agent-operations\versions\<version>`; hook definition ссылается на абсолютный versioned command path, а не на mutable script pointer. Новая версия изменяет definition hash и требует нового trust review.
4. Структурно merge-ит `hooks.json`, сохраняя неизвестные events/handlers.
   - Если тот же user config layer уже содержит inline `[hooks]`/`[[hooks.*]]`, installer останавливается без mutation и показывает конфликт representation; автоматическая миграция inline hooks в этом change set запрещена.
5. Точечно добавляет/обновляет только `agents.max_threads = 4` и `agents.max_depth = 1`; остальные TOML keys/comments сохраняются.
6. Копирует reviewer template в `<CodexHome>\agents\independent-reviewer.toml` только если путь отсутствует либо его current fingerprint принадлежит предыдущей installer version. Foreign/conflicting файл или user drift блокирует write вместо перезаписи.
7. Повторный install не создаёт duplicates и не меняет файл без semantic diff.
8. `-Uninstall` удаляет только installer-owned hook entries и reviewer file, чьи command/content fingerprints совпадают с install manifest. Произвольные дополнительные поля, не предусмотренные Codex hook schema, не используются как managed id.
9. Предыдущие agent limits восстанавливаются только если текущие значения всё ещё равны установленным managed values. При пользовательском drift uninstall сохраняет текущие значения и требует явного выбора вместо перезаписи.
10. Backups хранятся отдельно в `%USERPROFILE%\.codex\backups\agent-operations\<timestamp>`, а sanitized counters — в `%USERPROFILE%\.codex\logs\agent-operations*.jsonl`; uninstall их не удаляет.
11. После install валидирует JSON/TOML и запускает synthetic hook/reviewer self-tests. Hook state равен `awaiting-trust`, а не `active`; agent limits и personal reviewer считаются применёнными только после controlled новой task.
12. User-level `hooks.json` трактуется как non-managed Codex hook source. Пользователь проверяет exact definition через `/hooks` или актуальный документированный эквивалент и явно доверяет её; installer не использует `--dangerously-bypass-hook-trust`.
13. State `active` подтверждается только controlled новой task после trust: safe call даёт zero warning, known-bad fixture даёт model-visible context, reviewer обнаруживается с effective read-only sandbox, а installed runtime записывает sanitized probe counter.

Installer отдельно проверяет, что `pwsh` и lifecycle hooks доступны в effective Codex runtime. Если hooks feature явно отключена либо effective managed policy игнорирует non-managed hooks, installer не включает и не обходит её скрыто: external activation останавливается с точным сообщением и сохранённым dry-run evidence.

Activation имеет отдельный пользовательский gate:
1. `Спеку подтверждаю` разрешает `EXEC-A`: только versioned docs/scripts/templates/tests, но не Git delivery, activation proposal или user config mutation.
2. До показа activation proposal approved change set должен быть committed/published по отдельному Git-полномочию, присутствовать в active central checkout, а critical validators должны пройти на active path.
3. Агент показывает exact `config.toml`/`hooks.json`/personal-reviewer diff, versioned runtime checksum, backup destination, trust steps, rollback command и `proposalHash`, вычисленный по previewed inputs/output plan.
4. Только фраза `Глобальную активацию подтверждаю` переводит workflow в `ACTIVATE` для показанного `proposalHash`; любой последующий drift требует нового `-WhatIf`, нового hash и повторного approval. Без этого `%USERPROFILE%\.codex` остаётся неизменным.

#### G. Local environment contract
Вместо немедленных правок разных consumer repos добавляется onboarding owner:
- setup проверяет, но не скрыто устанавливает toolchain без явного repo policy;
- preflight фиксирует SDK/runtime/workloads/package manager, restore/auth reachability, browser/UI dependencies и известные long-running actions;
- common actions предоставляют targeted tests, full tests и build с видимым progress;
- Windows-specific scripts используют PowerShell;
- consumer repo обязан хранить точные команды рядом с кодом; central catalog хранит только contract и шаблон;
- шаблон не изобретает undocumented `.codex` schema: он предоставляет `preflight.ps1` и пошаговое подключение через Desktop-generated local environment config, после чего сгенерированный repo config проверяется в consumer change;
- rollout в конкретные репозитории выполняется отдельными small/medium specs после проверки их актуального toolchain.

#### H. Repeatable telemetry
Analyzer принимает `-Since`, `-Until`, `-SessionsRoot`, `-OutputDirectory`, отдельно считает top-level tasks и all traces, дедуплицирует tool calls и создаёт:
- `summary.json` с schema version, window, denominators, category counts/rates и classifier version;
- `summary.md` без raw prompts/output/absolute user paths;
- optional local evidence map с salted `sessionHash`/`evidenceHash`, но без raw session IDs и message bodies; artifact по умолчанию ignored и никогда не переносится в hook telemetry.

Analyzer читает JSONL через streaming reader, не загружает весь archive в память, показывает progress минимум каждые 10 секунд и сохраняет partial parse/error counters. Contract test использует synthetic malformed/large-line fixtures; целевой peak memory для baseline run — не более 256 MB.

`scripts/test-agent-operations.ps1` принимает `-Area All|Hooks|Installer|Analyzer|Privacy` (default `All`), чтобы standard gate запускал весь набор, а troubleshooting мог повторить только релевантный contract без изменения test semantics.

Классификатор обязан отдельно помечать:
- real failure;
- expected no-match;
- expected TDD red;
- environment blocker;
- user correction/rework signal;
- aborted/interrupted trace.

Accuracy contract разделяет compatibility и correctness:
- exact reproduction прежних denominators/counts является regression compatibility check, но не доказательством правильной классификации;
- private-local gold set включает все найденные strong user-correction signals и для каждой ключевой технической категории до 20 positive и 20 negative episodes, либо все episodes, если их меньше; manual labels формируются независимо от classifier output из broad high-recall candidate pool и deterministic background sample, а sampling algorithm/seed id фиксируются для воспроизводимости без публикации локальной salt;
- разметка хранит salted evidence IDs и labels без raw message/tool bodies; в versioned evidence попадает только confusion matrix;
- для auto-counted key categories требуется precision >= 0.90, recall >= 0.80 и false-positive rate <= 0.10; undefined metric или категория, не прошедшая любой порог, выводится отдельно как `manual-review-only` и исключается из автоматического success metric;
- изменение classifier version требует пересчёта baseline и follow-up одним и тем же новым classifier либо параллельного отчёта old/new; смешивать версии в одной delta запрещено.

#### I. Behavioral smoke
На одинаковых surface/model/reasoning/sandbox выполняются пять representative scenarios до и после change:
1. Неизвестный Windows wildcard path.
2. Stale-context patch после внешнего изменения файла.
3. TUnit targeted test при наличии медленного full suite.
4. Предложение параллельно изменить shared spec/changelog.
5. Git commit/push из managed worktree под `workspace-write`.

PASS требует, чтобы after-поведение сделало preflight/ownership/validation-strategy/approval decision до первого соответствующего отказа. Static markers не заменяют behavioral smoke.

### 6.3 User-Observable Scenarios

| Scenario | User action / trigger | Expected visible result / output | Evidence required | Covered by AC |
| --- | --- | --- | --- | --- |
| Tool-heavy задача начинается | Пользователь просит изменить/проверить repo | Агент сначала делает узкий preflight и не загружает весь session archive | Behavioral smoke + routing markers | AC1-AC4, AC15 |
| Указан неверный wildcard path | Агент собирается читать путь | До/после вызова появляется короткая подсказка использовать inventory/`-g`; работа не блокируется | Hook fixture + smoke | AC3, AC9 |
| Patch не применился | Контекст файла изменён | Агент перечитывает участок, уменьшает hunk и не повторяет идентичный patch | Hook fixture + smoke | AC4, AC9 |
| Нужны subagents | Задача допускает параллелизм | Пользователь видит ownership plan; reviewers read-only; shared files меняет main agent | Spec review + smoke | AC6, AC8 |
| Полный тест долгий | Targeted tests прошли, full suite выполняется долго или завершился timeout | Агент показывает progress, меняет diagnostic strategy после timeout и не завершает behavior-changing задачу без successful full run либо repo-approved CI с итоговым green status | Test fixtures + final-run evidence | AC7 |
| Git mutation в worktree | Пользователь просит commit/rebase/push | Агент проверяет Git state и запрашивает scoped approval до первой metadata-write ошибки | Behavioral smoke | AC5, AC15 |
| Hook ошибся | Runtime script падает/timeout | Tool call продолжается, пользователь получает короткий diagnostic без потери команды | Hook contract test | AC9 |
| Установка выполняется повторно | Пользователь повторно применяет installer | Нет duplicate hooks/config/reviewer; есть dry-run и backup/rollback | Installer tests | AC10-AC11 |
| Versioned implementation готова | `EXEC-A` прошёл validation | `%USERPROFILE%\.codex` не изменён; после отдельно разрешённой delivery пользователь получает exact config/hooks/reviewer `-WhatIf`, checksum и backup/trust/rollback plan | Git/config evidence | AC20-AC21 |
| Пользователь подтверждает активацию | Фраза `Глобальную активацию подтверждаю` после active-catalog gate | Installer меняет только показанные config/hooks/reviewer paths; hook state становится `awaiting-trust` | Before/after diff + manifest | AC20-AC22 |
| Hook проходит trust review | Пользователь доверяет exact versioned definition | Controlled новая task подтверждает hook `active`, agent limits и discoverable reviewer с effective read-only sandbox | Trust/pilot evidence | AC6, AC9, AC22 |
| Пользователь просит повторный анализ через месяц | Запускается analyzer | Получается сопоставимый privacy-safe отчёт и delta к baseline | Analyzer fixture + schema check | AC12-AC14, AC16 |

### 6.4 State / Interaction Matrix

| Current state | Trigger | Expected transition/result | Empty/error/disabled/concurrent case | Notes |
| --- | --- | --- | --- | --- |
| Новая tool-heavy task | Routing по task intent | Central stack включает компактный operational baseline | Read-only non-tool task -> baseline не подключается | Primary prevention layer |
| Safe tool call | `PreToolUse` | Выполнение без warning | Empty input -> fail-open diagnostic only | Zero-noise target |
| Suspicious tool call | `PreToolUse` | Model-visible `additionalContext`, optional UI warning, tool continues | Неуверенный classifier -> no warning | Только high-confidence patterns |
| `rg` returns 1 without stderr | `PostToolUse` | Expected no-match, retry не требуется | stderr/exit >=2 -> real failure | Исключается из failure rate |
| Patch stale context | `PostToolUse` | Reread -> smaller fresh hunk | Concurrent writer -> ownership возвращается main | Identical retry запрещён |
| Long validation timed out | `PostToolUse` | New hypothesis: scope/progress/root cause; repo-approved CI только с final green | Повтор без изменений -> stop rule | Без successful full evidence outcome фиксируется как incomplete, не pass |
| Git metadata protected | До Git mutation | Scoped approval/preflight | Approval unavailable -> explicit blocker | No global sandbox weakening |
| Multiple writers | Ownership overlap обнаружен | Shared file serializes under main | Reviewer requests edit -> returns finding only | Integration files protected by policy |
| Active catalog validated | `-WhatIf` | Exact diff/backup/trust plan и `proposalHash` показаны; mutation отсутствует | Active catalog не содержит commit -> activation proposal запрещён | User activation gate |
| Runtime not installed | Separate activation approval | Backup -> versioned copy -> config/hooks/reviewer transaction; hook state `awaiting-trust` | Любой write/validation failure -> restore all touched paths | No mutable command pointer |
| Hook runtime awaiting trust | Codex skips new user hook | Пользователь выполняет exact definition review | Trust недоступен -> hooks остаются disabled; agent limits/reviewer проверяются отдельно либо весь install откатывается | Не выдавать hook runtime за active |
| Installed configuration | Controlled post-trust task | Safe/noisy/fail-open probes, exact agent limits и reviewer effective read-only соответствуют contract | Payload shape неизвестна -> classifier disabled; reviewer writable/missing -> pilot fails | Release-specific evidence |
| Runtime installed | Повторный `-Install` | No semantic diff | Existing foreign hooks -> preserved | Idempotent merge |
| Runtime active | `-Uninstall` | Entries с manifest fingerprint удалены; previous limits восстановлены только без user drift | Missing manifest/drift -> stop, no destructive cleanup | Rollback evidence required |

### 6.5 Decision Ledger

| Decision | Owner | Default / chosen option | Confidence | Risk if assumed | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |
| Где должны жить повторяемые operational rules | agent | Новый обязательный core owner; session-insights остаётся retrieval layer | 0.97 | Duplicate/conflicting rules при плохом owner split | Нет |
| Режим hooks первого релиза | agent | `warn-only`, `fail-open` минимум 14 дней | 0.99 | Часть ошибок не будет предотвращена механически | Нет |
| Глобальная sandbox policy | agent | Сохранить `workspace-write`/approval; не включать broad bypass | 0.99 | Дополнительный approval friction остаётся | Нет |
| Subagent concurrency | agent | `max_threads = 4`, `max_depth = 1` + one-writer policy | 0.90 | Некоторые read-only analyses станут чуть медленнее | Нет |
| Включать ли глобальную активацию в `EXEC-A` | user | Нет; `Спеку подтверждаю` разрешает только versioned implementation. Exact `-WhatIf` формируется позднее после отдельно разрешённой delivery | 1.00 | Скрытая mutation user config и потеря контроля | Нет: не блокирует EXEC-A; отдельное approval обязательно перед ACTIVATE |
| Активировать ли exact global diff | user | Только после active-catalog evidence и фразы `Глобальную активацию подтверждаю` | 1.00 | Hooks/config меняются вне repo | Нет перед EXEC-A; Да перед ACTIVATE |
| Изменять consumer repos сейчас | agent | Нет; создать contract/template, rollout отдельными specs | 0.98 | Environment issues там сохранятся до rollout | Нет |
| Full test requirement | agent | Сохранить current MUST: successful full run до завершения behavior-changing task; authoritative CI допустим только как repo-approved equivalent и только после green status | 0.99 | Длинный validation step остаётся, но не ослабляется correctness gate | Нет |
| Independent reviewer | agent | Обязателен для large/high-risk при доступности; documented fallback | 0.91 | Fallback менее независим | Нет |
| Telemetry payload | agent | Только категории/counters/schema и salted `sessionHash` optional; без raw content/raw session id | 0.99 | Меньше forensic detail | Нет |
| Автоматический blocking после pilot | user/future spec | Не входит в `3.1.0`; решение после 14/30-day evidence | 0.99 | Warn-only может быть проигнорирован | Нет |
| Целевая версия каталога | agent | `3.1.0`: existing testing MUST сохранён; добавляются staged iteration, no-blind-retry и новые optional runtime capabilities | 0.98 | Новые MUST ужесточают процесс, но не отменяют прежний completion contract | Нет |

### 6.6 Runtime / Config / Data Contract Matrix

| Contract area | Current source of truth | Expected change | Compatibility / migration | Verification |
| --- | --- | --- | --- | --- |
| Instruction routing | `AGENTS.md`, `routing-matrix.md` | Tool-heavy tasks load operational baseline | Existing context/profile selection сохраняется | Validator + semantic scan + smoke |
| Tool execution rules | Fragmented docs/session-insights | Новый core owner | Context docs ссылаются на owner, не дублируют MUST | Document contract tests |
| Collaboration | `collaboration-baseline.md` | One-writer/read-only reviewer | Existing delegation remains allowed | Semantic checks + scenario review |
| Validation | `testing-baseline.md`, `testing-dotnet.md` | Staged iteration + progress/no-blind-retry; successful full run remains completion gate | No weakening; CI only repo-approved equivalent and must be green | Docs tests + long-run scenario |
| Hook config | Нет user `hooks.json` entries | Installer-owned non-managed groups for `PreToolUse` and `PostToolUse` | Foreign entries preserved; exact definition requires trust | JSON parse + idempotency + trust-state pilot |
| Hook runtime | Нет | Versioned absolute PowerShell dispatcher path in stable Codex home | Fail-open; no mutable command pointer; version update retriggers trust | Synthetic + actual Windows payload tests |
| Agent limits / reviewer | User `config.toml`, no `[agents]`; no enforced reviewer role | `max_threads=4`, `max_depth=1`, custom `independent-reviewer` default read-only | Other TOML preserved; live override recorded | Config parse + child write-denial test |
| Hook telemetry | Нет | Local sanitized JSONL counters | New ignored local data; no repo commit | Privacy tests |
| Session analysis | Ad hoc scripts/queries | Repeatable analyzer schema v1 | Existing session files read-only | Fixture tests + exact baseline denominator/key-category reproduction |
| Local environments | Per-repo/ad hoc | Central contract/template only | No consumer mutation | Onboarding lint |
| Git permissions | Codex sandbox/approval | Proactive scoped approval rule | No config weakening | Behavioral smoke |

## 7. Бизнес-правила / Алгоритмы

### 7.1 Failure classifier precedence
1. Если stderr/structured output указывает permission/auth/lock/missing dependency, категория `environment-blocker` имеет приоритет над generic non-zero.
2. `rg` exit `1` без stderr классифицируется `expected-no-match` и исключается из real-failure numerator.
3. Test failure может быть `expected-tdd-red` только при наличии явного planned-red state и подтверждённой причины; иначе `test-failure`.
4. Timeout не становится product failure без evidence; категория `timeout` плюс subcategory команды.
5. Одинаковый tool call в одном turn считается один раз для unique-failure metric, но retry count сохраняется отдельно.
6. User correction считается strong rework signal только по консервативному словарю и не используется для вывода о намерениях без ручной проверки.

### 7.2 Hook warning threshold
- Warning выдаётся только для deterministic/high-confidence patterns.
- `raw Windows glob` в v1 означает только известные небезопасные формы: wildcard в positional path argument `rg` вместо `-g` либо wildcard перед PowerShell `-LiteralPath`; wildcard в regex/pattern, `rg -g`, `Get-ChildItem -Filter/-Include` и другие fixture-confirmed safe forms warning не получают.
- Bash-heredoc warning требует PowerShell/Windows runtime и command shape вида `python|node|pwsh ... <<`; одиночный `<`, here-string `@'...'@`/`@"..."@` и unrelated operators исключены negative fixtures.
- TUnit `--filter` warning разрешён только для `dotnet test`/test runner command, когда bounded read-only repo evidence подтверждает TUnit package/runner; при timeout или неоднозначности lookup classifier fail-open молчит.
- Если classifier confidence ниже `0.9`, hook пишет только локальный category counter либо ничего; user-facing warning запрещён.
- В `3.1.0` hook не возвращает deny/stop decision.
- Повтор одинакового warning в одном turn подавляется.

### 7.3 Success metrics

| Metric | Baseline | Target after 30 days | Denominator |
| --- | ---: | ---: | --- |
| Tasks with path/glob failure | 40% | <10% | top-level tool-heavy tasks |
| Tasks with failed patch | 40% | <10% | top-level tasks with mutations |
| Tasks with first-attempt Git permission/index failure | 32% | <5% | top-level tasks with Git mutations |
| Tasks with blind identical retry after timeout/patch failure | Baseline to be reconstructed | 0 | classified failure episodes |
| Overlapping subagent writes to same file | Baseline not reliable | 0 | delegated write tasks |
| `rg` no-match counted as real failure | 173 noise events observed | <5% classification error | `rg` exit-1 events |
| Approved specs requiring user-triggered post-EXEC review/fix | 4/11 | <=1/10 | tasks with explicit spec approval |
| Expected TDD red correctly separated | Not reliable | 100% in fixture/sampled review | planned-red test events |

## 8. Точки интеграции и триггеры
- `AGENTS.md` и routing matrix подключают core owner при tool-heavy trigger.
- `PreToolUse` и `PostToolUse` получают documented hook JSON и вызывают единый dispatcher.
- Custom `independent-reviewer` загружается как personal agent config и проходит effective read-only probe.
- Installer работает с `%USERPROFILE%\.codex\config.toml`, non-managed user `%USERPROFILE%\.codex\hooks.json`, personal `%USERPROFILE%\.codex\agents\independent-reviewer.toml`, versioned runtime directory и backup/trust manifest.
- Analyzer читает `sessions` и `archived_sessions` потоково, не изменяя source JSONL.
- Standard validator вызывает semantic markers и `test-agent-operations.ps1` либо документированно запускает его отдельной обязательной командой.
- Onboarding quick-start ссылается на local environment contract.

## 9. Изменения модели данных / состояния
- Новый local install manifest:
  - `schemaVersion`
  - `runtimeVersion`
  - `installedAt`
  - `approvedProposalHash`
  - `installerOwnedHookFingerprints`
  - `installerOwnedReviewerFingerprint`
  - `previousAgentSettings`
  - `backupPath`
  - checksums versioned/runtime files.
- Sanitized telemetry event:
  - `schemaVersion`, `timestamp`, `runtimeVersion`, `eventName`, `category`, `severity`, `action`, `exitClass`, `repoHash`, optional salted `sessionHash`.
- Локальная случайная salt создаётся installer, хранится только в install manifest и не попадает в Git; raw repo/session identifiers не записываются рядом с hashes.
- Запрещённые telemetry fields: raw command, raw stdout/stderr, prompt/response body, absolute cwd/path, file content, env values, secrets.
- Telemetry retention: active log ограничен 10 MB, хранится не более трёх rotated files и не дольше 45 дней; rotation выполняется атомарно без загрузки полного файла в память.
- Backup retention: hard cap — не более 10 successful-install backups. Backups старше 90 дней становятся prune candidates, но последний валидный rollback point не удаляется, даже если он старше age target, пока не появился более новый validated backup. Если следующий backup превысит hard cap или существуют stale non-protected candidates, activation останавливается до записи и показывает `-Prune -WhatIf`; удаление выполняется только отдельным `-Prune` после пользовательского подтверждения preview.
- Runtime retention: в `<CodexHome>\agent-operations\versions` хранится не более трёх installer-owned versions; active version и последняя known-good rollback version protected. Если next install превысит hard cap, activation останавливается до previewed `-Prune`; чужие/изменённые directories и protected versions не удаляются.
- Analyzer summary schema:
  - window and timezone;
  - top-level task/trace/tool-call denominators;
  - category counts/rates;
  - exclusions and classifier version;
  - quality counters for unclassified/parse errors.
- Всё runtime/telemetry state хранится вне Git; `.artifacts/session-insights/` и local reports добавляются в `.gitignore`.

## 10. Миграция / Rollout / Rollback
### EXEC-A: versioned candidate
1. После approval сверить `origin/main`, active central checkout и worktree; rebase branch на актуальный main, сохранив spec. При material instruction/template drift повторить post-SPEC review и остановиться, если требуется новое пользовательское решение.
2. Зафиксировать before behavioral smoke, baseline analyzer output и private-local gold-set aggregate на текущем effective runtime.
3. Реализовать versioned docs/scripts/templates/custom-reviewer/tests только после успешной drift проверки.
4. Запустить standard validators, reviewer write-denial test, hook/installer/analyzer tests, exact-baseline compatibility check, classifier accuracy gate и after behavioral smoke в изолированном checkout.
5. Выполнить post-EXEC review versioned change set. `%USERPROFILE%\.codex\config.toml`, `hooks.json`, personal-agent files и runtime на этой фазе не изменяются.
6. По отдельному Git-полномочию commit/publish/merge change set и синхронизировать active central checkout. Если пользователь ещё не запросил delivery, остановиться с готовым candidate и не переходить к activation.
7. На active central path повторить critical validators и checksum versioned runtime.

### ACTIVATE: отдельный пользовательский gate
8. Выполнить installer `-WhatIf` и показать пользователю exact `config.toml`/`hooks.json`/`agents\independent-reviewer.toml` diff, versioned command path/checksum, backup path, trust steps и rollback command.
9. Остановиться до точной фразы `Глобальную активацию подтверждаю`.
10. После approval повторно проверить drift user config/hooks/reviewer, создать backup, скопировать versioned runtime и транзакционно применить только показанный diff. Hook state после write: `awaiting-trust`.
11. Пользователь проверяет и доверяет exact non-managed hook definition через `/hooks` или актуальный документированный эквивалент; bypass trust запрещён.
12. Запустить controlled новую Codex task: safe call без warning, known-bad `PreToolUse` с model-visible context, подтверждённый `PostToolUse` payload/classification, fail-open case, exact agent limits и reviewer effective read-only. Только после этого hook state становится `active`, а install — verified.
13. Повторить install для idempotency check. Оставить hooks в warn-only минимум на 14 дней; любой blocking mode требует отдельной spec и false-positive evidence.
14. Через 30 дней повторить analyzer той же classifier version; при новой version сформировать параллельный old/new report до сравнения.

Rollback:
- `scripts/install-agent-operations.ps1 -Uninstall` удаляет только hook entries/reviewer/runtime files с совпавшими manifest fingerprints/checksums и возвращает сохранённые agent limits только при отсутствии user drift.
- При повреждённом manifest автоматический uninstall прекращается; восстановление выполняется из указанного timestamped backup с diff preview.
- Uninstall не удаляет backups/logs автоматически. Logs ротируются по 10 MB / 3 files / 45 days; backup/runtime pruning выполняется только через отдельный previewed `-Prune`, сохраняет минимум последний успешный rollback point и active/last-known-good runtime versions.
- Instruction rollback выполняется единым revert change set `3.1.0` на active central path с повторными validators. Перед таким rollback выполняется drift-safe installer uninstall hooks/reviewer/agent limits/runtime; нельзя оставить user-level behavior без соответствующего owner doc и operational support.
- Consumer repos не требуют rollback, потому что в этом релизе не изменяются.

## 11. Тестирование и критерии приёмки

### Acceptance Criteria
- **AC1.** `tool-execution-baseline.md` существует, проходит document contract и является mandatory owner для всех tool-heavy routes.
- **AC2.** Routing не заставляет выбирать `session-insights-context` вместо task-specific context; historical context остаётся targeted lookup layer.
- **AC3.** Core owner формально задаёт path inventory, literal path/glob separation, `rg` exit normalization и Windows-safe PowerShell patterns.
- **AC4.** Patch state machine запрещает identical retry, требует fresh context и возвращает shared-file ownership main agent при repeated conflict.
- **AC5.** Git/worktree rule требует proactive state/approval preflight и явно запрещает `writable_roots` как fix Git metadata protection.
- **AC6.** Collaboration baseline задаёт one-writer, main-owned integration files и serial shared-output validation; versioned custom-agent template содержит required fields и explicit read-only sandbox, а effective behavior подтверждён controlled write-denial test.
- **AC7.** Testing owners задают `targeted -> build -> full`, visible progress, repo-specific timeout strategy, expected-red classification и no-blind-retry, сохраняя successful full run обязательным до завершения behavior-changing задачи; repo-approved CI считается full evidence только после green status.
- **AC8.** Review owner требует independent reviewer для large/high-risk QUEST при доступности, фиксирует effective child sandbox и запрещает называть writable/self fallback read-only independent review.
- **AC9.** Hooks покрывают только `PreToolUse`/`PostToolUse`, не блокируют tools, не используют transcript, завершаются <=2 секунд в fixtures, используют model-visible `additionalContext`, не предупреждают safe calls и отключают classifier при unknown actual payload.
- **AC10.** Installer поддерживает dry-run/install/uninstall/prune, backup, transaction rollback across config/hooks/reviewer/runtime, self-test и двойную idempotent установку.
- **AC11.** После install user config содержит ровно `max_threads=4`, `max_depth=1`, personal reviewer установлен по documented path, foreign TOML/hooks сохранены; foreign/drifted reviewer не перезаписывается, inline-hook representation или managed-only policy дают no-mutation stop, а uninstall изменяет только paths/entries с совпавшим fingerprint.
- **AC12.** Telemetry privacy test доказывает отсутствие raw command/output/prompt/path/env/secret fields.
- **AC13.** Analyzer на synthetic fixtures правильно отделяет real failure, `rg` no-match, expected TDD red, environment blocker и interruption.
- **AC14.** Compatibility check точно воспроизводит denominators `25` top-level tasks, `124` traces, `21 955` tool calls и key-category task counts: paths/globs `10`, failed patch `10`, Git/sandbox `8`, timeout `7`; независимый deterministic gold-set report подтверждает precision >=0.90, recall >=0.80 и false-positive rate <=0.10 либо переводит категорию в `manual-review-only`.
- **AC15.** Same-profile before/after behavioral smoke по пяти сценариям показывает preventive decision до первого отказа.
- **AC16.** Success metrics, denominators и 14/30-day follow-up documented; immediate EXEC не выдаёт targets за уже достигнутые.
- **AC17.** Consumer repos, global sandbox mode и approval policy не изменены; после `EXEC-A` user config/hooks/personal agents/runtime также неизменны.
- **AC18.** Standard validators, new contract tests, `git diff --check`, privacy scan и changelog `3.1.0` проходят.
- **AC19.** Onboarding owner и Windows preflight template существуют, не содержат undocumented `.codex` schema и явно требуют repo-specific rollout вместо скрытой установки зависимостей.
- **AC20.** Global activation proposal запрещён, пока approved commit не присутствует в active central checkout и critical validators/checksum не прошли на active path.
- **AC21.** Installer `-WhatIf` создаёт exact config/hooks/reviewer diff, backup/trust/rollback proposal и `proposalHash` без mutation; только отдельная фраза `Глобальную активацию подтверждаю` разрешает применить этот hash, а drift требует нового preview и approval.
- **AC22.** После install hook state равен `awaiting-trust`; exact versioned non-managed hook definition пропускается Codex до user trust и становится `active` только после controlled post-trust task, которая также подтверждает agent limits и reviewer effective read-only. Mutable command pointer и trust bypass отсутствуют.
- **AC23.** Telemetry автоматически соблюдает 10 MB / 3 files / 45 days; successful-install backup count никогда не превышает 10, installer-owned runtime version count никогда не превышает 3, а stale/excess non-protected state требует previewed `-Prune` до следующей activation. Последний valid backup и active/last-known-good runtime versions не удаляются.

### Команды проверки
```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
pwsh -File scripts/test-agent-operations.ps1
pwsh -File scripts/install-agent-operations.ps1 -WhatIf
pwsh -File scripts/install-agent-operations.ps1 -Prune -WhatIf
pwsh -File scripts/analyze-codex-session-errors.ps1 -Since <utc> -Until <utc> -OutputDirectory .artifacts/session-insights/baseline
git diff --check
rg -n "tool-execution-baseline|one-writer|warn-only|max_threads|expected-no-match|successful full run|independent-reviewer|awaiting-trust" AGENTS.md instructions scripts templates *.toml
# Privacy contract проверяется synthetic output, а не поиском слов в исходниках:
pwsh -File scripts/test-agent-operations.ps1 -Area Privacy
```

Stop rules для validation:
- первый timeout -> собрать progress/log evidence и изменить стратегию; неизменённый retry запрещён;
- hook/installer test, который меняет реальный `%USERPROFILE%\.codex` вместо fixture `-CodexHome`, является test bug и блокирует activation;
- любое раскрытие raw content в telemetry блокирует EXEC;
- behavioral smoke с другой model/surface/reasoning конфигурацией не считается before/after evidence;
- отсутствие active-catalog checksum/validator evidence, exact activation approval или Codex trust evidence блокирует external activation, но не отменяет готовый versioned candidate;
- CI status `pending`, `timeout`, `cancelled` или red не удовлетворяет full-test completion gate;
- если standard validator и new tests расходятся по owner contract, исправить contract/tests, а не обходить проверку.

### Acceptance-to-Test Matrix

| Acceptance criterion | Automated test | Manual / visual / log check | Evidence artifact | If not tested, why |
| --- | --- | --- | --- | --- |
| AC1-AC2 | Validator + semantic marker tests | Проверка routing stack | Validator log | - |
| AC3-AC5 | Document semantic tests + hook fixtures | Behavioral scenarios 1, 2, 5 | Smoke report | - |
| AC6 | Semantic checks + custom-agent config parse + write-denial test | Ownership scenario 4 и effective sandbox inspection | Smoke/review report | - |
| AC7 | Hook/analyzer fixtures | Long-test scenario 3 | Test log + smoke report | - |
| AC8 | Template/review marker tests | Post-SPEC/post-EXEC role review | Review sections | Независимость требует доступного subagent facility |
| AC9 | Synthetic hook contract tests + duration assertion | Actual Windows payload probe before/after trust | Hook test/probe log | Unsupported shell paths explicitly excluded |
| AC10-AC11 | Installer fixture matrix, transaction rollback, foreign-reviewer, inline-hooks/managed-policy stops, double-install/uninstall | Real `-WhatIf`, active config/hooks/reviewer diff | Backup path + install log | - |
| AC12 | Forbidden-field/property tests and content scan | Inspect sample telemetry | Sanitized fixture output | - |
| AC13-AC14 | Analyzer fixtures + exact compatibility run + deterministic-sampling/confusion-matrix checks | Independent gold-set review: all strong corrections and up to 20 positive/20 negative per key category | Summary JSON/MD + private-local gold aggregate | Raw evidence remains only in source sessions; report uses salted IDs |
| AC15 | Не полностью автоматизируется | Same-profile before/after run | `.artifacts/evals/agent-operations-*` | Model behavior requires representative run |
| AC16 | Summary schema checks | 14/30-day follow-up checklist | Baseline report | 30-day target проверяется позже |
| AC17 | Fixture CodexHome tests + Git status | Confirm no real user config/hooks/agents/runtime mutation after EXEC-A | Candidate report | - |
| AC18 | Standard scripts + diff/privacy scans + Linux/Windows CI split markers | Changelog/workflow review | Validation log | - |
| AC19 | Template smoke + documentation links | Проверка через Desktop local environment в отдельном consumer pilot | Template test log | Consumer integration вне scope |
| AC20 | Active HEAD/checksum/validator precondition tests | Inspect active central checkout | Active-path validation artifact | - |
| AC21 | `-WhatIf` no-mutation and proposal-hash/drift assertions across config/hooks/reviewer | User reviews exact diff/hash and gives exact phrase | Activation proposal + user decision | Human approval is intentionally mandatory |
| AC22 | Installer trust-state fixtures + reviewer probe | `/hooks` review plus controlled post-trust task | Trust/pilot/effective-sandbox evidence | Trust cannot be automated or bypassed |
| AC23 | Log rotation, backup/runtime-limit and protected-state fixtures | `-Prune -WhatIf` preview | Retention/prune test log | - |

## 12. Риски и edge cases
- Hook tool names/matcher semantics могут отличаться между Codex versions. Mitigation: runtime probe и fixture на фактически emitted event; unknown event fail-open.
- TOML не имеет built-in parser в PowerShell. Mitigation: точечный managed update с fixture matrix, backup и semantic readback; не сериализовать весь config заново.
- Warn-only сообщения могут стать шумом. Mitigation: confidence >=0.9, suppression per turn, safe-call zero-warning tests и 14-day false-positive review.
- `max_threads=4` может замедлить независимый read-only анализ. Mitigation: это user-level default, а не запрет; изменение измеряется и может быть откатано.
- Repo-approved CI equivalent может скрыть локальный toolchain defect. Mitigation: local preflight/targeted/build обязательны, CI допустим только по owner contract, с итоговым green status и явным указанием локального blocker.
- Required independent reviewer может быть недоступен. Mitigation: documented adversarial fallback и residual risk; не выдавать self-review за независимый.
- Session classifier остаётся heuristic. Mitigation: versioned classifier, parse-error counters и ручная выборка.
- Baseline из 25 задач мал и неоднороден. Mitigation: цели трактуются как operational indicators, не статистическое доказательство.
- Global activation до попадания instruction changes в active central catalog создаёт несогласованный runtime. Mitigation: activation proposal блокируется до approved delivery, active-path commit/checksum evidence и повторных critical validators.
- Existing user hooks/config могут измениться параллельно. Mitigation: drift check непосредственно перед write и abort при несовпадении preview hash.
- Existing user layer может хранить hooks inline в `config.toml` или managed policy может игнорировать non-managed hooks. Mitigation: detect-and-stop без создания второго representation или обхода policy; migration требует отдельного previewed решения.
- Line-ending normalization может создать шумный diff. Mitigation: `.gitattributes`/existing repo policy проверить до broad rewrite; менять только нужные строки.
- Windows-specific junction/reparse tests не исполнимы в existing Ubuntu-only gate. Mitigation: Linux job запускает catalog validator regressions с explicit operational skip, а отдельный `windows-latest` job выполняет полный operational suite.

### Expected User Review Objections

| Likely objection | Why likely | Mitigation in spec/code plan | Status |
| --- | --- | --- | --- |
| «Правила уже есть в session-insights; зачем ещё документ?» | Риск дублирования и роста контекста | Новый core хранит только обязательный компактный contract; history остаётся targeted retrieval | mitigated |
| «Hooks будут мешать и спамить» | Lifecycle warnings видны в каждой задаче | Warn-only, confidence threshold, suppression, safe-call test, no blocking | mitigated |
| «Не меняй глобальный config без моего контроля» | Scope выходит за Git repo и пользователь просил максимальную вовлечённость | `Спеку подтверждаю` не разрешает activation; после exact `-WhatIf` diff и active-catalog evidence требуется отдельная фраза `Глобальную активацию подтверждаю` | mitigated |
| «Снова сделали большую систему, а ошибки останутся» | Инструкции без runtime enforcement уже пропускались | P0 сочетает core routing, hooks, limits, tests и metrics; 30-day follow-up отделён от promises | mitigated |
| «Ограничение subagents ухудшит скорость» | Пользователь ценит параллелизм | Ограничивается fan-out, не полезный параллелизм; four read-only lanes остаются доступны | accepted-risk |
| «Нельзя ослаблять полный прогон тестов» | Full suite важен для delivery | Successful full run остаётся обязательным до завершения behavior-changing задачи; меняются только staged progress, timeout diagnosis и строго ограниченный repo-approved final-green CI equivalent | mitigated |
| «А где реальные repo environment fixes?» | Многие failures связаны с SDK/restore/UI tooling | Central contract входит сейчас; consumer rollout явно выделен в последующие repo-specific specs | accepted-risk |
| «Статистика может считать шум как ошибки» | Уже найдено 173 false-red `rg` events | Separate classifier states, denominators, versioned schema и manual sample | mitigated |
| «Локально всё зелёное, а Ubuntu CI упадёт на Windows junction tests» | Existing workflow был только `ubuntu-latest` | Catalog regressions остаются на Linux, полный operational suite вынесен в обязательный `windows-latest` job | mitigated |

### Rework Prevention Checklist
- Does the spec name what the user will see or operate? Да: warnings, ownership plan, validation progress, installer dry-run и reports описаны.
- Does every user-visible scenario have evidence? Да: hook/installer/analyzer tests и behavioral smoke mapped.
- Did the agent list decisions it assumed? Да: Decision Ledger содержит global activation, concurrency, sandbox и rollout decisions.
- Did the agent predict likely objections and mitigate them? Да: девять objections разобраны.
- Did role-based review run for the relevant task type? Да; user-triggered fresh review выявил findings, исправления и re-review зафиксированы в секции 19.
- Are acceptance criteria verifiers, not preparation steps? Да: AC сформулированы как observable contracts.
- Does EXEC have a path to prove the scenarios before final? Да: commands, artifacts, activation pilot и rollback определены.

## 13. План выполнения
1. После approval фразой `Спеку подтверждаю` начать только `EXEC-A`: rebase branch на актуальный `origin/main`, сверить approved scope с active owners и повторить review при material drift.
2. Зафиксировать before behavioral smoke, gold-set baseline и baseline analyzer output на текущем effective runtime.
3. Добавить core owner и минимально обновить routing/AGENTS/session-insights references.
4. Обновить collaboration, testing, review и onboarding owners без дублирования или ослабления существующих MUST; добавить custom `independent-reviewer` с read-only default и write-denial test.
5. Реализовать `PreToolUse`/`PostToolUse` dispatcher, template, release payload probe и synthetic contract tests.
6. Реализовать installer с fixture Codex homes, `-WhatIf`/install/uninstall/prune, backup, retention, idempotency и user-drift tests.
7. Реализовать analyzer, gold-set evaluation, fixtures, privacy schema, classifier migration report и ignored artifact paths.
8. Добавить semantic validator checks и changelog `3.1.0`.
9. Запустить standard validation, new tests, privacy scan, full required test run, diff check и after behavioral smoke.
10. Выполнить post-EXEC review; исправить findings и повторить affected checks.
11. Если отдельная Git delivery authority не дана, остановиться с готовым versioned candidate без commit/push/merge и без global activation.
12. После отдельно разрешённых commit/publish/merge синхронизировать active central checkout, проверить его commit identity и повторить critical validators на active path.
13. Выполнить exact global `-WhatIf` и предъявить пользователю diff, `proposalHash`, backup destination, retention/prune state и evidence, что active central catalog уже содержит соответствующие instruction changes.
14. Остановиться до отдельной точной фразы `Глобальную активацию подтверждаю`; она разрешает только показанный `proposalHash`, а drift аннулирует approval.
15. После этой фразы транзакционно установить immutable versioned runtime, `[agents]` limits, hook definitions и personal reviewer; hook state после записи равен `awaiting-trust`, а не `active`.
16. После ручного trust exact non-managed hook definition через `/hooks` или актуальный документированный эквивалент запустить controlled new task, подтвердить hooks `active`, exact agent limits и reviewer effective read-only, проверить idempotency/rollback/retention evidence и завершить отчёт с 14/30-day follow-up.

## 14. Открытые вопросы
Для `EXEC-A` блокирующих вопросов нет. Global activation намеренно имеет два последующих human gate: отдельную Git delivery authority для попадания versioned изменений в active central catalog и точную фразу `Глобальную активацию подтверждаю` после предъявления exact `-WhatIf`. Это фазовые stop conditions, а не неразрешённые design questions; consumer repo rollout и blocking hooks остаются вне scope.

## 15. Соответствие профилю
- Профиль: `catalog-governance`, `product-system-design`; context `session-insights-context`; QUEST SPEC.
- Выполненные требования профиля:
  - использован canonical template активного central catalog;
  - выделены owner boundaries и исключено дублирование session-insights;
  - описаны surface/effective runtime и same-profile behavioral smoke;
  - определены runtime/config/data contracts, migration, rollback и external activation boundary;
  - session-derived evidence рассматривается как heuristic baseline, а не абсолютная истина;
  - изменение каталога проходит SemVer/changelog и standard validators;
  - на фазе SPEC меняется только рабочая спецификация.

## 16. Таблица изменений файлов

| Файл | Изменения | Причина |
| --- | --- | --- |
| `specs/2026-07-17-agent-operational-error-prevention.md` | Working spec и review evidence | QUEST gate |
| `AGENTS.md` | Pointer на mandatory operational owner | Entry-point discoverability |
| `instructions/core/tool-execution-baseline.md` | Новый owner operational rules | Prevention до tool call |
| `instructions/governance/routing-matrix.md` | Tool-heavy trigger и owner stack | Обязательная доставка контекста |
| `instructions/core/collaboration-baseline.md` | One-writer/read-only reviewer contract | Предотвращение write conflicts |
| `instructions/core/testing-baseline.md` | Staged progress/evidence без ослабления final full-run MUST | Предотвращение timeout loops с сохранением completion gate |
| `instructions/contexts/testing-dotnet.md` | TUnit/full-run/допустимый final-green CI contract | .NET-specific correctness |
| `instructions/governance/review-loops.md` | Independent and guided-artifact review | Снижение поздних исправлений |
| `instructions/contexts/session-insights-context.md` | Явная роль retrieval layer | Устранение ownership ambiguity |
| `instructions/onboarding/local-environment.md` | Новый consumer preflight contract | Environment readiness |
| `instructions/onboarding/quick-start.md` | Ссылка на preflight/local environment owner | Adoption |
| `templates/codex/local-environment/README.md` | Как подключить preflight через generated local environment config | Не изобретать unstable schema |
| `templates/codex/local-environment/preflight.ps1` | Parameterized Windows toolchain/preflight template | Практическая environment мера |
| `templates/codex/agent-operations-hooks.json` | Versioned hook event config | Reproducible activation |
| `scripts/hooks/agent-operations-hook.ps1` | Warn-only dispatcher | Mechanical high-confidence feedback |
| `templates/codex/agents/independent-reviewer.toml` | Versioned personal custom reviewer с required fields и `sandbox_mode = "read-only"` | Проверяемый source для independent review |
| `scripts/install-agent-operations.ps1` | Install/update/uninstall/backup | Safe global activation |
| `scripts/analyze-codex-session-errors.ps1` | Repeatable privacy-safe metrics | 30-day verification |
| `scripts/test-agent-operations.ps1` | Runtime/installer/analyzer/privacy tests | Regression protection |
| `scripts/fixtures/agent-operations/*` | Synthetic hooks/config/session inputs | Deterministic tests |
| `scripts/validate-instructions.ps1` | Mandatory markers/new doc checks | Enforceability |
| `scripts/test-validate-instructions.ps1` | Validator regressions | Contract alignment |
| `.github/workflows/validate-instructions.yml` | Разделение Linux catalog и Windows operational gates | Проверять target-specific filesystem semantics в поддерживаемой среде |
| `.gitignore` | Ignore local reports/evals | Privacy and clean Git state |
| `README.md` | Краткий rollout/operational owner pointer | Catalog navigation |
| `CHANGELOG.md` | `3.1.0` Added/Changed/Migration/Rollback | Versioning policy |
| `%USERPROFILE%\.codex\config.toml` | Только `[agents]` limits | Ограничить accidental fan-out |
| `%USERPROFILE%\.codex\hooks.json` | Installer-owned non-managed `PreToolUse`/`PostToolUse` entries после отдельного approval | Активировать lifecycle feedback без trust bypass |
| `%USERPROFILE%\.codex\agents\independent-reviewer.toml` | Installer-owned exact copy versioned template после отдельного approval; foreign/drifted file блокирует write | Активировать технически read-only reviewer без скрытой перезаписи |
| `%USERPROFILE%\.codex\agent-operations\*` | Installed immutable runtime versions и manifest; hook command использует exact versioned path | Stable external runtime и повторный trust при update |
| `%USERPROFILE%\.codex\backups\agent-operations\*` | Timestamped pre-install backups | Проверяемый rollback |
| `%USERPROFILE%\.codex\logs\agent-operations*.jsonl` | Sanitized bounded/rotated category counters | Warn-only pilot telemetry |

Consumer repositories отсутствуют в таблице и не должны изменяться.

## 17. Таблица соответствий (было -> стало)

| Область | Было | Стало |
| --- | --- | --- |
| Historical lessons | Optional context after routing choice | Optional retrieval plus mandatory compact core rules |
| Paths/globs | Reactive command correction | Preflight inventory + hook warning |
| `rg` exit 1 | Часто false-red failure | Explicit expected-no-match state |
| Patch retry | Ad hoc repeat | Finite reread/rehunk/ownership state machine |
| Git worktree permissions | First failure reveals sandbox | Proactive state + scoped approval decision |
| Subagents | Up to default 6, ownership implicit | Max 4, depth 1, one writer per file; custom reviewer read-only default и effective-sandbox evidence |
| Validation | Full local run as unconditional final step | Targeted/build progress плюс сохранённый обязательный full-run completion gate; CI только по owner contract и после final green |
| Review | Full QUEST self-review | Independent read-only pass для large/high-risk, write-denial probe и честное fallback disclosure |
| Hooks | Нет | Два warn-only event (`PreToolUse`/`PostToolUse`), model-visible context, explicit user trust и fail-open |
| Environment onboarding | Per-repo ad hoc | Central preflight/action contract, repo rollout separately |
| Session analysis | One-off scripts | Versioned classifier and privacy-safe comparable report |
| Improvement proof | Anecdotal | Baseline, 14-day warning review, 30-day targets |

## 18. Альтернативы и компромиссы

### Вариант A: Только расширить `session-insights-context`
- Плюсы: минимальный diff, нет runtime components.
- Минусы: context остаётся конкурирующим выбором; правило может не загрузиться до ошибки; нет measurement loop.
- Почему не выбран: не устраняет корневую проблему timing/routing.

### Вариант B: Только hooks
- Плюсы: механическая доставка в нужный момент.
- Минусы: hooks видят ограниченный event payload, не заменяют judgement, ownership и validation policy; возможен шум.
- Почему не выбран: runtime guard без owner instructions будет хрупким и непрозрачным.

### Вариант C: Глобальный `danger-full-access` или broad auto-approval
- Плюсы: меньше Git permission failures.
- Минусы: резко расширяет blast radius и не решает paths, patches, tests, rework.
- Почему не выбран: несоразмерный security tradeoff.

### Вариант D: Сразу blocking hooks
- Плюсы: максимальное механическое предотвращение.
- Минусы: classifier ещё не измерен; false positives могут блокировать нормальную работу.
- Почему не выбран: сначала нужен warn-only pilot.

### Вариант E: Плагин с hooks/skills
- Плюсы: удобная упаковка и обновление.
- Минусы: лишний packaging/install layer для одного пользователя; config `[agents]` всё равно внешний.
- Почему не выбран: versioned scripts + installer проще проверить и откатить; plugin можно рассмотреть после pilot.

### Вариант F: Немедленно изменить все consumer repos
- Плюсы: быстрее закрывает missing dependency/setup issues.
- Минусы: разные toolchains, большой cross-repo scope, высокий риск stale assumptions.
- Почему не выбран: сначала central contract, затем repo-specific rollout по реальному состоянию.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, measured AS-IS, root problem, design goals и жёсткие non-goals зафиксированы |
| B. Качество дизайна | 6-10 | PASS | Owner boundaries, two-event hook contract, trust states, classifier/gold set, retention и failure handling определены |
| C. Безопасность изменений | 11-13 | PASS | `EXEC-A` не меняет user config; activation защищена active-catalog gate, отдельным approval, backup/drift/fingerprint checks и Codex trust |
| D. Проверяемость | 14-16 | PASS | AC1-AC23 сопоставлены tests/checks/evidence; exact compatibility, accuracy gate и same-profile smoke заданы |
| E. Готовность к автономной реализации | 17-19 | PASS | Dependency order и stop rules однозначны; `EXEC-A` готов, а Git delivery, activation и trust оставлены явными human gates |
| F. Соответствие профилю | 20 | PASS | QUEST, catalog governance, product-system-design и session-insights trust boundaries соблюдены |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Prevention outcome, `EXEC-A`/activation boundary, consumer non-goals и delayed metrics отделены |
| 2. Понимание текущего состояния | 5 | Current owner docs, routing gap, runtime config и measured 30-day baseline описаны с ограничениями |
| 3. Конкретность целевого дизайна | 5 | Core owner, one-writer, preserved full-run gate, two-event hooks, installer, analyzer/gold set и schemas определены |
| 4. Безопасность (миграция, откат) | 5 | Active-catalog/approval/trust gates, fail-open hooks, bounded state, backup, fingerprint uninstall и user-drift behavior заданы |
| 5. Тестируемость | 5 | Actual payload probe, synthetic fixtures, write-denial/privacy/installer/accuracy tests и пять behavioral scenarios mapped |
| 6. Готовность к автономной реализации | 5 | File plan, ordered `EXEC-A`, activation preconditions, stop rules и intentionally deferred human decisions зафиксированы |

Итоговый балл: 30 / 30
Зона: готово к `EXEC-A`; user-level activation не автономна и требует последующих delivery, approval и trust gates

### Role-Based Review Result

| Role | Applicability | Review question | Verdict | Required spec changes |
| --- | --- | --- | --- | --- |
| Business analyst / domain workflow | applicable | Соответствует ли prevention workflow повторным проблемам и заявленной вовлечённости пользователя? | PASS | `Спеку подтверждаю` ограничено `EXEC-A`; activation требует отдельной точной фразы после observable proposal |
| UX / designer | applicable как agent workflow UX | Не создают ли warnings/trust/setup скрытую работу или постоянный шум? | PASS | Только два релевантных event, model-visible high-confidence context, suppression, explicit `awaiting-trust` и safe-call zero-warning |
| Tester / validation | applicable | Не ослаблен ли existing full-run MUST и проверяется ли точность classifier? | PASS | Full-run completion gate сохранён; CI только repo-approved/final-green; добавлены write-denial, payload probe, gold set и retention fixtures |
| Developer / architect | applicable | Согласованы ли owner boundaries, event payloads и activation order? | PASS | `SessionStart`/`Stop` исключены; actual payload probe обязателен; immutable runtime активируется только после active catalog |
| Delivery / operations / security | applicable | Безопасны ли non-managed hooks, user config, telemetry/backups и rollback? | PASS | Добавлены Codex trust, second approval, manifest fingerprint, user-drift-safe uninstall и bounded retention/prune |

### Post-SPEC Review
- Статус: PASS
- Scope reviewed: `specs/2026-07-17-agent-operational-error-prevention.md`, active central `AGENTS.md`, routing/QUEST/review/testing/document/version owners, canonical template, worktree HEAD `b689110` vs active central HEAD `a19ca21`, user Codex config boundary, official hooks/subagents/local-environment/sandbox contracts и measured session-analysis baseline.
- Decision: можно запрашивать `Спеку подтверждаю` только для `EXEC-A`; эта фраза не разрешает commit/push/merge или user-level activation.
- Review passes:
  - Scope/Evidence pass: PASS; 25-task/124-trace baseline имеет явные denominators/exclusions, а 30-day targets не представлены как уже достигнутые.
  - Contract pass: PASS; mandatory core, optional historical context, two-event runtime, non-managed hook trust, user config и consumer onboarding имеют отдельных owners и совместимые границы.
  - Adversarial risk pass: PASS after fixes; проверены premature activation, untrusted/skipped hooks, wrong event semantics, config corruption, foreign-hook deletion, branch drift, warning spam, raw-data leakage, classifier false positives, blind retries и unbounded retention.
  - Role-Based pass: PASS; agent workflow, testability, architecture и delivery/security рассмотрены отдельно.
  - Re-review after fixes / Fix and re-review: PASS; после девяти findings повторно проверены metadata, hook/reviewer/testing contracts, state model, rollout, AC1-AC23, file/correspondence tables и rollback.
  - Stop decision: PASS для `EXEC-A`; external activation обязана остановиться до active-catalog evidence, exact `-WhatIf`, отдельной фразы `Глобальную активацию подтверждаю` и последующего Codex trust.
- Evidence inspected:
  - `C:\Users\Kibnet\.codex\agents\AGENTS.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/core/quest-mode.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/collaboration-baseline.md`
  - `instructions/core/testing-baseline.md`
  - `instructions/contexts/testing-dotnet.md`
  - `instructions/contexts/session-insights-context.md`
  - `instructions/governance/review-loops.md`
  - `instructions/governance/spec-linter.md`
  - `instructions/governance/spec-rubric.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`
  - `templates/specs/_template.md`
  - current worktree status/HEAD and active central main HEAD
  - [official Codex hooks contract](https://learn.chatgpt.com/docs/hooks)
  - [official Codex subagents contract](https://learn.chatgpt.com/docs/agent-configuration/subagents)
  - [official Codex local environments](https://learn.chatgpt.com/docs/environments/local-environment)
  - [official Codex sandboxing](https://learn.chatgpt.com/docs/sandboxing)
  - current-turn 30-day aggregate analysis and classifier caveats
- Depth checklist:
  - Scope drift / unrelated changes: PASS; edits этого агента ограничены текущим working spec. Уже изменённые `specs/2026-04-17-comment-language-policy.md` и `specs/2026-04-24-routing-ui-tunit-mcp.md` не читались и не редактировались; consumer repos и global config не затронуты.
  - Acceptance criteria: PASS; AC1-AC23 имеют automated/manual/log evidence или явную отсрочку 30-day outcome.
  - User-observable scenarios / Decision ledger / Expected objections: PASS; `EXEC-A`, delivery, activation, trust, warnings, concurrency, validation и reports покрыты.
  - Validation evidence: PASS для SPEC; standard validators и structural checks прошли, EXEC tests/smoke определены заранее.
  - Unsupported claims: PASS; statistics описаны как measured baseline/heuristic classifier, а hooks/subagent claims привязаны к documented contracts и release payload probe.
  - Regression / edge case: PASS after fixes; предусмотрены untrusted definitions, unknown payload, unsupported interception path, foreign hooks, TOML drift, hook failure, missing manifest, unavailable feature, malformed JSONL, long archive и retention overflow.
  - Comments/docs/changelog: PASS; planned `3.1.0` and onboarding/readme changes перечислены, unrelated docs исключены.
  - Hidden contract change: PASS; user-level paths/keys, non-managed trust, approval effect и retention явно перечислены; broad sandbox weakening и trust bypass запрещены.
  - Manual-review challenge: наиболее вероятны замечания «подтверждение спеки не должно менять global config», «hooks ещё не trusted», «event срабатывает не в тот момент», «полный test gate ослаблен», «classifier ошибается». Для каждого возражения введён observable gate или measurable test.
- No-findings justification: Не применимо; user-triggered review выявил девять findings, после исправлений выполнен повторный adversarial review.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| HIGH | hook trust/security | User-level hooks ошибочно трактовались как managed/сразу active, хотя exact definition пропускается до явного trust | Назвать source non-managed, ввести `awaiting-trust`, immutable command path, `/hooks` review и запрет trust bypass | fixed |
| HIGH | hook event contract | `SessionStart` не знает task intent, `Stop` срабатывает каждый turn, а `PreToolUse.systemMessage` не даёт model-visible guidance | Оставить только `PreToolUse`/`PostToolUse`, использовать `additionalContext`, требовать actual payload probe и исключить unsupported paths | fixed |
| HIGH | activation ordering | Runtime мог активироваться из unmerged feature branch до появления instruction owners в active central catalog | Разделить `EXEC-A`/`ACTIVATE`; требовать approved delivery, active HEAD/checksum и повторные critical validators | fixed |
| HIGH | user control/governance | Одна фраза `Спеку подтверждаю` неявно разрешала global config mutation вопреки требованию максимальной вовлечённости | Ограничить её versioned implementation; после exact `-WhatIf` требовать отдельную фразу, привязанную к `proposalHash`, и аннулировать approval при drift | fixed |
| HIGH | testing/versioning | Произвольный 15-minute budget и `full-or-CI` ослабляли existing successful-full-run MUST, что делало `3.1.0` несовместимым | Удалить universal budget, сохранить completion gate; CI разрешать только как repo-approved equivalent после final green | fixed |
| MEDIUM | review enforcement | Read-only reviewer обеспечивался только текстовой инструкцией и мог унаследовать writable parent sandbox | Добавить schema-valid versioned personal-agent template, documented install path, explicit read-only default, effective-sandbox evidence и controlled write-denial test | fixed |
| MEDIUM | classifier validity | Exact воспроизведение старых counts проверяло совместимость, но не accuracy и допускало selection/false-negative bias | Добавить independently sampled private-local gold set, confusion matrix, thresholds precision 0.90 / recall 0.80 / FPR 0.10 и `manual-review-only` fallback | fixed |
| MEDIUM | retention/operations | Telemetry logs, backups и immutable runtime versions не имели полного ограниченного retention/prune contract | Ограничить logs 10 MB/3 files/45 days, backups count 10/age target 90 days и runtimes count 3; требовать previewed prune с protected rollback state | fixed |
| LOW | review hygiene | Rework checklist содержал устаревший placeholder и итог ревью ссылался на прежний набор AC | Зафиксировать фактически выполненный review и синхронизировать все ссылки с AC1-AC23 | fixed |

- Fixed before continuing:
  - Разделены versioned implementation, Git delivery, proposal-hash-bound user activation и Codex trust.
  - Hook design сокращён до двух корректно привязанных event с model-visible context и actual payload probe.
  - Existing full-run MUST сохранён; arbitrary timeout policy удалена.
  - Reviewer install/enforcement, classifier precision/recall/FPR и bounded log/backup/runtime retention получили отдельные tests/AC.
  - Inline-hook/managed-policy conflicts и foreign reviewer переведены в no-mutation stop conditions.
  - Обновлены rollout, state model, file/correspondence tables, objections и review trail.
- Checks rerun:
  - Structural required-sections/AC1-AC23/trailing-whitespace check: PASS.
  - `pwsh -File scripts/validate-instructions.ps1`: PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1`: PASS.
  - Final untracked-file whitespace scan и `git diff --no-index --check`: PASS; line-ending warning, если Git его выдаёт отдельно, не классифицируется как trailing-whitespace defect.
- Needs human: approval `Спеку подтверждаю` для `EXEC-A` получен 2026-07-17; позднее всё ещё требуются отдельные Git delivery authority, activation phrase и manual hook trust.
- Residual risks / follow-ups:
  - Runtime, analyzer и instruction/governance lanes получили отдельные independent read-only review с повторной проверкой после исправлений; итоговый repository gate завершён `PASS`.
  - Hook matcher/tool payload может измениться между Codex versions; runtime probe и fail-open behavior обязательны.
  - Consumer repo setup остаётся отдельным rollout и не улучшится только от central template.
  - 14/30-day effectiveness и false-positive rate нельзя подтвердить до накопления новых задач.
  - Большой change set следует коммитить логически раздельно: instructions, runtime/tests, activation/docs.

### Post-EXEC Review
- Статус: PASS; runtime, analyzer и instruction/governance independent review завершены `PASS`, шесть governance findings исправлены и подтверждены re-review, финальные repository gates пройдены. Фазы Git delivery и `ACTIVATE` не начинались.
- Scope reviewed: approved spec; `git status --short`; tracked и untracked candidate diff; central owner/routing/testing/review/onboarding changes; `.github/workflows/validate-instructions.yml`; hook/installer/probe/analyzer runtime; fixtures/schemas; validators; README/changelog; ignored behavioral/private-gold evidence. Уже изменённые `specs/2026-04-17-comment-language-policy.md` и `specs/2026-04-24-routing-ui-tunit-mcp.md` отделены как pre-existing line-ending-only changes и не редактировались.
- Decision: versioned `EXEC-A` завершён `PASS`. Initial independent governance review вернул `NEEDS-FIX` с 3 HIGH, 2 MEDIUM и 1 LOW; все findings получили regression/contract fix, а focused independent re-review в effective `read-only` sandbox вернул `Нет находок` / `VERDICT: PASS`. `%USERPROFILE%\.codex`, consumer repositories, hooks trust и active runtime не активировались; commit/push/merge не выполнялись.
- Review passes:
  - Scope/Evidence pass: PASS after fixes; versioned candidate включает только approved operational-prevention scope плюс обязательный CI portability fix, raw reviewer harness удалён из candidate, local evidence остаётся в ignored paths.
  - Contract pass: PASS; mandatory tool owner, testing full-run gate, Desktop-only local-environment surface, activation/Git boundaries и Linux catalog / Windows operational CI split согласованы и подтверждены independent re-review.
  - Adversarial risk pass: PASS after fixes; отдельно проверены Ubuntu/NTFS incompatibility, executable PowerShell array syntax, ignored/private Markdown isolation, unsupported CLI claim, stale counts и raw review artifacts.
  - Role-Based pass: PASS locally; tester, developer/architect и delivery/operations/security findings устранены. Business/domain и UI design не применимы, поскольку product/domain/UI behavior не меняется; onboarding UX проверен developer/tester passes.
  - Re-review after fixes / Fix and re-review: targeted Privacy 20 assertions, validator, 18 catalog scenarios, `baseline-v4`, full operational 326 assertions и оба standard gates PASS; focused independent governance re-review не нашёл новых defects.
  - Installer/security pass: PASS after independent fix/re-review; manifest self-binding, physical alias lock, reparse checks, captured runtime bytes, exact proposal/live-input hash, transactional rollback, bounded activation evidence и evidence-bound `awaiting-trust -> active` transition покрыты fixtures.
  - Hook/telemetry pass: PASS after independent fix/re-review; allowlisted salted identifiers, no-raw-content privacy, physical telemetry lock, atomic warning state/append/rotation, recovery marker/quarantine и concurrent append проверены, включая fault-injection paths.
  - Analyzer/privacy pass: PASS after independent fix/re-review with bounded fallback; `baseline-v4` сохранил `21 955` legacy envelopes, `14 269` direct envelopes / `14 267` matched direct, `7 686` matched wrappers и 28 additional recognized envelopes без matched calls. Pairing-quality counters, trace deduplication, root-task aggregation, duplicate call IDs и Since/Until boundaries имеют regression coverage.
  - Behavioral smoke pass: PASS; isolated before checkout `a19ca21` и after candidate запущены на одинаковых Codex CLI / `gpt-5.6-sol` / `xhigh` / `workspace-write`. Independent reviewer оценил before `0/5`, after `5/5` и подтвердил concrete improvement по каждому сценарию.
  - Reviewer enforcement pass: PASS для controlled evidence; отдельный `codex exec --sandbox read-only` реально попытался выполнить `Set-Content`, получил policy denial, probe-файл отсутствует. Initial governance reviewer также зафиксировал effective child sandbox `read-only`; его raw host-wrapper artifacts удалены из candidate.
  - Stop decision: PASS для versioned `EXEC-A`; workflow останавливается перед внешними side effects. Отдельно потребуются Git delivery authority, active-catalog evidence, exact global `-WhatIf`, hash-bound approval и ручной Codex hook trust.
- Role-Based Review Result:
  - Business analyst / domain workflow: не применимо; доменная логика и business workflow не меняются.
  - UX / designer: не применимо для UI; onboarding command UX проверен как copy-ready developer/tester contract.
  - Tester / validation: PASS after fixes; CI split, multi-command preflight и ignored-link regression добавлены, полный gate green.
  - Developer / architect: PASS after fixes; owner boundaries, Desktop surface и analyzer/runtime contracts согласованы.
  - Delivery / operations / security: PASS after fixes; Windows filesystem tests вынесены в `windows-latest`, raw reviewer artifacts удалены, activation остаётся отдельным gate.
- Evidence inspected:
  - PowerShell AST parse восьми scripts и JSON parse трёх schemas плюс hook manifest template: PASS.
  - Targeted suites: Hooks 74, Installer 155, Analyzer 77, Privacy 20 assertions; все PASS.
  - `pwsh -NoProfile -File scripts/test-agent-operations.ps1 -Area All`: PASS, 326 assertions.
  - `pwsh -NoProfile -File scripts/validate-instructions.ps1`: PASS.
  - `pwsh -NoProfile -File scripts/test-validate-instructions.ps1`: PASS, 18 catalog scenarios и полный operational suite 326 assertions.
  - Exact compatibility `baseline-v4` для `[2026-06-17T11:05:24.066Z, 2026-07-17T11:05:24.066Z)`: PASS; 25 top-level tasks, 124 traces, key task counts `10/10/8/7`, malformed lines `0`, boundary pairs `0`, duplicate call IDs `0`.
  - Private-local gold aggregate: matrices `19/1/19/1`, `20/0/20/0`, `7/13/20/0`, `19/1/19/1` в порядке `tp/fp/tn/fn`; 27/27 unique strong corrections confirmed; `git-sandbox` честно остаётся `manual-review-only`.
  - Focused independent governance re-review: effective sandbox `read-only`, `Нет находок`, `VERDICT: PASS`; worktree artifacts не создавались, temp raw streams удалены после получения verdict.
  - `git diff --check`: PASS; CRLF conversion notices не являются whitespace defects.
  - Privacy/profile check: accidental top-level fixture paths и user-level hooks/reviewer/runtime отсутствуют. `.codex\config.toml` timestamp остаётся `2026-07-18T10:10:00.7230097Z`; hooks/install manifest отсутствуют.
- Depth checklist:
  - Scope drift / unrelated changes: PASS; CI workflow добавлен только для исполнения approved Windows-specific tests, два pre-existing spec line-ending diff отделены.
  - Acceptance criteria: PASS locally; AC1-AC23 имеют automated/manual/log evidence либо явную deferred activation/14/30-day границу.
  - User-observable scenarios / Acceptance-to-test matrix / Expected objections: PASS; preflight, timeout, Git, hooks, installer, activation, analyzer и новый Ubuntu/Windows objection mapped.
  - Validation evidence: PASS; exact commands/counts перечислены выше, independent governance re-review завершён `PASS`.
  - Unsupported claims: PASS after fixes; CLI local-environment support удалён, Desktop contract привязан к официальной поверхности.
  - Regression / edge case: PASS; CI OS mismatch, array binding, ignored Markdown, duplicate traces/calls, boundary pairs, reparse races, rollback/quarantine и privacy covered.
  - Comments/docs/changelog: PASS; README, CHANGELOG, onboarding, workflow и spec синхронизированы.
  - Hidden contract change: PASS; Linux catalog validation сохраняется, Windows runtime tests добавлены отдельным job, global activation и user policy не меняются.
  - Manual-review challenge: independent review нашёл CI portability, stale final evidence, host-wrapper artifacts, broken array syntax, unsupported CLI claim и non-hermetic link scan; все шесть устранены и отправляются на re-review.
- No-findings justification: initial review имел findings и они перечислены ниже; final focused re-review не нашёл новых defects после проверки всех шести fixes, cross-contract sanity и post-EXEC completeness.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| HIGH | CI / validation | Ubuntu job безусловно запускал Windows junction/reparse suite | Разделить Linux catalog regressions и полный `windows-latest` operational job; защитить split validator-ом | fixed, re-review PASS |
| HIGH | evidence | После последних runtime/analyzer fixes не было полного актуального standard gate | Повторить оба canonical scripts на стабильном snapshot и зафиксировать counts | fixed, re-review PASS |
| HIGH | review hygiene / privacy | Host wrapper создавал raw неигнорируемые prompt/stdout/stderr files в worktree | Удалить artifacts; следующий reviewer запускать из `%TEMP%`, сохранять только sanitized ignored final при необходимости | fixed, re-review PASS |
| MEDIUM | onboarding command | Comma-separated `-RequiredCommand git,pwsh,dotnet` связывался как одно имя | Использовать PowerShell array syntax и добавить required/optional multi-command regression | fixed, re-review PASS |
| MEDIUM | surface contract | Local environments ошибочно заявлялись для CLI | Ограничить owner/quick-start/template подтверждённой Codex Desktop поверхностью | fixed, re-review PASS |
| LOW | validator isolation | Markdown link scan читал ignored `.artifacts` и private-local files | Исключить ignored evidence/private-local paths и добавить broken-link isolation scenario | fixed, re-review PASS |

- Fixed before final report: все шесть governance findings, предшествующие runtime/analyzer findings и stale post-EXEC evidence.
- Checks rerun: AST/JSON parse; Privacy 20; validator; 18 catalog scenarios; `baseline-v4`; operational All 326; оба standard gates; `git diff --check`.
- Unrelated changes: `specs/2026-04-17-comment-language-policy.md` и `specs/2026-04-24-routing-ui-tunit-mcp.md` остаются pre-existing line-ending-only и не включаются в текущий scope.
- Execution incident and remediation: в одном изолированном installer debug invocation имя переменной `$home` столкнулось с read-only `$HOME`, из-за чего fixture кратковременно был направлен в `C:\Users\Kibnet`, но не в `.codex`. Созданные exact paths были удалены через managed uninstall/точечную очистку и повторно подтверждены отсутствующими; реальный `.codex\config.toml` не изменился. Test harness использует `$codexHome`, уникальный system-temp root и проверку границ cleanup.
- Current fix-run incidents: первый gold baseline превысил 120-second shell timeout; после profiling устранено четырёхкратное построение review text. Первый `xhigh` before smoke превысил 300 seconds и оставил child process; exact PID остановлен, повтор с 600-second budget завершился. Encoded background reviewer invocation был отклонён exec-policy до старта; прозрачный wrapper сработал, после review его raw artifacts удалены и re-review переводится во внешний `%TEMP%` harness. Идентичные failed invocation не повторялись без новой гипотезы.
- Deferred activation evidence: actual trusted Windows Desktop release payload, user trust exact hook definition и persisted active-state в реальном `%USERPROFILE%\.codex` остаются gates `ACTIVATE`. Versioned activation probe и fixture state transition готовы, но не выдаются за global activation.
- Needs human after repository `PASS`: отдельное полномочие на Git delivery. Только после попадания commit в active central catalog можно сформировать exact global `-WhatIf`; для его применения потребуется отдельная фраза `Глобальную активацию подтверждаю` для показанного `proposalHash`.
- Residual risks / follow-ups: GitHub-hosted `windows-latest` job ещё не запускался до commit/push; actual Desktop hook trust/payload и 14/30-day effectiveness остаются намеренно deferred, а consumer local-environment rollout требует отдельной repo-specific спеки.

## Approval
`EXEC-A` подтверждён пользователем фразой `Спеку подтверждаю` 2026-07-17. Это подтверждение не разрешает commit/push/merge или global activation.

## 20. Журнал действий агента

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Сверить active central stack и canonical template | 0.99 | Нет | Составить working spec | Нет | Нет | Worktree отстаёт от active main, поэтому owner docs/template прочитаны из `C:\Users\Kibnet\.codex\agents` | Central `AGENTS.md`, routing, QUEST, review, testing, template, changelog |
| SPEC | Перевести session analysis в layered prevention design | 0.94 | 30-day follow-up ещё не существует | Зафиксировать instructions/runtime/config/telemetry contracts | Нет | Нет | Частые ошибки требуют обязательного core слоя и механической обратной связи, а не только historical context | Этот spec |
| SPEC | Создать working specification | 0.93 | Нужен обязательный post-SPEC review | Выполнить linter/rubric/role-based/adversarial review | Нет | Нет | Global activation выделена из versioned implementation и до review остаётся заблокированной | Этот spec |
| SPEC | Выполнить initial post-SPEC review и fix/re-review | 0.97 | Independent subagent review не требуется действующим stack | Повторить structural/standard/whitespace checks | Нет | Нет | Исправлены rollback fingerprint/drift, exact compatibility, branch drift, privacy и local-environment contract | Этот spec |
| SPEC | Выполнить user-triggered fresh review | 0.99 | Требовалась сверка с current official hook/subagent contracts и existing testing MUST | Выдать findings по severity до summary | Да | Да: пользователь запросил `Сделай ревью спеки` | Найдены 5 HIGH, 3 MEDIUM и 1 LOW: trust/event semantics, activation order/control, testing, reviewer enforcement, accuracy, retention и review drift | Этот spec; official Codex docs; active central owners read-only |
| SPEC | Исправить findings и повторить adversarial review | 0.99 | Нет | Синхронизировать все contracts/AC/tables, затем запустить validators | Нет | Да: пользователь дал команду `Исправь` | Все девять findings переведены в explicit gates, tests или bounded state; unrelated modified specs не затронуты | Только этот spec |
| SPEC | Завершить quality gate | 0.99 | Только approval `EXEC-A` | Запросить фразу `Спеку подтверждаю`; не переходить к Git delivery или activation автоматически | Да | Нет | Linter PASS, rubric 30/30, role review PASS, validators и final whitespace check прошли | Этот spec, validator scripts read-only |
| EXEC | Синхронизировать branch и проверить drift | 0.99 | Нет | Реализовать только versioned scope | Нет | Да: пользователь подтвердил `EXEC-A` | Branch без собственных commit fast-forward перенесён с `b689110` на `a19ca21`; material spec drift не найден | Worktree, approved spec, central owners |
| EXEC | Реализовать instruction и onboarding owners | 0.98 | Нет | Перейти к runtime/tests | Нет | Нет | Routing подключает компактный mandatory baseline, сохраняя task-specific owners и full-run gate | `AGENTS.md`, `instructions/*`, `templates/codex/*`, README/changelog |
| EXEC | Реализовать hooks, installer и analyzer | 0.96 | Live trust/payload probe намеренно отложен | Запустить fixture contracts | Нет | Нет | Runtime остаётся warn-only/fail-open; user config не меняется; analyzer выдаёт bounded aggregate | `scripts/hooks/*`, installer/analyzer, fixtures/tests |
| EXEC | Выполнить adversarial review и исправления | 0.98 | Independent subagent недоступен | Повторить affected tests | Нет | Нет | Исправлены ownership/schema/privacy edge cases; fallback явно не назван independent review | Installer, analyzer, tests, spec |
| EXEC | Проверить первоначальный versioned candidate | 0.99 | 14/30-day follow-up и private gold ещё не существовали | Перейти к post-EXEC review | Нет | Нет | На этом промежуточном этапе AST, 144 operational assertions, standard validators, exact baseline, privacy/profile и diff checks прошли; результат позднее был superseded повторным review | Весь change set и local aggregate evidence |
| EXEC | Соблюсти внешнюю границу | 1.00 | Нужны отдельные Git и activation approvals | Не выполнять commit/push или `%USERPROFILE%\.codex` mutation | Да | Нет | Текущее approval разрешает только `EXEC-A`; candidate не установлен и не активирован | Git state, user Codex home |
| EXEC | Исправить findings повторного post-EXEC review | 0.99 | Требуются новые regression checks и повторный full review | Сначала зафиксировать красные tests, затем исправить analyzer, installer, telemetry и evidence gates | Нет | Да: пользователь дважды дал команду `Исправляй` | Review выявил ложный PASS, current `exec` envelope drift, biased gold sampling, недостижимый `active`, backup collision, schema/salt drift и concurrency gaps | Spec, analyzer, installer, hook runtime, fixtures/tests |
| EXEC | Исправить installer и telemetry contracts | 0.99 | Нет | Запустить targeted suites | Нет | Нет | Добавлены random salt, approved manifest, collision-safe backup, protected rollback, `MarkActive`, mutex/atomic writes и exact telemetry allowlist | Installer, hook, activation probe, tests |
| EXEC | Получить независимый private gold | 0.98 | Git classifier не проходит thresholds | Оставить category manual-only, не скрывая качество | Нет | Нет | 187 unique episodes размечены отдельными read-only `gpt-5.6-sol/xhigh` runs без classifier predictions; три категории прошли, Git precision `0.35` | Ignored gold/evidence artifacts, analyzer summary |
| EXEC | Выполнить same-profile behavioral smoke | 0.98 | Actual Desktop trust доступен только в ACTIVATE | Передать before/after независимому reviewer | Нет | Нет | Before/after использовали одинаковые CLI/model/reasoning/sandbox; reviewer подтвердил after 5/5 и реальный write denial | Ignored eval artifacts, smoke schemas |
| EXEC | Повторить промежуточный validation gate | 0.99 | Нужен independent code review | Запустить read-only review по отдельным lanes | Нет | Нет | На этом этапе AST/schema parse, 206 operational assertions, catalog validator и validator regression suite прошли; результат позднее был superseded дальнейшими fixes | Весь versioned candidate |
| EXEC | Исправить runtime findings и выполнить independent re-review | 0.99 | Нет | Зафиксировать PASS и перейти к governance lane | Нет | Нет | Исправлены physical locking, recovery/quarantine rollback, reparse/alias races, captured-byte execution и activation-evidence drift; targeted suites Hooks 74 и Installer 155 PASS, independent reviewer вернул PASS | Hook runtime, installer, activation probe, fixtures/tests |
| EXEC | Исправить analyzer findings и выполнить independent re-review | 0.99 | Нет | Зафиксировать PASS и перейти к governance lane | Нет | Нет | Исправлены trace dedup/root aggregation, envelope accounting, Since/Until boundaries, duplicate call IDs, hash-keyed gold labels и strict schemas; Analyzer 77 и Privacy 18 PASS, independent reviewer вернул PASS | Analyzer, schemas, gold fixture, tests |
| EXEC | Завершить instruction/governance review | 0.97 | Нужен независимый read-only verdict | Проверить owners, routing, onboarding, docs, validators и spec на contract drift | Нет | Нет | Runtime/analyzer lanes закрыты; repository `PASS` запрещён до governance verdict и final full gate | Instructions, templates, validators, README/changelog, spec |
| EXEC | Исправить governance findings и повторить full gate | 0.99 | GitHub-hosted Windows job доступен только после delivery | Выполнить independent re-review | Нет | Нет | Исправлены CI portability, stale evidence, raw review artifacts, array syntax, Desktop surface и link-scan isolation; `baseline-v4`, 18 catalog scenarios и 326 operational assertions PASS | Workflow, onboarding, validators/tests, docs, spec |
| EXEC | Завершить independent governance re-review | 1.00 | Для внешних шагов нужны отдельные полномочия | Остановиться перед Git delivery и `ACTIVATE` | Да | Нет | Effective `read-only` reviewer вернул `Нет находок` / `VERDICT: PASS`; versioned `EXEC-A` завершён без global config mutation, commit или push | Весь candidate diff и post-EXEC evidence |
