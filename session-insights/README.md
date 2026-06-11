# Session Insights

Дата подготовки: 2026-06-05.

Источник: локальный snapshot Codex-сессий. Приватные пути к исходным журналам намеренно не включаются в committable docs.

Охват последнего полного прохода:

- 421 JSONL-сессия.
- 4099 отфильтрованных пользовательских сообщений.
- Период: 2025-11-13 .. 2026-06-05.
- Основные репозитории по числу сессий: `Unlimotion`, `TopLunchBot`, `AppAutomation`, `DotnetDebug`, `Agents`, `Arm.Srv`, `graph-bot`, `ArduinoAndRaspberry`, `PDFAnnotator`, `UTEP`.

## Назначение

Этот каталог содержит не память пользователя в личном смысле, а рабочие артефакты для улучшения качества будущих Codex-сессий:

- какие ошибки агент чаще всего повторял;
- какие команды и проверки реально использовались;
- какие repo-specific runbooks стоит применять;
- как проверять UI в стиле, который ожидает пользователь;
- какие инструкции стоит улучшить в центральном каталоге;
- чего не повторять.

## Артефакты

Перед использованием этих файлов см. routing policy: [instructions/contexts/session-insights-context.md](../instructions/contexts/session-insights-context.md).

### Sanitized Operational Artifacts

- [AGENT_SESSION_LESSONS.md](AGENT_SESSION_LESSONS.md) - частые ошибки агента и как действовать иначе.
- [REPO_RUNBOOKS_FROM_SESSIONS.md](REPO_RUNBOOKS_FROM_SESSIONS.md) - краткие runbooks по основным репозиториям.
- [VALIDATION_COOKBOOK_FROM_SESSIONS.md](VALIDATION_COOKBOOK_FROM_SESSIONS.md) - cookbook проверок по типам задач.
- [UI_QUALITY_RUBRIC_FROM_SESSIONS.md](UI_QUALITY_RUBRIC_FROM_SESSIONS.md) - user-specific UI quality rubric.
- [COMMAND_COOKBOOK_FROM_SESSIONS.md](COMMAND_COOKBOOK_FROM_SESSIONS.md) - проверенные командные паттерны.
- [USER_WORKFLOW_PREFERENCES.md](USER_WORKFLOW_PREFERENCES.md) - рабочие предпочтения взаимодействия с агентом.
- [AGENTS_IMPROVEMENT_BACKLOG.md](AGENTS_IMPROVEMENT_BACKLOG.md) - backlog улучшений центральных инструкций.
- [DO_NOT_REPEAT.md](DO_NOT_REPEAT.md) - анти-паттерны, которые уже встречались в сессиях.

### Private-Local Artifacts

Эти файлы могут существовать в рабочем дереве, но по умолчанию не предназначены для commit/PR:

- `PROJECT_INTEREST_MAP.md` - карта проектов, стеков и интересов.
- `FLAKY_SLOW_TESTS_REGISTRY.md` - slow/flaky test candidates и как запускать аккуратно.
- `../USER_PROFILE_FROM_CODEX_SESSIONS.md` - full user profile snapshot.

## Правила использования

1. Эти файлы не заменяют текущий user prompt, `AGENTS.md`, local override или repo-specific инструкции.
2. Если файл говорит "обычно", "кандидат", "вероятно" или "вывод", это не факт текущего состояния репозитория. Перед действием нужно проверить локальный контекст.
3. Не копировать из этих файлов секреты, токены, приватные endpoint details или локальные credentials в коммиты/PR.
4. Не stage/commit private-local artifacts без отдельного явного решения пользователя.
5. Для задач в репозитории `Agents` после изменений запускать:

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
```

## Как обновлять

При повторном анализе сессий:

1. Сначала обновить метаданные охвата.
2. Затем обновлять только те разделы, где появилась новая устойчивая закономерность.
3. Не превращать разовый сбой в глобальное правило.
4. Указывать, где информация является выводом агента, а не прямым фактом из сессий.
