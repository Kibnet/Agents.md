# Do Not Repeat

Дата подготовки: 2026-06-05.

Это список анти-паттернов, которые уже встречались в сессиях и ухудшали работу агента. Использовать как pre-flight checklist перед значимыми задачами.

## Shell And Tooling

- Не использовать Bash heredoc в PowerShell.
- Не писать `$file:$line` в interpolated strings.
- Не передавать `200..245` в `Select-Object -Index` без скобок.
- Не строить план вокруг `dotnet-script`, `dumpbin`, `llvm-readelf`, Playwright или PyYAML без preflight.
- Не запускать рекурсивный поиск по всему repo/cache/artifacts, если можно искать в `src/tests/specs/docs`.
- Не считать `rg` exit code `1` ошибкой без stderr.

## Testing

- Не запускать full `.NET` suite первым шагом в крупных repos.
- Не угадывать VSTest `--filter`, если repo может использовать TUnit.
- Не использовать `--no-restore`/`--no-build` без уверенности, что состояние актуально.
- Не скрывать timeout как "тесты не прошли"; timeout - отдельный validation blocker.
- Не завершать behavior change без test evidence или объяснения, почему тест невозможен.

## UI

- Не считать UI готовым без визуальной проверки.
- Не игнорировать wide/narrow states.
- Не оставлять обрезанные иконки, некрасивые кнопки, переносы и визуальный шум.
- Не делать "похоже работает", если пользователь просил "до идеала".
- Не заменять editable artifact плоской картинкой, если пользователь просил редактируемость.

## Patching

- Не повторять stale `apply_patch` hunk после failure.
- Не патчить большой XAML/C# файл без свежего nearby context.
- Не использовать broad patch, когда можно изменить small stable anchor.
- Не игнорировать изменения пользователя в рабочем дереве.

## Git / GitHub

- Не создавать branch/PR без проверки current branch, worktree state and existing PR.
- Не использовать `gh` без auth check.
- Не коммитить unrelated changes, line-ending noise или status-only changes.
- Не включать секреты, токены, SSH keys, private configs.
- Не считать PR готовым без validation section.

## Docs And Language

- Не отвечать на английском, если пользователь явно не просит.
- Не смешивать русский и английский в пользовательской документации без причины.
- Не оставлять mojibake or escaped Russian text when user wants readable Russian.
- Не добавлять длинную воду в финальный ответ.

## Environment

- Не переписывать код из-за NuGet SSL/auth/permission failure, пока не доказано, что это code bug.
- Не считать API failure доказательством бизнес-ошибки без token/auth/connectivity check.
- Не предполагать, что телефон/эмулятор/сервер всё ещё доступен.

## Process

- Не останавливаться на плане, если пользователь сказал "делай" и scope ясен.
- Не обходить SPEC gate, если текущий repo instructions требуют SPEC-first.
- Не задавать уточняющий вопрос вместо чтения очевидного repo context.
- Не финализировать без self-review после существенных изменений.

## Final Answer

- Не писать "готово" без указания проверок.
- Не скрывать, что проверка не запускалась.
- Не перегружать финал огромным логом.
- Не заканчивать неопределённым "если хотите".
- Не давать пользователю вручную копировать файлы, которые уже созданы в workspace.
