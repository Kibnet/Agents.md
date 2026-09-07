# Prompt: /storm:expand

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:expand`.

Цель: на основе Product Goal найти недостающие needs, stories, constraints и enablers.

Действия:

1. Проверь, достаточны ли текущие needs для Product Goal.
2. Найди missing needs.
3. Для каждой missing need предложи stories, constraints или enablers.
4. Для proposed stories добавь AC, Rule/Scenario examples с happy path и применимыми negative/constraint cases, test strategy и traceability. Используй canonical `.feature` template и реальные IDs; не создавай test/step implementation. Для EN укажи обязательные id/title/status/provenance/confidence и зависимости отдельно от описательных supports.
5. Пометь новые элементы `status = proposed`, `provenance = generated_from_goal_gap`.
6. Не реализуй код.

В конце выдай стратегические направления и список proposed backlog items.
