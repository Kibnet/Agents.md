# Prompt: /storm:bdd-implement ST-XXXX

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:bdd-implement ST-XXXX`.

Эта команда меняет tests/code/behavior и должна идти как `delivery-task` через `QUEST`.

Порядок:

1. Найди story, linked needs, constraints, acceptance criteria, rules и scenarios в `docs/product/storm.json`.
2. Убедись, что story имеет минимум один Gherkin Scenario или создай его через `/storm:gherkin ST-XXXX`.
3. Проверь unresolved conflicts and unmet dependencies.
4. Создай failing automation для target scenarios: step definitions, test runner integration или подходящий test case.
5. Реализуй минимальное production code изменение.
6. Запусти targeted tests, BDD tests и релевантные regression checks.
7. Обнови scenario statuses, automation_status, linked_tests, step_definitions, code references and traceability.
8. Запусти `/storm:bdd-sync` и `/storm:bdd-lint`.
9. Обнови ranking/process reports, если effort или coverage изменились.

DoD: Story нельзя считать implemented, пока сценарии не синхронизированы с tests/code или явно не помечены как `manual` с verification evidence.

