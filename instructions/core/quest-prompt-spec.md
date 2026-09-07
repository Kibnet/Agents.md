# Core: Quest Prompt SPEC

## Когда применять

- Для запуска фазы SPEC уже применимого QUEST workflow.

## MUST

- Применять owner-документы по ссылкам ниже. Эта prompt-обёртка не повторяет и не меняет их разрешения, критерии review или проверки.
- Сохранять output contract и существенные ограничения результата; не превращать краткость в пропуск evidence.

## Команды

```text
Input: Новая задача и её контекст.
Goal: Подготовить проверяемую рабочую спецификацию без реализации.
Success: Рабочая SPEC выбранной формы, результат quality gate и точный следующий шаг для пользователя.
Constraints: форму определяет quest-governance; фазовые действия — quest-mode;
review — review-loops; команды проверок — применимый testing context.
Output: outcome, проверки и ограничения; подробный audit в рабочей SPEC.
Stop: по owner gates; не считать план, static lint или частичные проверки выполненной реализацией.
```

## Связанные документы

- [Applicability и форма](./quest-governance.md)
- [Фазовые правила](./quest-mode.md)
- [Review loop](../governance/review-loops.md)
- [Testing baseline](./testing-baseline.md)
- [Model behavior](./model-behavior-baseline.md)
