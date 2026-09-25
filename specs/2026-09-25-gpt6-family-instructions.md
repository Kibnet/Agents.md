# Поддержка семейства GPT-6 в каталоге инструкций

## 0. Метаданные

- Тип: catalog-governance; профиль `product-system-design` (публичный machine contract и границы API).
- Владелец: Павел; исполнитель: Codex.
- Масштаб: medium; expanded SPEC из центрального `templates/specs/_template.md`, поскольку меняются семантика инструкций и API metadata.
- Behavior baseline: GPT-6 Astra; семейство выбора workload: GPT-6 Astra / Sol / Luna; явные GPT-5.6 pins сохраняются.
- Поверхности: инструкции Codex/Work; API metadata отдельно для OpenAI API.
- Effective runtime подготовки: Codex desktop, Windows/PowerShell; точные model ID/effort не подтверждены runtime evidence. Для исполнения smoke их требуется зафиксировать; название семейства в сообщении не считается доказательством.
- Baseline репозитория: `main`, HEAD `9c63f4de6c2d7a54825e7fcf839a6046087f9fcb`; до SPEC рабочее дерево чистое.
- Активный путь: `C:\Users\Kibnet\.codex\agents` — проверенный Junction на этот checkout. Реализация только в изолированном candidate после approval.
- Целевой релиз: следующий свободный MINOR после 5.0.0 (ожидается 5.1.0); перед EXEC перепроверить текущую версию.
- Фаза: SPEC; разрешено изменение только этого файла.
- Источники проверены 2026-09-25:
  - S1: https://developers.openai.com/api/docs/models/gpt-6-sol
  - S2: https://developers.openai.com/api/docs/models/gpt-6-luna
  - S3: https://developers.openai.com/api/docs/guides/latest-model/gpt-6-astra.md
  - S4: https://developers.openai.com/api/docs/guides/reasoning
  - HTML открыт web-инструментом; содержимое S1/S2/S3 дополнительно прочитано через официальный Markdown endpoint. Markdown fetch web-инструмента не поддержал content-type; использован Invoke-WebRequest без записи файлов.

## 1. Overview / Цель

Исходное поручение: найти информацию о новых GPT-6 и предложить улучшения инструкций; текущий запрос: «Оформи спеку». Результат будущего EXEC — согласованный каталог, который учитывает Sol и Luna, правильно объясняет API-ограничения и сохраняет пользовательский выбор модели.

Success means: агент рекомендует модель по сложности, качеству, времени и стоимости задачи; верно отличает ограничения Astra от Sol/Luna; не выводит доступность Codex из API-документации.

Артефакты EXEC: обновлённые owners, JSON contract, проверки, changelog и evidence. Stop: все обязательные AC подтверждены; недоступный обязательный smoke блокирует активацию, а не заменяется lint.

## 2. Текущее состояние (AS-IS)

- `model-behavior-baseline.md` уже задаёт Astra, outcome-first, lean prompts, effort/eval и surface boundaries. В workload-рядах Sol/Terra/Luna ещё связаны с GPT-5.6 без явного нового семейства.
- `openai-responses-api.md` и `schemas/openai-api-model-contract.json` описывают Astra и три GPT-5.6 tiers; `reviewedAt` JSON — 2026-09-07.
- Валидатор явно проверяет Astra, GPT-5.6 и alias `gpt-5.6`. Условий Sol/Luna в нём нет.
- API owner ограничивает `configuration_update` Astra; текущий S4 описывает семейство GPT-6 в standard single-agent.
- Collaboration уже защищает продолжение разрешённой работы и QUEST; добавление повторов автономности не требуется.
- Активный каталог совпадает с checkout через junction: преждевременное редактирование owners затронет следующие сессии.

## 3. Проблема

Каталог отражает начало выпуска GPT-6 и не представляет отличия новых моделей; механическая замена названий дала бы неверные ограничения для `none`, tools и sampling.

## 4. Цели дизайна

Один owner поведения, отдельный owner API, один machine contract; явные модельные условия; совместимость старых pins и существующих полей; воспроизводимая проверка до активации. Рекомендация роли является эвристикой, а не обещанием качества.

## 5. Non-Goals

- Изменение выбранной модели пользователя, config.toml, hooks, skills, памяти, подписки, тарифа или ключей.
- Автоматическое включение Pro/Ultra, async, multi-agent, steering или новых API features.
- Создание runtime router или API-клиента; вызовы платного API ради проверки документации.
- Переписывание исторических SPEC/evidence, прежних model pins, изменение QUEST/authorization gates.
- Cross-model performance benchmark, гарантии экономии, commit/push/PR/release.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности

`model-behavior-baseline` — workload и effort heuristics; `openai-responses-api` — wire semantics; JSON — проверяемые значения; существующие validators — структурные и негативные проверки; summaries — только ссылки и краткий обзор.

### 6.2 Детальный дизайн

Поведенческий baseline Astra сохраняется. Рекомендательный ряд: Astra для сложной сквозной работы и высокой цены ошибки; Sol для сложной повседневной работы с балансом качества/времени/стоимости; Luna для ограниченных повторяемых задач с проверяемым выходом. Выбор учитывает фактическую доступность, явный pin и результаты eval. GPT-5.6 Terra остаётся legacy-вариантом, без изобретения GPT-6 Terra.

Если настройка модели не разрешена пользователем/поверхностью, агент даёт рекомендацию и работает в текущем runtime. Ухудшение качества, повторные исправления и интеграция результатов входят в cost per successful task; цена токена сама по себе не доказывает экономию. Дорогой benchmark не становится обязательным для каждого поручения.

API факты S1–S4:

| Условие | Astra | Sol / Luna |
| --- | --- | --- |
| Exact ID | gpt-6-astra | gpt-6-sol / gpt-6-luna |
| Efforts | low, medium, high, xhigh, max | none, low, medium, high, xhigh, max |
| `minimal` | не поддерживается | не поддерживается |
| Tools с reasoning | Responses | Responses |
| Function calling в Chat Completions | отсутствует | только effort none |
| Sampling/logprobs restrictions | текущие ограничения сохраняются | применяются при effort != none; отсутствие этого запрета не означает поддержку любого endpoint-параметра |
| EU residency | Standard | Standard |

`schemaVersion: 1` и старые записи/alias сохраняются. Добавить две записи, `reasoningEfforts`, `toolEndpoint: "responses"` как основной endpoint, `chatCompletionsFunctionCallingEfforts: ["none"]` как явно именованное исключение и `euUnsupportedServiceTiers: ["fast", "priority"]`. Для условных запретов добавить `parameterRestrictionsWhenReasoning` с объектом `efforts: ["low","medium","high","xhigh","max"]`, `unsupportedParameters: ["temperature","top_p","top_logprobs"]`, `chatCompletionsUnsupportedParameters: ["logprobs"]`, `responsesUnsupportedInclude: ["message.output_text.logprobs"]`. Существующие поля Astra не переопределять. Обновить sources/reviewedAt; consumer этого additive contract — локальный validator. Не вводить непроверенный alias `gpt-6`.

API owner объясняет семейную поддержку configuration_update по S4 с существующими ограничениями standard/single-agent, replay и compaction. Для async/steering проверяется текущая специализированная документация перед изменением Astra-only формулировок; при отсутствии однозначного подтверждения оставить проверку capability конкретной модели/harness, без обещания поддержки. Новые функции не включаются этой миграцией.

Инструкции о ясной цели, инициативе, краткости и завершении сохраняются у существующих owners; повторное добавление правил исключается semantic review. Числовые цены не включать в обязательный prompt: они изменчивы и не нужны для выбора роли.

Visual planning и UI video: Не применимо — изменение текстовых инструкций/API metadata без интерфейса. Производительность: измерять только фактические smoke duration/usage; заявлений об ускорении нет.

### 6.3 User-Observable Scenarios

| Scenario | Trigger | Expected result | Evidence | AC |
| --- | --- | --- | --- | --- |
| S01 | Выбрать модель для сложного исследования и массового извлечения | Разные уместные роли Astra/Sol/Luna с ограничениями | paired smoke | AC1, AC4 |
| S02 | Пользователь явно закрепил GPT-5.6 Terra | Pin сохранён, замена лишь рекомендация | paired smoke | AC1, AC4 |
| S03 | Sol/Luna, Chat Completions tools, effort high/none | high требует Responses; none допускает function calling | JSON checks + smoke | AC2, AC4 |
| S04 | Astra none; Sol/Luna minimal | Несовместимость распознана; low как миграционная отправная точка | negative checks + smoke | AC2, AC4 |
| S05 | API поддерживает модель, в Codex она не подтверждена | Нет утверждения о доступности или смены runtime | smoke | AC1, AC4 |
| S06 | Обновить активные инструкции | Проверенный candidate, drift gate, локальная активация и evidence | hashes + validation | AC5 |

### 6.4 State / Interaction Matrix

| State | Trigger | Result | Error/concurrency |
| --- | --- | --- | --- |
| SPEC | Exact approval | EXEC/candidate | До approval меняется только SPEC |
| Candidate | Все mandatory checks PASS | Готов к активации | Missing smoke → blocker |
| Ready | Active hashes совпали | Применён allowlisted change set | Drift → перечитать и подготовить заново |
| Active | Critical checks failed | Адресный rollback | Новые чужие правки не перезаписывать |

### 6.5 Decision Ledger

| Decision | Owner | Choice | Confidence | Risk | Needs user before EXEC |
| --- | --- | --- | --- | --- | --- |
| Optimization baseline | agent | Сохранить Astra | high | Низкий | Нет |
| Новые роли | agent | Семейство GPT-6 + legacy pins | high | Нужен smoke | Нет |
| Machine shape | agent | Additive schema 1 | medium | Обновить parser/checks синхронно | Нет |
| Активация | user | Только после exact approval и candidate checks | high | Активный junction | Нет, кроме approval всей SPEC |
| Цены и benchmark | agent | Без цен в core и без cross-model benchmark | high | Не обещать измеренный выигрыш | Нет |

### 6.6 Runtime / Config / Data Contract Matrix

| Area | Source of truth | Change | Compatibility | Verification |
| --- | --- | --- | --- | --- |
| API | Официальные model/guides + JSON | Sol/Luna conditional metadata | Existing keys сохранены | Positive/negative fixtures |
| Codex runtime | Actual session/runtime | Нет изменения | API не доказывает availability | Surface smoke |
| Каталог | Active junction + Git | Одно allowlisted применение | Hash/drift protection | Candidate/active checks |

## 7. Бизнес-правила / Алгоритмы

Приоритет выбора: явное пользовательское решение → доступность и полномочия → требования задачи → подходящая workload-роль → eval evidence при оптимизации. Недоступность не разрешает приписывать результат другой модели. Ни `max`, ни дешёвая модель не назначаются всем задачам автоматически.

## 8. Точки интеграции и триггеры

Routing всегда загружает model baseline, API owner — по существующим API-триггерам. Добавить Sol/Luna в поисковые команды и согласовать summaries, только если они описывают текущий ряд. JSON читается `scripts/validate-instructions.ps1`; негативные сценарии — существующим `scripts/test-validate-instructions.ps1`.

## 9. Изменения модели данных / состояния

Только additive JSON metadata из §6.2. Пользовательские данные, credentials, runtime settings и operational manifests не меняются. Исторические evidence не мигрируют.

## 10. Миграция / Rollout / Rollback

После approval: подтвердить active HEAD/status/junction, сохранить preimage hashes и создать isolated checkout. Authoring, before/after smoke и полный gate выполнить там. Перед применением сравнить HEAD, dirty state и hashes всех целевых файлов; при drift не перезаписывать новую версию. Применить один подготовленный allowlisted change set; новые файлы создавать без overwrite. Проверить postimage и повторить critical checks на active path. Откат — только файлы этого change set с совпадающим postimage, восстановление preimage; при конфликте остановить зависимую запись. Не менять config и не обещать обновление уже загруженного контекста текущей сессии.

## 11. Тестирование и критерии приёмки

- AC1: рекомендации и summaries включают GPT-6 роли, сохраняют pins и surface boundaries, не вводят GPT-6 Terra/непроверенные aliases.
- AC2: JSON и API owner согласованы по effort, endpoint, conditional parameters, EU restrictions, provenance и feature applicability.
- AC3: обязательные validators проходят; негативные fixtures выявляют испорченные Sol/Luna efforts, потерю none-only условия Chat Completions, sampling restrictions и EU restrictions; старые Astra/GPT-5.6 checks работают.
- AC4: before/after behavioral smoke на одинаковой подтверждённой model/surface/effort/sandbox конфигурации показывает корректность всех целевых сценариев без регрессии pins, QUEST и полномочий. Static lint не заменяет его.
- AC5: candidate и active hashes/validation подтверждены; diff ограничен §16; post-EXEC review PASS и changelog соответствует изменению.

Smoke: переиспользовать `scripts/run-outcome-behavioral-smoke.ps1` и `scripts/fixtures/outcome-contracts/runtime.py`, synthetic inputs без внешних side effects. Добавить optional `-FixtureRoot` / `--fixture-root` для нового набора `scripts/fixtures/gpt6-family-contracts/`; default старого suite, его cases/oracles и исторические outputs сохраняются. В новой папке — manifest, cases и reviewer-only oracles для S01–S05 плюс EU residency, conditional sampling, configuration_update, разрешённое продолжение работы и сохранение SPEC gate. Две задачи S01 оформить отдельными cases; всего 11 пар. Зафиксировать полный prompt, hash instruction bundle, actual runtime, ответы и verdict каждой пары. Для обеих фаз выбрать отдельный тестовый процесс Codex App Server `gpt-6-astra`/`high`, read-only/inert tools, без изменения user config; effective model/effort/sandbox/version должны совпасть. Global pointer обслуживается только frozen snapshot backend; host active owners недоступны. Oracle не передавать модели. Перед EXEC сверить доступный runner; отсутствие достоверного runtime binding блокирует smoke и активацию. Cross-model runs не требуются. Сохранять evidence в `specs/evidence/2026-09-25-gpt6-family-instructions/` после approval; auth/личные данные туда не копировать.

Плановая команда после добавления указанного optional параметра (значения путей определит EXEC preflight):

```powershell
pwsh -File scripts/run-outcome-behavioral-smoke.ps1 -BaselineRoot <frozen-baseline> -CandidateRoot <candidate> -FixtureRoot <candidate>/scripts/fixtures/gpt6-family-contracts -OutputDirectory <evidence-output> -Phase both
python -B -m unittest discover -s scripts/fixtures/outcome-contracts -p "test_runtime.py"
```

Перед полным запуском выполнить `-Preflight` на отдельном output path. Source scenarios и runner одинаковы для обеих фаз, различаются только instruction bundles. Audit проверяет фактические request frames, snapshot hashes и effective metadata, а не только запрошенную конфигурацию. Backend tests должны подтверждать прежний default и отказ для ошибочного fixture root; semantic oracle review остаётся обязательным.

В `runtime.py` расширить обе функции `snapshot()` и `verify_snapshot()` точным allowlisted путём `schemas/openai-api-model-contract.json`: bytes входят в frozen snapshot и provenance hashes и доступны через тот же virtual read backend. Проверить baseline/candidate read-back JSON, отказ при его подмене и неизменность остальных host boundaries. Исторические snapshots не переиспользовать с новым составом; прежний suite сохраняет scenario semantics, для новых прогонов формируется свежий snapshot. Не открывать произвольное чтение host/schema каталога.

Обязательные команды EXEC (AGENTS + изменение schemas/scripts):

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
python -m unittest discover -s scripts/storm/tests -p "test_*.py"
git diff --check
```

На active path повторить оба PowerShell validators, проверку JSON и hashes; Python suite повторить при отличии candidate/active либо новой ошибке. Stop: повторять только затронутые проверки после изменения или новой гипотезы ошибки. UI/build/install проверки не применимы; активность каталога доказывается путём и файлами, не перезапуском приложения.

### Acceptance-to-Test Matrix

| AC | Automated check | Semantic/runtime check | Evidence | If not tested |
| --- | --- | --- | --- | --- |
| AC1 | Targeted text checks | S01/S02/S05 | bundle + paired outputs | EXEC ещё не разрешён |
| AC2 | JSON assertions | S03/S04 + EU/sampling/configuration scenarios; source mapping | fixture results + sources | EXEC ещё не разрешён |
| AC3 | Два validators + STORM suite | Проверить причины негативных failures | command logs | EXEC ещё не разрешён |
| AC4 | Paired runner | Все verdicts; baseline failures допускаются, candidate failures нет | runtime metadata + raw outputs | Нет runtime → blocker |
| AC5 | Hashes + active checks | Scope/adversarial review | activation log + diff | До approval активации нет |

## 12. Риски и edge cases

Устаревание upstream — повторная сверка перед EXEC; противоречивые источники — не угадывать контракт. Conditional поля могут восприниматься как абсолютный запрет — отрицательные fixtures и S03. Новая модель может быть недоступна — сохранить фактический runtime. Legacy записи не удалять. Дорогая Astra может оказаться дешевле за успешный результат — не обещать экономию только по токенам.

### Expected User Review Objections

| Objection | Why likely | Mitigation | Status |
| --- | --- | --- | --- |
| «Опять только переименовали модели» | Цель — улучшить инструкции | Conditional contracts, роли и behavioral smoke | mitigated |
| «Ты переключил мне модель» | API и Codex часто смешиваются | Non-goals + S02/S05 | mitigated |
| «Каталог разросся» | Текущие правила уже подробны | Один owner на правило, без цен/повторов автономности | mitigated |
| «Прошёл lint, но агент ошибается» | Инструкции семантические | AC4 обязателен | mitigated |

Rework checklist: сценарии названы; AC связаны с evidence; решения записаны; objections закрыты дизайном; роли проверяются в §19; EXEC имеет путь доказательства, missing runtime блокирует активацию.

## 13. План выполнения

1. После exact approval — preflight, source refresh, isolated candidate и baseline hashes.
2. Baseline smoke; согласованные owners/JSON/checks; candidate smoke тем же runtime.
3. Полные обязательные checks; исправление in-scope defects; post-EXEC candidate review.
4. Drift gate, применение и active checks; итоговый review/evidence и краткий отчёт.

## 14. Открытые вопросы

Существенных продуктовых решений нет. Доступный runner/model binding проверяются в EXEC как технический preflight; без них результат не объявлять завершённым.

## 15. Соответствие профилю

`product-system-design`: цели/границы, разделение owners, интерфейс JSON, совместимость, проверяемый rollout и rollback определены. Core stack: creator-vibe-lens, model-behavior-baseline, collaboration-baseline, tool-execution-baseline, quest-governance/mode. Governance: routing-matrix, openai-responses-api, document-contract, versioning-policy, spec-linter/rubric, review-loops. Context: session-insights-context для прежнего migration workflow; его исторические утверждения перепроверены по текущим файлам/junction. Full creator-vibe не требуется: конкретная техническая спецификация по согласованным предложениям.

## 16. Таблица изменений файлов

| Файл | Изменения | Причина |
| --- | --- | --- |
| instructions/core/model-behavior-baseline.md | Роли семейства, pins, effort/eval | Актуальное поведение |
| instructions/governance/openai-responses-api.md | Conditional API и feature applicability | Правильные запросы |
| schemas/openai-api-model-contract.json | Additive Sol/Luna metadata | Машинный источник |
| scripts/validate-instructions.ps1 | Новые contract assertions | Выявление drift |
| scripts/test-validate-instructions.ps1 | Адресные negative fixtures | Проверяемость validator |
| scripts/run-outcome-behavioral-smoke.ps1; scripts/fixtures/outcome-contracts/runtime.py, test_runtime.py, audit_pairs.py, README.md | Optional fixture root, адресная совместимость runner/audit | Выполнение нового набора без изменения старых сценариев |
| scripts/fixtures/gpt6-family-contracts/ | 11 синтетических cases, manifest и отдельные oracles | Same-runtime behavioral smoke |
| AGENTS.md, README.md, instructions/governance/routing-matrix.md | Только необходимые summaries/links/markers | Согласованность; не дублировать owner |
| CHANGELOG.md | Следующий MINOR, scope/compatibility | Traceability |
| Эта SPEC и specs/evidence/2026-09-25-gpt6-family-instructions/ | Review, sources, logs, smoke | Доказательство результата |

Другие файлы требуют обоснования scope; история и внешние runtime настройки не входят.

## 17. Таблица соответствий (было → стало)

| Область | Было | Стало |
| --- | --- | --- |
| Workload | Astra + GPT-5.6 tiers | GPT-6 family + сохранённые legacy pins |
| Machine metadata | Только Astra из GPT-6 | Три модели с точными различиями |
| Tools | Astra правило | Responses + none-only исключение Sol/Luna |
| Effort changes | Astra-only wording | Семейная применимость с mode/harness ограничениями |
| Evidence | Static legacy checks | Расширенные negative checks + same-runtime smoke |

## 18. Альтернативы и компромиссы

Только переименование дешевле, но теряет conditional API semantics. Автоматический router потребует runtime-интеграции и не запрошен. Полный пересмотр всех prompts увеличит scope и риск. Выбран адресный family update с прежним Astra baseline и сохранением контрактов.

## 19. Результат quality gate и review

### SPEC Linter Result

| № | Статус | Evidence / основание |
| --- | --- | --- |
| 1 | PASS | §1, S01–S06: наблюдаемый результат |
| 2 | PASS | Owners/JSON/validator, HEAD и junction прочитаны, §2 |
| 3 | PASS | §3: неполный семейный контракт |
| 4 | PASS | §4: owners, совместимость, проверяемость |
| 5 | PASS | §5: config, публикация и полный router исключены |
| 6 | PASS | §6.1 и §16: ownership файлов |
| 7 | PASS | §8: router, JSON reader и fixtures |
| 8 | PASS | §6.2/§7: модельные условия и приоритет pins |
| 9 | PASS | §10/§12: drift, missing runtime, recovery |
| 10 | PASS | §6.2: нет performance promise, cross-model не нужен |
| 11 | PASS | §9: additive metadata, пользовательских данных нет |
| 12 | PASS | §6.2/§10: старые keys/pins, fresh snapshots |
| 13 | PASS | §10: адресный rollback с postimage guard |
| 14 | PASS | AC1–AC5 определяют готовность |
| 15 | PASS | Матрица AC, negative fixtures, 11 paired cases |
| 16 | PASS | §11: конкретные команды, preflight и stop rules |
| 17 | PASS | §13: baseline → candidate → active |
| 18 | PASS | Decision Ledger и §14: решения заданы |
| 19 | PASS | §0: medium/expanded из-за публичного behavior/API |
| 20 | PASS | §15: product-system-design применим к machine contract |

Итог: ГОТОВО к запросу approval после указанного ниже re-review; это оценка SPEC, не результатов EXEC.

### SPEC Rubric Result

| Критерий | Балл | Основание |
| --- | --- | --- |
| Цель/границы | 5 | §1/§5 и сценарии |
| AS-IS | 5 | Live файлы/HEAD/junction |
| Дизайн | 5 | Точные conditional поля и owners |
| Безопасность | 5 | Изоляция, drift и rollback |
| Проверяемость | 5 | AC→checks, paired smoke, JSON snapshot |
| Автономность | 5 | Решения заданы, runtime blocker определён |

30/30; готовность SPEC не заменяет approval и validation EXEC.

### Role-Based Review Result

| Role | Verdict | Evidence |
| --- | --- | --- |
| Domain workflow | PASS | Сохраняется исходный запрос улучшить инструкции, roles/pins доступны пользователю |
| Tester / validation | PASS | AC matrix, conditional negative checks, paired traces; JSON snapshot finding исправлен |
| Developer / architect | PASS | Additive schema и прежние поля, owner boundaries |
| Delivery / security | PASS | Active junction, isolated candidate, hashes/rollback; config и auth не меняются |
| UX / designer | Не применимо | Нет визуального интерфейса |

### Post-SPEC Review

Статус / stop decision: PASS на фазе SPEC; можно запросить exact approval. EXEC не начат.

- Scope reviewed: эта SPEC, §16, central template, quest-governance/mode, spec-linter/rubric, review-loops, model/API owners, product-system-design, schema/validator/runner, S1–S4.
- Scope/Evidence pass: текущие модели/условия проверены по официальным страницам; schema и два текущих consumers прочитаны. План не выдаёт API capability за product availability.
- Contract pass: AC1–AC5, pins, none/minimal, tools/sampling и unchanged Astra baseline согласованы.
- Advisory child: `/root/spec_review`, фактический sandbox `danger-full-access`, filesystem unrestricted, approval never. Действия только чтение; технически независимым read-only review не считается.
- Отдельный adversarial fallback основного агента: проверены контрпримеры Astra none, Sol high+Chat Completions tools, Luna none+sampling, недоступная Codex модель, устаревший alias, подмена active path и отсутствующий JSON в smoke. Новых нарушений после исправления JSON snapshot не выявлено; runtime evidence будет получено только в EXEC.
- Depth checklist: outcome/scope — §1/5; AC/negative coverage — §11; authorization — Approval; hidden contract change — additive fields; migration/rollback — §10; no unsupported availability/price claims — §6; duplicate rules — owners сохранены; no max/Pro default — §7.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | smoke completeness | Старый snapshot включает Markdown, но исключает API JSON | Включить exact JSON в snapshot/verify/hash/readback и negative tamper check | fixed; advisory re-review подтвердил закрытие |

- Fix and re-review: внесён exact JSON allowlist в обе snapshot функции, fresh snapshot policy и readback/tamper checks; повторно сопоставлены §11 и §16.
- Checks rerun: reviewer перечитал затронутые §11/16 и вернул PASS по поправке; основной агент подтвердил секции 0–20, `git diff --check` и единственный новый файл в status. Каталожные и behavioral suites не запускались: их реализация/результаты относятся к EXEC.
- No-findings justification: после поправки контракт доступен virtual agent полностью, сохраняются pins и API/product границы; обязательные smoke и activation checks не подменены lint.
- Manual-review challenge: одинаковые запрошенные model settings не доказывают одинаковый effective runtime; §11 требует actual frames/metadata и блокирует активацию при их отсутствии.
- Residual risk: live runner может оказаться несовместим с будущим App Server; проверка preflight и запрет ложного PASS определены. Needs human: только exact approval готовой SPEC после re-review.

### Post-EXEC Review

Статус: PASS. AC1–AC5 закрыты реализацией, same-runtime smoke, validators, active drift/hash gate и post-activation validation.

- Scope: изменены только файлы §16; active HEAD перед применением не дрейфовал, junction указывает на `C:\Projects\My\Agents`.
- Contract: Astra/Sol/Luna roles, сохранение explicit GPT-5.6 pins, effort/endpoint/sampling/EU constraints и API/product boundary согласованы между owners, JSON и validators.
- Behavioral evidence: baseline 5 PASS / 6 ожидаемых FAIL; candidate 11 PASS / 0 FAIL. Полные prompts, final answers, runtime и hashes сохранены в `specs/evidence/2026-09-25-gpt6-family-instructions/behavioral-smoke.json`; G08 после exact EU tier закрыт scoped delta.
- Candidate checks: оба PowerShell validators PASS; runtime tests 13/13; STORM tests 15/15; `git diff --check` без ошибок. Post-EXEC reviewer после исправления fixture traversal, durable evidence и docs вернул PASS.
- Active checks: оба PowerShell validators PASS; `test-validate-instructions.ps1` — 43 catalog assertions, 37/57 guards/mutations, 318 operations assertions, 96 checks / 0 failures; runtime tests 13/13; JSON exact fields PASS; `git diff --check` без ошибок.
- Hash gate: 39 candidate/active postimages совпали по canonical LF SHA-256. Byte-level отличие существующих текстовых файлов ограничено CRLF/LF; новых файлов не затронуло.
- Reviewer boundary: отдельный reviewer работал read-only по дисциплине, но имел writable/unrestricted sandbox; проход является adversarial review, а не технически независимым read-only evidence. Residual risk процедурной изоляции явно сохранён.
- Stop decision: реализация и локальная активация завершены. Commit, push, PR, release и изменение user config не разрешены и не выполнялись.

## Approval

Ожидается фраза: «Спеку подтверждаю». Текущий запрос разрешает подготовку SPEC.

## 20. Журнал действий агента

| Фаза / событие | Решение и основание | Evidence / остаток | Следующее действие | Решение человека | Артефакты |
| --- | --- | --- | --- | --- | --- |
| SPEC, 2026-09-25 | Оформить family update в expanded форме | Owners, API источники, active junction прочитаны; review впереди | Post-SPEC review | «Оформи спеку» | Эта SPEC |
| SPEC review завершён, 2026-09-25 | MEDIUM закрыт: JSON включён в дизайн smoke snapshot; advisory + adversarial fallback PASS | 20 linter criteria PASS, rubric 30/30; изменена только SPEC, implementation checks впереди | Exact approval | Ожидается «Спеку подтверждаю» | Эта SPEC |
| Переход SPEC → EXEC, 2026-09-25 | Exact approval получен; scope AC1–AC5 разрешён | Пользователь: «Спеку подтверждаю»; официальные OpenAI Docs повторно сверены | Создать isolated candidate и реализовать утверждённый change set | Спеку подтверждаю | Эта SPEC |
| EXEC candidate, 2026-09-25 | Реализован семейный контракт, JSON, validators и 11-case smoke pack | Candidate validators PASS; behavioral baseline 5/11, candidate 11/11; reviewer findings по path boundary/evidence/docs исправлены | Post-EXEC re-review | Approval уже дан | Candidate + durable evidence |
| EXEC activation, 2026-09-25 | После reviewer PASS применён allowlisted change set к active junction | 39 canonical hashes match; active validators, JSON, 13 runtime tests и diff check PASS | Завершить без delivery side effects | Дополнительного разрешения не требуется | Active files + evidence |
