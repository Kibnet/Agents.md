# Prompt: /storm:implement ST-XXXX

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:implement ST-XXXX`.

Замени `ST-XXXX` на конкретный ID story.

Порядок:

1. Найди story в `docs/product/storm.json`.
2. Проверь dependencies, conflicts, needs, constraints и AC.
3. Если есть unresolved mandatory conflicts или unmet dependencies, не реализуй и выдай blockers.
4. Уточни story до ready state.
5. Напиши/обнови tests под AC.
6. Реализуй минимальное изменение кода.
7. Запусти тесты.
8. Обнови annotations, `storm.json`, traceability, ranking и reports.
9. В итоговом ответе укажи все изменённые файлы и проверки.

DoD: Story получает `status = implemented` только после синхронизации спецификации и кода.
