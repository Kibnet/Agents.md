# Видео evidence из UI-тестов для фич и багфиксов

## 0. Метаданные
- Тип (профиль): catalog-governance + `ui-automation-testing`
- Владелец: central instruction catalog
- Масштаб: medium
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: `2.5.0` / текущая рабочая ветка
- Ограничения: до подтверждения спеки менять только этот файл; после подтверждения не менять поведение UI-тестов в потребительских репозиториях, только центральные инструкции и шаблон
- Связанные ссылки:
  - `instructions/profiles/ui-automation-testing.md`
  - `templates/specs/_template.md`
  - `instructions/governance/review-loops.md`
  - `instructions/governance/github-delivery-policy.md`
  - `CHANGELOG.md`

Если секция не применима, явно укажите `Не применимо` и короткую причину, вместо заполнения нерелевантными деталями.

## 1. Overview / Цель
Усилить центральные инструкции так, чтобы UI-facing фичи и багфиксы подтверждались видео evidence, записанным во время автоматизированных UI-тестов, с понятным состоянием `до` и `после`.

Outcome contract:
- Success means:
  - `ui-automation-testing.md` требует video evidence из UI test run для UI-facing фич и багфиксов, когда в репозитории есть релевантный UI suite и test runner, harness или CI умеет записывать безопасное видео.
  - Для багфикса зафиксирован контракт `до`: failing/repro UI test run до фикса; `после`: passing UI test run после фикса.
  - Для новой фичи зафиксирован контракт `до`: baseline текущего состояния, если он существует и полезен; иначе явное `Не применимо` с причиной; `после`: passing UI test run новой фичи.
  - Spec template подсказывает планировать UI video evidence в тестировании и acceptance criteria.
  - Post-EXEC review проверяет наличие нужного video evidence или явного fallback.
  - Changelog отражает изменение и влияние на потребителей.
- Итоговый артефакт / output:
  - Обновленные центральные документы и changelog.
  - Результаты validator/test suite.
  - Краткий EXEC-отчет с post-EXEC review.
- Stop rules:
  - Остановиться на SPEC до фразы пользователя `Спеку подтверждаю`.
  - На EXEC завершать только после обновления документов, changelog, validator checks и post-EXEC review.
  - Не требовать video evidence для non-UI задач, copy-only изменений без UI flow/state acceptance, репозиториев без релевантного UI suite или сред, где запись видео технически/безопасностно невозможна; в этих случаях нужен явный reason и next-best evidence.

## 2. Текущее состояние (AS-IS)
- `ui-automation-testing.md` требует UI tests для UI behavior / visual flows / UI-facing state changes при наличии релевантного UI suite.
- `ui-automation-testing.md` сейчас только рекомендует сохранять diagnostic artifacts на падениях: лог, screenshot, trace/video при наличии.
- `templates/specs/_template.md` содержит visual planning artifact и visual acceptance, но не требует планировать video evidence из UI test runs.
- `review-loops.md` проверяет visual planning artifact на post-SPEC и validation evidence на post-EXEC, но не проверяет `до/после` video evidence для UI automation задач.
- `github-delivery-policy.md` уже просит screenshots/video для UI-facing изменений в PR, но не связывает это с записью автоматизированных UI-тестов и `до/после`.

## 3. Проблема
Для UI-facing фич и багфиксов текущие инструкции допускают финальное подтверждение только текстовым отчетом, скриншотом или обычным UI test result, из-за чего reviewer не всегда видит воспроизводимое пользовательское доказательство поведения `до` и `после`.

## 4. Цели дизайна
- Разделение ответственности: `ui-automation-testing.md` задает профильное правило video evidence; `review-loops.md` проверяет его на EXEC; spec template помогает планировать evidence заранее; delivery policy связывает PR evidence с результатами UI tests.
- Повторное использование: использовать существующие механизмы записи Playwright, Selenium, FlaUI/AppAutomation wrappers, Avalonia.Headless artifacts, CI artifacts или test output directories.
- Тестируемость: evidence должно быть привязано к конкретной команде UI test run и acceptance scenario.
- Консистентность: формулировать правило как условный MUST, чтобы оно было строгим для поддерживаемых UI suites и не блокировало задачи, где запись невозможна или не применима.
- Обратная совместимость: не менять структуру документов `instructions/*`; добавить правила в существующие секции.

## 5. Non-Goals (чего НЕ делаем)
- Не внедрять видео-запись в конкретный потребительский репозиторий.
- Не выбирать единый storage backend для видео во всех проектах.
- Не требовать коммитить бинарные `.webm`/`.mp4` файлы в репозиторий.
- Не заменять автоматизированные UI tests ручной записью экрана.
- Не требовать `до`-видео для новой фичи, если до реализации не существовало осмысленного пользовательского flow.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/profiles/ui-automation-testing.md` -> профильный contract: когда video evidence обязательно, как трактовать `до` и `после`, какие fallback допустимы.
- `templates/specs/_template.md` -> подсказки в design/testing sections: план video evidence из UI tests, artifact paths/links, `до/после` applicability.
- `instructions/governance/review-loops.md` -> post-EXEC проверка: video evidence есть или явно объяснено `Не применимо` / fallback.
- `instructions/governance/github-delivery-policy.md` -> PR evidence: для UI automation задач указывать video artifacts из UI test runs.
- `CHANGELOG.md` -> новая версия `2.5.0` с impact summary.

### 6.2 Детальный дизайн
- потоки данных
  - SPEC фиксирует UI scenarios и video evidence plan.
  - EXEC сначала записывает `до` evidence, если есть багфикс или meaningful baseline.
  - EXEC после реализации запускает passing UI test и сохраняет `после` evidence.
  - Финальный отчет/PR/spec указывает команды и пути/ссылки на artifacts.
- контракты / API
  - Под `video evidence из UI test run` понимать видео, автоматически созданное test runner, trace viewer video, CI artifact или запись окна/браузера, запущенную и остановленную в рамках автоматизированного UI-теста.
  - Ручная screen recording без автоматизированного UI-сценария может быть supplementary evidence, но не заменяет UI test recording там, где test-runner recording доступен.
  - `До` для багфикса: failing/repro UI test run, подтверждающий исходный дефект. Characterization run допустим только если дефект нельзя надежно выразить как deterministic failing assertion; в этом случае видео должно визуально демонстрировать дефект, а отчет должен фиксировать причину выбора characterization.
  - `До` для фичи: baseline текущего поведения, если он помогает reviewer понять изменение; если flow новый, явно `Не применимо: flow отсутствовал до реализации`.
  - `После`: passing UI test run, подтверждающий исправление или новую фичу.
- output contract / evidence rules
  - Evidence указывается как repo-relative path, CI artifact URL, PR attachment/link или local-only path с явной пометкой `local-only`.
  - Если видео содержит чувствительные данные, использовать test fixtures/masking; если безопасная запись невозможна, явно указать причину и next-best evidence (`trace`, screenshots, logs).
  - Крупные бинарные видео по умолчанию не коммитятся, если в проекте нет принятой практики хранить такие artifacts в репозитории.
- visual planning artifact для UI-facing изменений: `Не применимо` к этой catalog-governance задаче; изменение не вводит UI layout/flow в приложении.
- границы сохранения поведения / допустимые изменения контракта
  - Новое правило усиливает evidence contract только для задач, где уже применяется `ui-automation-testing`.
  - Non-UI и backend-only задачи не получают новый video requirement.
- обработка ошибок
  - Fallback вместо видео допустим только по объективным причинам: UI suite отсутствует, recorder не поддерживается test runner/harness/CI, запись окна или headless-сессии технически невозможна, безопасная запись невозможна из-за чувствительных данных, либо CI/artifact policy запрещает сохранять видео. В этих случаях agent фиксирует причину, команду проверки и next-best evidence.
  - Если `после` UI test падает, задача не завершается.
- производительность
  - Видео recording может замедлять UI tests; допустимо включать запись только для targeted acceptance/e2e сценариев, а не для всего full suite.

## 7. Бизнес-правила / Алгоритмы (если есть)
Правило применимости:

| Условие | Требование |
| --- | --- |
| UI-facing багфикс + существующий UI suite + запись видео доступна | Записать `до` failing/repro video и `после` passing video из UI test run |
| UI-facing багфикс, где deterministic failing assertion невозможен | Записать `до` characterization video, визуально демонстрирующее дефект, и явно указать причину отказа от failing assertion |
| UI-facing новая фича + существующий UI suite + запись видео доступна | Записать `после` passing video; записать `до` baseline, если существовал meaningful flow |
| UI-facing изменение + UI suite есть, но video recording недоступен/опасен по объективной причине | Зафиксировать конкретную причину и next-best evidence: trace/screenshots/logs |
| UI-facing изменение без UI suite | Следовать текущему правилу профиля: не применять `ui-automation-testing`, если создание suite не согласовано отдельно |
| Non-UI изменение | Video evidence не требуется |

## 8. Точки интеграции и триггеры
- Триггер `UI behavior / automation / e2e` в `routing-matrix.md` продолжает выбирать `ui-automation-testing`; сам routing менять не нужно.
- SPEC gate использует `templates/specs/_template.md` для планирования video evidence.
- EXEC review использует `review-loops.md` для проверки evidence.
- PR delivery использует `github-delivery-policy.md` для ссылок на artifacts.

## 9. Изменения модели данных / состояния
- Новых данных приложения нет.
- Persistent state не меняется.
- В инструкции добавляется новый evidence artifact type: UI test video `до/после`.

## 10. Миграция / Rollout / Rollback
- Rollout: выпустить как `2.5.0` в changelog.
- Для потребителей: правило начинает действовать после обновления central stack.
- Rollback: удалить добавленные bullets из затронутых документов и удалить changelog entry версии `2.5.0`.
- Обратная совместимость: структура документов и шаблона сохраняется.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria
  - `ui-automation-testing.md` содержит условный MUST про video evidence из UI test runs для UI-facing фич/багфиксов.
  - `ui-automation-testing.md` различает `до` для багфикса, `до` для новой фичи и `после`.
  - `templates/specs/_template.md` содержит подсказку для планирования `до/после` UI test video evidence.
  - `review-loops.md` проверяет video evidence на post-EXEC для UI automation задач.
  - `github-delivery-policy.md` синхронизирует PR visual evidence с UI test recordings там, где применим профиль.
  - `CHANGELOG.md` содержит запись версии `2.5.0`.
- Какие тесты добавить/изменить
  - Изменений тестов validator не ожидается, структура документов не меняется.
- Characterization tests / contract checks для текущего поведения (если применимо)
  - До изменения выполнить `rg` по `video|trace|screenshot` для фиксации текущих мест evidence guidance.
- Visual acceptance для UI-facing изменений: `Не применимо`; это изменение инструкций, не UI приложения.
- Базовые замеры до/после для performance tradeoff (если применимо): `Не применимо`; performance impact относится к будущим consumer UI suites и ограничен targeted recording.
- Команды для проверки
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `rg -n "video|видео|до|после|UI test|UI-тест" instructions templates CHANGELOG.md`
  - `git diff --stat`
- Stop rules для test/retrieval/tool/validation loops
  - Повторять правки, если validator или validator tests падают из-за изменения.
  - Остановиться и сообщить пользователю, если возникает конфликт между новым rule и существующим owner-документом без единственного лучшего решения.

## 12. Риски и edge cases
- Слишком жесткое правило может блокировать desktop/headless проекты без стабильного video recorder.
  - Смягчение: условный MUST с явным fallback reason и next-best evidence.
- Видео может содержать секреты или персональные данные.
  - Смягчение: test fixtures/masking; при невозможности безопасной записи использовать trace/screenshots/logs с причиной.
- Большие artifacts могут засорять репозиторий.
  - Смягчение: по умолчанию хранить видео как CI artifact, PR attachment/link или local-only path, не коммитить binary evidence без принятой практики проекта.
- `До` для новой фичи может быть искусственным.
  - Смягчение: разрешить `Не применимо`, если flow реально отсутствовал.

## 13. План выполнения
1. Обновить `instructions/profiles/ui-automation-testing.md`.
2. Обновить `templates/specs/_template.md`.
3. Обновить `instructions/governance/review-loops.md`.
4. Обновить `instructions/governance/github-delivery-policy.md`.
5. Добавить `CHANGELOG.md` entry `2.5.0`.
6. Запустить validation commands.
7. Выполнить post-EXEC review и при необходимости исправить найденные проблемы.

## 14. Открытые вопросы
Нет блокирующих вопросов.

## 15. Соответствие профилю
- Профиль: `ui-automation-testing`
- Выполненные требования профиля:
  - Изменение усиливает UI test coverage/evidence для UI behavior, visual user flows и UI-facing state changes.
  - Сохраняет фокус на существующих repository UI test patterns.
  - Не требует создавать UI suite там, где его нет и создание не согласовано отдельно.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/profiles/ui-automation-testing.md` | Добавить video evidence `до/после` из UI tests | Основной профильный контракт |
| `templates/specs/_template.md` | Добавить подсказку video evidence plan и acceptance | Планирование evidence до EXEC |
| `instructions/governance/review-loops.md` | Добавить post-EXEC проверку video evidence | Не завершать UI automation задачу без evidence/fallback |
| `instructions/governance/github-delivery-policy.md` | Уточнить PR evidence для UI automation задач | Связать PR visual evidence с test-run artifacts |
| `CHANGELOG.md` | Добавить версию `2.5.0` | Выпуск значимого изменения каталога |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| UI evidence | Видео только как возможный diagnostic artifact на падениях | Video evidence из UI test run требуется для применимых UI фич/багфиксов |
| Багфикс | Требуется UI test и passing result | Требуется `до` failing/repro video и `после` passing video, если запись доступна |
| Новая фича | Требуется UI test и visual acceptance | Требуется `после` passing video; `до` baseline при meaningful existing flow |
| Post-EXEC review | Проверяет validation evidence в целом | Проверяет `до/после` UI test video evidence или явный fallback |
| PR evidence | Screenshots/video generic | Для UI automation задач video artifacts должны быть из UI test runs, если применимо |

## 18. Альтернативы и компромиссы
- Вариант: Требовать видео всегда для любых UI-facing задач.
- Плюсы: Максимально строгий reviewer evidence.
- Минусы: Блокирует проекты без UI suite/video support, создает риск записи чувствительных данных, замедляет full suites.
- Почему выбранное решение лучше в контексте этой задачи: условный MUST сохраняет жесткость там, где автоматизированная запись доступна, и требует явной accountability там, где она невозможна.

- Вариант: Оставить видео только рекомендацией (`SHOULD`).
- Плюсы: Минимальное влияние на потребителей.
- Минусы: Не выполняет запрос на подтверждающие видео `до/после`.
- Почему выбранное решение лучше в контексте этой задачи: профиль получает проверяемый requirement, а fallback остается ограниченным исключением.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, цели и Non-Goals зафиксированы |
| B. Качество дизайна | 6-10 | PASS | Ответственность, evidence rules, rollout и rollback описаны |
| C. Безопасность изменений | 11-13 | PASS | Риски, fallback и план выполнения покрывают безопасное внедрение |
| D. Проверяемость | 14-16 | PASS | Acceptance criteria, команды и таблица файлов проверяемы |
| E. Готовность к автономной реализации | 17-19 | PASS | Нет блокирующих вопросов, scope средний и bounded |
| F. Соответствие профилю | 20 | PASS | Изменение сфокусировано на UI automation evidence |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Цель и Non-Goals явно ограничивают video evidence contract |
| 2. Понимание текущего состояния | 5 | Перечислены текущие документы и пробелы |
| 3. Конкретность целевого дизайна | 5 | Определены `до`, `после`, artifact handling и fallback |
| 4. Безопасность (миграция, откат) | 5 | Rollout/rollback и sensitive-data risks описаны |
| 5. Тестируемость | 5 | Есть validator, rg contract check и acceptance criteria |
| 6. Готовность к автономной реализации | 5 | План bounded, открытых вопросов нет |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Что исправлено:
  - Правило сформулировано как условный MUST, чтобы не блокировать проекты без video support или безопасной записи.
  - Добавлен отдельный contract для `до` у багфиксов и новых фич.
  - Добавлено правило не коммитить крупные binary artifacts по умолчанию.
  - После review сужены fallback-условия до объективных причин: отсутствие UI suite, отсутствие recorder support, техническая невозможность записи окна/headless-сессии, sensitive-data ограничения или CI/artifact policy.
  - Уточнено, что characterization video для багфикса допустимо только когда deterministic failing assertion невозможен, а само видео визуально демонстрирует дефект.
- Что осталось на решение пользователя:
  - Подтвердить переход к EXEC фразой `Спеку подтверждаю`.

### Post-EXEC Review
- Статус: PASS
- Что исправлено до завершения:
  - Не потребовалось; review не выявил критичных или высокоуверенных проблем с однозначным исправлением.
- Что проверено дополнительно для refactor / comments:
  - Refactor и cleanup комментариев не выполнялись.
- UI video evidence для UI automation задач:
  - Не применимо к этой catalog-governance задаче; изменение обновляет инструкции, а не UI приложения. Semantic check подтвердил наличие новых video evidence markers в профильном документе, шаблоне, review loop, delivery policy и changelog.
- Остаточные риски / follow-ups:
  - Остаточных блокеров нет.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Catalog-governance для UI video evidence | 0.95 | Нет | Запросить подтверждение спеки | Да | Нет | Канонические инструкции требуют SPEC gate до изменения `instructions/*`, `templates/*` и `CHANGELOG.md`. | `specs/2026-05-14-ui-test-video-evidence.md` |
| SPEC | Исправление review-находок | 0.97 | Нет | Запросить подтверждение спеки | Да | Да: пользователь попросил исправить ревью-находки | Сужены fallback-условия и уточнен bugfix `до` evidence, чтобы requirement оставался проверяемым. | `specs/2026-05-14-ui-test-video-evidence.md` |
| EXEC | Реализация UI video evidence contract | 0.96 | Нет | Запустить validator, validator tests и semantic contract check | Нет | Да: пользователь подтвердил spec | Обновлены профиль, spec template, post-EXEC review, GitHub delivery policy и changelog в границах утвержденной spec. | `instructions/profiles/ui-automation-testing.md`, `templates/specs/_template.md`, `instructions/governance/review-loops.md`, `instructions/governance/github-delivery-policy.md`, `CHANGELOG.md`, `specs/2026-05-14-ui-test-video-evidence.md` |
| EXEC | Validation и post-EXEC review | 0.98 | Нет | Завершить отчет | Нет | Нет | Validator, validator tests и focused semantic check прошли; post-EXEC review не выявил обязательных исправлений. | `specs/2026-05-14-ui-test-video-evidence.md` |
