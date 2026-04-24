# Уточнение маршрутизации override/UI/TUnit/MCP в каталоге инструкций

## 0. Метаданные
- Тип (профиль): `product-system-design`
- Владелец: `instructions/governance/routing-matrix.md`
- Масштаб: medium
- Целевой релиз / ветка: `2.1.2` / текущая рабочая ветка
- Ограничения:
  - не менять conflict model и не ослаблять центральные `MUST`;
  - не разносить одно и то же правило по нескольким owner-документам без необходимости;
  - минимизировать diff и менять только те entry point/owner-файлы, которые реально влияют на поведение агентов;
  - для `TUnit` использовать только подтверждённый MTP/TUnit workflow, без xUnit/NUnit folklore;
  - не вводить обязательство создавать новый UI test harness в репозиториях, где его нет.
- Связанные ссылки:
  - `AGENTS.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/onboarding/quick-start.md`
  - `instructions/onboarding/AGENTS.consumer.template.md`
  - `instructions/onboarding/AGENTS.override.template.md`
  - `instructions/profiles/ui-automation-testing.md`
  - `instructions/contexts/testing-dotnet.md`
  - `instructions/contexts/debug-dotnet-mcp-coreclr.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`
  - `CHANGELOG.md`

## 1. Overview / Цель
Уточнить каталог инструкций в четырёх местах, где агенты регулярно ошибаются в эксплуатации: порядок применения `AGENTS.override.md`, обязательность UI test workflow для UI-поведения при наличии существующего UI test suite, корректный запуск `TUnit` и `TUnit`-фильтрация, а также обязательное использование MCP для runtime/test-debug и перехвата исключений в .NET, например через стек вроде `Killer Bug`.

## 2. Текущее состояние (AS-IS)
- `routing-matrix.md` уже задаёт правильную модель: локальный `AGENTS.override.md` применяется после central stack и только для ужесточения `MUST`.
- При этом entry-point и onboarding-формулировки местами недостаточно явно подчёркивают, что `AGENTS.override.md` является дополнительным слоем поверх central stack, а не его заменой.
- `ui-automation-testing.md` сейчас в основном описывает сопровождение самих UI automation-изменений и слабо маршрутизируется на обычные UI bugfix/feature задачи, когда меняется поведение интерфейса, но не обязательно сам test harness.
- `.NET` testing context знает только общий `dotnet test --filter`-style workflow, который вводит агентов в заблуждение в проектах на `TUnit`.
- Для `TUnit` ключевой нюанс в том, что он работает поверх `Microsoft.Testing.Platform`; таргетный запуск делается не через VSTest `--filter`, а через `--treenode-filter`, обычно через `dotnet run` или `dotnet test -- ...`.
- `debug-dotnet-mcp-coreclr.md` уже маршрутизирует debug через MCP, но недостаточно явно связывает это требование с runtime-отладкой, перехватом исключений и типовым инструментом вроде `Killer Bug`.
- `CHANGELOG.md` пока не отражает эти уточнения контракта.

## 3. Проблема
Каталог формально содержит нужные строительные блоки, но несколько критичных эксплуатационных сценариев описаны недостаточно явно, из-за чего агенты либо воспринимают `AGENTS.override.md` как замену central stack, либо пропускают обязательные UI тесты, либо запускают `TUnit` неверными командами, либо пытаются ловить runtime-исключения без MCP.

## 4. Цели дизайна
- Сделать порядок применения `AGENTS.override.md` однозначным для агентов и людей.
- Подтянуть UI testing requirement через маршрутизатор на реальные UI bugfix/feature задачи при наличии UI test suite.
- Зафиксировать рабочие и воспроизводимые команды для `TUnit`, включая запуск конкретного теста.
- Сделать MCP-first подход обязательным для runtime/test-debug и перехвата исключений в .NET.
- Сохранить минимальную иерархию owner-документов без лишнего дублирования.

## 5. Non-Goals (чего НЕ делаем)
- Не меняем базовый algorithm stack assembly и conflict resolution model.
- Не превращаем `AGENTS.override.md` в произвольный override, который может ослаблять центральные требования.
- Не вводим глобальное требование писать UI тесты в проектах, где UI test infrastructure отсутствует.
- Не переписываем весь `.NET` testing context под один конкретный test framework; добавляем только явную ветку для `TUnit`.
- Не описываем конкретные MCP API конкретного внешнего сервера за пределами минимального нормативного контракта.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/governance/routing-matrix.md` -> канонически уточнить маршрутизацию `AGENTS.override.md`, UI behavior changes и runtime exception debug.
- `AGENTS.md` -> синхронизировать краткий entry-point порядок применения override с owner-моделью routing.
- `instructions/onboarding/quick-start.md` -> явно описать `AGENTS.override.md` как дополнительные локальные инструкции поверх central stack.
- `instructions/onboarding/AGENTS.consumer.template.md` -> обновить шаблон локального указателя, чтобы агент не воспринимал override как замену central stack.
- `instructions/onboarding/AGENTS.override.template.md` -> сформулировать override как дополнительный слой локальных инструкций, который дополняет и ужесточает central stack.
- `instructions/profiles/ui-automation-testing.md` -> превратить профиль из узкого “меняем UI automation” в overlay для UI behavior/UI flow changes при наличии UI tests.
- `instructions/contexts/testing-dotnet.md` -> добавить ветку для `TUnit` с корректными full-run/targeted-run/list-tests командами и явным запретом на `--filter`.
- `instructions/contexts/debug-dotnet-mcp-coreclr.md` -> сделать более явным, что runtime-debug и перехват исключений обязаны идти через MCP-first workflow, например `Killer Bug`.
- `CHANGELOG.md` -> зафиксировать изменение как patch-level уточнение эксплуатационного контракта каталога.

### 6.2 Детальный дизайн
- В `AGENTS.md`, `routing-matrix.md`, `quick-start.md` и `AGENTS.consumer.template.md` использовать формулировку вида: локальный `AGENTS.override.md` применяется после central stack как дополнительные локальные инструкции поверх него; override не заменяет central `AGENTS.md` и может только ужесточать `MUST`.
- В `AGENTS.override.template.md` явно показать такую модель в заголовочном тексте примера, чтобы consumer-репозиторий наследовал правильную фразу по умолчанию.
- В `routing-matrix.md` расширить overlay rule для `ui-automation-testing` так, чтобы он включался не только при изменении самих UI automation тестов, но и при исправлении багов/разработке фич, затрагивающих UI behavior, visual flow или UI-facing state changes, если в репозитории есть существующий UI test suite.
- В `ui-automation-testing.md` добавить/переформулировать `MUST`:
  - использовать UI tests при UI bugfix/feature задачах, влияющих на поведение интерфейса;
  - добавлять или обновлять relevant coverage в рамках изменения;
  - предпочитать существующие AppAutomation Headless/FlaUI, Avalonia.Headless или иные уже принятые в репозитории UI test patterns;
  - запускать релевантные UI тесты перед завершением или явно объяснять, почему это невозможно.
- В `testing-dotnet.md` добавить явное ветвление:
  - сначала определить, обычный ли это VSTest-совместимый проект или `TUnit`;
  - для `TUnit` prefer `dotnet run` из каталога тестового проекта как основной способ запуска;
  - если используется `dotnet test`, дополнительные флаги передавать только после `--`;
  - targeted execution делать через `--treenode-filter`, а не через `--filter`;
  - дать примеры full run, list-tests, class-level run и exact test run.
- В `debug-dotnet-mcp-coreclr.md` усилить формулировку:
  - при runtime/test-debug и отлове исключений сначала использовать MCP debug workflow;
  - MCP обязателен для breakpoint/stack/exception inspection;
  - при наличии стандартного MCP-инструмента вроде `Killer Bug` использовать его как предпочтительный путь;
  - прямой JSON-RPC fallback оставлять только как fallback при сбое MCP-обвязки.
- Изменение версии отразить как `PATCH`, поскольку меняются формулировки и эксплуатационная точность, но не структура каталога и не breaking semantics.

## 7. Бизнес-правила / Алгоритмы (если есть)
- Алгоритм применения `AGENTS.override.md`:
  - сначала собрать central stack по `routing-matrix.md`;
  - затем, если в consumer-репозитории есть `AGENTS.override.md`, применить его как дополнительный слой локальных инструкций;
  - локальный слой не отменяет central stack и может только ужесточать требования.
- Алгоритм выбора UI testing overlay:
  - если изменение затрагивает UI behavior, visual flow или UI-facing state changes;
  - и в репозитории уже есть релевантный UI test suite;
  - подключить `ui-automation-testing` и требовать обновление/запуск соответствующих UI tests.
- Алгоритм выбора `.NET` test runner:
  - если проект использует `TUnit`, применять `Microsoft.Testing.Platform` команды;
  - если проект использует xUnit/NUnit/MSTest, сохранять обычный `dotnet test`/`--filter` workflow;
  - не смешивать `TUnit` и VSTest filter syntax.
- Алгоритм debug/exceptions:
  - если задача требует runtime/test-debug или перехвата исключений в .NET, использовать MCP-first workflow;
  - если доступен профиль/сервер вроде `Killer Bug`, использовать его как основной инструмент;
  - прямой HTTP/JSON-RPC к MCP endpoint использовать только при сбое штатной MCP-интеграции.

## 8. Точки интеграции и триггеры
- Entry point для любого consumer-репозитория: `AGENTS.md` и onboarding templates.
- UI routing trigger: багфикс/фича, меняющие UI behavior или пользовательский flow в репозитории с уже существующими UI tests.
- `.NET` testing trigger: локальная валидация изменений в репозитории с тестами на xUnit/NUnit/MSTest или `TUnit`.
- Debug trigger: runtime exception, flaky runtime behavior, test-debug, breakpoint/session analysis.
- Governance trigger: обновление канонических `instructions/*`, `AGENTS.md` и `CHANGELOG.md`.

## 9. Изменения модели данных / состояния
- Persisted-модель, schema и runtime state приложений не меняются.
- Меняется только нормативный контракт каталога инструкций и onboarding/diagnostic guidance.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - обновить entry point, owner-документы и onboarding templates;
  - синхронизировать `CHANGELOG.md`;
  - прогнать validator и test suite validator.
- Обратная совместимость:
  - central stack и модель ужесточения `AGENTS.override.md` сохраняются;
  - новые правила UI/TUnit/MCP только делают существующие сценарии более явными.
- Rollback:
  - откатить уточняющие формулировки в `AGENTS.md`, `routing-matrix.md`, onboarding, `testing-dotnet.md`, `debug-dotnet-mcp-coreclr.md`, `ui-automation-testing.md`;
  - удалить запись из `CHANGELOG.md`.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - `AGENTS.md`, `routing-matrix.md` и onboarding-документы явно формулируют, что `AGENTS.override.md` является дополнительным слоем поверх central stack, а не заменой.
  - `routing-matrix.md` и `ui-automation-testing.md` маршрутизируют UI test requirements на UI behavior/UI flow changes при наличии существующего UI test suite.
  - `ui-automation-testing.md` явно требует использовать, обновлять и запускать релевантные UI tests либо явно сообщать о невозможности запуска.
  - `testing-dotnet.md` явно описывает `TUnit`-workflow и запрещает использовать VSTest `--filter` для `TUnit`.
  - В `.NET` context есть пример запуска конкретного `TUnit`-теста.
  - `debug-dotnet-mcp-coreclr.md` явно требует MCP-first workflow для runtime/test-debug и перехвата исключений, с примером вроде `Killer Bug`.
  - `CHANGELOG.md` содержит patch-level запись об уточнении каталога.
  - `pwsh -File scripts/validate-instructions.ps1` и `pwsh -File scripts/test-validate-instructions.ps1` проходят.
- Какие тесты добавить/изменить:
  - автоматические тесты validator не требуют изменения, если сохраняется обязательный набор секций и относительных ссылок;
  - достаточно прогнать существующие validator/test suite.
- Characterization tests / contract checks для текущего поведения (если применимо):
  - `rg -n "AGENTS\\.override|treenode-filter|Killer Bug|UI behavior|AppAutomation|Avalonia\\.Headless|FlaUI" AGENTS.md instructions CHANGELOG.md`
  - ручная сверка, что порядок central stack -> local override сформулирован одинаково в entry point и onboarding.
- Базовые замеры до/после для performance tradeoff (если применимо):
  - не применимо.
- Команды для проверки:
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `rg -n "AGENTS\\.override|treenode-filter|Killer Bug|AppAutomation|Avalonia\\.Headless|FlaUI" AGENTS.md instructions CHANGELOG.md`

## 12. Риски и edge cases
- Слишком агрессивная формулировка про UI tests может быть неверно прочитана как требование создать новый UI framework с нуля; это нужно явно ограничить наличием существующего UI test suite или repository patterns.
- Если `TUnit` описание будет смешано с обычным `.NET` тестовым workflow без явного ветвления, агенты продолжат использовать `--filter` по инерции.
- Если правило про `Killer Bug` написать слишком конкретно, каталог станет зависимым от одного инструмента; нужна формулировка “например”.
- Несинхронность между `AGENTS.md`, routing и onboarding снова создаст неоднозначность для consumer-репозиториев.

## 13. План выполнения
1. Обновить рабочую spec и зафиксировать минимальный набор owner/entry-point файлов.
2. После подтверждения спеки обновить `AGENTS.md`, `routing-matrix.md` и onboarding-документы про `AGENTS.override.md`.
3. Обновить `ui-automation-testing.md` и routing-триггеры для UI behavior changes.
4. Обновить `testing-dotnet.md` и `debug-dotnet-mcp-coreclr.md` для `TUnit` и MCP-first debug.
5. Обновить `CHANGELOG.md`.
6. Прогнать validator и test suite validator.
7. Выполнить `post-EXEC review` на отсутствие дублирования и на точность примеров команд.

## 14. Открытые вопросы
- Блокирующих открытых вопросов нет.

## 15. Соответствие профилю
- Профиль: `product-system-design`
- Выполненные требования профиля:
  - цели и `Non-Goals` выделены явно;
  - целевой контракт маршрутизации и эксплуатационные сценарии описаны;
  - публичные договоры совместимости каталога сохранены;
  - интеграционные требования для debug/tooling и consumer-onboarding зафиксированы.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `AGENTS.md` | Уточнить краткий порядок применения локального override | Убрать трактовку override как замены central stack |
| `instructions/governance/routing-matrix.md` | Уточнить routing для override, UI behavior changes и MCP debug trigger | Синхронизировать owner-модель и реальные эксплуатационные сценарии |
| `instructions/onboarding/quick-start.md` | Уточнить смысл `AGENTS.override.md` как дополнительного слоя | Исправить consumer-onboarding guidance |
| `instructions/onboarding/AGENTS.consumer.template.md` | Обновить шаблон локального `AGENTS.md` | Сделать корректную формулировку видимой прямо в consumer repo |
| `instructions/onboarding/AGENTS.override.template.md` | Обновить вводный текст шаблона override | Снизить шанс неверной трактовки локального файла |
| `instructions/profiles/ui-automation-testing.md` | Расширить профиль на UI behavior/UI flow changes при наличии UI tests | Сделать UI testing requirement маршрутизируемым |
| `instructions/contexts/testing-dotnet.md` | Добавить explicit `TUnit` workflow и примеры | Убрать повторяющиеся ошибки с запуском и фильтрацией тестов |
| `instructions/contexts/debug-dotnet-mcp-coreclr.md` | Усилить MCP-first правило для runtime/test-debug и перехвата исключений | Зафиксировать правильный диагностический workflow |
| `CHANGELOG.md` | Добавить patch-level запись | Соблюсти versioning policy |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| `AGENTS.override.md` | Формально “после central stack”, но местами недостаточно явно, что это дополняющий слой | Во всех ключевых точках явно сказано “дополнительные локальные инструкции поверх central stack” |
| UI routing | Профиль сфокусирован на самих UI automation изменениях | Профиль включается и на UI behavior/UI flow changes при наличии существующего UI test suite |
| `TUnit` | Агенты по инерции используют `dotnet test --filter` | Есть явная ветка `TUnit` с `dotnet run`, `dotnet test -- ...` и `--treenode-filter` |
| Runtime debug/exceptions | MCP упомянут, но связь с обязательным runtime exception workflow выражена слабо | Явный MCP-first контракт, с примером вроде `Killer Bug` |

## 18. Альтернативы и компромиссы
- Вариант: править только onboarding templates, не трогая `AGENTS.md` и `routing-matrix.md`.
- Плюсы:
  - меньше diff.
- Минусы:
  - проблема останется в центральном entry point и owner-документе;
  - часть агентов читает только `AGENTS.md` и пропустит уточнение.
- Почему выбранное решение лучше в контексте этой задачи:
  - нужно синхронизировать и owner-уровень, и consumer entry points.

- Вариант: добавить новый отдельный профиль только для `TUnit`.
- Плюсы:
  - более узкая специализация.
- Минусы:
  - избыточная дробность каталога;
  - `TUnit` — это ветка внутри существующего `.NET` testing context, а не отдельный сценарий маршрутизации.
- Почему выбранное решение лучше в контексте этой задачи:
  - достаточно усилить `testing-dotnet.md`, не раздувая матрицу маршрутизации.

- Вариант: сделать `Killer Bug` обязательным единственным инструментом.
- Плюсы:
  - максимально конкретная инструкция.
- Минусы:
  - каталог станет зависимым от одного MCP-провайдера;
  - ухудшится переносимость.
- Почему выбранное решение лучше в контексте этой задачи:
  - MCP-first правило остаётся общим, а `Killer Bug` приводится как типовой пример.

## 19. Результат quality gate и review
- чеклист из SPEC-LINTER.md;

### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, дизайн-цели и жёсткие границы описаны явно. |
| B. Качество дизайна | 6-10 | PASS | Owner-файлы, распределение ответственности, rollout и rollback определены. |
| C. Безопасность изменений | 11-13 | PASS | Правки локализованы в документации; breaking semantics не вводятся. |
| D. Проверяемость | 14-16 | PASS | Acceptance Criteria, команды проверки и таблица файлов присутствуют. |
| E. Готовность к автономной реализации | 17-19 | PASS | Альтернативы разобраны, блокирующих вопросов нет, масштаб controllable. |
| F. Соответствие профилю | 20 | PASS | Изменение касается публичного контракта подсистемы инструкций и укладывается в `product-system-design`. |

Итог: ГОТОВО

- итог по SPEC-RUBRIC.md;

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---|---|
| 1. Ясность цели и границ | 5 | Все четыре пользовательские проблемы сведены в один связанный контракт и ограничены конкретным набором файлов. |
| 2. Понимание текущего состояния | 5 | Зафиксированы текущие owner-документы, пробелы в формулировках и реальные эксплуатационные ошибки. |
| 3. Конкретность целевого дизайна | 5 | По каждому проблемному сценарию описаны точные формулировки и место их размещения. |
| 4. Безопасность (миграция, откат) | 5 | Изменение локализовано в документации и легко откатывается без миграций данных. |
| 5. Тестируемость | 5 | Есть чёткие acceptance criteria и команды validator/regression scan. |
| 6. Готовность к автономной реализации | 5 | Блокирующих вопросов нет, реализация не требует дополнительного выбора пользователя. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

- краткий Post-SPEC Review:
  - Статус: PASS
  - Что исправлено:
    - ограничен scope UI-testing требования условием “при наличии существующего UI test suite”, чтобы не навязать создание нового harness;
    - `Killer Bug` оставлен как пример, а не как жёсткая vendor-specific зависимость;
    - `TUnit` оформлен как ветка существующего `.NET` context, а не как новый отдельный профиль.
  - Что осталось на решение пользователя:
    - только подтверждение перехода в `EXEC`.

### Post-EXEC Review
- Статус: PASS
- Что исправлено до завершения:
  - `AGENTS.md`, `routing-matrix.md` и onboarding-документы синхронизированы на одной формулировке: локальный `AGENTS.override.md` применяется после central stack как дополнительный слой локальных инструкций и не заменяет central правила;
  - `ui-automation-testing.md` расширен на UI behavior / visual flow / UI-facing state changes при наличии существующего UI test suite и теперь требует обновлять/добавлять relevant coverage и запускать релевантные UI tests;
  - `testing-dotnet.md` получил явное ветвление для `TUnit`/`Microsoft.Testing.Platform` с `--list-tests` и `--treenode-filter`, без смешения с VSTest `--filter`;
  - `debug-dotnet-mcp-coreclr.md` усилен до MCP-first контракта для runtime/test-debug и отлова исключений с примером `Killer Bug`;
  - `CHANGELOG.md` обновлён patch-level записью `2.1.2`.
- Что проверено дополнительно для refactor / comments:
  - валидность `TUnit`-команд сверена по официальным источникам `TUnit` и `Microsoft.Testing.Platform`;
  - проверено, что изменение не создало новой conflict model и не ослабило центральные `MUST`;
  - проверено, что обязательные секции документов и относительные ссылки остаются валидными.
- Остаточные риски / follow-ups:
  - каталог по-прежнему описывает `Killer Bug` как пример предпочтительного MCP entry point, а не как жёстко обязательный vendor-specific инструмент;
  - в consumer-репозиториях без существующего UI test suite решение о создании нового UI harness всё ещё должно приниматься отдельно, вне этого overlay.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | catalog-governance / уточнение routing и execution guidance | 0.95 | Нужно было подтвердить owner-файлы и корректные `TUnit` команды | Подготовить spec и запросить подтверждение перехода в `EXEC` | Да | Нет | Задача меняет канонические `instructions/*`, поэтому обязателен `SPEC`-gate с фиксацией точного scope правок | `AGENTS.md`, `instructions/governance/routing-matrix.md`, `instructions/onboarding/quick-start.md`, `instructions/onboarding/AGENTS.consumer.template.md`, `instructions/onboarding/AGENTS.override.template.md`, `instructions/profiles/ui-automation-testing.md`, `instructions/contexts/testing-dotnet.md`, `instructions/contexts/debug-dotnet-mcp-coreclr.md`, `CHANGELOG.md`, `specs/2026-04-24-routing-ui-tunit-mcp.md` |
| EXEC | реализация owner/onboarding/testing/debug правок | 0.97 | Нужно было только сверить точные `TUnit` команды по официальным источникам | Внести правки в документы и changelog | Нет | Да: пользователь подтвердил спеки фразой `Спеку подтверждаю` | После подтверждения выполнен минимальный согласованный набор правок без изменения общей conflict model каталога | `AGENTS.md`, `instructions/governance/routing-matrix.md`, `instructions/onboarding/quick-start.md`, `instructions/onboarding/AGENTS.consumer.template.md`, `instructions/onboarding/AGENTS.override.template.md`, `instructions/profiles/ui-automation-testing.md`, `instructions/contexts/testing-dotnet.md`, `instructions/contexts/debug-dotnet-mcp-coreclr.md`, `CHANGELOG.md`, `specs/2026-04-24-routing-ui-tunit-mcp.md` |
| EXEC | quality gate, regression suite, post-review | 0.99 | Существенных пробелов после прохождения validator и test suite не осталось | Обновить spec итогами `EXEC` и завершить задачу | Нет | Нет | Проверки подтвердили структурную валидность каталога; regression suite потребовал только больший timeout запуска, но завершился успешно без изменений в тестах | `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1`, `specs/2026-04-24-routing-ui-tunit-mcp.md` |
