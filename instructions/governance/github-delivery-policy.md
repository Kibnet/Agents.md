# Governance: GitHub Delivery Policy

## Когда применять

- При создании или ревью рабочих веток.
- При подготовке, открытии, обновлении или ревью GitHub Pull Request.
- При подготовке GitHub Release, release tag и release notes.
- Когда нужно связать issue, PR, changelog и release notes в единый delivery trace.

## Когда не применять

- Для локальных экспериментальных веток, которые не пушатся и не участвуют в review или release workflow.
- Для репозиториев без GitHub как delivery platform, если локальный override не подключает GitHub workflow.
- Как замену `commit-message-policy.md` для сообщений коммитов.
- Как замену `versioning-policy.md` для SemVer и changelog.

## MUST

- Называть рабочие ветки по схеме `<type>/<scope-or-issue>-<short-summary>`.
- Использовать для `<type>` значения из `commit-message-policy.md`; для release-веток дополнительно разрешен `release`.
- Писать branch slug в lowercase kebab-case: латиница, цифры, `/` и `-`, без пробелов.
- Держать branch summary коротким и описательным, без служебных слов вроде `final`, `changes`, `update`.
- Оформлять PR title в Conventional Commits формате `<type>(<scope>): <short summary>`, если PR будет squash-merge commit или станет основой release notes.
- В PR body фиксировать минимум: цель, ключевые изменения, проверку, риски/rollback и связанные issue/spec.
- Использовать GitHub closing keywords только когда PR полностью закрывает связанную issue.
- Открывать PR как draft, если implementation, tests, self-review или обязательный template еще не готовы.
- Перед переводом PR в ready for review выполнить self-review, указать validation evidence и убрать unrelated changes.
- Для PR с UI automation изменениями указывать в validation evidence ссылки или пути на `до`/`после` video artifacts из автоматизированных UI test runs либо явный fallback с причиной и next-best evidence.
- Для breaking changes явно помечать PR и release notes через `BREAKING CHANGE:` или отдельный блок `Breaking`.
- Публиковать GitHub Release только от SemVer tag формата `vMAJOR.MINOR.PATCH`, если профиль репозитория не задает более строгую схему.
- Перед публикацией GitHub Release сверять release notes с changelog, merged PR и фактическим diff.
- Не полагаться на automatically generated release notes как на финальный текст без human/agent curation.

## SHOULD

- Держать ветки короткоживущими и удалять их после merge, если branch не является release/support branch.
- Использовать branch examples:
  - `feat/auth-refresh-token`
  - `fix/issue-123-login-timeout`
  - `docs/github-delivery-policy`
  - `refactor/routing-matrix`
  - `release/v2-3-0`
- Делать PR маленькими: одна корневая проблема или один связный outcome на PR.
- Использовать PR body sections: `Summary`, `Changes`, `Validation`, `Risks / Rollback`, `Links`.
- Для UI-facing изменений добавлять screenshots/video или явно объяснять, почему визуальное evidence не применимо; если применялся `ui-automation-testing`, video evidence должно быть связано с UI test run.
- Для production-sensitive изменений добавлять rollout notes, rollback plan и impact.
- Настраивать GitHub labels так, чтобы они помогали release notes categories: `feature`, `fix`, `docs`, `breaking`, `security`, `dependencies`.
- Группировать GitHub Release body по блокам: `Highlights`, `Added`, `Changed`, `Fixed`, `Removed`, `Security`, `Breaking`, `Migration`, `Known Issues`.
- Использовать GitHub pre-release для `alpha`, `beta`, `rc` и других версий, которые не считаются production-ready.
- Защищать основные ветки через GitHub branch protection rules: review, status checks и запрет прямого push, если это поддерживается репозиторием.

## MAY

- Добавлять ticket id в branch slug: `feat/proj-123-import-preview`.
- Использовать repository-specific `AGENTS.override.md` для более строгой схемы веток, labels, reviewers или release trains.
- Использовать GitHub automatically generated release notes как черновик перед ручной редактурой.
- Использовать release branch `release/vX-Y-Z` для стабилизации версии, если в репозитории есть отдельный release train.
- При публикации бинарных артефактов прикладывать checksums, SBOM или подписи, если это требуется доменом.

## Команды

```powershell
# Проверка текущей ветки и последних коммитов
git branch --show-current
git log --oneline -n 20

# Просмотр PR/release-related изменений перед публикацией
git status --short
git diff --stat
git tag --list "v*"
```

## Примеры PR body

```markdown
## Summary
- Что меняется и зачем.

## Changes
- Ключевые изменения.

## Validation
- Команды, проверки, screenshots или причина, почему проверка не применима.

## Risks / Rollback
- Риски, impact и план отката.

## Links
- Closes #123
- Spec: ...
```

## Примеры Release body

```markdown
## Highlights
- Главное изменение релиза.

## Added
- Новые возможности.

## Changed
- Изменения поведения или workflow.

## Fixed
- Исправления.

## Breaking
- Несовместимые изменения и migration notes.

## Validation
- Проверки перед публикацией.
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/commit-message-policy.md](./commit-message-policy.md)
- [instructions/governance/routing-matrix.md](./routing-matrix.md)
- [instructions/governance/versioning-policy.md](./versioning-policy.md)
- [CHANGELOG.md](../../CHANGELOG.md)
