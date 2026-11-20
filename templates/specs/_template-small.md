# <Короткое название изменения>

Имена owner-документов в этой SPEC разрешаются от корня центрального каталога текущего instruction stack, а не от каталога локальной SPEC: `routing-matrix` — `instructions/governance/routing-matrix.md`, `quest-mode` — `instructions/core/quest-mode.md`, `model-behavior-baseline` — `instructions/core/model-behavior-baseline.md`.

## Контекст

- Metadata: owner, применимые profiles/contexts по `routing-matrix`, short eligibility по quest-governance, связанные источники.
- Планировочные вложения (если нужны): путь/назначение по `quest-mode`; встроенная схема допустима по `model-behavior-baseline`.
- Effective runtime и before/after behavioral smoke: если меняется semantic instruction/prompt contract; для других задач — когда влияет на результат.

## Пять содержательных проверок

| Проверка | Решение / ожидаемый результат | План проверки → фактическое evidence |
| --- | --- | --- |
| 1. Результат / границы | Исходное поручение, AS-IS и пользовательский сценарий; outcome и Non-Goals; при существенном различии — референс, база реализации и место поставки | Обычный пользовательский путь; изменяемые файлы / ответственность |
| 2. Решения / разрешения | Выбранные решения, оставшиеся существенные вопросы, уже разрешённый scope | Основание выбора; exact approval ниже |
| 3. AC→evidence | Обязательные AC, независимое основание ожидаемого результата и выбранный набор проверок по model-behavior-baseline/testing-baseline | Команды / визуальная проверка / артефакт; до EXEC — план, после — фактический результат |
| 4. Существенный риск / rollback | Вероятный дефект или user objection; безопасный откат | Counterexample / проверка; неприменимость с причиной |
| 5. Findings / disposition / stop | Что реально проверено, findings/fixes либо обоснованное «Нет находок»; остаток | Затронутые повторные проверки и stop decision по review-loops |

Одна таблица покрывает содержательные linter и review критерии; 20 отдельных оценок, числовой rubric, раздельные passes и неприменимые роли не нужны. Если появляется риск вне short eligibility, перейти к expanded по quest-governance. Обязательные AC/authorization/validation условия не заменяются residual risk.

## Quality gate и review

- Post-SPEC: один компактный evidence-based pass по таблице выше; PASS / NEEDS-FIX / ASK-HUMAN и проверяемое основание. Все обязательные условия текущей фазы соблюдены; scope/finding dispositions — по review-loops.
- Post-EXEC: до EXEC — «Не выполнен». После — один компактный pass по той же таблице: исходный пользовательский сценарий, фактическое evidence, findings/disposition/stop. Ссылаться на результаты без повторного пересказа.

## Approval

Ожидается «Спеку подтверждаю». Фазовые правила — central quest-mode.

## Журнал действий агента

Обновлять при переходе фазы, существенном решении, blocker и завершении; рутинные tool calls и проверки отдельно не протоколировать.

| Фаза / событие | Решение | Evidence / остаток | Следующий шаг | Фактическое решение человека, если требовалось |
| --- | --- | --- | --- | --- |
| SPEC | <выбранное решение> | <проверенный факт / неизвестное> | <действие> | <ожидается / получено / не требовалось> |
