# Prompt: /storm:gherkin [ST-XXXX]

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:gherkin [ST-XXXX]`.

Если `ST-XXXX` не указан, актуализируй Gherkin для всех active stories.

Цель: создать или обновить executable behavior specification layer между acceptance criteria и tests/code.

Порядок:

1. Открой `docs/product/storm.json` и найди target stories, linked needs, constraints и acceptance criteria.
2. Определи или создай `.feature` files в root из `metadata.feature_root`, по умолчанию `features/`.
3. Для каждой target story сформируй Gherkin Feature/Rule/Scenario metadata в `storm.json`.
4. Для каждой active story обеспечь минимум один scenario или `gherkin_exception` с причиной.
5. Для risk-sensitive stories добавь negative path и constraint scenario.
6. Сценарии пиши декларативно: `Given` = состояние, `When` = событие, `Then` = наблюдаемый outcome.
7. Добавь tags `@scenario`, `@story`, `@need`, при необходимости `@goal`, `@constraint`, `@coverage`, `@risk`.
8. Обнови `gherkin_features`, `gherkin_rules`, `gherkin_scenarios`, `step_definitions` только если есть реальные связи.
9. Запусти или логически выполни `/storm:bdd-lint` и `/storm:bdd-sync`.

Не меняй production code, tests или test annotations без перехода в `delivery-task` через `QUEST`.

