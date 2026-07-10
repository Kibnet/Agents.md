# Prompt: /storm:bdd-conflicts

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:bdd-conflicts`.

Цель: искать product conflicts не только на уровне Story/Need, но и на уровне Gherkin Rule, Scenario, scenario data и step implementation.

Порядок:

1. Прочитай active/proposed stories, needs, constraints, rules и scenarios из `storm.json`.
2. Для каждого scenario проверь, какие needs он verifies и какие constraints protects.
3. Найди сценарии, где `Then` outcome или scenario data угрожают need/constraint.
4. Для каждого конфликта создай или обнови conflict record с `rule_id`, `scenario_id` и `scenario_data_risk`, если применимо.
5. Разложи конфликт через cloud structure: common objective, need A, need B, want A, want B, assumptions, injections.
6. Предложи rewrite/split/add constraint/change scenario/deprecate/supersede/accept risk.
7. Обнови `.feature` files, `gherkin_rules`, `gherkin_scenarios`, stories, constraints и conflict records.

Не меняй production code или tests на этом шаге. Если conflict resolution требует реализации, создай proposed follow-up для `/storm:bdd-implement ST-XXXX`.

