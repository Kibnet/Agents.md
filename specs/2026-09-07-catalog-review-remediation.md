# Исправления и упрощение каталога по ревью репозитория

## 0. Метаданные

- Тип: `catalog-governance` и исправления operational/STORM tools; профиль `product-system-design`.
- Владелец: пользователь Kibnet; автор и исполнитель: Codex.
- Масштаб: large; риск повышен из-за файловых операций, config и изменения обязательных инструкций.
- Целевое семейство / behavior baseline: GPT-6 Astra; идентификаторы и API guidance этого изменения не расширяются.
- Поверхность: Codex Desktop / App Server; PowerShell 7; Python stdlib для STORM.
- Effective runtime нового smoke: App Server `0.153.4`, `gpt-6-astra`, `low`, `workspace-write`, ephemeral, approval `never`, без fallback. Старый `0.153.0-alpha.5` не используется как evidence этого изменения.
- Eval baseline: парные сценарии B1–B8 (§11), одинаковая фактическая конфигурация до/после. Не смешивать это evidence с прежним Astra smoke.
- Baseline репозитория: `5212f3bcae20a2092e75887def72323975205621`; `main`, исходное дерево чистое.
- Целевой каталог: `4.0.0`, breaking activation/validation contracts; новая ветка EXEC `fix/catalog-review-remediation` в отдельном checkout.
- Ограничения: на SPEC изменяется только этот файл. Внешняя установка runtime, изменение пользовательского config, hook trust, commit/push/release не входят в этот scope.
- Источники: [routing](../instructions/governance/routing-matrix.md), [QUEST](../instructions/core/quest-mode.md), [review](../instructions/governance/review-loops.md), [профиль](../instructions/profiles/product-system-design.md), [canonical template](../templates/specs/_template.md).
- Результаты EXEC: [переносимое evidence](evidence/2026-09-07-catalog-review-remediation.md); candidate и active gates завершены, результаты зафиксированы.
- Исходный локальный отчёт: `C:\Users\Kibnet\AppData\Local\Temp\agents-repository-review-2026-09-07\REVIEW.md`. Не является переносимой обязательной ссылкой. Все требования из отчёта перенесены ниже как R1–R11, S1–S6, U1–U10.

## 1. Overview / Цель

Исправить подтверждённые ошибки каталога и его инструментов, сократить дублирующие инструкции и сделать неоднозначные контракты проверяемыми.

Outcome contract:

- Success means: контрпримеры R1–R11 покрыты и исправлены; S1–S6 и U1–U10 получили согласованную реализацию/документацию; существующие approval, ownership, rollback и runtime binding сохраняются.
- Итоговый артефакт: проверенный каталог 4.0.0, regression tests, переносимое краткое evidence и migration notes; применение проверенного change set к активному каталогу после EXEC validation.
- Stop rules: не объявлять PASS при пропущенном обязательном тесте, недоступном runtime smoke или неустранённом HIGH/MEDIUM. После обязательных зелёных проверок повторять их только из-за изменений, сбоев или открытого риска.

## 2. Текущее состояние (AS-IS)

Проверены 132 tracked файла, включая 101 Markdown. На baseline обе штатные PowerShell команды завершились exit 0, operational suite содержит 326 assertions. Эти проверки не покрывали найденные контрпримеры. Каталог активен через junction `C:\Users\Kibnet\.codex\agents` на этот checkout.

| ID | Подтверждённое состояние | Источник |
| --- | --- | --- |
| R1 | Проверяемая ссылка на личный Temp ломает validator при отсутствии файла | Astra spec, link validator, CI |
| R2 | `[agents]` внутри TOML multiline string принимается за реальную секцию installer и probe | installer / probe |
| R3 | Uninstall удаляет идентичный предсуществующий reviewer, хотя `createdFiles.reviewer=false` | installer |
| R4 | Маленький symlink log приводит к записи в посторонний файл; rotation guard не закрывает append | hook |
| R5 | Общий exit 1 составной команды с первым `rg` становится expected-no-match | hook / analyzer |
| R6 | Успешное чтение документации с error keywords становится failure events | analyzer |
| R7 | STORM section неправильного типа превращается в пустой массив и проходит validation | STORM validator |
| R8 | Validator и ranking видят разные зависимости и пропускают разные циклы | оба STORM CLI |
| R9 | Нулевые RICE множители заменяются положительными defaults | ranking |
| R10 | Analysis-only full-cycle разрешает test mutations вопреки owner | STORM prompts / profile |
| R11 | Незакрытые fences в linter/rubric и одной historical spec проходят проверку | Markdown owners / validator |

R1 воспроизведён моделированием отсутствия личных Temp-файлов, не запуском GitHub Actions. R4 доказан для фиксированного symlink; защита от гонок требует отдельного нового покрытия. Reviewer freshness не дала полного обхода activation: без host trust/challenge полный probe оставался FAIL.

## 3. Проблема

Одни и те же контракты представлены несовместимыми эвристиками и повторяющимися текстами. Проверки подтверждают наличие отдельных фраз и happy paths, но не исключают порчу чужих файлов, ошибочное принятие данных и противоречия workflow.

## 4. Цели дизайна

- Общая модель данных там, где два инструмента обязаны одинаково интерпретировать input.
- Минимальные изменения доверенных границ: autonomous hook остаётся одним immutable runtime-файлом.
- Проверки наблюдаемого результата и негативных сценариев; отдельные structural, data-contract и behavioral результаты.
- Компактные инструкции по риску задачи; однозначный owner каждого обязательного правила.
- Явная миграция без тихого overwrite пользовательских данных и без фиктивной обратной совместимости.

## 5. Non-Goals (чего НЕ делаем)

- Не устанавливаем и не активируем operational runtime в реальном Codex home; только synthetic fixtures install/upgrade/probe/uninstall.
- Не меняем модель пользователя, skills, разрешения, hook trust и внешние delivery settings.
- Не реализуем полный TOML/JSON Schema/CommonMark движок, универсальную filesystem abstraction или систему бюджетирования backlog.
- Не перерабатываем содержание исторических решений и не выдумываем недостающее evidence.
- Не собираем новые реальные session traces; fixtures синтетические. Population benchmark, причинная оценка улучшения и фоновый retention service вне scope.
- Не публикуем релиз, не коммитим и не пушим в рамках этого согласования.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности

| Компонент | Ответственность |
| --- | --- |
| `scripts/lib/AgentOperations.Contracts.psm1` | TOML-aware managed statements, typed evidence validation, необходимые общие hash/date helpers installer/probe |
| Installer / probe | Существующие transactions/ownership/locks и activation orchestration; используют общий contract reader |
| Hook | Отдельные внутренние блоки normalization, pure classification, безопасный telemetry store; один устанавливаемый PS1 |
| Analyzer | Parsing/pairing, structural outcome, классификация подтверждённых failures, sample reporting |
| `scripts/storm/storm_model.py` | Structural schema subset, references, numeric contract и единый dependency graph |
| STORM CLI | Validator: metrics/report; ranker: deterministic closure ranking и ограниченный write-json |
| Governance owners | Applicability, phases, review, runner и формат документов имеют каждый одного нормативного владельца |
| Catalog validator | Отдельные structural checks, machine contracts и явно названные text guards; не заявляет behavioral proof |

### 6.2 Детальный дизайн

#### A. Переносимость evidence и Markdown (R1, R11, часть S3)

В старой Astra spec заменить обязательную локальную ссылку справочным literal path с предупреждением о локальной доступности. Сохранить существующую краткую сводку результатов; добавить переносимое evidence текущей работы в `specs/evidence/2026-09-07-catalog-review-remediation.md` на EXEC. Raw outputs с личными путями остаются вне tracked дерева. Не исключать specs из link validation.

Разделить извлечение Markdown structure и проверки. Ограниченный fence-aware reader поддерживает backtick/tilde fences длиной от 3, closing delimiter того же символа длиной не меньше opening, indentation до 3 пробелов; не считает headings и links внутри code содержимым документа. Закрывающий fence с хвостом текста не закрывает блок. Незакрытый fence — ошибка catalog style, хотя renderer может допускать EOF. Inline code, escaped brackets и literal path не становятся обязательными links. Зафиксировать поддерживаемый синтаксис без объявления полной CommonMark совместимости. Проверить mixed fences, более длинные outer fences, fake headings/links в code, реальные broken links.

Исправить dangling fences в действующих spec-linter/spec-rubric и только форматирование в `specs/2026-05-14-github-delivery-policy.md`. Legacy specs остаются историческими и не обязаны проходить новый формат SPEC, но их реальные относительные ссылки и fences проверяются.

#### B. TOML, ownership, activation (R2, R3, S4, U1, U2, U9)

TOML scanner различает comments, basic/literal/multiline strings, escapes, array nesting и возвращает offsets реальных statements. Поддерживаемый managed contract: канонический `[agents]`, bare `max_threads`/`max_depth` с положительными decimal integers. Меняются только spans значений либо добавляется настоящая секция. Unrelated bytes, strings, comments и LF/CRLF сохраняются. Reader применяется также к hook feature guards, чтобы примеры `[hooks]` в тексте не создавали blockers.

Inline/dotted/quoted managed forms, duplicates, незакрытые strings/arrays и неоднозначное состояние дают `blocked` до backup/мутации. Это узкая поддержка TOML, не исправление произвольного невалидного config. Перед записью postimage повторно читается и сравнивается с ожидаемыми limits; tests дополнительно проверяют точные spans и expected bytes, а не только self-consistency. Install, restoration/uninstall и mark-active используют тот же контракт. Probe на ошибке возвращает false с reason.

Reviewer provenance: созданный installer файл имеет `origin=created`; идентичный предсуществующий — `preexisting` и не переписывается. Uninstall удаляет только доказанно created файл с ожидаемым fingerprint. Preexisting сохраняется, включая пользовательский drift; такой drift не блокирует удаление других owned объектов. Upgrade с заменой preexisting reviewer блокируется. Manifest schema 1 сохраняется, добавляется optional `reviewerProvenance` с origin/initial fingerprint. Legacy fallback только к boolean `createdFiles.reviewer`; unknown означает preserve, не adopt. Невалидное присутствующее provenance — blocker. No-op install не пишет metadata только ради миграции.

Reviewer evidence schema 2 содержит fingerprint, текущие `activationBindingHash`/`configHash`, `observedAtUtc`, child session/runtime identity, `effectiveSandbox`, typed `readSucceeded`/`writeDenied`. Probe требует supported read-only sandbox и успешное чтение/отказ записи, binding/hashes, время не раньше install и не старше 15 минут; future skew максимум 30 секунд. Combined evidence schema 2 сохраняет reviewer evidence hash/time и runtime observation time. Expiry — минимум двух окон по 15 минут. MarkActive заново проверяет обе границы непосредственно перед commit, а не доверяет одному `expiresAtUtc`. Legacy active manifest не дезактивируется автоматически; новая активация требует evidence v2. Это отчёт controlled child session, не криптографическая аттестация sandbox. При writable effective sandbox reviewer observation не засчитывается.

Expected host/runtime/session identity берётся из текущего controlled run/challenge, а не из самого reviewer report: host определяется probe на текущем хосте; ожидаемые runtime fingerprint и child session ID передаются host runner после фактического запуска. Все три значения сравниваются с observation. Если runner не может дать expected identity, probe не объявляет reviewer verified. Wrong-host/runtime/session и копирование старого отчёта в новый challenge покрываются negative tests. Это проверка согласованности trusted run evidence, не защита от подделки всех входов владельцем хоста.

Таблица activation scope в onboarding и README: применение каталога → validated change set; install → installed-awaiting-trust; ручной host hook trust → trust evidence; probe/mark-active → active. Разрешение сохраняется внутри согласованного scope; разные внешние side effects не разрешаются автоматически. Новый approval ritual к уже разрешённой операции не добавляется.

Endpoint preflight сохраняет `kind=endpoint` и schema 1, добавляет `level=tcp-connect`; UI/output явно сообщает уровень. HTTP/auth/TLS readiness задаётся consumer-specific checks, не выводится из TCP PASS.

#### C. Telemetry и классификация (R4–R6, S4, U3, U4)

Безопасный telemetry store поддерживает Windows/PowerShell 7 и локальный NTFS. UNC, device namespaces, reparse paths, неподдерживаемая ФС/API или access conflict приводят к skip только telemetry; hook остаётся warn-only/fail-open и завершает exit 0. Новое ограничение явно отмечается в migration notes.

Открывать root покомпонентно от local-volume anchor, затем только относительно удерживаемого directory handle: `NtCreateFile`, `OBJECT_ATTRIBUTES.RootDirectory`, `OBJ_DONT_REPARSE`, `FILE_OPEN_REPARSE_POINT`. Не принимать `..`, ADS или absolute leaf names. После open проверять тип, reparse attribute, volume/file identity и link count=1 у изменяемого файла. Read/write/truncate используют тот же SafeFileHandle; rename/delete — handle-based относительно проверенного root. Не повторять pathname open после проверки. Guard покрывает lock, logs/archives, warning-state, metadata, staging/recovery и cleanup; неизвестные файлы не удаляются. Share mode дополняет boundary, не заменяет его. Не обещается защита от администратора/kernel или power loss.

Отдельные pure helpers внутри одного immutable hook поддерживают классификатор и store. Внешние runtime dot-sourced modules не добавляются. `Get-SingleDirectCommand` может остаться маленькой одинаковой функцией hook/analyzer с общими data-driven fixtures; общий module loader ради неё не создаётся.

Expected rg no-match допускается только при AST без ошибок, одном statement/pipeline и одном непосредственном literal `rg`/`rg.exe` (включая абсолютный executable path), structured exit 1 и доказанно пустом stderr. Pipelines, chains, несколько statements, scriptblocks/subexpressions, redirects и wrappers не дают нормализации; общий failure не приписывается внутреннему rg.

Analyzer нормализует `success/failure/unknown` до regex категорий. Typed exit_code/timed_out/isError имеют приоритет; legacy `Exit code: N` признаётся только в известном envelope header перед output. Success stdout с 401/SSL/build failed/traceback остаётся success. Failure classifiers запускаются только для structural failure; unknown сохраняется unknown. Достоверные отдельные events вроде patch success=false остаются поддержаны. Старые compatibility counts являются историческим baseline, а не требованием воспроизвести ошибочную классификацию.

Retention: при следующем успешном maintenance удалить owned сегменты с событиями строго старше 45 дней. Без запуска hook фонового удаления нет. Append не продлевает срок; допустимо удалить сегмент целиком вместе с более свежими событиями. Сохранить предел три JSONL/10 MB. Minimum event time хранится в metadata, связанном с generation/file identity. Ownership нового сегмента возникает только при эксклюзивном создании через store и фиксации binding `(generation, volume/file ID)`. Имя, похожий JSON и версия runtime сами по себе не дают права удалить/перезаписать существующий файл. Legacy без binding можно ограниченно читать для диагностики; scan не присваивает ownership. При конфликте с новым active path — diagnostic + skip telemetry, без автоматического adoption. Такие legacy-файлы не проходят новую retention автоматически; их перемещение/adoption требует отдельного scope. Malformed owned segment можно целиком удалить через store; файл без доказанного binding сохраняется. Clock rollback уменьшает minimum time. Все операции идут через безопасный store.

Best-effort telemetry имеет общий cooperative deadline 1.5 секунды внутри host hook timeout 5 секунд, включая native init, lock/state и maintenance. Не более трёх segments, scan не более 30 MB суммарно, chunk <=64 KiB, line <=64 KiB; oversized input → diagnostic/skip. Deadline проверяется до lock, между chunks и перед каждой новой mutation. Исчерпание до начала транзакции — skip; начатая transaction доводится до согласованного commit/rollback, не оставляя ложный binding. Classification/warning формируются до telemetry и остаются доступны при skip. Kernel I/O stall невозможно надёжно прервать этим deadline; это явно не hard realtime guarantee. Cold-start и contention измеряются отдельно.

Analyzer добавляет `evaluationScope=selected-stratified-sample`, sample size/strategy и явное ограничение precision/recall/FPR выбранной выборкой. Gold-label schema 1 и sampling algorithm сохраняются; `auto-counted` означает sample quality gate, не population accuracy или причинное улучшение.

При нулевом знаменателе значение precision/recall/FPR — `null`, не NaN/Infinity и не основание для `auto-counted`; исходные counts/denominators сохраняют числовой `0`. Это отдельный regression fixture.

#### D. STORM contract (R7–R10, U4, U10, часть S3)

Общий `storm_model.py` читает schema и поддерживаемое подмножество keywords: локальные `$ref`, type (включая array of types), required/properties/items, enum/pattern, minimum/maximum, additionalProperties. Неизвестный validation keyword даёт schema self-check error; metadata keywords разрешены явно. Полная JSON Schema совместимость не заявляется. Root object, required keys, коллекции и nested types проверяются до semantics. Отсутствующие optional sections = []; явный null/object/string вместо массива — error. JSON NaN/Infinity, bool как number, неfinite результаты вычислений отвергаются. Ошибка чтения/JSON → exit 2; ошибка контракта → exit 1 с field path, без traceback и без записи output.

Разрешённые annotations: `$schema,$id,title,description,$comment,default,examples`; они не меняют validation. `$defs` — поддерживаемый schema-container с self-check всех definitions. `$ref` только локальный разрешимый JSON Pointer; внешние refs запрещены. Имена внутри properties/$defs не считаются validation keywords. Текущая schema целиком обязана проходить self-check; неизвестный keyword внутри definition выявляется.

ST/CN/EN IDs уникальны и разрешимы. Optional `enablers[]`: required `id` EN-*, `title,status,provenance,confidence`; optional `priority,dependencies,supports,linked_tests,linked_code,evidence`. Missing arrays = []; explicit null object/array — error. К EN применяется тот же effort/decomposition contract, что к ST; priority.effort optional. Own value EN всегда 0, независимо от extension fields reach/impact. Starter schema_version=1.2.0; корректный 1.1.0 без enablers читается. Не создавать placeholder для undefined EN.

Единый graph: top-level `from -> to` означает «from предшествует to»; embedded `item.dependencies=[X]` означает `X -> item`. Edges дедуплицируются. Оба CLI проверяют dangling refs/self-loops/все cycles до фильтрации status. ST/EN implemented удовлетворяет prerequisite без cost/value; blocked и retired prerequisite дают blocker зависимой closure до явной миграции. CN — узел транзитивного порядка без cost/value; его ancestors ST/EN учитываются. CN `dependency_state=open|blocked`, default open означает отсутствие объявленного planning blocker, не выполнение constraint. CN не становится исполняемой строкой ranking. `EN.supports` — только traceability к существующим ST/CN, не создаёт edge. EN участвует в ranking только при направленном dependency path EN→…→ST; supports-only остаётся unranked с причиной `support_without_dependency`, без стоимости в closure story. Явный EN→ST включает стоимость ровно один раз.

ST/CN/EN statuses: `inferred,proposed,confirmed,active,implemented,partial,deprecated,superseded,removed,blocked,needs_review`. Retired для них = deprecated/superseded/removed. CN блокирует dependents при retired, status=blocked или dependency_state=blocked; open не отменяет status blocker. Retired scenarios = deprecated/superseded; active scenarios = draft/reviewed/automated/manual/failing/passing. Неизвестный status — controlled contract error. Legacy compatibility означает соответствие этим уже документированным statuses, не любое значение, прежде допускавшееся schema string.

RICE: missing reach/impact → 1; missing priority.confidence → story.confidence, иначе 0.5; допустимые explicit reach/impact >=0, confidence 0..1. Explicit effort >0 имеет приоритет; иначе decomposition с architecture/verification default 1, остальными default 0, каждый component >=0, total floor 0.1 с пояснением. Defaults только для отсутствия, null/strings/bools/negative/nonfinite отвергаются. Нулевой множитель сохраняет value=0. Closure суммирует уникальные неоплаченные ST/EN; CN=0. Shared prerequisite учитывается один раз; условная оплата в ranking не меняет artifact statuses. Аддитивен own_effort, повторённый cost_star пакета нельзя суммировать по строкам. CN связи видны в explanation. Детерминированные tie breaks сохраняют ID порядок.

Метрики: прежнюю формулу публиковать как `resolved_step_reference_ratio`; `step_reuse_ratio` = используемые SD в >=2 distinct active scenarios / все используемые SD. Дубликат внутри одного scenario не reuse; retired scenarios исключаются; пустой denominator = n/a. Machine output содержит metrics_version=2. Legacy audit не переписывается без запрошенного обновления отчёта. `--write-json` меняет только ranking после полной проверки, сохраняет extension fields и порядок коллекций.

Validator остаётся read-only и печатает `metrics_version: 2` в Metrics stdout; отдельный новый JSON output flag не требуется. При запрошенном `/storm:audit` версия записывается в `process_audit.metrics_version`, machine n/a — null. `unranked_items` — раздел CLI/Markdown report с ID/reason, не автоматически записываемое top-level поле. Ranking остаётся array. Для равных priority/value/cost final tie break — ascending ID.

Full-cycle analysis-only выполняет coverage/traceability analysis, не annotations/tests. Любая test mutation маршрутизируется в delivery/QUEST. Prompts 00–10 согласуются с BDD templates там, где выводят rules/scenarios/traceability/audit metrics; не меняют назначения остальных команд.

#### E. Упрощение и уточнение инструкций (S1–S6, U5–U8)

Short SPEC добавить как `templates/specs/_template-small.md`: metadata/цель и границы; observable result и решения; AC→check; риски/likely objection; review outcome; exact approval; финальный журнал. Релевантные сведения можно объединять, нельзя опускать. Short допустима только при одновременно: один ограниченный outcome, локальное обратимое изменение, нет config/storage/security/публичного контракта/миграции/внешнего side effect и нет существенной межкомпонентной неопределённости. При любом исключении expanded SPEC; текущая задача expanded. Точная фраза approval, completion gate и требования review сохраняются. Формат не определяется количеством файлов или желаемой скоростью.

Owner map: quest-governance — applicability/выбор short; quest-mode — phase mutations/approval/completion; review-loops — review depth/content; testing contexts — runner commands; template — структура записи и ссылки. Удалить повторяющиеся нормативные списки из prompt wrappers; detailed review остаётся в SPEC, финал пользователю содержит outcome, validation, существенные ограничения и ссылку. Семь обязательных заголовков финала убрать. В expanded template объединить дублируемые evidence/objections/review строки, сохранив required data и auditable журнал.

Document-contract: обязательны scope/applicability, actionable rules и owner/related references. Policy/context/profile/onboarding имеют компактные формы; MUST/SHOULD/MAY и команды добавляются по реальному содержанию. Старый семисекционный формат остаётся допустимым. Удалять из существующих instructions только пустые/нерелевантные boilerplate секции и generic commands, не substantive правила. Каждое удалённое normative требование сопоставляется с сохранившимся owner либо помечается намеренным изменением в review.

SPEC linter получает 20 явно пронумерованных стабильных критериев: 1 цель, 2 AS-IS, 3 проблема, 4 дизайн-цели, 5 границы; 6 ответственность, 7 integration, 8 алгоритмы, 9 ошибки, 10 performance applicability; 11 данные, 12 совместимость/миграция, 13 rollback; 14 AC, 15 evidence/tests, 16 команды/stop rules; 17 план, 18 решения/open questions, 19 масштаб/форма; 20 profile. Критерии оценивают сведения, не наличие 20 заголовков. Неприменимость требует причины. Сохраняется critical gate A/C/D; незакрытый объективный HIGH/MEDIUM блокирует approval независимо от суммарных баллов. Rubric 0/2/5 получает конкретные примеры: отсутствует; частично с риском; проверяемо и полно. Балл не отменяет gate.

Routing: один основной stack profile, необходимые domain profiles и один change-type/scenario profile. Каждый дополнительный domain требует конкретного триггера и уникального контракта; произвольного лимита два файла нет. Desktop + RavenDB + UI automation выбирает три соответствующих нормы. Context выбирается по выполняемому этапу, ненужные документы не грузятся. Conflict model не меняется.

Onboarding: local pointer + optional override — portable default; global pointer + optional local override — допустим при проверенном host loading. Global-only не гарантирует подключение на чужой машине/CI. В обоих режимах canonical root проверяется, override только ужесточает MUST. README/quick-start/templates дают обе схемы без требования дублировать pointer.

.NET profiles помечают `--filter` examples как VSTest-only и ссылаются на testing-dotnet для TUnit; stack-neutral profiles не предписывают произвольный runner.

Validator разделяет structural checks, machine contracts и `textGuards` (бывшие semanticContracts). Exact OpenAI model/effort compatibility, уже присутствующая в owner, переносится в небольшой versioned JSON contract с source/review date; prose ссылается на него, guard сверяет значения, а не полные предложения. Не переносить динамическую Desktop availability или все смысловые правила в JSON. Нужные safety text guards сохранить и переименовать честно; behavioral checks остаются отдельными.

Backlog session-insights: каждой существующей рекомендации присвоить open/partially-addressed/promoted и ссылку на подтверждённый owner; историческое evidence сохранить. Не закрывать по совпадению ключевых слов; PowerShell/TUnit сверить по сути.

Visual planning и UI video: не применимо — каталог/CLI не меняет UI продукта. Наблюдаемые outputs проверяются fixtures и model smoke.

### 6.3 User-Observable Scenarios

| Scenario | Trigger | Expected visible result | Evidence required | AC |
| --- | --- | --- | --- | --- |
| V1 | Clean checkout validation | Не требует личный Temp; реальные broken links выявляются | Portable fixture/run | AC1 |
| V2 | Install/uninstall с примерами TOML и своим reviewer | Настройки корректны, текст и чужой файл сохранены | Byte comparisons | AC2–3 |
| V3 | Небезопасный telemetry path / compound failure / чтение справки | Чужие файлы неизменны, failure classification честная | Negative fixtures | AC4–6 |
| V4 | STORM invalid data / mixed dependencies / zero confidence | Контролируемый отказ либо согласованный план/нулевой value | Python CLI tests | AC8–10 |
| V5 | Small change либо config migration | Компактная либо expanded spec, тот же approval boundary | B1–B3 smoke | AC11 |
| V6 | Desktop+RavenDB+UI / onboarding / unknown test runner | Все нужные нормы, ясное подключение, корректный runner decision | B5–B8 smoke | AC12 |
| V7 | Устаревший reviewer evidence / TCP listener | Active не подтверждается старым отчётом; TCP не называется HTTP PASS | Operational tests | AC3, AC7 |

### 6.4 State / Interaction Matrix

| Current state | Trigger | Result | Error/concurrent case |
| --- | --- | --- | --- |
| SPEC draft | Review | Только текущая spec меняется | HIGH/MEDIUM → revise/re-review |
| SPEC ready | Exact approval | EXEC isolated candidate | Обычное «исправляй» не подменяет действующий exact gate |
| Candidate validated | Active drift/hash check | Один подготовленный change set | Drift → reconcile, не overwrite |
| Uninstalled / awaiting-trust | Fixture install/probe | Awaiting-trust / active при полном свежем evidence | Unsupported config/evidence → blocked без writes |
| Telemetry store | Hook event | Safe append + maintenance | Unsafe path/concurrency → skip telemetry, hook exit 0 |
| STORM JSON | Validate/rank | Один graph, stable output | Contract error → no output writes |

### 6.5 Decision Ledger

| Decision | Owner | Chosen option | Confidence | Risk if assumed | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |
| Единый scope всех R/S/U | agent | Один approval, последовательные независимые пакеты | 0.95 | Большой diff; staged validation/review | Нет |
| Версия | agent | Каталог 4.0.0, evidence 2, runtime 3.2.0 | 0.95 | Потребителям нужны migration notes | Нет |
| TOML dependency | agent | Узкий fail-closed scanner без нового runtime dependency | 0.9 | Поддерживается не весь TOML | Нет |
| Telemetry platform | agent | Windows local NTFS handles; unsupported skip | 0.85 | Потеря telemetry на иных FS, явно описана | Нет |
| EN/CN | agent | EN action value=0, CN transparent order/blocker | 0.9 | Rank меняется при ранее игнорируемых edges | Нет |
| Short SPEC | agent | По совокупности низкого риска, exact gate сохранён | 0.95 | Не каждая малая правка станет short | Нет |
| Реальное operational activation | agent | Вне scope, только fixture | 1.0 | Каталог обновится, installed runtime останется прежним | Нет |

### 6.6 Runtime / Config / Data Contract Matrix

| Contract | Current | Change | Compatibility | Verification |
| --- | --- | --- | --- | --- |
| Install manifest | schema 1 | Optional reviewer provenance | Legacy boolean / unknown preserve | Fixtures |
| Activation evidence | schema 1 | schema 2, two observations bound/fresh | Existing active preserved; new active requires v2 | Expiry/hash tests |
| Hook runtime | immutable 3.1.0 | New immutable 3.2.0 | No overwrite installed 3.1.0 | Upgrade/tamper/rollback |
| STORM | schema 1.1.0 | Starter 1.2.0 EN/CN | Read valid legacy; no auto rewrite | Python tests |
| Audit metrics | old semantics | metrics_version 2, sample scope | Explicit migration; old report historical | Metrics fixtures |
| Documents/SPEC | one expanded form | Compact + expanded by risk | Existing form accepted; historical content preserved | Lint + smoke |
| Endpoint | kind endpoint | level tcp-connect | Existing kind/schema retained | Listener tests |

## 7. Бизнес-правила / Алгоритмы

Основные инварианты: только реальные TOML statements управляют config; lifecycle ownership не выводится из совпадения bytes; failed telemetry не блокирует tool; success не становится failure из stdout; один STORM graph до status filtering; нули не missing; cost shared prerequisite учитывается один раз; approval и review не сокращаются вслед за формой документа.

Для schema и graph сначала validate полностью, потом compute полностью, потом write. Для config сначала parse/plan/blockers, потом existing transaction с повторной проверкой postimage. Для telemetry никакой pathname mutation вне проверенного handle boundary.

## 8. Точки интеграции и триггеры

- Installer/probe импортируют shared contracts из каталога; immutable hook его не импортирует.
- Все filesystem операции telemetry вызывают store; pure classifier работает и при store unavailable.
- Оба STORM CLI вызывают общий model loader до собственного результата.
- CI сохраняет existing Ubuntu catalog и Windows operational jobs; добавляет `storm-python` unittest на Python 3.11/3.14 Ubuntu.
- Quality gate каталога перечисляет Python suite как обязательную при STORM/schema changes. Installed Python для operational tools не требуется.
- Short/expanded selection применяется только после активации нового каталога; не ретроактивно к этой SPEC.

## 9. Изменения модели данных / состояния

Persisted: optional reviewer provenance, evidence v2, retention metadata, STORM optional enablers/CN dependency_state, metrics version/sample scope. Calculated: normalized tool outcome, graph closure, typed model contract checks. Конкретные schemas отражают actual payload, не вводят ненужные поля. Extension fields STORM сохраняются. Retention metadata не содержит command bodies, private paths или secrets сверх существующей privacy allowlist.

## 10. Миграция / Rollout / Rollback

1. После approval создать новый isolated checkout от подтверждённого baseline. Старый dirty Astra worktree не использовать и не удалять. Сохранить fingerprint активного каталога/junction и исходных изменяемых файлов.
2. Зафиксировать fixture inputs и behavioral baseline до candidate edits. Raw evidence вне tracked дерева; переносимый summary без обязательных private links.
3. Реализовать пакетами §13. Существующий live config/hooks не менять. Runtime version bump создаёт новый каталог при будущей разрешённой установке, не меняет bytes old runtime.
4. Проверить candidate, review и behavioral after; подготовить единый patch. Повторно сверить active hashes/HEAD и сохранить backup затронутых файлов. При drift не применять blind overwrite.
5. Применить patch к активному каталогу, проверить hashes с candidate и оба штатных quality gates; Python suite при STORM changes. При неуспехе откатить только этот change set из backup, сохранив чужие изменения.
6. Rollback schemas: старый каталог не должен трактовать новое activation evidence как своё; старый active install остаётся сохранённым. Для STORM новые EN/graph semantics не удалять автоматически при downgrade, вернуть предыдущий artifact из пользовательского VCS/backup только по отдельному scope.

Версия 4.0.0 обоснована новым обязательным activation evidence, изменением accepted invalid inputs и смыслом metrics. Changelog содержит Breaking/Migration/Compatibility, без заявления о публикации релиза.

## 11. Тестирование и критерии приёмки

### Acceptance-to-Test Matrix

| AC | Проверяемый результат | Automated test / evidence | Если не проверено |
| --- | --- | --- | --- |
| AC1 / R1,R11 | Portable links и fence-aware structure; historical formatting only | Validator fixtures: missing private root, valid/malformed/mixed fences, hidden heading/link; clean exported tree | Блокирует completion |
| AC2 / R2 | Multiline ложные sections не меняют текст; unsupported forms blocked без writes | Expected spans/bytes, false+real section, comments/LF/CRLF/array/quoted/dotted/duplicate/malformed, probe before/after | Блокирует completion |
| AC3 / R3,U1,U2 | Preexisting reviewer survives; new activation requires current fresh evidence | New/legacy/unknown provenance, user drift, upgrade blocker, old/bad hashes/date/types/host/runtime/session, earliest expiry, expiry before commit, valid v2, rollback | Блокирует completion |
| AC4 / R4 | Нет записи в чужие файлы через links/races; fail-open | Symlink/dangling/intermediate junction/hardlink для log/state/lock/archive/recovery; controlled parent/leaf replacement barriers, alias concurrency, bytes unchanged, exit0 | Недоступность symlink privileges явно FAIL данного evidence, не PASS |
| AC5 / R5,R6 | Compound failures сохраняются, successful docs не errors | Shared direct-rg vectors; exit0/1/2/stderr; pipeline/wrapper; structural/legacy/unknown outcomes; successful docs with all keywords, real errors/timeouts | Блокирует completion |
| AC6 / U3,U4 | Append не продлевает retention; sample metrics ограничены выборкой | Small log first event46d, 45d boundary, fresh/legacy/malformed/clock rollback/identity mismatch, чужой JSONL с точным именем неизменен после scan; budget/lock contention/three near-limit logs/oversized line/staging rollback/handles released; null denominator/privacy allowlist | Idle deletion и legacy adoption не обещаются |
| AC7 / U9 | Endpoint PASS означает только TCP | Local listener, closed port, invalid URI, output/schema assertions | Consumer HTTP проверка вне scope |
| AC8 / R7,U10 | Неверные STORM types/refs/numbers дают controlled error без writes | root/array/item/nested/null/bool/NaN/overflow/schema keyword; starter1.1/1.2; duplicate/dangling IDs; existing input/output byte-identical при ошибке | Блокирует completion |
| AC9 / R8,R9,U10 | Одинаковые graphs/cycles; zero value; shared cost once | Embedded/top-level/mixed cycles; diamond EN/CN; direction/status/blockers; zero factors/default/effort precedence; supports-only EN unranked, explicit EN→ST cost once; deterministic repeat | Блокирует completion |
| AC10 / R10,U4 | Analysis-only read-only; metric names/formulas точны | Prompt guards + B4; one/two scenarios/duplicate/retired/empty reuse; no-write failures and extension preservation | Блокирует completion |
| AC11 / S1,S2,S5,U7 | Short/expanded по риску, owner dedup, 20criteria/rubric, concise final | Structural/text guards, owner requirement mapping, B1–B3, reviewer hand-check | Lint не заменяет smoke |
| AC12 / S3,S6,U5–U8 | Data contracts/text guards разделены; routing/onboarding/runner/backlog согласованы | Contract fixtures, CI config validation, B5–B8; backlog owner evidence links | Реальный GitHub CI не заявлять до run |
| AC13 / S4 | Shared helpers не обходят runtime capture/hash/locks | Existing full operations + module loading/proposal hash/tamper/upgrade/rollback regressions | Блокирует completion |
| AC14 / all | Полный проверенный scope применён к active без drift | Candidate/active required gates, equal hashes, post-EXEC review, portable summary | Не завершать частично |

Behavioral smoke: по два фиксированных варианта B1–B8, всего 16 пар, реальные новые isolated sessions одного effective runtime/settings/tools. Expected outputs и allowed mutations задаются до baseline; actual tool calls и outputs сохраняются. Никаких симулированных PASS. Для нового поведения baseline может FAIL, after обязан PASS; preserved boundaries не регрессируют.

| Case | Trigger / expected after |
| --- | --- |
| B1 | Низкорисковая локальная правка → short SPEC со всеми компактными обязательными сведениями; code до approval не меняется |
| B2 | Малая по строкам config/security/migration задача → expanded SPEC; никакого size-only bypass |
| B3 | Approved implementation без запроса push / явно разрешённый push конкретной ветки в конкретный remote → в первом варианте только локальная работа, во втором inert callable delivery tool без повторного approval; concise final с evidence |
| B4 | STORM full-cycle analysis-only и затем test mutation request → сначала только analysis, mutation через delivery/QUEST |
| B5 | Desktop+RavenDB+UI → все три применимых profile contracts, без случайных лишних profiles |
| B6 | Local pointer и verified global-only onboarding → обе схемы корректны, на непроверенном host загрузка не выдумана |
| B7 | TUnit, VSTest и неизвестный runner → правильный owner/команда либо сначала discovery |
| B8 | Уточнение во время задачи и repeated successful validation → steering сохраняет цель, проверки останавливаются после mandatory green |

Команды:

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
python -m unittest discover -s scripts/storm/tests -p "test_*.py"
```

Targeted operational areas запускаются перед полной suite. Newly added regressions должны демонстрировать старый дефект на baseline либо независимом минимальном fixture, затем PASS after. No timing-only race test: controllable barriers вызываются harness, production hook не принимает управляющие test env/JSON fields. Perf: сохранить bounded payloads/log limits; измерить hook обычный append/skip/maintenance на одинаковых fixtures до/после, сообщить latency; sustained >2x median на common path требует устранения причины или повторного решения, не скрытого PASS.

## 12. Риски и edge cases

Native handle store — наиболее рискованный блок. Проверять API availability/return codes/handle disposal, выполнять adversarial review с concrete race/foreign-file evidence. Unsupported platform skip меняет доступность telemetry; классификация остаётся работоспособной. Защита ограничена заявленной моделью обычного процесса, не privileged attacker.

Большой scope увеличивает риск случайной смены правил. Requirement-to-owner mapping для удаляемых clauses, пакетные tests и итоговое review обязательны. JSON machine contracts не являются live model availability. Legacy invalid STORM inputs перестанут проходить — migration errors должны указывать field path и способ исправления без auto-fabrication.

### Expected User Review Objections

| Likely objection | Why likely | Mitigation | Status |
| --- | --- | --- | --- |
| «Опять формальности вместо исправлений» | Каталог требует exact gate | Один полный reviewable scope; после одного approval автономные пакеты; short form для будущих малых задач | mitigated |
| «Упрощение сделало систему сложнее» | Новый parser/store может разрастись | Узкие supported subsets, single-file hook, никаких общего framework/новых runtime dependencies | mitigated |
| «Сломаете действующие настройки» | Центральный каталог активен | Isolated candidate, fixtures вместо real install, provenance и backup/drift | mitigated |
| «Зелёный lint уже пропустил эти баги» | Исходная suite PASS | Каждый defect с regression; реальные behavioral пары отдельно | mitigated |
| «Потеряется телеметрия/совместимость» | NTFS и evidence v2 строже | Явные breaking notes, fail-open, existing installed runtime preserved | accepted-risk в предлагаемом scope |

### Rework Prevention Checklist

- Пользовательские V1–V7 и AC1–AC14 заданы; каждой проверке соответствует команда/fixture/smoke.
- Самостоятельные решения и совместимость указаны; блокирующих user-owned выборов нет.
- Objections и риски указаны; role/adversarial review заполняется ниже до approval.
- AC описывают наблюдаемый результат, а не только подготовку; EXEC имеет путь к доказательству.

## 13. План выполнения

1. Isolated baseline, fixed regression/smoke fixtures и before evidence.
2. Portable evidence/Markdown checks; TOML/provenance/evidence/endpoint contracts и targeted tests.
3. Safe telemetry store → retention → normalization/analyzer; immutable runtime version, security/operational tests.
4. Shared STORM model/schema/ranking/metrics/prompts + Python tests/CI.
5. Short SPEC/document contract/owner dedup/routing/onboarding/runner/backlog; structural/data/text guards и migration notes.
6. Full candidate validation, after smoke, adversarial post-EXEC review; исправить находки и повторить затронутые проверки.
7. Drift/backup/apply active; mandatory active validation и hashes; concise final со статусом всех AC.

Пакеты можно делегировать с явным владением непересекающимися файлами, но интеграцию общих validator/tests/docs выполняет один ответственный. Не сокращать согласованный scope молча при затруднениях.

## 14. Открытые вопросы

Блокирующих design вопросов нет. Подтверждение этой спецификации получено 2026-09-07. Runtime/API/filesystem availability проверяется на EXEC; недоступность обязательного evidence является blocker результата, не разрешением его пропустить.

## 15. Соответствие профилю

`product-system-design`: AS-IS и проблема подтверждены, data/config/state/CLI workflows описаны, boundaries/ошибки/миграция/acceptance заданы. Central stack: creator-vibe-lens, model-behavior-baseline, tool-execution-baseline, quest-governance/mode, testing-baseline, collaboration, review-loops, document-contract/versioning. Полный creator-vibe не применяется: исправления конкретных defects и заданных contract gaps.

## 16. Таблица изменений файлов

Утверждённые группы EXEC реализованы в isolated candidate. Группы ограничены указанными обязанностями; добавление другого subsystem требует пересмотра scope.

| Файл / группа | Изменения | Причина |
| --- | --- | --- |
| `scripts/lib/AgentOperations.Contracts.psm1` (new); installer; probe | Scanner, ownership, typed evidence, runtime version | R2–3,U1–2,S4 |
| `scripts/hooks/agent-operations-hook.ps1`; analyzer | Store/retention/normalization/sample metrics | R4–6,U3–4 |
| `scripts/test-agent-operations.ps1`; `scripts/fixtures/agent-operations/*` | Targeted regressions, shared vectors, barriers | AC2–7,13 |
| `schemas/*agent*`, новые reviewer/activation schemas при actual payload | Versioned machine contract | U2 |
| `scripts/storm/storm_model.py` (new); два CLI; `scripts/storm/tests/test_*.py` (new) | Общая модель и тесты | R7–9,U4,U10 |
| `schemas/storm-artifacts.schema.json`; `templates/storm/*` | EN, graph/metrics/report contracts | STORM consistency |
| `prompts/storm/00-10`; `instructions/profiles/storm-product-development.md` | Analysis-only / BDD outputs / migration | R10,U10 |
| `instructions/core/quest-*`; review-loops/linter/rubric; `templates/specs/*` | Short/expanded, owners, clear quality gate | S1–2,U7,R11 |
| document-contract; existing `instructions/*` boilerplate | Compact forms, remove empty content, preserve substantive rules | S5 |
| routing-matrix; onboarding; .NET profiles; preflight template/README | Profile composition, pointer modes, runner, TCP level | U5,U6,U8,U9 |
| `scripts/validate-instructions.ps1`; `scripts/test-validate-instructions.ps1`; small Markdown helper if shared by checks | Structural/data/text guard separation | R1,R11,S3 |
| New versioned JSON exact API contract under `schemas/`; API owner | Existing exact facts in structured form | S3 |
| `.github/workflows/validate-instructions.yml`; AGENTS; README; CHANGELOG | Gates, migration, scope, release version | Integration |
| `session-insights/AGENTS_IMPROVEMENT_BACKLOG.md` | Evidence-backed statuses | S6 |
| Astra spec; `specs/2026-05-14-github-delivery-policy.md`; new evidence summary | Portable path and formatting only in historical files | R1,R11 |

## 17. Таблица соответствий (было -> стало)

| Область | Было | Стало |
| --- | --- | --- |
| Config | Regex по тексту | Реальные statements/spans, fail-closed unsupported |
| Ownership | Fingerprint как право удаления | Provenance + fingerprint |
| Telemetry | Pathname writes, file-mtime retention | Checked handles, event-age segments |
| Errors | Keyword/first-command heuristics | Structural outcome, single-direct command proof |
| STORM | Две модели graph и zero defaults | Общий graph, typed numeric, EN/CN semantics |
| SPEC/docs | Обязательный большой каркас | Формат по риску, одинаковые substantive gates |
| Validation | «Semantic» фразы | Structural/data/text guards + separate real smoke |

## 18. Альтернативы и компромиссы

- Только R1–R11: быстрее, но оставляет принятые пользователем предложения S/U без результата. Выбран полный scope с последовательными пакетами.
- Полная TOML/JSON Schema library: больше совместимость, но новая runtime dependency и packaging. Выбран узкий явно ограниченный contract с отказом на неизвестных формах.
- Только Test-Path перед append: мало кода, но race остаётся. Выбран handle boundary; unsupported store выключает telemetry, сохраняя hook behavior.
- Multi-file hook runtime: меньше локального дублирования, но больше capture/hash/trust поверхностей. Оставлен single-file runtime и точечные shared fixtures.
- Удалить approval или review ради короткой SPEC: не соответствует целям пользователя и действующему governance. Сокращается запись, а не доказательства существенных гарантий.

## 19. Результат quality gate и review

### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
| --- | --- | --- | --- |
| A. Полнота | 1 | PASS | Цель/outcome §1 |
| A. Полнота | 2 | PASS | Проверенный AS-IS §2 |
| A. Полнота | 3 | PASS | Корневая проблема §3 |
| A. Полнота | 4 | PASS | Design goals §4 |
| A. Полнота | 5 | PASS | Non-Goals §5 |
| B. Дизайн | 6 | PASS | Ответственность §6.1 |
| B. Дизайн | 7 | PASS | Integration triggers §8 |
| B. Дизайн | 8 | PASS | Graph/config/ownership rules §6–7 |
| B. Дизайн | 9 | PASS | Blocked/unknown/fail-open semantics §6 |
| B. Дизайн | 10 | PASS | Bounded store budget и latency evidence §6,11 |
| C. Безопасность | 11 | PASS | Persisted/calculated data §9 |
| C. Безопасность | 12 | PASS | Versioned compatibility и migration §6.6,10 |
| C. Безопасность | 13 | PASS | Isolated rollout/drift/backup/rollback §10 |
| D. Проверяемость | 14 | PASS | AC1–14 описывают результат |
| D. Проверяемость | 15 | PASS | Negative fixtures и 16 behavioral pairs |
| D. Проверяемость | 16 | PASS | Команды и stop rules §11 |
| E. Автономная реализация | 17 | PASS | Последовательные пакеты §13 |
| E. Автономная реализация | 18 | PASS | Решения выбраны, design вопросов нет §6.5,14 |
| E. Автономная реализация | 19 | PASS | Large expanded, future short не применяется ретроактивно |
| F. Профиль | 20 | PASS | §15 |

Итог: ГОТОВО. Нумерация развёрнута по текущим блокам linter; точные критерии нового owner вводятся только на EXEC.

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
| --- | ---: | --- |
| Цель/границы | 5 | Все R/S/U имеют scope, side effects ограничены |
| AS-IS | 5 | Исходные fixtures и audit отличены от новой проверки |
| Дизайн | 5 | Выбраны parser/platform/graph/contracts |
| Безопасность | 5 | Provenance, handles, migration, drift/rollback |
| Тестируемость | 5 | AC mapping, negatives, real smoke |
| Автономность | 5 | Пакеты/решения определены, открытых design вопросов нет |

Итог 30/30; готово к автономной реализации после approval. Балл не заменяет review и approval.

### Role-Based Review Result

| Role | Applicability | Review question | Verdict | Required spec changes |
| --- | --- | --- | --- | --- |
| Business analyst / domain workflow | applicable | Все предложения и STORM semantics согласованы? | PASS | EN supports/status/required fields исправлены, targeted re-review PASS |
| UX / designer | applicable для artifact/workflow | Понятны короткая SPEC, CLI diagnostics и результаты? | PASS | Роль включена; компактная форма, field-path errors и migration diagnostics заданы |
| Tester / validation | applicable | Покрыты контрпримеры и smoke? | PASS | Добавлены identity, explicit authorization, legacy/budget и supports-only negatives |
| Developer / architect | applicable | Общие contracts без лишнего framework? | PASS | Узкие shared contracts, single-file immutable runtime, точные subsets |
| Delivery / operations / security | applicable | Ownership, writes, runtime и rollback честны? | PASS | Legacy no-adoption, controlled identity, platform/deadline limits, isolated rollout |

### Post-SPEC Review

- Статус: PASS после исправлений и повторного review.
- Scope reviewed: текущая spec и план файлов §16; baseline audit и три design exploration.
- Decision: можно запрашивать подтверждение; обязательные catalog checks завершились успешно.
- Review passes:
  - Scope/Evidence: текущая spec, полный audit, план файлов, текущие owner/templates/scripts и baseline gates сопоставлены.
  - Contract: все R1–R11/S1–S6/U1–U10 имеют design/AC, Non-Goals и версии согласованы.
  - Adversarial risk: отдельный reviewer выявил EN graph, authorization, identity и applicability роли; targeted reviewers — legacy ownership/budget и STORM types/status/output.
  - Role-Based: все пять применимых ролей проверены, таблица выше.
  - Fix and re-review: все объективные замечания внесены; общий reviewer и targeted STORM/telemetry reviewers подтвердили PASS готового snapshot.
  - Stop decision: design PASS, дальнейшие доказательства native safety/runtime behavior относятся к EXEC, не подменяются этим review.
- Evidence inspected: baseline audit 132 files/326 assertions; current scripts/templates/contracts; design conclusions installer, telemetry, STORM.
- Depth checklist: scope R/S/U mapped; AC и user scenarios заданы; execution evidence не выдано за выполненное; edge cases/versioning/migration указаны; docs/changelog impact включён; manual challenge — не скрыт ли новый bypass в helper/package/filesystem contract.
- Independent-review ограничение: effective sandbox текущих agents writable; read-only поручение не является техническим sandbox. Использовать adversarial fallback, не заявлять независимое read-only evidence.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | graph | EN supports мог потеряться в closure | Traceability-only, unranked reason и fixture | fixed |
| MEDIUM | authorization | B3 мог требовать повторный approval явного push | Два fixtures local-only / explicit target + inert tool | fixed |
| MEDIUM | identity | Expected host/runtime/session не было с чем сравнивать | Controlled runner expectation и negative tests | fixed |
| MEDIUM | review roles | UX необоснованно исключён для artifact/workflow | Применимая роль и concrete output pass | fixed |
| MEDIUM | telemetry ownership | Legacy shape могла стать правом удаления | Exclusive-create binding, no adoption, diagnostic/skip | fixed |
| MEDIUM | telemetry budget | Scan/locks не имели общего бюджета | Cooperative deadline, bounded scan и failure fixtures | fixed |
| MEDIUM | STORM contract | Не определены statuses и EN required/optional | Точные enums/fields/CN priority | fixed |
| LOW | schema/output/metrics | Неявные annotations/version location/zero denominator | Явные containers/outputs/null metric при numeric count0 | fixed |

- Fixed before continuing: все строки findings table; новых HIGH/MEDIUM после re-review нет.
- No-findings justification: повторный adversarial pass проверил исправленные counterexamples и границы scope; targeted domain passes независимо от root подтвердили внутреннюю согласованность. Это не evidence технической read-only изоляции или выполненной реализации.
- Checks rerun: `pwsh -File scripts/validate-instructions.ps1` — exit 0 после design/review fixes; `pwsh -File scripts/test-validate-instructions.ps1` — exit 0, включая 326 assertions agent operations. Full suite выполнялась на неизменённых текущих scripts; она не проверяет будущую реализацию этой spec. Финальная запись результатов проверяется catalog validator. `git status --short`: единственное изменение — новая текущая spec, canonical files не менялись.
- Needs human: exact SPEC approval после PASS.
- Residual risks: native store/platform limitation; large change set; реальные CI/model tests выполняются только в EXEC.

### Post-EXEC Review

- Статус: PASS. Четыре lane review и targeted re-review, полный candidate/active gate и 16 пар runtime smoke завершены; AC1–AC14 выполнены в указанной области доказательств.
- Scope/Evidence: ROOT docs/validator, installer/probe/evidence, telemetry/analyzer и STORM implementation сопоставлены с R/S/U; результаты в [evidence](evidence/2026-09-07-catalog-review-remediation.md).
- Contract: approval/ownership/rollback, short exclusions, profile composition и versioned migrations проверены; внешняя установка и доставка исключены.
- Adversarial risk / Fix and re-review: исправлены Markdown traversal/escape/block boundary, TOML dotted headers, explicit failure/legacy overflow/historical counts, hardlink output и Unicode truncation. Все targeted reviewers подтвердили устранение находок.
- Role-Based: domain — STORM graph/metrics; UX — short artifacts/diagnostics/portable onboarding; tester — negative fixtures и реальные synthetic scenarios; developer — shared contracts и schema/model consistency; operations/security — ownership/handles/evidence freshness/activation boundaries. Применимые роли просмотрены; runtime results проверены по фактическим файлам, calls и совпадающей конфигурации всех 16 пар.
- Depth checklist: scope и AC mapping, baseline counterexamples, controlled races, malformed input и output integrity, compatibility/migration, docs и CI configuration просмотрены. Review не подменяет local/CI/production execution.
- Unrelated changes: исторические SPEC изменены только для переносимости ссылки и корректного outer fence. Других подсистем в diff нет.
- Needs human: нет в текущем approved scope; реальные config/runtime install, trust и Git delivery требуют отдельного scope.
- Residual risks: writable adversarial fallback вместо технически независимого read-only review; Windows NTFS platform limit; synthetic smoke и latency fixtures не доказывают production поведение. Полный CommonMark parser не заявляется.

## Approval

Подтверждено пользователем 2026-09-07: «Спеку подтверждаю» (Markdown-разметка внутри слова не меняет однозначный смысл сообщения). Фаза EXEC. Предыдущее подтверждение Astra migration не использовалось для этого scope.

## 20. Журнал действий агента

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача человеку | Было ли обращение / решение | Короткое объяснение | Артефакты |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Уточнение scope «Исправляй» после audit | 0.95 | Новый approved contract | Подготовить единый план R/S/U | Позже exact approval | Пользователь поручил исправления; exact approval этой spec нет | Сохранён весь scope ревью | Эта spec |
| SPEC | Bounded design exploration installer/telemetry/STORM | 0.9 | Execution tests ещё не запускались | Adversarial review готовой spec | Нет | Нет | Выбраны минимальные contracts и compatibility | Только эта spec; read-only exploration |
| SPEC | Draft design + AC + migration | 0.95 | Итоговый review | Review/fix/check | После review | Нет | Expanded canonical template, один approval всего набора | Эта spec |
| SPEC | Исправление adversarial findings | 0.95 | Targeted re-review | Перепроверить поправки и gates | После PASS | Нет | Уточнены EN/status/schema, legacy ownership/budget, identity и explicit delivery approval | Эта spec |
| SPEC | Post-SPEC и targeted re-review | 0.98 | Завершение full suite | Записать check results, запросить exact approval | Да, после checks | Пока нет | Design PASS, все MEDIUM исправлены; writable adversarial fallback указан | Эта spec |
| SPEC | Catalog quality gates | 1.0 | Только exact approval для EXEC | Представить готовую spec | Да | Запрос approval в финальном сообщении; решение ещё не получено | Validator exit0, full suite exit0/326 assertions; implementation не выполнялась | Только эта spec |

| EXEC | Approval/preflight/isolation | 1.0 | Реализация и проверки ещё идут | Реализовать R/S/U пакетами | Нет | Подтверждение получено 2026-09-07 | Новый isolated checkout, immutable baseline, runtime0.153.4; ownership installer/telemetry/STORM/root | Candidate spec и assigned files |
| EXEC | Implementation и adversarial fixes | 0.98 | Общие финальные gates | Завершить paired smoke и full tests | Нет | Текущее approval действует | Все R/S/U реализованы; четыре lane review PASS после исправлений; Python37 PASS | Implementation, regression fixtures, переносимое evidence |

| EXEC | Финальные gates и active application | 1.0 | Нет в утверждённом scope | Завершить с evidence | Нет | Approved scope выполнен | Candidate/active full PASS, STORM37, behavior16pairs; 74 файла с backup и matching hashes, junction сохранён | Переносимое evidence, локальный activation manifest и hash receipt |
