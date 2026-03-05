# Governance: Commit Message Policy

## Когда применять

- Для любого коммита в этом каталоге инструкций.
- Для изменений, которые должны быть понятны в аудите и changelog.

## Когда не применять

- Для временных локальных экспериментальных коммитов вне основного workflow.

## MUST

- Использовать Conventional Commits формат:
  - `<type>(<scope>): <short summary>`
- Использовать императивный стиль и ясный scope.
- Избегать расплывчатых сообщений (`update`, `changes`, `final`).
- Для breaking изменений добавлять `BREAKING CHANGE:` в footer.
- Разделять логически независимые изменения на отдельные коммиты.

## SHOULD

- Держать заголовок до 72 символов.
- В body пояснять `что` и `почему`, а не дублировать diff.
- Для production-sensitive изменений явно описывать impact.

## MAY

- Добавлять ссылки на задачи (`Closes #...`, `Refs: ...`) в footer.

## Команды

```powershell
# Пример проверки локальной истории
git log --oneline -n 20
```

## Допустимые типы

- `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`, `style`, `revert`

## Примеры

```text
fix(auth): correct JWT expiration validation
feat(arm): add production reserve support
refactor(nac-rabbit): simplify connection retry logic
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/versioning-policy.md](./versioning-policy.md)
- [CHANGELOG.md](../../CHANGELOG.md)
