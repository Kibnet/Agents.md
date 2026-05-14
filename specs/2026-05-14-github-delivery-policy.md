# GitHub Delivery Policy

## 0. Метаданные
- Тип (профиль): catalog-governance / product-system-design
- Владелец: central instruction catalog
- Масштаб: medium
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: `2.3.0` / текущая рабочая ветка
- Ограничения:
  - На фазе SPEC изменяется только этот файл.
  - До фразы `Спеку подтверждаю` нельзя менять `instructions/*`, `scripts/*`, `README.md`, `CHANGELOG.md` и другие проектные файлы.
  - Новый документ должен соблюдать `document-contract.md`: русский язык, kebab-case имя, обязательные секции.
  - Правила должны дополнять, а не дублировать `commit-message-policy.md` и `versioning-policy.md`.
- Связанные ссылки:
  - [GitHub Docs: About branches](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-branches)
  - [GitHub Docs: About pull requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)
  - [GitHub Docs: About issue and pull request templates](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-issue-and-pull-request-templates)
  - [GitHub Docs: Linking a pull request to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue)
  - [GitHub Docs: Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
  - [GitHub Docs: Automatically generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes)
  - [GitHub Docs: About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
  - [Semantic Versioning 2.0.0](https://semver.org/)
  - [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)

Если секция не применима, явно указано `Не применимо` и причина.

## 1. Overview / Цель
Добавить в каталог единый governance-документ для GitHub delivery workflow: правила именования веток, оформления pull request и публикации GitHub Releases.

Outcome contract:
- Success means:
  - В каталоге появляется owner-документ `instructions/governance/github-delivery-policy.md`.
  - Routing подключает новый документ по триггерам `ветки`, `PR`, `GitHub Releases`.
  - Правила согласованы с Conventional Commits, SemVer и существующими `commit-message-policy.md` / `versioning-policy.md`.
  - Validator и changelog отражают новый канонический документ.
- Итоговый артефакт / output:
  - Новый governance-документ.
  - Обновленные ссылки в routing и связанных governance-документах.
  - Запись в `CHANGELOG.md`.
  - При необходимости обновленный список обязательных путей в `scripts/validate-instructions.ps1`.
- Stop rules:
  - На SPEC остановиться после готовой спеки, self-review и запроса подтверждения.
  - На EXEC остановиться после реализации, запуска validator/test-validator, post-EXEC review и отчета.

## 2. Текущее состояние (AS-IS)
- `instructions/governance/commit-message-policy.md` задает Conventional Commits для коммитов.
- `instructions/governance/versioning-policy.md` задает SemVer и changelog для версий каталога.
- `instructions/governance/routing-matrix.md` маршрутизирует `commit-message-policy` и `versioning-policy` для коммитов и changelog.
- Отдельных правил для:
  - branch naming;
  - PR title/body/review readiness;
  - GitHub Release body/tag/pre-release;
  - связи GitHub issue, PR, release notes и labels;
  сейчас нет.
- `scripts/validate-instructions.ps1` содержит статический список обязательных документов, поэтому новый owner-документ следует добавить туда, если он становится каноническим.

## 3. Проблема
В каталоге есть правила коммитов и версионирования, но нет единого owner-документа для GitHub delivery artifacts. Из-за этого ветки, PR и релизы могут называться и оформляться по-разному в разных репозиториях, а связь между коммитами, PR, changelog и GitHub Releases остается неявной.

## 4. Цели дизайна
- Разделение ответственности:
  - `commit-message-policy.md` отвечает за сообщения коммитов.
  - `versioning-policy.md` отвечает за SemVer и changelog.
  - новый `github-delivery-policy.md` отвечает за branch, PR и GitHub Release artifacts.
- Повторное использование:
  - типы веток и PR должны использовать уже принятые Conventional Commit types.
- Тестируемость:
  - документ должен проходить existing markdown/instruction validator.
  - acceptance criteria должны проверяться локальными командами.
- Консистентность:
  - одинаковые type/scope/issue conventions проходят через branch name, PR title, squash title и release notes.
- Обратная совместимость:
  - новый документ добавляет rules/guidance без изменения существующих обязательных контрактов коммитов и версионирования.

## 5. Non-Goals (чего НЕ делаем)
- Не внедряем GitHub Actions workflow, branch protection settings или GitHub repository settings.
- Не создаем `.github/PULL_REQUEST_TEMPLATE.md` или `.github/release.yml`.
- Не меняем формат `CHANGELOG.md` задним числом.
- Не меняем список допустимых Conventional Commit types в `commit-message-policy.md`, кроме ссылочной синхронизации.
- Не требуем один жесткий ticket tracker format для всех consumer-репозиториев.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности
- `instructions/governance/github-delivery-policy.md` -> новый owner-документ для веток, PR и GitHub Releases.
- `instructions/governance/routing-matrix.md` -> добавляет governance overlay для триггеров `ветка`, `pull request`, `GitHub Release`.
- `instructions/governance/commit-message-policy.md` -> добавляет ссылку на новый документ.
- `instructions/governance/versioning-policy.md` -> добавляет ссылку на новый документ и сохраняет SemVer owner role.
- `scripts/validate-instructions.ps1` -> добавляет новый governance path в `$requiredPaths`.
- `CHANGELOG.md` -> добавляет релизную запись `2.3.0`.

### 6.2 Детальный дизайн
Целевой документ: `instructions/governance/github-delivery-policy.md`.

Обязательная структура по `document-contract.md`:
- `## Когда применять`
- `## Когда не применять`
- `## MUST`
- `## SHOULD`
- `## MAY`
- `## Команды`
- `## Связанные документы`

Содержание целевого policy:

```markdown
# Governance: GitHub Delivery Policy

## Когда применять

- При создании или ревью рабочих веток.
- При подготовке, открытии, обновлении или ревью GitHub Pull Request.
- При подготовке GitHub Release, release tag и release notes.
- Когда нужно связать issue, PR, changelog и release notes в единый delivery trace.

## Когда не применять

- Для локальных экспериментальных веток, которые не пушатся и не участвуют в review/release workflow.
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
- Для UI-facing изменений добавлять screenshots/video или явно объяснять, почему визуальное evidence не применимо.
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
- [instructions/governance/versioning-policy.md](./versioning-policy.md)
- [instructions/governance/routing-matrix.md](./routing-matrix.md)
- [CHANGELOG.md](../../CHANGELOG.md)
```

Output/evidence rules:
- Для внешних factual claims в policy использовать только устойчивые формулировки, основанные на GitHub Docs, SemVer и Conventional Commits.
- Не копировать длинные фрагменты внешней документации.
- В итоговом отчете указать, что внешние источники использовались как guidance, а не как runtime dependency.

Границы сохранения поведения:
- Existing commit and versioning contracts не меняются.
- Новый document only expands delivery governance.
- Consumer overrides могут ужесточать, но не ослаблять центральные `MUST`.

## 7. Бизнес-правила / Алгоритмы (если есть)
Формальные правила целевой политики:

| Область | Правило |
| --- | --- |
| Branch type | Совпадает с Conventional Commit type, кроме `release` для release branches |
| Branch pattern | `<type>/<scope-or-issue>-<short-summary>` |
| Branch charset | lowercase kebab-case для slug; `/` только как разделитель type и slug |
| PR title | Conventional Commits title, если PR title может стать squash commit или release note seed |
| PR body | Goal, changes, validation, risks/rollback, links |
| Issue link | Closing keywords только для полного закрытия issue |
| Release tag | `vMAJOR.MINOR.PATCH`, SemVer |
| Release notes | Curated, grouped, reconciled with changelog and merged PR |
| Breaking change | Явный marker в PR и release notes |

## 8. Точки интеграции и триггеры
- `routing-matrix.md`:
  - добавить governance overlay:
    - `Ветки, PR и GitHub Releases` -> `github-delivery-policy`, при необходимости `commit-message-policy`, `versioning-policy`.
  - добавить ссылку в `Связанные документы`.
- `commit-message-policy.md`:
  - добавить related link на `github-delivery-policy.md`.
- `versioning-policy.md`:
  - добавить related link на `github-delivery-policy.md`.
- `scripts/validate-instructions.ps1`:
  - добавить `instructions/governance/github-delivery-policy.md` в `$requiredPaths`.
- `CHANGELOG.md`:
  - добавить `2.3.0` с `Added` для нового governance-документа и `Changed` для routing/validator sync.

## 9. Изменения модели данных / состояния
- Не применимо: изменений runtime state, persisted data или API данных нет.
- Состояние каталога меняется как набор markdown-инструкций и validator contract.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - Добавить новый governance-документ.
  - Синхронизировать routing и related links.
  - Обновить validator required paths.
  - Зафиксировать изменение в changelog как `MINOR`, потому что добавляется новый policy без breaking contract.
- Rollback:
  - Удалить новый документ.
  - Убрать ссылки из routing/related docs.
  - Убрать path из validator.
  - Удалить changelog entry.
- Обратная совместимость:
  - Existing consumer repositories продолжают работать.
  - Local `AGENTS.override.md` может уточнить branch/PR/release conventions под конкретную организацию.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - Создан `instructions/governance/github-delivery-policy.md`.
  - Документ содержит все обязательные секции `document-contract.md`.
  - `routing-matrix.md` маршрутизирует новый policy по релевантным триггерам.
  - `commit-message-policy.md` и `versioning-policy.md` ссылаются на новый policy.
  - `CHANGELOG.md` содержит запись релиза `2.3.0`.
  - `scripts/validate-instructions.ps1` считает новый policy обязательным.
  - Все проверки проходят.
- Какие тесты добавить/изменить:
  - Обновление validator required paths достаточно, отдельный новый test scenario не требуется, потому что scenario `валидный каталог` и `missing required path` implicitly covered by required paths.
- Characterization tests / contract checks:
  - До EXEC проверить `git status --short`.
  - После EXEC запустить validator и validator tests.
- Команды для проверки:
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `git diff --stat`
- Stop rules для validation loops:
  - Если validator падает из-за нового документа, исправить документ или ссылки и повторить.
  - Если test-validator падает из-за contract drift, исправить validator/tests или зафиксировать blocker.

## 12. Риски и edge cases
- Риск: слишком жесткая branch naming policy будет неудобна consumer-репозиториям с Jira/Azure DevOps naming.
  - Смягчение: центральный policy задает базовую схему, а ticket id оставляет `MAY`; локальные overrides могут ужесточать.
- Риск: PR body template может быть воспринят как обязательный `.github` template.
  - Смягчение: в Non-Goals явно не создается `.github/PULL_REQUEST_TEMPLATE.md`.
- Риск: GitHub Releases и changelog начнут дублировать друг друга.
  - Смягчение: release notes сверяются с changelog, но GitHub Release остается delivery artifact, а changelog - canonical catalog history.
- Риск: release tag `vMAJOR.MINOR.PATCH` конфликтует с проектами без `v` prefix.
  - Смягчение: `MUST` допускает более строгий repo profile; central catalog получает consistent default.

## 13. План выполнения
Этапы EXEC после подтверждения:

1. Добавить `instructions/governance/github-delivery-policy.md`.
2. Обновить `routing-matrix.md` overlay и related links.
3. Обновить related links в `commit-message-policy.md` и `versioning-policy.md`.
4. Добавить новый path в `scripts/validate-instructions.ps1`.
5. Добавить запись `2.3.0` в `CHANGELOG.md`.
6. Запустить:
   - `pwsh -File scripts/validate-instructions.ps1`
   - `pwsh -File scripts/test-validate-instructions.ps1`
7. Выполнить post-EXEC review и исправить найденные проблемы в рамках спеки.

## 14. Открытые вопросы
- Блокирующих вопросов нет.
- Неблокирующая настройка для будущего: можно отдельно решить, нужен ли `.github/PULL_REQUEST_TEMPLATE.md` в самом каталоге.

## 15. Соответствие профилю
- Профиль: `instructions/profiles/product-system-design.md`
- Выполненные требования профиля:
  - Цели и non-goals выделены.
  - Границы новой policy-подсистемы описаны.
  - Публичный contract нового governance-документа зафиксирован.
  - Совместимость с существующими owner-документами и validator проверена в плане.
  - Внешние GitHub/SemVer/Conventional Commit источники зафиксированы.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `specs/2026-05-14-github-delivery-policy.md` | Рабочая спецификация | QUEST SPEC gate |
| `instructions/governance/github-delivery-policy.md` | Новый документ | Owner policy для веток, PR и GitHub Releases |
| `instructions/governance/routing-matrix.md` | Новый trigger overlay и related link | Маршрутизация policy |
| `instructions/governance/commit-message-policy.md` | Related link | Связь PR/branch naming с Conventional Commits |
| `instructions/governance/versioning-policy.md` | Related link | Связь release policy с SemVer/changelog |
| `scripts/validate-instructions.ps1` | Required path | Зафиксировать новый owner-документ как обязательный |
| `CHANGELOG.md` | `2.3.0` entry | Версионирование каталога |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Branch naming | Нет центрального правила | `<type>/<scope-or-issue>-<short-summary>` |
| PR title | Нет центрального правила | Conventional Commits title для review/squash/release workflow |
| PR body | Нет центрального минимального состава | Goal, changes, validation, risks/rollback, links |
| Release notes | Только changelog/versioning policy | GitHub Release rules плюс сверка с changelog |
| Routing | Коммиты и changelog | Коммиты/changelog плюс branches/PR/releases |
| Validator | Новый policy не обязателен | Новый policy входит в required paths |

## 18. Альтернативы и компромиссы
- Вариант: расширить `commit-message-policy.md`.
  - Плюсы: меньше файлов.
  - Минусы: документ начнет отвечать за ветки, PR и releases, теряется разделение owner responsibility.
  - Почему не выбран: scope становится слишком широким.
- Вариант: расширить `versioning-policy.md`.
  - Плюсы: релизы уже рядом с версионированием.
  - Минусы: branch и PR правила не относятся напрямую к SemVer.
  - Почему не выбран: PR/branch workflow нужен до релизной фазы.
- Вариант: создать `github-delivery-policy.md`.
  - Плюсы: ясный owner для GitHub delivery artifacts, хорошая связка с commit/version policies.
  - Минусы: еще один governance-документ и validator path.
  - Почему выбранное решение лучше в контексте этой задачи: оно сохраняет маленькие owner-документы и делает routing явным.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, цели и Non-Goals зафиксированы. |
| B. Качество дизайна | 6-10 | PASS | Target policy, ownership, rollout и rollback описаны. |
| C. Безопасность изменений | 11-13 | PASS | Изменения документационные; acceptance и план проверки заданы. |
| D. Проверяемость | 14-16 | PASS | Есть команды проверки, acceptance criteria и file table. |
| E. Готовность к автономной реализации | 17-19 | PASS | Блокирующих вопросов нет, этапы EXEC конкретны. |
| F. Соответствие профилю | 20 | PASS | Профиль и выполненные требования указаны. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---|---|
| 1. Ясность цели и границ | 5 | Цель, output, Non-Goals и stop rules заданы. |
| 2. Понимание текущего состояния | 5 | Указаны существующие commit/version/routing/validator contracts. |
| 3. Конкретность целевого дизайна | 5 | Есть проект целевого policy и список изменяемых файлов. |
| 4. Безопасность (миграция, откат) | 5 | Документирован rollout/rollback без runtime side effects. |
| 5. Тестируемость | 5 | Команды validator/test-validator и acceptance criteria заданы. |
| 6. Готовность к автономной реализации | 5 | Нет блокирующих вопросов, порядок EXEC определен. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Что исправлено:
  - Разведены обязанности `commit-message-policy`, `versioning-policy` и нового `github-delivery-policy`.
  - Добавлены rollback и риск конфликтов с локальными ticket naming conventions.
  - Уточнено, что GitHub generated notes являются черновиком, а не финальным release text.
- Что осталось на решение пользователя:
  - Подтвердить spec фразой `Спеку подтверждаю` или попросить изменить proposed policy.

### Post-EXEC Review
- Статус: PASS
- Что исправлено до завершения:
  - Не требовалось: отклонений от утвержденной spec не найдено.
- Что проверено дополнительно для refactor / comments:
  - Проверено, что изменение не является refactor и не добавляет устаревших code comments.
  - Проверено, что новый документ соблюдает обязательные секции `document-contract.md`.
- Остаточные риски / follow-ups:
  - Нет блокирующих рисков. Возможный будущий follow-up: отдельный `.github/PULL_REQUEST_TEMPLATE.md`, если каталог решит поставлять GitHub templates как артефакты.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Сбор контекста и маршрутизация | 0.95 | Нет | Создать рабочую spec | Нет | Нет | Изменение `instructions/*` требует QUEST SPEC gate; выбран `product-system-design` как ближайший профиль проектирования policy. | `AGENTS.md`, `routing-matrix.md`, `commit-message-policy.md`, `versioning-policy.md`, `document-contract.md`, `quest-*`, `product-system-design.md` |
| SPEC | Черновик и review спецификации | 0.95 | Нет | Запросить подтверждение пользователя | Да | Да, ожидается подтверждение `Спеку подтверждаю` | Spec содержит целевой документ, acceptance criteria, rollback, linter/rubric и post-SPEC review. | `specs/2026-05-14-github-delivery-policy.md` |
| EXEC | Переход к реализации | 1.0 | Нет | Создать новый governance-документ и синхронизировать ссылки | Нет | Да, пользователь подтвердил `Спеку подтверждаю` | Фраза подтверждения получена, поэтому разрешены изменения за пределами рабочей spec в границах утвержденного плана. | `specs/2026-05-14-github-delivery-policy.md` |
| EXEC | Реализация policy и синхронизация каталога | 0.95 | Нет | Запустить validator и validator tests | Нет | Нет | Создан owner-документ для GitHub delivery workflow; routing, related links, validator required path и changelog синхронизированы. | `instructions/governance/github-delivery-policy.md`, `instructions/governance/routing-matrix.md`, `instructions/governance/commit-message-policy.md`, `instructions/governance/versioning-policy.md`, `scripts/validate-instructions.ps1`, `CHANGELOG.md` |
| EXEC | Проверки и post-EXEC review | 0.95 | Нет | Подготовить итоговый отчет | Нет | Нет | Validator и validator tests прошли; post-EXEC review подтвердил соответствие реализации утвержденной spec. | `specs/2026-05-14-github-delivery-policy.md`, `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1` |
