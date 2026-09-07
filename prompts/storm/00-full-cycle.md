# Prompt: /storm:full-cycle

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:full-cycle`.

Цель: восстановить текущую живую продуктовую спецификацию из кода и тестов, построить трассируемость, вывести needs/Product Goal/Vision, найти gaps/conflicts, построить dependency-aware ranking и провести audit процесса.

Ограничения:

- Не реализуй новые функции.
- Не удаляй код и тесты.
- Не меняй поведение продукта.
- Analysis-only: можно уточнять product artifacts, `.feature` specifications и reports. Tests, code и test annotations не менять.
- Любую запрошенную мутацию tests/annotations/code маршрутизировать в `delivery-task` через QUEST; само наличие существующего поведения не разрешает test changes.

Порядок:

1. `/storm:bootstrap`
2. `/storm:trace`
3. `/storm:cover` — только coverage/traceability analysis и список gaps, без test mutations.
4. `/storm:gherkin` — rules/scenarios по AC, с observed Then и связями; анализ существующих step definitions без их изменения.
5. `/storm:derive`
6. `/storm:expand`
7. `/storm:conflicts`
8. `/storm:rank`
9. `/storm:audit`

В конце выдай отчёт:

- какие файлы обновлены;
- сколько stories/needs/constraints/enablers/rules/scenarios/step definitions/tests/code units найдено;
- какие главные пробелы и конфликты найдены;
- какой top-10 backlog получился;
- какие метрики качества процесса (`process_audit.metrics_version = 2`, n/a как null);
- какие изменения предложены для следующей итерации.
