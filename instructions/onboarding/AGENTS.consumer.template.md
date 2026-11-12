# Onboarding Template: AGENTS Consumer

## Когда применять

- При создании локального `AGENTS.md` в репозитории-потребителе.

## Когда не применять

- Если в репозитории уже настроен корректный локальный указатель на центральный каталог.

## MUST

- Сохранить смысл шаблона: локальный файл должен быть указателем, а не копией центральных правил.
- Указать путь к центральному `AGENTS.md` через каталог-переменную (например, `<AGENTS_ROOT>\AGENTS.md`).
- Явно подсказать, что для `QUEST` рабочие spec-файлы создаются локально, а форму и canonical template выбирает central [quest-governance](../core/quest-governance.md) из `<AGENTS_ROOT>\templates\specs\`; pointer не закрепляет одну форму для всех задач.
- Явно подсказать, что локальный `AGENTS.override.md` применяется только после central stack как дополнительные локальные инструкции поверх него и не заменяет central `AGENTS.md`.

## SHOULD

- Добавить project-specific профиль по умолчанию только при фактическом триггере по routing-matrix.

## MAY

- Добавить ссылку на локальный `AGENTS.override.md`.

## Команды

```markdown
# AGENTS (local pointer)

Этот репозиторий использует центральный каталог инструкций:

- `<AGENTS_ROOT>\AGENTS.md`

Для QUEST-задач:

- рабочие spec-файлы создаются в локальном `.\specs\`
- форма и canonical template выбираются по `<AGENTS_ROOT>\instructions\core\quest-governance.md` из `<AGENTS_ROOT>\templates\specs\`; фазовые границы и SPEC-вложения — по central quest-mode

Порядок применения:
1. Центральный `AGENTS.md` -> central stack
2. Локальный `AGENTS.override.md` -> дополнительные локальные инструкции поверх central stack; только ужесточение MUST
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/onboarding/quick-start.md](./quick-start.md)
- [instructions/onboarding/AGENTS.override.template.md](./AGENTS.override.template.md)
