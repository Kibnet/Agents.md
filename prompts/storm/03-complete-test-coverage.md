# Prompt: /storm:cover

Используй central stack по `AGENTS.md` и `instructions/governance/routing-matrix.md`, подключи профиль `storm-product-development` и выполни `/storm:cover`.

Цель: повысить requirements coverage для active/implemented stories и constraints.

Режим: при analysis-only только coverage report и предлагаемые проверки. Добавление/изменение tests или annotations требует `delivery-task` через QUEST до мутации.

Действия после выбора режима:

1. Найди acceptance criteria с `coverage_level = none|smoke|partial`.
2. Для каждого AC сопоставь Rule/Scenario, coverage_role, наблюдаемый Then, linked tests и step definitions; предложи минимальные недостающие проверки.
3. При разрешённом delivery EXEC для существующего поведения добавь regression/characterization tests; в analysis-only запиши рекомендации.
4. Если поведение отсутствует, не реализуй его без отдельной команды `/storm:implement`; в analysis-only запиши planned verification в отчёте. Failing test допустим только в разрешённом delivery EXEC и принятом workflow проекта.
5. Обнови `storm.json` и traceability report; test annotations меняй только в разрешённом delivery EXEC.
6. При test changes запусти релевантные tests через обнаруженный runner; укажи проверенные scenarios и фактический результат.

В конце дай список:

- какие AC улучшены;
- какие всё ещё имеют partial/none;
- какие риски остались.
