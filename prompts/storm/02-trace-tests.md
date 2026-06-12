# Prompt: /storm:trace

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:trace`.

Построй двунаправленную трассируемость:

```text
story → acceptance criteria → tests → code
code/test → story/constraint
```

Действия:

1. Найди, какие тесты проверяют каждую story и constraint.
2. Найди, какие stories/AC/constraints проверяет каждый тест.
3. Добавь annotations в тесты через `@story`, `@stories`, `@acceptance`, `@constraint`, если это безопасно.
4. Обнови `docs/product/storm.json`.
5. Обнови `docs/product/reports/traceability.md`.
6. Выдели orphan tests, orphan code units и stories without tests.

Не добавляй фиктивных связей. Если связь сомнительная, пометь confidence и open question.
