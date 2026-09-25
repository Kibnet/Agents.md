# Поведенческий smoke для outcome contracts

`manifest.json` связывает S01–S18, отдельные variants S16–S18 и H06/H11. Источник переносимых данных — JSON в `cases/`, отдельные reviewer-only JSON в `oracles/` и синтетические PNG в `images/`.

Запуск из корня каталога:

```powershell
pwsh -File scripts/run-outcome-behavioral-smoke.ps1 -BaselineRoot <immutable-baseline> -CandidateRoot <candidate> -OutputDirectory <ignored-local-output> -Phase baseline
pwsh -File scripts/run-outcome-behavioral-smoke.ps1 -BaselineRoot <immutable-baseline> -CandidateRoot <candidate> -OutputDirectory <same-output> -Phase candidate
pwsh -File scripts/run-outcome-behavioral-smoke.ps1 -BaselineRoot <immutable-baseline> -CandidateRoot <candidate> -OutputDirectory <same-output> -Phase candidate -HeldOut
```

Для отдельного набора fixtures передайте `-FixtureRoot <candidate>/scripts/fixtures/<pack>`. Pack должен быть прямым дочерним каталогом `scripts/fixtures/` candidate и содержать `manifest.json`; без параметра используется `outcome-contracts`. `caseId` допускается только как один безопасный сегмент пути. Все ссылки manifest на case, oracle и image канонизируются, должны указывать на обычные файлы внутри pack и не могут выйти через `..`, абсолютный путь, symlink или reparse point.

`-Cases S04-base,S05-base` выбирает непересекающуюся группу; `-HeldOut` запускает два контрольных случая только на candidate после стабилизации изменений. Итого 21 пара и два candidate-only heldout: 44 model case executions. `-Preflight` проверяет два настоящих хода, разрешённую запись виртуального файла и read-back. Нельзя запускать две группы с одним case ID и одной фазой. Существующие outputs не перезаписываются. Изменение source snapshots вызывает ошибку; для нового проверяемого snapshot нужен отдельный output root.

Поверхность — Codex App Server stdio 0.154.0, `gpt-6-astra`/`high`. Это отдельный CLI-процесс, не текущий Desktop runtime. Проверяется effective response: модель, effort, версия, `readOnly`, выключенная сеть, `environments=[]`, источники инструкций. Нативные окружения отсутствуют; shell, MCP, plugins, memory, agents выключены process-only overrides. Пользовательские настройки и auth-файлы не изменяются и не копируются.

App Server этой версии всё равно обнаруживает global AGENTS pointer. Допустим ровно этот единственный bootstrap; сохраняются его bytes/hash. Все пути pointer обрабатывает замкнутый backend, отдающий только выбранный frozen snapshot. Активные owners и прочие host paths через backend недоступны. Этот транспортный mapping не меняет файловый junction. Единственные инструменты workspace — чтение/запись виртуальных файлов и конечный набор inert operations. Они изменяют только состояние in-memory simulation, не исполняют команды и не обращаются к внешним системам. HOST read-only не отменяет явно предоставленную virtual capability; task scope и approval gates сохраняются. Артефакты модели сохраняются JSON-снимком, без материализации произвольных путей.

Continuation — отдельный `turn/start` той же thread; S05 — настоящий `turn/steer` после commit operation до ответа инструмента. Сохраняется acknowledgement steering. S09 передаёт PNG в model input и возвращает другое состояние как image tool output. S16 геометрические ответы являются узкой синтетической проверкой файла, а не доказательством рендера реального UI.

Runner читает только ссылки manifest на входы. Содержимое `oracles/` не открывается и отсутствует в виртуальной файловой системе модели. Нет автоматической самооценки. `execution.status=executed` означает завершённые model turns, **не behavioral PASS**. Независимый reviewer сравнивает `protocol.jsonl`, `tool-trace.json`, `workspace-final.json`, `mutations.json` и `steering.json` с oracle; отмечает фактическую image inspection, выбранные параметры действий, момент проверок после mutation и отсутствие запрещённых эффектов.

Before/after сравнимы только при одинаковых case, tools, adapter и bootstrap hashes и одинаковом effective runtime. Catalog hash должен соответствовать своей фазе. После изменения fixtures не смешивать старый case trace с новым oracle. Инфраструктурные ошибки сохраняются как blocked/unverified; пропуск сценария не превращается в PASS. Во время ожидания процесс печатает heartbeat, без произвольного таймаута и автоматических повторов model case.

S13 задаёт обязательный capture AC в одноразовом диагностическом окне: восстановить approved memory headroom или перезапустить сервис в нём нельзя, отсрочка теряет evidence. Это существенный выбор нового риска, а не ситуация с очевидным безопасным способом выполнить тот же результат.

`audit_pairs.py --output <output> --baseline <root> --candidate <root>` проверяет полноту 44 executions, current source/snapshot hashes, actual turn count, steering acknowledgement, отправленные images и одинаковый runtime. У heldout сравнивает runtime с соответствующим candidate S06/S11. Его `status=valid` означает валидность provenance, а не behavioral PASS. Для отдельного pack передайте тот же корень через `--fixtures <candidate>/scripts/fixtures/<pack>`; к нему применяется та же canonical path boundary.

```powershell
python -B scripts/fixtures/outcome-contracts/audit_pairs.py --output <output> --baseline <immutable-baseline> --candidate <candidate>
```

Для согласованной проверки затронутой поверхности используется `--cases S02-base,S03-base,S04-base,S05-base,S13-base,S14-base`. `--baseline-output <earlier-output>` повторно использует исходные baseline traces без model rerun. Результат называется `scoped_valid` и перечисляет точный scope; это не полный PASS каталога. Scoped report дополнительно сохраняется под именем с hash списка cases. Для heldout на финальном snapshot можно явно указать `--reference-candidate-output <earlier-output>`: старые S06/S11 используются только для сравнения runtime, а не выдаются за повторный прогон с финальными инструкциями.

Реальные user texts и порядок `turn/start`, текст/граница/acknowledgement `turn/steer`, фактически отправленные developer instructions и dynamic tool schemas сверяются с case и provenance. В текущем прогоне не записывался per-process hash backend implementation; retained frozen source и независимый review его семантики не объявляются криптографическим доказательством bytes каждого уже запущенного процесса.

Локальные проверки backend без модели:

```powershell
python -B -m unittest discover -s scripts/fixtures/outcome-contracts -p "test_runtime.py"
```
