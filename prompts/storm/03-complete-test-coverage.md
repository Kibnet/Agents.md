# Prompt: /storm:cover

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:cover`.

Цель: повысить requirements coverage для active/implemented stories и constraints.

Действия:

1. Найди acceptance criteria с `coverage_level = none|smoke|partial`.
2. Для каждого AC предложи минимальный набор тестов.
3. Если поведение уже существует, добавь regression/characterization tests.
4. Если поведение отсутствует, не реализуй его без отдельной команды `/storm:implement`; пометь тест как planned/failing только если это принято в проекте.
5. Обнови test annotations и `storm.json`.
6. Запусти релевантные тесты.

В конце дай список:

- какие AC улучшены;
- какие всё ещё имеют partial/none;
- какие риски остались.
