# Onboarding Template: AGENTS Consumer

## Когда применять

- При создании локального `AGENTS.md` в репозитории-потребителе.

## Когда не применять

- Если в репозитории уже настроен корректный локальный указатель на центральный каталог.

## MUST

- Сохранить смысл шаблона: локальный файл должен быть указателем, а не копией центральных правил.
- Указать путь к центральному `AGENTS.md` через каталог-переменную (например, `<AGENTS_ROOT>\AGENTS.md`).
- Явно подсказать, что для `QUEST` рабочие spec-файлы создаются локально, а canonical template всегда берётся из `<AGENTS_ROOT>\templates\specs\_template.md`.

## SHOULD

- Добавить краткий раздел с project-specific профилем по умолчанию.

## MAY

- Добавить ссылку на локальный `AGENTS.override.md`.

## Команды

```markdown
# AGENTS (local pointer)

Этот репозиторий использует центральный каталог инструкций:

- `<AGENTS_ROOT>\AGENTS.md`

Для QUEST-задач:

- рабочие spec-файлы создаются в локальном `.\specs\`
- canonical template всегда берётся из `<AGENTS_ROOT>\templates\specs\_template.md`

Порядок применения:
1. Центральный `AGENTS.md`
2. Локальный `AGENTS.override.md` (только ужесточение MUST)
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/onboarding/quick-start.md](./quick-start.md)
- [instructions/onboarding/AGENTS.override.template.md](./AGENTS.override.template.md)
