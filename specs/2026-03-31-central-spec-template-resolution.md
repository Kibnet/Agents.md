# Move Canonical Spec Template Out of `specs/`

## 0. Метаданные
- Тип (профиль): product-system-design
- Владелец: Codex
- Масштаб: medium
- Целевой релиз / ветка: 1.2.2
- Ограничения:
  - Не ломать текущую модель central source of truth.
  - Рабочая спецификация должна по-прежнему создаваться в локальном `./specs/` репозитория задачи.
  - Канонический шаблон должен жить в отдельном каталоге, а не в `specs/`.
  - Не поддерживать локальный override для шаблона спеки в consumer-репозитории.
- Связанные ссылки:
  - `AGENTS.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/quest-mode.md`
  - `instructions/core/quest-prompt-spec.md`
  - `instructions/onboarding/quick-start.md`
  - `instructions/onboarding/AGENTS.consumer.template.md`
  - `scripts/validate-instructions.ps1`
  - `scripts/test-validate-instructions.ps1`
  - `README.md`

## 1. Overview / Цель
Устранить двусмысленность, из-за которой агент путает рабочий каталог `specs/` репозитория задачи и канонический template в центральном каталоге. Для этого вынести шаблон спеки из `specs/` в отдельный каталог шаблонов и сделать путь к нему структурно отличным от пути сохранения рабочих spec-файлов.

## 2. Текущее состояние (AS-IS)
- Сейчас канонический template лежит в `specs/_template.md`.
- Рабочие спецификации тоже создаются в `specs/`, и в consumer-репозитории агент часто ожидает такой же путь локально.
- Даже central-only правило не устраняет корневую неоднозначность полностью, потому что namespace `specs/` продолжает обозначать сразу две разные сущности:
  - каталог рабочих spec-артефактов;
  - местоположение canonical template.
- В результате агент может:
  - искать `_template.md` локально по привычному пути `./specs/_template.md`;
  - неверно интерпретировать относительные команды и ссылки;
  - путать destination для новой спеки и source для template.

## 3. Проблема
Путь `specs/_template.md` конфликтует по смыслу с локальным `./specs/` как каталогом рабочих спецификаций, поэтому даже при central-only contract агентам легко ошибиться в резолве template.

## 4. Цели дизайна
- Разделение ответственности
- Повторное использование
- Тестируемость
- Консистентность
- Обратная совместимость: локальное размещение рабочих spec-файлов остаётся прежним, меняется только canonical source template

## 5. Non-Goals (чего НЕ делаем)
- Не переносим рабочие спецификации из consumer-репозитория в центральный каталог.
- Не вводим новый формат `AGENTS.md`.
- Не добавляем поддержку project-specific локального `_template.md`.
- Не меняем mandatory структуру самой спецификации.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `templates/specs/_template.md` -> новый canonical путь для шаблона спецификации.
- `specs/` -> каталог только для рабочих spec-документов и больше не источник канонического template.
- `instructions/core/quest-governance.md` -> канонический contract: spec создаётся в `./specs/`, template читается из `templates/specs/_template.md`.
- `instructions/core/quest-mode.md` -> тот же contract для `QUEST MODE` и примеров команд.
- `instructions/core/quest-prompt-spec.md` -> prompt-ориентированная формулировка нового пути.
- `instructions/governance/spec-linter.md` и `instructions/governance/spec-rubric.md` -> обновлённые ссылки на canonical template.
- `instructions/profiles/*`, где есть ссылки на template -> обновить связанные документы.
- `instructions/onboarding/quick-start.md` и `instructions/onboarding/AGENTS.consumer.template.md` -> consumer onboarding без двусмысленности со `specs/`.
- `scripts/validate-instructions.ps1` -> validator должен требовать новый template path и ловить активные ссылки на старый путь.
- `scripts/test-validate-instructions.ps1` -> regression test для validator-правила.
- `README.md` -> синхронизированная структура каталога и quick start.
- `CHANGELOG.md` -> patch-level описание переноса canonical template.

### 6.2 Детальный дизайн
- Создать новый каталог `templates/specs/` и переместить canonical template в `templates/specs/_template.md`.
- Зарезервировать `specs/` только для рабочих спецификаций:
  - в центральном каталоге это исторические/текущие spec-документы изменений каталога;
  - в consumer-репозиториях это локальные рабочие spec-документы задачи.
- Во всех активных документах заменить ссылки и команды:
  - было: `specs/_template.md`;
  - станет: `templates/specs/_template.md`.
- Для `QUEST`-workflow явно разделить:
  - `destination`: локальный `./specs/YYYY-MM-DD-short-name.md`;
  - `source`: canonical `<AGENTS_ROOT>/templates/specs/_template.md` или эквивалентный путь в каталоге текущих инструкций.
- Удалить `specs/_template.md` из центрального каталога, чтобы старый путь перестал быть рабочим и не оставлял двусмысленность.
- В validator добавить проверку, что в активных документах каталога не осталось operational references на `specs/_template.md` как на действующий canonical template path.
- В test suite добавить сценарий, где validator падает при появлении новой активной ссылки на старый путь.

## 7. Бизнес-правила / Алгоритмы (если есть)
- Алгоритм резолва шаблона спеки:
  1. Определить центральный каталог инструкций, откуда загружен текущий instruction stack.
  2. Использовать только `templates/specs/_template.md` внутри этого каталога.
  3. Не использовать локальный `./specs/_template.md` consumer-репозитория как источник шаблона.
  4. Если central path или template отсутствует, остановиться на фазе `SPEC` и явно сообщить о нарушенном onboarding-контракте.
- Алгоритм размещения результата:
  1. Создать/обновить итоговый spec-файл в локальном `./specs/` репозитория задачи.
  2. Не записывать рабочую спецификацию в каталог `templates/`.
- Алгоритм regression guard:
  1. Validator проверяет наличие `templates/specs/_template.md`.
  2. Validator падает, если активные документы в `AGENTS.md`, `README.md` или `instructions/*` ссылаются на `specs/_template.md` как на рабочий путь template.

## 8. Точки интеграции и триггеры
- Запуск `QUEST MODE` в центральном каталоге и в consumer-репозиториях.
- Использование `instructions/core/quest-prompt-spec.md` как стартового prompt template.
- Consumer onboarding и локальные `AGENTS.md`.
- Validator и его regression test suite.

## 9. Изменения модели данных / состояния
- Новый top-level каталог: `templates/`.
- Новый canonical файл: `templates/specs/_template.md`.
- Старый canonical путь `specs/_template.md` удаляется.

## 10. Миграция / Rollout / Rollback
- Поведение при первом запуске:
  - агент ищет canonical template только по новому пути `templates/specs/_template.md`.
- Обратная совместимость:
  - локальные рабочие spec-файлы остаются в `./specs/`;
  - существующие локальные `./specs/_template.md`, если где-то есть, не являются частью контракта и игнорируются.
- План rollout:
  1. Перенести template.
  2. Обновить все активные ссылки и команды.
  3. Усилить validator и тесты.
- План отката:
  - вернуть template в старый путь и откатить ссылки/validator до предыдущей версии.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria
  - Canonical template существует по пути `templates/specs/_template.md`.
  - В активных документах (`AGENTS.md`, `README.md`, `instructions/*`) нет operational reference на `specs/_template.md` как на действующий путь template.
  - Core `QUEST`-документы явно разделяют `destination` spec-файла и `source` template.
  - Onboarding-документы не описывают локальный override `./specs/_template.md`.
  - `scripts/validate-instructions.ps1` проверяет новый template path и ловит активные ссылки на старый путь.
  - `scripts/test-validate-instructions.ps1` содержит сценарий, который падает на старом пути и проходит на новом.
  - `pwsh -File scripts/validate-instructions.ps1` проходит успешно.
  - `pwsh -File scripts/test-validate-instructions.ps1` проходит успешно.
- Какие тесты добавить/изменить
  - Обновить validator required paths.
  - Добавить negative test на активную ссылку `specs/_template.md`.
- Команды для проверки
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `rg -n "specs/_template.md|specs\\\\_template.md" AGENTS.md README.md instructions scripts -S`

## 12. Риски и edge cases
- Риск: при удалении `specs/_template.md` сломаются исторические markdown-ссылки, например в `CHANGELOG.md`.
  - Смягчение: обновить или де-ссылочить historical references так, чтобы validator не получал broken links.
- Риск: часть активных документов останется на старом пути.
  - Смягчение: добавить явный validator check и regression test.
- Риск: агент всё ещё может искать локальный `_template.md` по старой памяти.
  - Смягчение: новый путь `templates/specs/_template.md` структурно отличается от `./specs/` и убирает смысловой конфликт.
- Риск: `templates/` не будет отражён в README и пользователи не поймут новую структуру.
  - Смягчение: синхронно обновить структуру репозитория и quick start.

## 13. План выполнения
1. Перенести canonical template из `specs/_template.md` в `templates/specs/_template.md`.
2. Обновить ссылки и команды в core/governance/profile/onboarding/README документах.
3. Удалить или переписать активные ссылки на старый путь, включая исторические места, где это нужно для прохождения validator.
4. Обновить validator и test suite под новый путь и regression guard.
5. Прогнать quality gate.
6. Выполнить post-EXEC review и проверить, что namespace `specs/` больше не используется как источник canonical template.

## 14. Открытые вопросы
- Нет блокирующих открытых вопросов.

## 15. Соответствие профилю
- Профиль: `product-system-design`
- Выполненные требования профиля:
  - Явно зафиксированы цели и `Non-Goals`.
  - Описан целевой contract и границы cross-repo onboarding.
  - Зафиксирован публичный интерфейс совместимости: `./specs/` только для рабочих spec-файлов, `templates/specs/_template.md` только для canonical template.
  - Учтены аспекты надёжности интеграции: явная остановка при неполном onboarding-контракте и regression guard через validator.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| templates/specs/_template.md | Новый canonical путь template | Развести namespace template и рабочих specs |
| specs/_template.md | Удалить | Убрать двусмысленный старый путь |
| instructions/core/quest-governance.md | Обновить contract и команды | Явно разделить `destination` и `source` |
| instructions/core/quest-mode.md | Обновить MUST и команды | Синхронизировать `QUEST MODE` |
| instructions/core/quest-prompt-spec.md | Обновить prompt-формулировку | Чтобы агент не искал template в `specs/` |
| instructions/governance/spec-linter.md | Обновить связанные документы | Ссылаться на новый canonical template |
| instructions/governance/spec-rubric.md | Обновить связанные документы | Ссылаться на новый canonical template |
| instructions/profiles/* с ссылкой на template | Обновить related docs | Убрать старый путь |
| instructions/onboarding/quick-start.md | Обновить onboarding contract | Убрать двусмысленность между central/local |
| instructions/onboarding/AGENTS.consumer.template.md | Обновить local pointer template contract | Оставить только central template path |
| scripts/validate-instructions.ps1 | Проверять новый path и старые active references | Поймать регрессию автоматически |
| scripts/test-validate-instructions.ps1 | Добавить regression scenario | Закрепить validator behavior |
| README.md | Обновить структуру репозитория и quick start | Синхронизировать публичное описание |
| CHANGELOG.md | Описать перенос template | Выполнить versioning policy |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Canonical template path | `specs/_template.md` | `templates/specs/_template.md` |
| Назначение `specs/` | И рабочие specs, и canonical template | Только рабочие specs |
| Локальный `./specs/_template.md` | Мог трактоваться как допустимый путь | Не является частью контракта и не используется |
| Validator | Не защищает от возврата старого пути | Явно ловит active references на старый путь |

## 18. Альтернативы и компромиссы
- Вариант: оставить template в `specs/`, но требовать central-only резолв.
- Плюсы:
  - Меньше файловых изменений.
- Минусы:
  - Сохраняется смысловая перегрузка namespace `specs/`.
  - Агентам всё равно легко спутать source template и destination spec.
- Почему выбранное решение лучше в контексте этой задачи:
  - Разные каталоги делают contract очевидным по структуре путей и снижают риск ошибочного резолва без дополнительных эвристик.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, цели и границы сформулированы явно. |
| B. Качество дизайна | 6-10 | PASS | Описаны новый путь template, затронутые документы и regression guard. |
| C. Безопасность изменений | 11-13 | PASS | Зафиксированы миграция, rollback и риск historical links. |
| D. Проверяемость | 14-16 | PASS | Есть acceptance criteria, validator changes и команды проверки. |
| E. Готовность к автономной реализации | 17-19 | PASS | План пошаговый, блокирующих вопросов нет, scope ограничен. |
| F. Соответствие профилю | 20 | PASS | Спека описывает cross-repo contract и публичные пути артефактов. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---|---|
| 1. Ясность цели и границ | 5 | Цель сводится к однозначному разделению namespace template и рабочих specs. |
| 2. Понимание текущего состояния | 5 | AS-IS описывает источник путаницы: одинаковый путь `specs/` для разных сущностей. |
| 3. Конкретность целевого дизайна | 5 | Новый каталог и список правок указаны точно. |
| 4. Безопасность (миграция, откат) | 5 | Учтены rollback и исторические ссылки. |
| 5. Тестируемость | 5 | Есть validator-level regression guard и команды проверки. |
| 6. Готовность к автономной реализации | 5 | Изменение локализовано, открытых вопросов нет. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Что исправлено:
  - Убрана слабая эвристика central-only в пользу структурного разделения путей.
  - Добавлен обязательный regression guard в validator/test suite.
  - Учтён риск сломать historical links при удалении старого `specs/_template.md`.
- Что осталось на решение пользователя:
  - Ничего блокирующего.

## Approval
Ожидается фраза: "Спеку подтверждаю"
