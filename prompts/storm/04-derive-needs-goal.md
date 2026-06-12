# Prompt: /storm:derive

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:derive`.

Цель: вывести needs, Product Goal и Product Vision из текущих stories и constraints.

Действия:

1. Для каждой story сформулируй need, которую она закрывает.
2. Для каждого constraint сформулируй need, которую он защищает.
3. Сгруппируй похожие needs, сохрани связи с исходными stories.
4. Сформулируй Product Goal как конкретное целевое состояние продукта.
5. Сформулируй Product Vision как долгосрочное зачем.
6. Отметь выводы из кода как `needs_review`.
7. Обнови `storm.json`, `needs.md`, `product-goal.md`.

Не превращай список функций в Product Goal. Goal должен объяснять достижимый outcome.
