# Evidence: исправления каталога по ревью 2026-09-07

Scope и критерии: [утверждённая SPEC](../2026-09-07-catalog-review-remediation.md). Baseline: `5212f3bcae20a2092e75887def72323975205621`. Каталог `4.0.0`, immutable runtime `3.2.0`, evidence schema `2`, STORM starter `1.2`.

## Изменения и доказательства

| Требования | Реализация | Evidence |
| --- | --- | --- |
| R1, R11 | Переносимые ссылки; fence/inline-code reader; containment относительно каталога | Старый validator принимает private absolute link и незакрытый fence; новые negative fixtures отклоняют их, escape/block boundary regressions |
| R2, R3, U1, U2 | Общий TOML scanner/spans; reviewer provenance; два окна freshness и controlled identity | Multiline/BOM/CRLF, dotted tables, preexisting/legacy reviewer, raw-byte drift, stale/mismatched evidence и commit barrier fixtures |
| R4, U3 | Windows NTFS handle store; exclusive ownership, identity/generation binding; bounded retention 45 дней | Reparse/hardlink/foreign-file и controlled race barriers; rollback, budget и retention tests; чужие bytes сохраняются |
| R5, R6, U4 | Direct-command classification; структурированные outcomes раньше keywords; sample metrics | Shared rg vectors, compound exit, explicit failure flags, успешное чтение документации, malformed legacy records и historical-window fixtures |
| R7, R8, R9, U4, U10 | Shared STORM schema/model/graph; zero RICE; точные метрики/EN/CN | 37 Python tests, включая types, cycles, zero values, hardlink outputs и invalid Unicode без потери данных |
| R10 | Analysis-only отделён от test/source mutations | Обновлены owner и prompts; поведенческая пара B4 |
| S1, S2, S5, U7 | Short/expanded по риску; lean wrappers, единые owner; три обязательные непустые секции | 20 критериев linter, rubric с примерами; structural fixtures и пары B1/B2/B8 |
| S3 | Structural checks / machine JSON / text guards / behavior evidence разделены | API JSON mutations и Markdown fixtures; модельный smoke отдельно от lint |
| S4 | Узкие shared helpers, один immutable hook | Общий TOML module и STORM model; captured module bytes/hash; hook не загружает mutable helper |
| S6 | Backlog с explicit status и owner links | Сохранена история; promoted/partial/open вместо безусловных повторных внедрений |
| U5, U6, U8, U9 | Local/global onboarding; stack/domain/change profiles; runner-specific tests; TCP-level preflight | Пары B5/B6/B7; preflight JSON обозначает `tcp-connect` |

## Проверки

Исполнение локальное на Windows, PowerShell 7 и Python 3.14. CI-конфигурация включает отдельные Ubuntu catalog checks, Windows operational tests и Python 3.11/3.14; фактический GitHub Actions run в этом изменении не выполнялся.

| Проверка | Результат |
| --- | --- |
| `pwsh -File scripts/validate-instructions.ps1` | PASS: candidate и active через рабочий junction |
| `pwsh -File scripts/test-validate-instructions.ps1` | PASS: повторный полный candidate и полный active run; каждый — 318 основных operational assertions + 96 installer + 136 telemetry; Markdown helper 43. Первые три устаревших analyzer fixture исправлены без снижения ожидаемых counts |
| `python -m unittest discover -s scripts/storm/tests -p "test_*.py"` | PASS: candidate 37 tests / 20.414 s; active 37 tests / 19.957 s |
| Markdown helper targeted | PASS: 43 assertions |
| Installer targeted | Исходные R2/R3 воспроизведены; focused final PASS: 96 assertions |
| Telemetry targeted | Native/security/retention/classification final PASS: 136 assertions |
| `git diff --check` | PASS |
| Clean export | PASS: отдельная копия без `.git` и личных файлов, собственные helper modules |
| Before/after behavior | Before: 12 PASS / 4 FAIL; after: 16 PASS; runtime и артефакты проверены отдельно от self-reported rubric |

## Производительность hook

Пять interleaved cold-process измерений baseline/candidate на одинаковом fixture, все десять процессов exit 0. Медиана до: **1158.999 ms**, после: **1915.485 ms**, отношение **1.653×**. Это замедление, ниже согласованного порога sustained 2×; оно включает запуск PowerShell и компиляцию native helper. Отдельный controlled near-limit maintenance уложился в 118 ms; это fixture evidence, не production SLA. Последние исправления классификации native store не меняли.

## Поведенческое evidence

Фиксированные 16 prompts B1a–B8b выполняются на реальном App Server `0.153.4`, `gpt-6-astra`, effort `low`, ephemeral, sandbox `workspace-write`, approval `never`, без model fallback. Before берёт immutable baseline, after — candidate; для каждой пары сохраняются effective runtime, tools/developer/source hashes, выбранный snapshot, tool calls, созданные файлы и результаты. B8b использует реальные `turn/steer` сообщения; delivery tool B3b инертен.

Первый широкий прогон прерван после TLS/stream disconnect; он не считается product PASS/FAIL. Повторный прогон использует одинаковую для обеих фаз выборку применимых документов и последовательное выполнение внутри фазы. Это synthetic consumer smoke, а не реальная установка, deployment или исчерпывающая оценка поведения модели.

| Case | Before → after | Проверенный результат after |
| --- | --- | --- |
| B1a, B1b | FAIL → PASS (2 пары) | Short SPEC содержит outcome, решения, AC/check, risk, review, approval и журнал; product bytes не изменены |
| B2a, B2b | PASS → PASS (2 пары) | Expanded config/security SPEC; provenance/rollback и неизвестные обозначены; только SPEC writes |
| B3a, B3b | PASS → PASS (2 пары) | READY + full checker; отдельный explicit inert publish ровно один раз, без повторного approval |
| B4a, B4b | PASS → PASS (2 пары) | Analysis-only с неизвестным coverage; новые test mutations маршрутизируются через delivery/QUEST |
| B5a, B5b | FAIL → PASS (2 пары) | Desktop, RavenDB и UI automation применяются вместе; произвольный cap удалён |
| B6a, B6b | PASS → PASS (2 пары) | Portable local pointer и verified global-only; ограничения другого host/CI раскрыты |
| B7a, B7b | PASS → PASS (2 пары) | TUnit treenode filter; unknown runner сначала фактически прочитан, затем VSTest filter |
| B8a, B8b | PASS → PASS (2 пары) | Нет повторных проверок после green; actual steering сохраняет ответ/цель, меняет stage2 на B и отменяет последующие записи |

Во всех 16 парах runtime JSON совпадает целиком, включая config, developer/tools hashes и global source hash. Фактически доставленный первый user message совпадает с сохранённым input; tasks совпадают с фиксированным JSON; inline blocks совпадают с selected manifests и baseline/candidate. Добавление short template — ожидаемое изменение состава B1/B2/B4. Оценка BEFORE опирается на артефакт: B2a остаётся PASS, несмотря на слово «компактная» в самоописании полной SPEC; B6b также PASS для именно заданного verified host.

Ограничения: общий fixture checker проверяет `message.txt`; его результаты для SPEC/analysis не являются доказательством качества документа. Эти артефакты проверены отдельно, нерелевантные failures не скрыты моделью. Часть owner-файлов предоставлена inline, без физической копии для `read_fixture`. B8b проверяет steering на границах операций, а не прерывание уже выполняющегося tool.

## Post-EXEC review

Раздельные adversarial passes ROOT, installer, telemetry, STORM. Все reviewers работают в writable sandbox; это fallback по ролям, **не технически независимое read-only evidence**.

| Область | Найдено и исправлено | Re-review |
| --- | --- | --- |
| Markdown | Relative traversal за корень; escaped opening backtick; span через границу абзацев | PASS, limited reader; full CommonMark не заявляется |
| Installer | Whitespace вокруг dot в managed table header обходил guard | PASS, parser и installer/probe negatives |
| Telemetry/analyzer | Explicit failure маскировался под no-match; overflow legacy exit; historical counts приводили к exit 2 | PASS; дополнительно исправлен sampleSize без salt |
| STORM | Hardlink output мог перезаписать input; Unicode encoding после truncation терял bytes | PASS, samefile guard и подготовка bytes всех outputs до записи |

Новых HIGH/MEDIUM после этих повторных проверок нет. Интеграционный прогон дополнительно выявил старые plain-text error fixtures: они заменены typed outcomes, сохранив ancestry/duplicate/tainted-pair expectations. Полные candidate и active gates завершились PASS; cleanup вложенных junction исправлен и проверен с неизменным внешним sentinel.

## Применение и границы

Работа выполнена в isolated checkout `fix/catalog-review-remediation`; проверенный пакет из 74 файлов применён к активному `C:\Projects\My\Agents`. HEAD остался `5212f3bcae20a2092e75887def72323975205621`, branch `main`, junction `C:\Users\Kibnet\.codex\agents` сохранил исходный target. До применения проверены все baseline hashes и утверждённая SPEC; сохранены backup и manifest. Все postimage hashes совпали с candidate. Active validator и полная suite запущены через рабочий junction; Python suite — из активного checkout. После этих gates обновлены только две записи SPEC/evidence о фактическом завершении, с проверкой прежних hashes; финальный catalog validator запускается повторно.

Real config, installed runtime, host hook trust, reviewer activation и пользовательские session logs не меняются. Runtime 3.2.0 начнёт действовать только после отдельной установки/активации; legacy telemetry не усыновляется автоматически. Unsupported filesystem/API приводит к telemetry skip с сохранением warn-only работы. Windows NTFS fixtures не доказывают поддержку других платформ.

Локальные raw artifacts (не требуются для validator/CI): `C:\Users\Kibnet\AppData\Local\Temp\agents-remediation-a13d32412705454385f4175556c03f72`. Здесь сохранены baseline archive, manifests, logs, runtime events и paired latency JSON. Дополнительные worker artifacts указаны в итоговом локальном manifest. Этот переносимый документ хранит выводы и границы доказательств; личные Temp paths не являются Markdown links.

Перенос проверен в четырёх изолированных filesystem-сценариях: обычная запись, drift под exclusive handle, конфликт CreateNew, concurrent edit при rollback. Все PASS; чужие bytes сохраняются. Реальный перенос завершён без rollback. Git commit/push/release не выполнялись.
