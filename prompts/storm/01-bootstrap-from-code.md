# Prompt: /storm:bootstrap

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:bootstrap`.

Проанализируй код, тесты, README, API/CLI/UI entry points и существующую документацию. Восстанови текущую продуктовую спецификацию как гипотезу о поведении, уже реализованном в системе.

Создай или обнови:

- `docs/product/storm.json`
- `docs/product/reports/stories.md`

Обязательно раздели:

- user stories;
- acceptance criteria;
- constraints;
- technical enablers (`enablers[]`, реальные EN IDs);
- Gherkin features/rules/scenarios и существующие step definitions;
- tests;
- code units.

Для каждой записи укажи:

- ID;
- status;
- provenance;
- confidence;
- evidence;
- assumptions;
- open questions.

Синхронизируй существующие Gherkin записи с `.feature` files, stable tags и `Story -> AC -> Rule -> Scenario -> Test / Step Definition -> Code`; неизвестные связи помечай как gaps. Для EN обязательны id/title/status/provenance/confidence; supports — описательная связь, prerequisite задаётся dependencies.

Не меняй tests, code и test annotations в artifact-only bootstrap.
