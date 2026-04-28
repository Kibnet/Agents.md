# Core: Model Behavior Baseline

## Когда применять

- Всегда как часть central instruction stack для этого каталога.
- Для задач, где агент формулирует план, выполняет инструменты, пишет итоговый ответ, проектирует prompt/workflow или обновляет инструкции.
- Для потребительских репозиториев, которые подключают этот каталог и используют целевую модель `gpt-5.5`.

## Когда не применять

- Как замену `QUEST`, testing, safety, governance или профильным owner-документам.
- Если будущая версия центрального каталога отдельным versioned изменением сменила целевую модель и обновила этот owner-документ.

## MUST

- Считать `gpt-5.5` целевой моделью каталога до отдельного versioned изменения этого owner-документа.
- Формулировать задачи outcome-first: цель, критерии успеха, ограничения, доступный контекст, ожидаемый результат и условия остановки.
- Сохранять пошаговый процесс только там, где точный путь является инвариантом workflow, безопасности, допустимых мутаций, валидации, compliance или внешних side effects.
- Использовать `MUST` / `NEVER` только для истинных инвариантов; для judgement calls задавать условия выбора, например когда искать, спрашивать пользователя, продолжать цикл или остановиться.
- Для multi-step или tool-heavy задач давать короткий user-visible preamble перед инструментами и краткие progress updates при долгой работе.
- Для retrieval, tool и validation loops задавать stop rules: продолжать только если не хватает обязательного факта, проверки, evidence, side-effect confirmation или явно запрошенного exhaustive coverage.
- После изменений запускать наиболее релевантную доступную проверку; если проверку нельзя выполнить, явно указать причину и next-best check.
- Не добавлять current date в центральные инструкции без business-specific причины: timezone, policy-effective date, локальная дата пользователя или другой не-UTC контекст.
- При проектировании Responses workflows учитывать `phase` preservation, если приложение вручную replayed assistant output items вместо `previous_response_id`.

## SHOULD

- Начинать настройку агентских workflow с `reasoning.effort=medium`; для latency-sensitive задач оценивать `low` перед повышением effort, а `high` / `xhigh` применять только при измеримой пользе или повышенном риске.
- Управлять длиной через `text.verbosity`, word budgets, section limits и output contract; не смешивать краткость финального ответа с глубиной reasoning.
- Для factual и retrieval задач заранее определять, какие claims требуют evidence, что считается minimum sufficient evidence и когда отсутствие evidence означает неопределённость, а не отрицательный факт.
- Для tool-heavy workflows держать tool-specific guidance в описаниях инструментов, а в системных инструкциях оставлять только общие policy, side-effect и retry rules.
- Для frontend, visual и generated artifact задач рендерить или инспектировать результат доступными инструментами перед завершением.
- Сохранять стабильные части prompt/context раньше динамических данных, чтобы не ухудшать prompt caching в API-интеграциях.

## MAY

- Использовать компактные блоки `Goal`, `Success criteria`, `Constraints`, `Output`, `Stop rules` для сложных prompt/workflow artifacts.
- Снижать `text.verbosity` до `low`, если продукту нужен короткий ответ и это не удаляет обязательные evidence, reasoning summary или completion checks.
- Добавлять domain-specific validation budget, если workflow дорогой и full validation не нужна на каждом шаге.

## Команды

```powershell
# Поиск модельного baseline и GPT-5.5 contract markers
rg -n "model-behavior-baseline|GPT-5\\.5|gpt-5\\.5|outcome-first|Stop rules|reasoning\\.effort|text\\.verbosity|phase" AGENTS.md README.md instructions templates
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
- [instructions/core/collaboration-baseline.md](./collaboration-baseline.md)
- [instructions/core/quest-mode.md](./quest-mode.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
