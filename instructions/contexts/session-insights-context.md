# Context: Session Insights

## Когда применять

- Пользователь просит учесть прошлые Codex-сессии, предпочтения, частые ошибки, memory, agent lessons или способы улучшить агента.
- Задача не self-contained и связана с известным репозиторием, для которого есть session-derived runbook.
- Задача затрагивает validation/build/test/CI, UI quality, PowerShell/Git/patch/tooling, GitHub delivery или repeated failure loop.
- Нужно выбрать, какие session-derived файлы безопасно догрузить в контекст.

## Когда не применять

- Запрос короткий, self-contained и не требует истории, repo context или предпочтений пользователя.
- В текущем repo нет `session-insights/`.
- Единственная причина загрузки - любопытство агента, а не задача.
- Требуется полный пользовательский профиль, но пользователь не просил персональный контекст явно.

## MUST

- Считать session-derived сведения подсказками, а не authoritative текущим состоянием repo.
- Перед действием проверять drift-prone факты в текущем workspace: файлы, команды, test runner, paths, branch, auth, CI, tool availability.
- Начинать lookup с `session-insights/README.md`, затем выбирать только релевантные файлы или секции.
- По умолчанию загружать не больше 1-3 session-derived источников для одной задачи.
- Не загружать полный `USER_PROFILE_FROM_CODEX_SESSIONS.md` без явного запроса пользователя про его предпочтения, стиль работы или факты о нём.
- Не stage/commit файлы, помеченные как `private-local`.
- Перед публикацией session-derived docs убирать user-specific absolute paths, credential paths, private endpoints и лишние персональные выводы.
- Если session-derived совет противоречит текущим user/developer/system instructions или repo docs, текущие инструкции и проверенный repo state имеют приоритет.
- Использовать этот context как targeted retrieval layer. Общие обязательные правила tool execution принадлежат `tool-execution-baseline` и не дублируются здесь.
- Не выбирать session-insights вместо stack/testing context: сначала собрать обязательный core и task-specific context, затем загрузить 1-3 релевантных historical sources.

## SHOULD

- Для known repo задач читать релевантную секцию `session-insights/REPO_RUNBOOKS_FROM_SESSIONS.md`, затем сверять её с текущими `AGENTS.md`, project files, scripts и CI.
- Для validation/test/build/CI читать `session-insights/VALIDATION_COOKBOOK_FROM_SESSIONS.md`; при known slow/flaky area можно дополнительно использовать private-local или repo-specific slow-test registry, если он доступен.
- Для UI/frontend/visual QA читать `session-insights/UI_QUALITY_RUBRIC_FROM_SESSIONS.md`.
- Для shell/Git/patch/tooling/timeouts читать `session-insights/AGENT_SESSION_LESSONS.md`, `session-insights/DO_NOT_REPEAT.md` или `session-insights/COMMAND_COOKBOOK_FROM_SESSIONS.md`.
- Для agent instruction work читать `session-insights/AGENTS_IMPROVEMENT_BACKLOG.md` и, при необходимости, `session-insights/AGENT_SESSION_LESSONS.md`.
- В финальном отчёте кратко указывать, какие session-derived источники повлияли на workflow, если они существенно изменили решение.

## MAY

- Делать deep lookup больше чем по 3 источникам, если пользователь прямо просит тщательный анализ сессий или задача повторяет прошлую ошибку.
- Использовать helper/script для выбора источников, если такой tooling появится позднее.
- Использовать sanitized summary пользовательских предпочтений для interaction-sensitive задач, но не превращать его в скрытое техническое требование.

## Команды

```powershell
# First-hop index
Get-Content session-insights/README.md

# Targeted source discovery
rg -n "Unlimotion|TUnit|PowerShell|GitHub|UI|validation" session-insights

# Before staging committable session-derived docs
git diff --cached
rg -n "token|secret|apiKey|password|ssh|private|credential|endpoint" session-insights instructions specs -g "*.md"
rg -n "<absolute-user-home-path>|<credential-path>" session-insights instructions specs -g "*.md"
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
- [instructions/governance/document-contract.md](../governance/document-contract.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
- [instructions/core/tool-execution-baseline.md](../core/tool-execution-baseline.md)
- [session-insights/README.md](../../session-insights/README.md)
- [specs/2026-06-05-session-insights-agent-context-delivery.md](../../specs/2026-06-05-session-insights-agent-context-delivery.md)
