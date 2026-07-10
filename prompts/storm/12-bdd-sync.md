# Prompt: /storm:bdd-sync

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:bdd-sync`.

Цель: проверить и восстановить синхронизацию между `storm.json`, `.feature` files, step definitions, tests и code references.

Порядок:

1. Прочитай `docs/product/storm.json`.
2. Найди `.feature` files в `metadata.feature_root` или `features/`.
3. Сопоставь tags `@scenario`, `@story`, `@need`, `@constraint`, `@coverage` с metadata в `storm.json`.
4. Проверь, что каждое `gherkin_rules.scenarios[]` указывает на существующий scenario.
5. Проверь, что active scenarios не ссылаются на deprecated/superseded stories без другого active основания.
6. Проверь, что automated/passing/failing scenarios связаны с tests или step definitions.
7. Проверь links `Scenario -> Story -> Need -> Product Goal` и `Scenario -> Test -> Code`.
8. Исправь artifact-only рассинхронизацию в `storm.json` и `.feature` files.
9. Если нужны изменения tests/code, остановись и переведи задачу в `delivery-task` через `QUEST`.

В результате выдай sync report: fixed items, remaining drift, orphan scenarios, deprecated drift, missing automation links.

