# Prompt: /storm:full-cycle

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:full-cycle`.

Цель: восстановить текущую живую продуктовую спецификацию из кода и тестов, построить трассируемость, вывести needs/Product Goal/Vision, найти gaps/conflicts, построить dependency-aware ranking и провести audit процесса.

Ограничения:

- Не реализуй новые функции.
- Не удаляй код и тесты.
- Не меняй поведение продукта.
- Можно добавлять/уточнять продуктовые артефакты и безопасные test annotations.

Порядок:

1. `/storm:bootstrap`
2. `/storm:trace`
3. `/storm:cover` — только characterization/regression tests для уже существующего поведения, без feature work.
4. `/storm:derive`
5. `/storm:expand`
6. `/storm:conflicts`
7. `/storm:rank`
8. `/storm:audit`

В конце выдай отчёт:

- какие файлы обновлены;
- сколько stories/needs/constraints/tests/code units найдено;
- какие главные пробелы и конфликты найдены;
- какой top-10 backlog получился;
- какие метрики качества процесса;
- какие изменения предложены для следующей итерации.
