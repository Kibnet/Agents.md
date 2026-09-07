# Governance: Document Contract

## Когда применять

- Для добавления, изменения и проверки документов `instructions/*`.

## MUST

- Каждый документ содержит непустые разделы `## Когда применять`, `## MUST` и `## Связанные документы`: область применения, обязательный контракт и owner/связи.
- SHOULD/MAY, исключения и команды добавлять по содержанию. Отсутствие этих секций допустимо; пустые секции и нерелевантные команды не нужны. Прежняя семисекционная форма остаётся допустимой.
- Язык контента — русский; имена файлов/папок — английский kebab-case, кроме стабильных `AGENTS.consumer.template.md` и `AGENTS.override.template.md`.
- Нормативное требование имеет одного owner. Обзор, prompt и template ссылаются на него; удаление дублирования не ослабляет substantive правило.
- Validator проверяет тот же структурный контракт вне code fences; незакрытый fence считается ошибкой каталога. Это style restriction, не обещание полного CommonMark parser.
- Ссылки на файлы внутри репозитория относительные. Private/local-only evidence — literal path с ограничением доступности, не обязательная Markdown-ссылка. Tracked ссылки не должны требовать личного home/Temp или абсолютного пути автора.

## Формы документов

| Тип | Полезное содержание помимо обязательного |
| --- | --- |
| Policy | Условия/исключения, единственный owner решения |
| Context | Входные сигналы, проверки/команды для реального runner |
| Profile | Уникальные stack/domain/change-type ограничения |
| Onboarding/template | Схема подключения, placeholders, проверка загрузки |

## SHOULD

- Проверять структуру отдельно от machine contracts и text guards. Наличие фразы не доказывает поведение агента.
- Оставлять команды только когда они исполнимы и помогают применить документ; stack-neutral profile не выбирает произвольный runner.

## Команды

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

## Связанные документы

- [Routing](./routing-matrix.md)
- [Версии](./versioning-policy.md)
- [Onboarding](../onboarding/quick-start.md)
