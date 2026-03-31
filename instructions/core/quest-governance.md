# Core: Quest Governance

## Когда применять

- Для любых изменений кода, инфраструктуры или канонической документации проекта, если работа требует принятия инженерных решений.
- Для всех задач, где нужен управляемый цикл `SPEC -> EXECUTION`.

## Когда не применять

- Для простых одношаговых запросов, не меняющих проектные файлы (например, вывести текущее время).
- Для чисто справочных ответов без мутаций репозитория.
- Для выполнения существующего workflow с выдачей пользовательских артефактов по шагам, если агент не меняет код, инфраструктуру, `instructions/*`, `scripts/*` или другие канонические проектные файлы.

## MUST

- Перед реализацией создать рабочую спецификацию в локальном `./specs/` репозитория задачи.
- Для шаблона спецификации использовать canonical путь `templates/specs/_template.md` из каталога инструкций, откуда был загружен текущий instruction stack.
- Не использовать локальный template из репозитория задачи как source template.
- Если canonical template не найден в центральном каталоге, остановиться на фазе `SPEC` и явно указать, что consumer-onboarding настроен неполно.
- Выбрать профиль из `instructions/profiles/*` и явно зафиксировать его в спецификации.
- Прогнать самопроверку по `instructions/governance/spec-linter.md`.
- Оценить спецификацию по `instructions/governance/spec-rubric.md`.
- Выполнить `post-SPEC review` по `instructions/governance/review-loops.md` и встроить в spec все улучшения, которые не требуют выбора пользователя.
- Если итог по рубрике < 21, явно пометить автономное выполнение как рискованное и предложить снижение рисков.
- До утверждения спецификации пользователем не выполнять реализацию.
- После утверждения реализовывать строго в границах `Non-Goals` и ограничений.
- После реализации и обязательных проверок выполнить `post-EXEC review`, исправить критичные и высокоуверенные проблемы, повторить затронутые проверки и только затем завершать задачу.
- Если review приводит к нескольким жизнеспособным вариантам без uniquely best option, явно сравнить варианты и запросить решение у пользователя.

## SHOULD

- Формулировать одну корневую проблему на одну спецификацию.
- Фиксировать измеримые критерии приемки и команды проверки.
- Для значимых изменений декомпозировать реализацию на этапы с явным порядком.
- Кратко фиксировать результат `post-SPEC review` в секции quality gate спецификации, а результат `post-EXEC review` в итоговом отчёте.

## MAY

- Уточнять шаблон спецификации под проект, если сохраняется обязательная структура.
- Добавлять project-specific шаблоны спецификации только в центральный каталог `templates/specs/`, если это снижает риск ошибок.

## Команды

```powershell
# Создать новую спецификацию
Copy-Item <AGENTS_ROOT>\templates\specs\_template.md .\specs\YYYY-MM-DD-short-name.md

# Проверка качества (ручная по документам)
Get-Content instructions/governance/spec-linter.md
Get-Content instructions/governance/spec-rubric.md
Get-Content instructions/governance/review-loops.md
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/core/quest-mode.md](./quest-mode.md)
- [instructions/governance/spec-linter.md](../governance/spec-linter.md)
- [instructions/governance/spec-rubric.md](../governance/spec-rubric.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
