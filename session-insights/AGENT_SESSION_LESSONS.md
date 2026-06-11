# Agent Session Lessons

Дата подготовки: 2026-06-05.

Источник: полный проход по локальным JSONL-сессиям Codex. Счётчики ниже - это tool-event tags; категории могут пересекаться, потому что один output может быть одновременно `dotnet_build`, `test_failure` и `network_auth`.

## Top Failure Clusters

| Категория | Событий | Основной смысл |
|---|---:|---|
| `timeout` | 3337 | Команды запускались слишком широко, долго или без правильного timeout budget |
| `other_nonzero` | 1964 | Non-zero без точной классификации; часто это shell/CLI нюансы |
| `search_no_match` | 1664 | `rg`/поиск не нашёл совпадений или искал не там |
| `test_failure` | 1574 | Падающие, неправильно отфильтрованные или слишком широкие тесты |
| `dotnet_build` | 1549 | Ошибки сборки, restore, compile/runtime, preview SDK warnings |
| `missing_path` | 892 | Неверные пути, старые имена файлов, отсутствующие project paths |
| `patch_failure` | 621 | `apply_patch` не нашёл ожидаемый контекст |
| `network_auth` | 612 | SSL/NuGet/auth/permission/SSH/API blockers |
| `git` | 498 | branch/PR/CI/auth/remote/ref lock issues |
| `powershell` | 332 | ParserError, interpolation, ranges, shell syntax mismatch |
| `missing_tool` | 292 | `dotnet-script`, `dumpbin`, `llvm-readelf`, Playwright/Python packages и т.п. |
| `dependency` | 27 | Python/Node import/package failures |

## Lessons

### 1. Не запускать широкие тесты первым шагом

Симптом: `dotnet test`, TUnit executable или full suite висит 30-60 минут и заканчивается timeout.

Причина: в `Unlimotion`, `Arm.Srv`, `AppAutomation` и UI-heavy проектах полный набор тестов дорогой; часть тестов требует serial mode, headless setup или заранее собранного проекта.

Правильное действие:

- начать с narrow test/filter по изменённому поведению;
- если TUnit, использовать repo-proven `--treenode-filter`;
- full suite запускать только после targeted green или когда пользователь/CI явно требует;
- заранее задавать timeout, serial options и `--no-progress`;
- в финале честно указать, какой уровень проверки выполнен.

### 2. Не угадывать test runner syntax

Симптом: агент пробует VSTest `--filter`, а проект использует TUnit/Microsoft Testing Platform.

Причина: привычная команда не совпадает с runner model.

Правильное действие:

- сначала определить runner: `.csproj`, test package, README, existing scripts, предыдущие успешные команды;
- для TUnit искать `--treenode-filter`, `--maximum-parallel-tests`, `--parallelism-strategy`, `--no-progress`;
- не смешивать `dotnet test --filter` и TUnit arguments без подтверждения.

### 3. `rg` exit code `1` - не всегда ошибка

Симптом: поиск помечается как failure, хотя stderr пустой.

Причина: `rg` возвращает `1`, когда совпадений нет.

Правильное действие:

- считать `rg` code `1` как "no matches", если stderr не содержит IO/syntax error;
- при no matches менять гипотезу или scope, а не чинить несуществующий сбой.

### 4. Сужать search scope до likely directories

Симптом: рекурсивный `rg`, `Get-ChildItem -Recurse` или `Select-String` таймаутится.

Причина: большие worktrees, `bin/obj`, artifacts, NuGet cache, Android SDK, generated outputs.

Правильное действие:

- сначала `rg --files` и узкие каталоги (`src`, `tests`, `specs`, `.github`);
- исключать `bin`, `obj`, `artifacts`, `TestResults`, `.git`;
- увеличивать timeout только после сужения scope.

### 5. Перед `apply_patch` читать свежий контекст

Симптом: `apply_patch verification failed: Failed to find expected lines`.

Причина: файл уже изменился в этой сессии, был изменён пользователем, имеет другую кодировку/форматирование или агент использует stale hunk.

Правильное действие:

- перед patch прочитать точные nearby lines;
- патчить малым локальным hunk;
- если patch failed, перечитать файл и не повторять тот же hunk;
- для XAML/больших файлов искать stable anchors.

### 6. PowerShell - не Bash

Симптомы:

- `Missing file specification after redirection operator`;
- `Variable reference is not valid`;
- `Cannot bind parameter Index`;
- `The term ... is not recognized`.

Причины:

- Bash heredoc в PowerShell;
- `$file:$line` интерпретируется как scoped variable;
- `Select-Object -Index 200..245` без скобок;
- кавычки ломают regex или command line.

Правильное действие:

- Python snippets: `@' ... '@ | python -`;
- line refs: `"${file}:$line"` или `"{0}:{1}" -f $file, $line`;
- ranges: `-Index (200..245)` или `-Skip 200 -First 46`;
- regex с `|` и кавычками передавать через single quotes или `-e`.

### 7. Optional tooling проверять preflight

Симптом: агент начинает решение через инструмент, которого нет.

Частые отсутствующие элементы:

- `dotnet-script`;
- `dumpbin`;
- `llvm-readelf`;
- Playwright Node package;
- PyYAML;
- PDF/OCR utilities;
- Android SDK/NDK pieces.

Правильное действие:

- перед планом, зависящим от tooling, запустить cheap `Get-Command`/package check;
- иметь fallback через bundled runtime или repo scripts;
- не строить решение вокруг отсутствующего инструмента.

### 8. NuGet/SSL/auth failures - сначала environment blocker

Симптомы:

- `error NU1301`;
- SSL connection could not be established;
- GitHub/SSH host key permission denied;
- `gh` требует auth;
- API fetch failed.

Причина: часто это сеть, credentials, token, local trust store, GitHub auth или permission, а не баг кода.

Правильное действие:

- отдельно классифицировать как environment/access blocker;
- попробовать `--no-restore` только если restore уже точно актуален;
- не переписывать код, пока failure не воспроизведён как code failure.

### 9. GitHub delivery начинать с state/auth check

Симптомы:

- branch ref lock;
- detached worktree confusion;
- existing PR;
- `gh auth login` required;
- remote SSH permission denied.

Правильное действие:

- `git status --short`, `git branch --show-current`, `git remote -v`;
- проверить existing PR/branch;
- предпочитать GitHub connector tools, если доступны;
- `gh` использовать только после auth check;
- не коммитить unrelated/status-only noise.

### 10. UI нельзя считать готовым без визуального self-review

Симптом: код собрался, но пользователь возвращает задачу из-за некрасивых кнопок, переносов, неполной иконки, визуального шума.

Причина: агент проверил техническое состояние, но не посмотрел результат глазами.

Правильное действие:

- для UI-задач планировать screenshot/render evidence;
- проверять wide/narrow, desktop/mobile, hover/empty/error states;
- сравнить скриншот с пользовательскими критериями;
- финально приложить или описать evidence.

### 11. Редактируемые артефакты важнее быстрой картинки

Симптом: презентация/слайд выглядит похоже, но сделан картинкой, а пользователь хотел редактируемую структуру.

Правильное действие:

- уточнять target artifact: editable HTML/PPTX/DOCX vs raster;
- сохранять текст, фигуры, изображения как редактируемые элементы;
- использовать raster только для исходных изображений/фоновых assets, если это не противоречит задаче.

### 12. Секреты и токены - отдельный риск

Симптом: задачи с ботами/API/сервером содержат токены, конфиги, SSH keys или deployment state.

Правильное действие:

- не выводить токены в финал;
- не добавлять их в git;
- при patch/commit проверять diff на secrets;
- если пользователь говорит "токен не забудь передать", это operational input, а не разрешение коммитить секрет.

## Guardrails From Memory

Эти пункты также зафиксированы в durable memory из ad-hoc note и должны применяться как operational guardrails. [ad-hoc note]

- Для TUnit использовать repo-documented `--treenode-filter`.
- В PowerShell использовать here-string pipeline вместо Bash heredoc.
- Перед `apply_patch` читать свежий контекст.
- В больших repo сужать search scope.
- Перед GitHub delivery проверять branch/auth/remote/existing PR.
- Network/NuGet/SSL/auth/permission failures считать environment blockers, пока не доказано обратное.
