# Prompt: /storm:implement ST-XXXX

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:implement ST-XXXX`.

Замени `ST-XXXX` на конкретный ID story.

Route: `delivery-task` через QUEST; наличие story не заменяет approval текущего изменения.

Порядок:

1. Найди story в `docs/product/storm.json`.
2. Проверь dependencies, conflicts, needs, constraints и AC.
3. Если есть unresolved mandatory conflicts или unmet dependencies, не реализуй и выдай blockers.
4. Уточни story до ready state: AC, Rule/Scenario с observed Then, happy path и применимые negative/constraint cases; отсутствие scenarios требует явного gherkin_exception.
5. Напиши/обнови tests и step definitions под AC/Scenario, установи traceability Scenario -> Test / Step Definition -> Code.
6. Реализуй минимальное изменение кода.
7. Запусти тесты.
8. Обнови annotations, `storm.json`, `.feature` specifications, traceability, ranking и reports; автоматизированные scenarios связывай с фактическим runner evidence.
9. В итоговом ответе укажи все изменённые файлы и проверки.

DoD: Story получает `status = implemented` только после синхронизации спецификации и кода.
