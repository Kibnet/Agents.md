# Profile: Rendering / Pipeline

## Когда применять

- Для задач с асинхронным рендером, пайплайнами покадровой отрисовки или preview-процессами.
- Для оптимизации очередности и производительности update/render flow.

## Когда не применять

- Для не-UI задач без визуального потока.
- Для простых статических отображений без пайплайна.

## MUST

- Описывать текущий пайплайн и новый целевой пайплайн.
- Зафиксировать триггеры перерисовки и условия invalidation.
- Проверить perf и fallback для деградации производительности.
- Зафиксировать безопасные пути при ошибках рендеринга.

## SHOULD

- Описывать кеширование промежуточных результатов.
- Проверять, как изменение пайплайна влияет на user-visible latency.

## MAY

- Добавлять диаграмму зависимостей и очередей.

## Команды

```text
npm run build
npm run test
```

## Связанные документы

- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/contexts/performance-optimization.md](../contexts/performance-optimization.md)
- [instructions/governance/spec-linter.md](../governance/spec-linter.md)
- [instructions/governance/spec-rubric.md](../governance/spec-rubric.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
