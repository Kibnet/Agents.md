# Core: Model Behavior Baseline

## Когда применять

- Всегда как часть central instruction stack для этого каталога.
- Для задач, где агент формулирует план, выполняет инструменты, пишет итоговый ответ, проектирует prompt/workflow или обновляет инструкции.
- Для consumer-репозиториев, оптимизирующих workflow под семейство моделей `GPT-5.6`.

## Когда не применять

- Как замену `QUEST`, testing, safety, governance или профильным owner-документам.
- Как wire-level контракт для OpenAI Responses API: для него применять `instructions/governance/openai-responses-api.md` по триггеру.
- Как утверждение, что `GPT-5.6` доступна в любой поверхности, тарифе или текущем runtime.

## MUST

- Считать семейство `GPT-5.6` целевой optimization baseline каталога до отдельного versioned изменения этого owner-документа.
- Разделять целевую модель каталога и фактический runtime: фиксировать поверхность (`standard ChatGPT`, `Work/Codex`, `OpenAI API` или другая), реально выбранный model/tier, reasoning level и fallback, если они влияют на результат или validation evidence.
- Не переносить model alias, tier name, reasoning control, Pro/Ultra semantics или доступность из одной поверхности в другую без проверки текущей документации и фактической среды.
- Выбирать уровень модели по форме workload: `Sol` для сложной reasoning/coding работы, `Terra` для баланса capability/cost и `Luna` для cost-sensitive high-volume задач; не повышать tier, effort, Pro или Ultra без риска либо измеримого выигрыша.
- Если рекомендуемый tier недоступен, выбирать наиболее близкий доступный fallback, фиксировать effective runtime и не приписывать результат недоступной модели.
- Формулировать задачи outcome-first: цель, критерии успеха, ограничения, доступный контекст, ожидаемый результат и условия остановки.
- Сохранять пошаговый процесс только там, где точный путь является инвариантом workflow, безопасности, допустимых мутаций, валидации, compliance или внешних side effects.
- Использовать `MUST` / `NEVER` только для истинных инвариантов; для judgement calls задавать условия выбора.
- Держать prompts lean: не дублировать правила owner-документов, не перечислять очевидные шаги, которые модель может вывести из цели, и удалять повторение только после проверки behavioral regression.
- Для retrieval, tool и validation loops задавать stop rules: продолжать только если не хватает обязательного факта, проверки, evidence, side-effect confirmation или явно запрошенного exhaustive coverage.
- После изменений запускать наиболее релевантную доступную проверку; если проверку нельзя выполнить, явно указывать причину и next-best check.
- Не сокращать final answer так, чтобы исчезли обязательный outcome, validation evidence, ограничения, residual risks или следующий шаг.
- Для задач, которые меняют UI layout, визуальное состояние, навигационный flow, feedback/error/success state или другое UI-facing поведение, на этапе планирования/SPEC фиксировать visual planning artifact до реализации: wireframe, annotated screenshot, storyboard, lightweight render/mockup или другой доступный render, показывающий целевую структуру экрана и ключевые состояния/переходы. Артефакт должен быть доступен reviewer в spec, PR, repo-relative path или приложении; local-only evidence нужно явно помечать. Если артефакт недоступен или непропорционален, явно указать `Не применимо` и дать текстовую fallback-схему layout/states. Copy-only изменения без влияния на layout, flow, state или visual acceptance не требуют visual artifact.
- Не добавлять current date в центральные инструкции без business-specific причины: timezone, policy-effective date, локальная дата пользователя или другой не-UTC контекст.

## SHOULD

- На product surfaces начинать с доступного default reasoning level; для прямого API-вызова `GPT-5.6` использовать `medium` как balanced baseline, затем сравнивать тот же уровень и один уровень ниже на репрезентативных задачах.
- Управлять длиной через output contract, word budgets и section limits; не смешивать краткость финального ответа с глубиной reasoning.
- Для factual и retrieval задач заранее определять, какие claims требуют evidence, что считается minimum sufficient evidence и когда отсутствие evidence означает неопределённость, а не отрицательный факт.
- Для tool-heavy workflows держать tool-specific guidance в описаниях инструментов, а в системных инструкциях оставлять только общие policy, authorization, side-effect и retry rules.
- Для visual planning artifact выбирать минимальную достаточную fidelity; для frontend, visual и generated artifact задач рендерить или инспектировать результат доступными инструментами перед завершением.
- Сохранять стабильные части prompt/context раньше динамических данных, чтобы не ухудшать prompt caching в API-интеграциях.
- Сравнивать tiers, reasoning levels, Pro или Ultra только на representative eval set с метриками качества, полноты, latency, token usage и cost; cross-tier benchmark не является обязательным для каждой обычной задачи.

## MAY

- Использовать компактные блоки `Goal`, `Success criteria`, `Constraints`, `Output`, `Stop rules` для сложных prompt/workflow artifacts.
- Снижать verbosity, если продукту нужен короткий ответ и это не удаляет обязательные evidence, reasoning summary или completion checks.
- Добавлять domain-specific validation budget, если workflow дорогой и full validation не нужна на каждом шаге.

## Команды

```powershell
# Поиск target markers, surface contract и API owner
rg -n "GPT-5\.6|gpt-5\.6|Surface Contract|openai-responses-api|reasoning|Pro|Ultra" AGENTS.md README.md instructions templates
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
- [instructions/governance/openai-responses-api.md](../governance/openai-responses-api.md)
- [instructions/core/collaboration-baseline.md](./collaboration-baseline.md)
- [instructions/core/quest-mode.md](./quest-mode.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
