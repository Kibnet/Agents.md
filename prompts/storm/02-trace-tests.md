# Prompt: /storm:trace

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:trace`.

Построй двунаправленную трассируемость:

```text
story → acceptance criteria → Gherkin Rule → Scenario → Test / Step Definition → Code
code/test/step → scenario/story/constraint
```

Действия:

1. Найди, какие тесты проверяют каждую story и constraint.
2. Найди, какие stories/AC/constraints проверяет каждый тест.
3. В analysis-only только сопоставь существующие annotations/связи. Для добавления или изменения test annotations (`@story`, `@scenario`, `@acceptance`, `@constraint`) сначала выбери `delivery-task` и пройди QUEST; tests/code без этого не менять.
4. Обнови `docs/product/storm.json`.
5. Обнови `docs/product/reports/traceability.md`.
6. Выдели orphan scenarios/tests/step definitions/code units, stories without scenarios/tests и расхождения обратных связей.
7. В traceability report используй колонки Story, AC, Rule, Scenario, Coverage, Test, Step Definition, Code по canonical template.

Не добавляй фиктивных связей. Если связь сомнительная, пометь confidence и open question.
