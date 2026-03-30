# Profile: Business Process Automation

## Когда применять

- Для задач, где нужно исследовать текущий бизнес-процесс и спроектировать его автоматизацию.
- Для сценариев вида `AS-IS -> точки автоматизации -> TO-BE -> skill graph ИИ-агента`.
- Для аналитических задач, где результатом являются process artifacts, а не код конкретной системы.

## Когда не применять

- Для обычных багфиксов и feature delivery в приложении без процессного анализа.
- Для задач, где уже есть готовый `TO-BE` и нужен только код реализации в конкретном стеке.
- Для общих brainstorm-сессий без требования к формальным артефактам процесса.

## MUST

- Если задача состоит в исполнении существующего process workflow, а не в изменении каталога инструкций или проектного кода, не запускать `SPEC gate`.
- Использовать этапы в каноническом порядке, если пользователь не предоставил корректный входной артефакт более позднего шага.
- Явно фиксировать, с какого шага стартует работа и какой артефакт считается входом.
- Сохранять трассировку артефактов:
  - шаг 1 -> таблица интервью;
  - шаг 2 -> `AS-IS` Mermaid sequence diagram;
  - шаг 3 -> таблица точек автоматизации;
  - шаг 4 -> `TO-BE` Mermaid sequence diagram;
  - шаг 5 -> Mermaid `graph TD` skill graph.
- Отдавать результат каждого шага отдельным файлом-артефактом.
- После выдачи файла-артефакта ждать подтверждения пользователя перед переходом к следующему шагу.
- Не проектировать `TO-BE`, пока не зафиксированы `AS-IS` и точки автоматизации.
- Не строить skill graph напрямую из `AS-IS`, если задача именно про целевого ИИ-агента.
- Нормализовать роли, системы, артефакты и метрики между шагами, чтобы следующий шаблон использовал тот же словарь сущностей.
- Для шагов 2, 4 и 5 перед выдачей Mermaid-артефакта обязательно прогонять результат через Mermaid lint/validator.
- Если Mermaid lint/validator сообщает ошибку синтаксиса или рендеринга, автоматически исправлять диаграмму и повторять проверку до успешного результата.
- Не считать Mermaid-артефакт готовым, пока Mermaid lint/validator не подтвердил его корректность.
- Если Mermaid lint/validator недоступен в среде выполнения, считать шаг заблокированным и не выдавать непроверенный Mermaid-артефакт как готовый результат.

## SHOULD

- Перед каждым шагом проверять полноту входа и минимизировать допущения.
- Задавать уточняющие вопросы только если без них нельзя подготовить следующий артефакт приемлемого качества.
- Явно отделять факты из входных данных от аналитических предположений.
- Останавливать workflow на том артефакте, который реально нужен пользователю, если полный цикл не требуется.
- Для Mermaid-артефактов предпочитать официальный syntax validation через `mermaid.parse(...)`; если он недоступен, использовать доступный render-check через `@mermaid-js/mermaid-cli` (`mmdc`) или эквивалентный Mermaid validator.

## MAY

- Пропустить шаг 1, если пользователь уже дал качественную таблицу процесса.
- Стартовать с шага 3, если есть подтвержденный `AS-IS`.
- Завершить работу на шаге 3 или 4, если skill graph не нужен.

## Команды

```powershell
Get-Content -Raw prompts\business-process-automation\01-expert-interview-simulation.md
Get-Content -Raw prompts\business-process-automation\02-as-is-process-modeling.md
Get-Content -Raw prompts\business-process-automation\03-automation-opportunities-analysis.md
Get-Content -Raw prompts\business-process-automation\04-to-be-process-design.md
Get-Content -Raw prompts\business-process-automation\05-ai-agent-skill-graph.md

# Пример внешней проверки Mermaid через доступный validator
npx -p @mermaid-js/mermaid-cli mmdc -i .\artifact.mmd -o .\artifact.svg
```

## Канонический Workflow

| Шаг | Когда запускать | Шаблон | Required Input | Output Contract |
|---|---|---|---|---|
| 1. Интервью с экспертом | Нет структурированного описания процесса | [01-expert-interview-simulation](../../prompts/business-process-automation/01-expert-interview-simulation.md) | Описание процесса, контекст, ограничения | Markdown-таблица `AS-IS` с фиксированными колонками |
| 2. Моделирование AS-IS | Есть таблица процесса | [02-as-is-process-modeling](../../prompts/business-process-automation/02-as-is-process-modeling.md) | Таблица шага 1 или эквивалентная таблица | Валидный Mermaid `sequenceDiagram` для текущего процесса после успешного lint/validation |
| 3. Анализ точек автоматизации | Есть подтвержденный `AS-IS` | [03-automation-opportunities-analysis](../../prompts/business-process-automation/03-automation-opportunities-analysis.md) | Mermaid `AS-IS` диаграмма | Таблица точек автоматизации и `Quick Wins` |
| 4. Проектирование TO-BE | Есть `AS-IS` и список точек автоматизации | [04-to-be-process-design](../../prompts/business-process-automation/04-to-be-process-design.md) | Mermaid `AS-IS` + таблица шага 3 | Валидный Mermaid `sequenceDiagram` целевого процесса после успешного lint/validation |
| 5. Построение skill graph | Есть подтвержденный `TO-BE` | [05-ai-agent-skill-graph](../../prompts/business-process-automation/05-ai-agent-skill-graph.md) | Mermaid `TO-BE` диаграмма | Валидный Mermaid `graph TD` граф навыков после успешного lint/validation |

## Правила переходов между шагами

- Если вход шага невалиден, сначала исправить или перестроить предыдущий артефакт, а не продолжать цепочку.
- Если пользователь приносит артефакт извне, агент должен явно признать его входом текущего шага и проверить его пригодность.
- Каждому следующему шагу передается только тот артефакт, который заявлен в `Output Contract` предыдущего шага.
- Если задача дошла до `TO-BE`, нельзя подменять его свободным narrative-текстом при построении skill graph; нужен именно формальный целевой артефакт.
- Если Mermaid-артефакт не проходит lint/validation, агент обязан исправить текущий артефакт и не переходить к следующему шагу, пока проверка не станет успешной.

## Связанные документы

- [instructions/core/quest-governance.md](../core/quest-governance.md)
- [instructions/core/collaboration-baseline.md](../core/collaboration-baseline.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
- [prompts/business-process-automation/01-expert-interview-simulation.md](../../prompts/business-process-automation/01-expert-interview-simulation.md)
- [prompts/business-process-automation/02-as-is-process-modeling.md](../../prompts/business-process-automation/02-as-is-process-modeling.md)
- [prompts/business-process-automation/03-automation-opportunities-analysis.md](../../prompts/business-process-automation/03-automation-opportunities-analysis.md)
- [prompts/business-process-automation/04-to-be-process-design.md](../../prompts/business-process-automation/04-to-be-process-design.md)
- [prompts/business-process-automation/05-ai-agent-skill-graph.md](../../prompts/business-process-automation/05-ai-agent-skill-graph.md)
