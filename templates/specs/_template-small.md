# <Короткое название изменения>

## Цель и границы

- Metadata: owner, profile, short eligibility по quest-governance, связанные источники.
- AS-IS / проблема → наблюдаемый outcome; Non-Goals / ограничения.
- Effective runtime: если влияет на результат; иначе причина неприменимости.

## Результат, решения и проверки

| Observable scenario / решение (owner) | AC / ожидаемый результат | Команда / evidence |
| --- | --- | --- |
| <триггер пользователя, выбранное решение> | <проверяемый outcome> | <реальная проверка> |

- Изменяемые файлы / ответственность, интеграция, ошибки и rollback.
- Риск / likely user objection и его устранение; открытые вопросы (если блокируют — сначала решить).
- Plan / stop rules; для изменяемых instructions/prompts — before/after behavioral smoke на одинаковом runtime.

## Quality gate и review

- Linter: критерии 1..20 по spec-linter с пояснением, допускается общая таблица для связанных сведений.
- Rubric: шесть оценок 0/2/5 и обоснование; критичные gates не заменяются суммой.
- Post-SPEC: scope/evidence, contract, adversarial/role passes, findings/fixes, re-review, stop decision по review-loops.
- Post-EXEC: тот же review contract плюс observed outcome, AC evidence и незакрытые objections; до EXEC — «Не выполнен».
- Для ролей фиксировать применимость и verdict; неприменимость объяснять. Подробности одного evidence не дублировать между блоками.

## Approval

Ожидается «Спеку подтверждаю». Фазовые правила — central quest-mode.

## Журнал действий агента

| Фаза / блок | Решение / уверенность | Evidence / что неизвестно | Следующий шаг | Передача человеку / фактическое решение |
| --- | --- | --- | --- | --- |
| SPEC | <0..1> | <проверенный факт> | <действие> | <ожидается / получено> |
