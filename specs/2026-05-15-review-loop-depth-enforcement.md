# Review Loop Depth Enforcement

## 0. Метаданные
- Тип (профиль): `catalog-governance` + профиль `product-system-design`
- Владелец: центральный каталог агентских инструкций
- Масштаб: medium
- Целевая модель: gpt-5.5
- Целевой релиз / ветка: `2.7.0`
- Ограничения:
  - Фаза `SPEC`: менять только этот файл.
  - Фаза `EXEC`: не менять фразу перехода `Спеку подтверждаю` и базовый `SPEC -> EXEC` gate.
  - Усиление должно предотвращать поверхностный review, но не превращать small-задачи в непропорциональный аудит.
  - Полный review-loop должен быть обязательным и проверяемым через output/evidence, а не декларативным.
  - Изменения каталога требуют обновления `CHANGELOG.md`.
- Связанные ссылки:
  - `AGENTS.md`
  - `instructions/governance/routing-matrix.md`
  - `instructions/core/model-behavior-baseline.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/quest-mode.md`
  - `instructions/governance/review-loops.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`
  - `instructions/core/quest-prompt-spec.md`
  - `instructions/core/quest-prompt-exec.md`
  - `templates/specs/_template.md`

Если секция не применима, явно укажите `Не применимо` и короткую причину, вместо заполнения нерелевантными деталями.

## 1. Overview / Цель
Сделать `post-SPEC review` и `post-EXEC review` реальным review-loop, а не формальным заполнением блока:

- review должен запускаться как отдельный цикл с минимум двумя независимыми проходами;
- `PASS` должен быть невозможен без concrete reviewed scope, evidence и depth checklist;
- после исправлений по review должен выполняться повторный review-loop по затронутой поверхности;
- агент должен искать критические недочёты сам до финального отчёта, а не только после ручной просьбы пользователя.

Outcome contract:
- Success means:
  - `review-loops.md` задаёт обязательный full review-loop: context/evidence pass, contract/compliance pass, adversarial risk pass, fix/re-review loop, explicit stop condition.
  - `templates/specs/_template.md` содержит поля `Review passes`, `Depth checklist`, `Evidence inspected`, `Re-review after fixes`.
  - `quest-mode.md`, `quest-prompt-spec.md` и `quest-prompt-exec.md` требуют именно full review-loop, а не single-pass summary.
  - `CHANGELOG.md` содержит запись `2.7.0`.
- Итоговый артефакт / output:
  - обновлённые governance/template/prompt документы;
  - changelog entry;
  - краткий EXEC-отчёт с validation и post-EXEC review.
- Stop rules:
  - На `SPEC` остановиться после готовой спеки, quality gate, post-SPEC review и запроса подтверждения.
  - На `EXEC` остановиться, если невозможно задать проверяемый minimum review depth без чрезмерного или неясного scope.
  - Не завершать EXEC без validator, validator tests и semantic marker check по новым review-loop markers.

## 2. Текущее состояние (AS-IS)
- `review-loops.md` уже требует findings table, reviewed scope, validation evidence и statuses.
- Однако текущий контракт не заставляет review работать как цикл:
  - нет минимального числа независимых проходов;
  - нет обязательного adversarial/risk pass, в котором агент пытается опровергнуть собственное решение;
  - нет запрета на `PASS`, если агент фактически не инспектировал diff/spec/evidence;
  - нет правила, что после исправлений review запускается повторно по затронутым областям;
  - `Нет находок` можно написать без списка проверенных вопросов и evidence.
- `quest-mode.md` и prompt wrappers говорят выполнить `post-* review`, но не уточняют, что это full loop с повтором после исправлений.
- `quest-governance.md` как owner applicability/quality gate тоже говорит только `post-* review`, без требования full loop.
- `templates/specs/_template.md` хранит результат review, но не вынуждает показать depth: какие проходы были сделаны, что именно инспектировалось и что было проверено на adversarial pass.

## 3. Проблема
Инструкции допускают поверхностный `PASS`: агент может заполнить review-блок, не сделав независимый глубокий анализ. После этого пользователь вручную просит ревью, и агент находит критические недочёты, которые должен был найти в обязательном review-loop.

## 4. Цели дизайна
- Разделение ответственности:
  - `review-loops.md` остаётся owner-документом review semantics и output contract.
  - `quest-governance.md` фиксирует, что mandatory quality gate использует full review-loop из owner-документа.
  - `quest-mode.md` фиксирует фазовый stop rule: нельзя завершить phase без full review-loop.
  - prompt wrappers направляют к owner-документам, не дублируя весь алгоритм.
  - template даёт audit-friendly поля, которые сложно заполнить без реального review.
- Повторное использование:
  - Один full review-loop подходит для spec review и repository change review.
- Тестируемость:
  - Semantic markers можно проверить через `rg`.
  - Validator/test suite проверяют структуру документов.
- Консистентность:
  - Сохраняются текущие statuses и severity.
  - Новый loop расширяет, но не заменяет формат `2.6.0`.
- Обратная совместимость:
  - Исторические spec-файлы не мигрируются.
  - Новый strict depth contract применяется к будущим `QUEST` review.

## 5. Non-Goals (чего НЕ делаем)
- Не меняем routing matrix и conflict resolution model.
- Не добавляем новый governance-документ.
- Не требуем внешние code review tools или LLM sub-agents.
- Не требуем exhaustive audit для small-задач.
- Не меняем GitHub PR policy, кроме косвенной совместимости с более качественным local review.
- Не меняем validator scripts, если semantic checks достаточно покрывают изменение.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/governance/review-loops.md` -> full review-loop semantics:
  - minimum passes;
  - depth checklist;
  - no-evidence/no-pass rule;
  - re-review after fixes;
  - stop conditions.
- `instructions/core/quest-governance.md` -> `QUEST` quality gate требует full `post-SPEC` / `post-EXEC` review-loop по `review-loops.md`.
- `instructions/core/quest-mode.md` -> запрет завершать `SPEC`/`EXEC`, пока full review-loop не завершён по `review-loops.md`.
- `instructions/core/quest-prompt-spec.md` -> `post-SPEC review` должен быть full loop с adversarial pass и re-review после правок.
- `instructions/core/quest-prompt-exec.md` -> `post-EXEC review` должен быть full loop с diff/evidence inspection, adversarial pass и re-review after fixes.
- `templates/specs/_template.md` -> поля для аудита глубины review.
- `CHANGELOG.md` -> запись `2.7.0`.

### 6.2 Детальный дизайн
- Добавить в `review-loops.md` `MUST`:
  - full review-loop состоит минимум из:
    1. `Scope/Evidence pass`: перечислить spec/diff/files/tests/evidence, которые реально были просмотрены;
    2. `Contract pass`: сверить результат с spec, non-goals, acceptance criteria, owner-documents и validation requirements;
    3. `Adversarial risk pass`: попытаться найти контрпример, скрытую регрессию, пропущенный edge case, неподтверждённый claim, missing test/evidence или поверхностное допущение;
    4. `Fix and re-review`: если внесены исправления по review, повторить relevant passes по затронутой поверхности;
    5. `Stop decision`: `PASS`, `NEEDS-FIX` или `ASK-HUMAN` только после фиксации evidence и остаточных рисков.
  - `PASS` запрещён, если:
    - `Scope reviewed` пустой или общий без конкретных файлов/команд/evidence;
    - `Review passes` не показывает минимум contract pass и adversarial risk pass;
    - `Нет находок` не сопровождается depth checklist;
    - после исправлений не выполнен re-review по затронутым областям;
    - validation evidence отсутствует без объективной причины и next-best check.
  - Для small-задач full review-loop может быть компактным, но должен фиксировать минимум `Scope/Evidence pass`, `Contract pass`, `Adversarial risk pass` и `Stop decision`; `Fix and re-review` обязателен, если review привёл к исправлениям.
- Добавить в template review-блоки:
  - `Review passes`;
  - `Evidence inspected`;
  - `Depth checklist`;
  - `Re-review after fixes`;
  - `No-findings justification`, если findings table содержит `Нет находок`.
  - Минимальный `Depth checklist`:
    - scope drift / unrelated changes;
    - missing или weak acceptance criteria;
    - missing validation или unverified fallback;
    - unsupported factual claims;
    - regression / edge case risk;
    - stale comments/docs/changelog;
    - hidden behavior/API/UX/operational contract change;
    - вопрос: `Что бы я нашёл, если пользователь после моего PASS попросит отдельное ручное ревью?`
- Обновить prompt wrappers:
  - запрещать single-pass review summary;
  - требовать adversarial pass перед `PASS`;
  - требовать повтор review после исправлений.
- Обновить `quest-mode.md`:
  - заменить общий wording `post-* review` на `full post-* review-loop`.
- Output contract / evidence rules:
  - Review блок должен показывать, что именно было проверено и какие вопросы были заданы.
  - Поверхностные формулировки вроде `Проверено, всё ок` невалидны.
  - `Нет находок` допустимо только с конкретным checklist и evidence.
- visual planning artifact для UI-facing изменений: `Не применимо`: меняется governance workflow, не UI приложения.
- UI test video evidence для UI automation задач: `Не применимо`: задача не является UI-facing фичей/багфиксом.
- границы сохранения поведения / допустимые изменения контракта:
  - Усиливается строгость `QUEST` review.
  - Approval phrase и запрет мутаций на SPEC не меняются.
- обработка ошибок:
  - Если невозможно собрать sufficient evidence, статус review `NEEDS-FIX` или `ASK-HUMAN`, не `PASS`.
- производительность:
- Для small-задач full loop может быть компактным, но должен содержать минимум `Scope/Evidence`, `Contract`, `Adversarial risk` и `Stop decision`; `Fix and re-review` выполняется при любых исправлениях по review.

## 7. Бизнес-правила / Алгоритмы (если есть)
Review-loop lifecycle:

| Шаг | Назначение | Minimum evidence |
| --- | --- | --- |
| `Scope/Evidence pass` | Зафиксировать, что реально просмотрено | spec path, file list/diff, test commands/results, relevant owner-documents |
| `Contract pass` | Сверить работу с утверждённым контрактом | acceptance criteria, non-goals, validation requirements, profile fit |
| `Adversarial risk pass` | Найти то, что агент мог пропустить | counterexample questions, edge cases, regression risks, missing evidence |
| `Fix and re-review` | Не завершать после исправлений без повторной проверки | changed areas, rerun commands, remaining findings |
| `Stop decision` | Завершить loop только при проверяемом состоянии | PASS/NEEDS-FIX/ASK-HUMAN with residual risks |

Minimum depth checklist:

| Check | Вопрос |
| --- | --- |
| Scope drift / unrelated changes | Не вышла ли работа за spec, non-goals или unrelated files? |
| Acceptance criteria | Нет ли пропущенных, слабых или непроверяемых acceptance criteria? |
| Validation evidence | Все ли required checks выполнены или fallback объективно объяснён? |
| Unsupported claims | Нет ли factual/performance/security claims без evidence? |
| Regression / edge case | Какой edge case или regression вероятнее всего пропущен? |
| Comments/docs/changelog | Не остались ли stale comments, docs или changelog gaps? |
| Hidden contract change | Нет ли скрытого изменения behavior/API/UX/operations под видом cleanup? |
| Manual-review challenge | Что бы я нашёл, если пользователь после моего `PASS` попросит отдельное ручное ревью? |

Invalid review patterns:

| Pattern | Почему невалидно | Требуемая замена |
| --- | --- | --- |
| `Нет находок` без checklist | Невозможно отличить review от формальности | Добавить depth checklist и evidence inspected |
| Только `git diff --stat` без relevant diff/context | Не проверяет correctness и скрытые риски | Просмотреть relevant diff и owner-contracts |
| Review до исправлений без re-review | Исправление может создать новый дефект | Повторить relevant passes |
| `PASS`, когда проверки не запускались и fallback не объяснён | Нет validation evidence | Указать объективную причину и next-best check или `NEEDS-FIX` |
| Findings без required action | Нельзя проверить закрытие замечания | Указать действие и статус |

## 8. Точки интеграции и триггеры
- `post-SPEC review` запускается после draft spec, linter/rubric и перед запросом подтверждения.
- `post-SPEC review` повторяется, если review изменил scope, acceptance criteria, risks, plan, files table или open questions.
- `post-EXEC review` запускается после реализации и обязательных проверок.
- `post-EXEC review` повторяется после любых исправлений, внесённых по review.
- Prompt wrappers и template должны использовать тот же vocabulary: `Review passes`, `Evidence inspected`, `Depth checklist`, `Re-review after fixes`.

## 9. Изменения модели данных / состояния
- Новых runtime данных нет.
- Persisted artifacts:
  - рабочая spec;
  - изменения Markdown-документов каталога;
  - changelog entry.

## 10. Миграция / Rollout / Rollback
- Rollout:
  - обновить review owner-документ;
  - синхронизировать quality-gate/phase/prompt/template wording;
  - обновить changelog;
  - выполнить validator, validator tests и per-file semantic marker checks.
- Обратная совместимость:
  - старые spec-файлы не мигрируются.
  - новый contract применяется к будущим reviews.
- Rollback:
  - revert изменений в `review-loops.md`, `quest-governance.md`, `quest-mode.md`, prompt wrappers, template и `CHANGELOG.md`;
  - повторить validator и tests.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - `review-loops.md` требует minimum full review-loop passes: `Scope/Evidence`, `Contract`, `Adversarial risk`, `Fix and re-review`, `Stop decision`.
  - `review-loops.md` запрещает `PASS` без concrete scope, evidence, depth checklist и re-review after fixes.
  - `templates/specs/_template.md` содержит fields `Review passes`, `Evidence inspected`, `Depth checklist`, `Re-review after fixes`, `No-findings justification`.
  - `quest-governance.md`, `quest-mode.md`, `quest-prompt-spec.md`, `quest-prompt-exec.md` требуют full review-loop, а не single-pass review summary.
  - `CHANGELOG.md` содержит запись `2.7.0`.
- Какие тесты добавить/изменить:
  - Код validator не менять, если structural checks проходят.
- Characterization tests / contract checks для текущего поведения:
  - Focused semantic check через `rg` по новым markers.
- Visual acceptance для UI-facing изменений: `Не применимо`.
- UI video evidence для UI-facing фич/багфиксов: `Не применимо`.
- Базовые замеры до/после для performance tradeoff: `Не применимо`.
- Команды для проверки:
  ```powershell
  pwsh -File scripts/validate-instructions.ps1
  pwsh -File scripts/test-validate-instructions.ps1
  rg -n "full review-loop" instructions\governance\review-loops.md
  rg -n "Scope/Evidence pass" instructions\governance\review-loops.md
  rg -n "Contract pass" instructions\governance\review-loops.md
  rg -n "Adversarial risk pass" instructions\governance\review-loops.md
  rg -n "Fix and re-review" instructions\governance\review-loops.md
  rg -n "no-evidence/no-pass" instructions\governance\review-loops.md
  rg -n "PASS.*запрещ" instructions\governance\review-loops.md
  rg -n "Review passes" templates\specs\_template.md
  rg -n "Evidence inspected" templates\specs\_template.md
  rg -n "Depth checklist" templates\specs\_template.md
  rg -n "Re-review after fixes" templates\specs\_template.md
  rg -n "No-findings justification" templates\specs\_template.md
  rg -n "Manual-review challenge" templates\specs\_template.md
  rg -n "full .*post-SPEC review-loop" instructions\core\quest-governance.md instructions\core\quest-mode.md
  rg -n "full .*post-EXEC review-loop" instructions\core\quest-governance.md instructions\core\quest-mode.md
  rg -n "full .*post-SPEC review-loop" instructions\core\quest-prompt-spec.md
  rg -n "single-pass review summary" instructions\core\quest-prompt-spec.md instructions\core\quest-prompt-exec.md
  rg -n "Adversarial risk pass" instructions\core\quest-prompt-spec.md instructions\core\quest-prompt-exec.md
  rg -n "Re-review after fixes" instructions\core\quest-prompt-spec.md instructions\core\quest-prompt-exec.md
  rg -n "все findings с однозначным исправлением|Все findings с однозначным исправлением" instructions\core\quest-mode.md instructions\core\quest-prompt-exec.md
  rg -n "## \[2\.7\.0\]" CHANGELOG.md
  ```
- Stop rules для test/retrieval/tool/validation loops:
  - Остановиться, если validator или tests падают.
  - Остановиться, если semantic check не подтверждает все required markers.
  - Остановиться, если implementation ослабляет существующие review statuses/severity.

## 12. Риски и edge cases
- Риск: review станет слишком тяжёлым для small-задач.
  - Смягчение: full loop может быть компактным, но должен включать `Scope/Evidence`, `Contract`, `Adversarial risk` и `Stop decision`.
- Риск: агент будет формально заполнять новые поля.
  - Смягчение: `PASS` запрещён без concrete evidence, no-findings justification и checked questions.
- Риск: слишком много дублирования между `review-loops.md`, `quest-mode.md` и prompt wrappers.
  - Смягчение: полный алгоритм только в `review-loops.md`; остальные документы ссылаются на full loop.
- Риск: `Adversarial risk pass` станет расплывчатым.
  - Смягчение: требовать counterexample questions и конкретные areas: edge cases, missing tests, regressions, unsupported claims, unrelated changes.

## 13. План выполнения
1. Обновить `instructions/governance/review-loops.md`: full review-loop semantics, no-evidence/no-pass rule, re-review after fixes.
2. Обновить `templates/specs/_template.md`: review depth fields.
3. Обновить `instructions/core/quest-governance.md`: mandatory quality gate использует full review-loop.
4. Обновить `instructions/core/quest-mode.md`: phase stop rule для full review-loop.
5. Обновить `instructions/core/quest-prompt-spec.md` и `instructions/core/quest-prompt-exec.md`: запрет single-pass summary, требование adversarial pass и re-review.
6. Обновить `CHANGELOG.md` версией `2.7.0`.
7. Выполнить validator, validator tests и per-file semantic marker checks.
8. Выполнить новый full `post-EXEC review-loop` по собственному контракту.

## 14. Открытые вопросы
Нет блокирующих вопросов.

## 15. Соответствие профилю
- Профиль: `product-system-design`
- Выполненные требования профиля:
  - Цели и non-goals выделены.
  - Целевой workflow contract и границы owner-документов описаны.
  - Публичный contract review-loop зафиксирован.
  - Совместимость с существующим `QUEST` phase gate сохранена.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/governance/review-loops.md` | Full review-loop, no-evidence/no-pass, adversarial pass, re-review after fixes | Owner-документ review semantics |
| `templates/specs/_template.md` | Поля depth/evidence/re-review в review blocks | Новые спеки должны затруднять поверхностный review |
| `instructions/core/quest-governance.md` | Quality gate wording для full review-loop | Обязательность review должна ссылаться на полный loop |
| `instructions/core/quest-mode.md` | Фазовый stop rule для full review-loop | Нельзя завершать phase после формального review summary |
| `instructions/core/quest-prompt-spec.md` | Full post-SPEC review-loop и запрет single-pass summary | Prompt должен вести к реальному review |
| `instructions/core/quest-prompt-exec.md` | Full post-EXEC review-loop, adversarial pass и re-review after fixes | Prompt должен ловить критические недочёты до финального отчёта |
| `CHANGELOG.md` | Добавить `2.7.0` | Значимое изменение governance contract |
| `specs/2026-05-15-review-loop-depth-enforcement.md` | Рабочая spec и audit trail | QUEST trace |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Review semantics | Формат и findings table | Full loop с минимумом проходов |
| `PASS` | Возможен после заполнения блока | Запрещён без scope/evidence/checklist/re-review |
| `Нет находок` | Допустимо как строка в таблице | Требует no-findings justification и depth checklist |
| После исправлений | Повтор проверок упомянут, но loop не формализован | Re-review after fixes обязателен |
| Prompt wrappers | Требуют review | Требуют full review-loop и adversarial pass |

## 18. Альтернативы и компромиссы
- Вариант: оставить текущий формат и просто добавить больше чеклистов.
  - Плюсы: меньше изменений.
  - Минусы: не решает проблему формального `PASS`.
  - Почему выбранное решение лучше в контексте этой задачи: нужен именно loop semantics и stop rules.
- Вариант: требовать внешний reviewer/sub-agent.
  - Плюсы: независимость выше.
  - Минусы: не всегда доступно; системные инструкции запрещают spawn без явного запроса пользователя.
  - Почему выбранное решение лучше в контексте этой задачи: self-contained review-loop работает в любом consumer-репозитории.
- Вариант: сделать review exhaustive для всех задач.
  - Плюсы: выше шанс найти дефекты.
  - Минусы: непропорционально для small changes.
  - Почему выбранное решение лучше в контексте этой задачи: minimum full loop сохраняет глубину без обязательного exhaustive audit.

## 19. Результат quality gate и review
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, goals и non-goals зафиксированы. |
| B. Качество дизайна | 6-10 | PASS | Full review-loop, stop rules, rollout и rollback описаны. |
| C. Безопасность изменений | 11-13 | PASS | Сохраняется `QUEST` gate, исторические spec не мигрируются. |
| D. Проверяемость | 14-16 | PASS | Acceptance criteria, validator commands и semantic check заданы. |
| E. Готовность к автономной реализации | 17-19 | PASS | План и файлы перечислены, блокирующих вопросов нет. |
| F. Соответствие профилю | 20 | PASS | Workflow contract описан как product-system-design artifact. |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Корневая проблема поверхностного review сформулирована явно. |
| 2. Понимание текущего состояния | 5 | AS-IS указывает, почему текущий формат не гарантирует реальный loop. |
| 3. Конкретность целевого дизайна | 5 | Описаны passes, no-pass rules, template fields и affected files. |
| 4. Безопасность (миграция, откат) | 5 | Rollout/rollback и совместимость зафиксированы. |
| 5. Тестируемость | 5 | Есть validator, regression suite и semantic marker checks. |
| 6. Готовность к автономной реализации | 5 | План достаточен, открытых вопросов нет. |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

### Post-SPEC Review
- Статус: PASS
- Scope reviewed: `specs/2026-05-15-review-loop-depth-enforcement.md`, central `catalog-governance` stack, профиль `product-system-design`, planned changed files, user problem statement.
- Decision: можно запрашивать подтверждение.
- Review passes:
  - Scope/Evidence pass: проверены текущая spec, `review-loops.md`, `quest-mode.md`, user problem statement, affected files table и semantic check commands.
  - Contract pass: сверены `QUEST` phase gate, owner boundaries, acceptance criteria, validation commands, non-goals.
  - Adversarial risk pass: искал способы обойти enforcement через слабые semantic checks, compact-loop exception, vague checklist, missing owner-doc updates и формальный self-review block.
  - Fix and re-review: после внесения исправлений повторно проверены affected files table, acceptance criteria, commands, own review block.
  - Stop decision: `PASS`, блокеров нет.
- Evidence inspected:
  - `specs/2026-05-15-review-loop-depth-enforcement.md`
  - `instructions/governance/review-loops.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/quest-mode.md`
  - `instructions/core/quest-prompt-spec.md`
  - `instructions/core/quest-prompt-exec.md`
  - `templates/specs/_template.md`
  - `CHANGELOG.md`
- Depth checklist:
  - Scope drift / unrelated changes: PASS, scope ограничен governance/template/prompt/changelog.
  - Acceptance criteria: PASS, per-file checks и `quest-governance.md` добавлены.
  - Validation evidence: PASS, validator/test/semantic checks описаны.
  - Unsupported claims: PASS, performance/security claims отсутствуют.
  - Regression / edge case: PASS, small-task compact loop больше не ослабляет evidence/stop decision.
  - Comments/docs/changelog: PASS, changelog target `2.7.0` включён.
  - Hidden contract change: PASS, approval phrase и SPEC mutation gate не меняются.
  - Manual-review challenge: проверено, что пользовательский повторный review не должен обнаружить обход через global `rg`, vague checklist или missing `quest-governance`.
- No-findings justification: Не применимо, findings были и исправлены.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | scope | Первичный дизайн мог ограничиться `review-loops.md` и template, не зафиксировав phase stop rule в `quest-mode.md`. | Добавить `quest-mode.md` в affected files и acceptance criteria. | fixed |
| MEDIUM | enforceability | Нужно явно запретить `PASS` без evidence, иначе агент сможет заполнить новые поля формально. | Добавить no-evidence/no-pass rule и no-findings justification. | fixed |
| LOW | proportionality | Full loop может быть тяжёлым для small changes. | Добавить compact full loop allowance без пропуска contract/adversarial passes. | fixed |
| HIGH | validation | Global semantic `rg` мог пройти, даже если markers есть только в changelog/template. | Разбить semantic checks по конкретным target files. | fixed |
| HIGH | proportionality | Compact-loop wording мог позволить пропустить `Scope/Evidence` и `Stop decision`. | Уточнить, что compact loop всё равно фиксирует `Scope/Evidence`, `Contract`, `Adversarial risk`, `Stop decision`; re-review обязателен при fixes. | fixed |
| HIGH | checklist | `Depth checklist` был полем без минимального содержания. | Добавить minimum depth checklist с конкретными вопросами. | fixed |
| MEDIUM | owner scope | `quest-governance.md` не был included, хотя он quality-gate owner. | Добавить `quest-governance.md` в affected files, acceptance criteria и plan. | fixed |
| MEDIUM | dogfooding | Собственный Post-SPEC Review не использовал будущий full-loop формат. | Добавить Review passes, Evidence inspected, Depth checklist, No-findings justification. | fixed |
| HIGH | validation | Semantic checks оставались OR-based и могли пройти по одному marker в target file. | Разделить semantic checks на атомарные per-invariant `rg` команды. | fixed |
| HIGH | phase owner | `quest-mode.md` сохранял weaker wording про исправление только критичных и высокоуверенных проблем. | Выровнять с owner-контрактом: исправлять все findings с однозначным исправлением. | fixed |
| MEDIUM | prompt wrapper | `quest-prompt-exec.md` повторял weaker completion criterion про critical/high-confidence issues. | Обновить success criteria на all unambiguous findings or `ASK-HUMAN`. | fixed |

- Fixed before continuing:
  - Добавлен `quest-mode.md` как affected file.
  - Добавлен no-evidence/no-pass rule.
  - Добавлен compact full loop allowance для small-задач.
  - Добавлен `quest-governance.md` как affected file.
  - Semantic checks разбиты по target files.
  - Semantic checks дополнительно разбиты на атомарные per-invariant команды, чтобы OR-based `rg` не создавал ложный PASS.
  - Добавлен minimum depth checklist и full-loop dogfooding в этом review block.
  - Rollout/rollback и evidence inspected синхронизированы с полным affected file set, включая `quest-governance.md`, prompt wrappers и `CHANGELOG.md`.
- Checks rerun:
  - Manual SPEC linter/rubric impact check: результат остаётся `ГОТОВО`, `30/30`.
- Needs human:
  - Нет.
- Residual risks / follow-ups:
  - Нет обязательных.

### Post-EXEC Review
- Статус: PASS
- Scope reviewed: approved spec `specs/2026-05-15-review-loop-depth-enforcement.md`, `git status --short`, `git diff --stat`, relevant diff for `review-loops.md`, `quest-governance.md`, `quest-mode.md`, prompt wrappers, canonical spec template, `CHANGELOG.md`, validation evidence.
- Decision: можно завершать.
- Review passes:
  - Scope/Evidence pass: проверены approved spec, changed file list, diff stat, relevant diff, validator/test outputs и per-file semantic checks.
  - Contract pass: сверены acceptance criteria, non-goals, affected files table, no-evidence/no-pass rule, per-file semantic checks и changelog target `2.7.0`.
  - Adversarial risk pass: искал способы сохранить single-pass loophole через старые `post-* review` формулировки, global marker checks, vague template fields, missing `quest-governance`, missing validation evidence и untracked spec invisibility in `git diff --stat`.
  - Fix and re-review: после исправления legacy `post-* review` wording повторены validator, validator tests и per-file semantic checks.
  - Stop decision: `PASS`, блокеров нет.
- Evidence inspected:
  - `git status --short`
  - `git diff --stat`
  - relevant diff for all approved files
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - per-file semantic marker checks from section 11
- Depth checklist:
  - Scope drift / unrelated changes: PASS, `git status --short` содержит только approved files и текущую working spec.
  - Acceptance criteria: PASS, all target files contain required full-loop markers.
  - Validation evidence: PASS, validator, regression suite and per-file semantic checks passed after review-fix.
  - Unsupported claims: PASS, no performance/security claims added.
  - Regression / edge case: PASS, small-task compact loop still requires `Scope/Evidence`, `Contract`, `Adversarial risk`, `Stop decision`.
  - Comments/docs/changelog: PASS, changelog `2.7.0` added; no code comments affected.
  - Hidden contract change: PASS, approval phrase and SPEC mutation gate unchanged.
  - Manual-review challenge: checked old `post-* review` wording and global-marker loophole; one wording loophole was found and fixed before final.
- No-findings justification: Не применимо, findings были и исправлены.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | single-pass loophole | В `review-loops.md` после первичной реализации оставались старые формулировки `post-SPEC review` / `post-EXEC review`, которые могли поддержать single-pass трактовку. | Заменить обязательный workflow wording на full `post-SPEC review-loop` / full `post-EXEC review-loop` и повторить проверки. | fixed |
| LOW | evidence | `git diff --stat` не показывает untracked working spec, поэтому по нему одному можно пропустить audit artifact. | Использовать `git status --short` в reviewed scope и финальном отчёте. | fixed |
| HIGH | validation | Semantic checks in spec were still OR-based and could pass with only one marker. | Split checks into atomic per-invariant commands and rerun relevant checks. | fixed |
| HIGH | phase owner | `quest-mode.md` still said to fix only critical/high-confidence issues. | Align phase owner to fix all findings with an unambiguous fix. | fixed |
| MEDIUM | prompt wrapper | `quest-prompt-exec.md` repeated the weaker critical/high-confidence success criterion. | Align prompt success criteria to all unambiguous findings or `ASK-HUMAN`. | fixed |

- Fixed before final report:
  - Legacy wording in `review-loops.md` changed to full `post-SPEC review-loop` / full `post-EXEC review-loop`.
  - `quest-prompt-exec.md` choice wording changed to full `post-EXEC review-loop`.
  - `quest-mode.md` and `quest-prompt-exec.md` now require resolving all findings with an unambiguous fix.
  - Semantic checks in the spec are now atomic per invariant.
- Checks rerun after latest fixes:
  - `pwsh -File scripts/validate-instructions.ps1` -> PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1` -> PASS.
  - Atomic per-invariant semantic checks from section 11 -> PASS.
- Checks rerun:
  - `pwsh -File scripts/validate-instructions.ps1` -> PASS.
  - `pwsh -File scripts/test-validate-instructions.ps1` -> PASS.
  - `rg -n "full review-loop|Scope/Evidence pass|Contract pass|Adversarial risk pass|Fix and re-review|no-evidence|PASS.*запрещ" instructions\governance\review-loops.md` -> PASS.
  - `rg -n "Review passes|Evidence inspected|Depth checklist|Re-review after fixes|No-findings justification|Manual-review challenge" templates\specs\_template.md` -> PASS.
  - `rg -n "full review-loop|post-SPEC|post-EXEC" instructions\core\quest-governance.md instructions\core\quest-mode.md` -> PASS.
  - `rg -n "full review-loop|single-pass|Adversarial risk pass|Re-review after fixes" instructions\core\quest-prompt-spec.md instructions\core\quest-prompt-exec.md` -> PASS.
  - Atomic per-invariant semantic checks from section 11 -> PASS.
  - `rg -n "## \[2\.7\.0\]" CHANGELOG.md` -> PASS.
- Validation evidence:
  - Validator, validator regression suite and per-file semantic checks passed after review-fix.
- Unrelated changes:
  - Нет. `git status --short` shows only files in approved spec scope plus this working spec.
- Needs human:
  - Нет.
- Residual risks / follow-ups:
  - Нет обязательных.

## Approval
Ожидается фраза: "Спеку подтверждаю"

## 20. Журнал действий агента
Заполняется инкрементально после каждого значимого блока работ. Одна строка = один завершённый значимый блок.

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Сбор instruction stack и анализ проблемы | 0.96 | Нет | Подготовить рабочую spec | Нет | Нет | Задача меняет governance-инструкции, поэтому применён `catalog-governance` stack с QUEST gate. | `AGENTS.md`, `instructions/governance/routing-matrix.md`, `instructions/core/*`, `instructions/governance/review-loops.md`, `templates/specs/_template.md` |
| SPEC | Черновик, quality gate и post-SPEC review | 0.97 | Нет | Запросить подтверждение пользователя | Да | Да, ожидается подтверждение `Спеку подтверждаю` | Spec задаёт full review-loop semantics, no-pass rules, re-review after fixes и проверяемые markers без изменения файлов вне `specs/`. | `specs/2026-05-15-review-loop-depth-enforcement.md` |
| SPEC | Исправление review-находок и повторное ревью | 0.98 | Нет | Запросить подтверждение пользователя | Да | Да: пользователь попросил внести исправления и сделать повторное ревью | Закрыты риски обхода через global semantic check, compact loop, vague checklist, missing `quest-governance` и поверхностный self-review; Post-SPEC Review переписан в full-loop формате. | `specs/2026-05-15-review-loop-depth-enforcement.md` |
| EXEC | Реализация full review-loop enforcement | 0.96 | Нет | Запустить validator, regression tests и per-file semantic checks | Нет | Да: пользователь подтвердил spec | Обновлены review owner contract, QUEST governance/mode, prompt wrappers, canonical spec template и changelog в границах утверждённой spec. | `instructions/governance/review-loops.md`, `instructions/core/quest-governance.md`, `instructions/core/quest-mode.md`, `instructions/core/quest-prompt-spec.md`, `instructions/core/quest-prompt-exec.md`, `templates/specs/_template.md`, `CHANGELOG.md`, `specs/2026-05-15-review-loop-depth-enforcement.md` |
| EXEC | Full post-EXEC review-loop и review-fix | 0.98 | Нет | Завершить отчёт пользователю | Нет | Нет | Full review-loop нашёл и закрыл legacy wording loophole, затем validator, regression suite и per-file semantic checks были повторены и прошли. | `instructions/governance/review-loops.md`, `instructions/core/quest-prompt-exec.md`, `specs/2026-05-15-review-loop-depth-enforcement.md`, `scripts/validate-instructions.ps1`, `scripts/test-validate-instructions.ps1` |
| EXEC | Исправление повторного review | 0.98 | Нет | Повторить проверки и завершить отчёт | Нет | Да: пользователь попросил исправить review findings | Закрыты OR-based semantic checks и weaker wording в phase owner/prompt wrapper, чтобы full review-loop не оставлял clear findings нерешёнными. | `instructions/core/quest-mode.md`, `instructions/core/quest-prompt-exec.md`, `specs/2026-05-15-review-loop-depth-enforcement.md` |
