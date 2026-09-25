# Core: Model Behavior Baseline

## Когда применять

- Всегда как часть central instruction stack для этого каталога.
- Для задач, где агент формулирует план, выполняет инструменты, пишет итоговый ответ, проектирует prompt/workflow или обновляет инструкции.
- Для consumer-репозиториев, оптимизирующих workflow под семейство `GPT-6` с `GPT-6 Astra` как behavior baseline и с сохранением явно закреплённых workload-ролей `GPT-5.6`.

## Когда не применять

- Как замену `QUEST`, testing, safety, governance или профильным owner-документам.
- Как wire-level контракт для OpenAI Responses API: для него применять `instructions/governance/openai-responses-api.md` по триггеру.
- Как утверждение, что `GPT-6 Astra` доступна в любой поверхности, тарифе или текущем runtime.

## MUST

- Считать `GPT-6 Astra` целевой optimization baseline каталога до отдельного versioned изменения этого owner-документа.
- Разделять целевую модель каталога и фактический runtime: фиксировать поверхность (`standard ChatGPT`, `Work/Codex`, `OpenAI API` или другая), реально выбранный model/tier, reasoning level и fallback, если они влияют на результат или validation evidence.
- Не переносить model alias, tier name, reasoning control, Pro/Ultra semantics или доступность из одной поверхности в другую без проверки текущей документации и фактической среды.
- Сохранять явный выбор модели пользователем; целевой baseline не разрешает менять настройки текущего продукта или все fallback-модели. Для разрешённого model selection в семействе GPT-6 учитывать workload: `Astra` для сложной сквозной работы и высокой цены ошибки, `Sol` для сложной повседневной работы с балансом качества, времени и стоимости, `Luna` для ограниченных повторяемых задач с проверяемым выходом. Явные pins `GPT-5.6 Sol/Terra/Luna` сохранять как legacy workload choices; не изобретать `GPT-6 Terra` и не заменять pin одной рекомендацией. Не повышать tier, effort, Pro или Ultra без риска либо измеримого выигрыша.
- Если рекомендуемый tier недоступен, выбирать наиболее близкий доступный fallback, фиксировать effective runtime и не приписывать результат недоступной модели.
- Формулировать задачи outcome-first: цель, критерии успеха, ограничения, доступный контекст, ожидаемый результат и условия остановки.
- Сохранять пошаговый процесс только там, где точный путь является инвариантом workflow, безопасности, допустимых мутаций, валидации, compliance или внешних side effects.
- Использовать `MUST` / `NEVER` только для истинных инвариантов; для judgement calls задавать условия выбора.
- Держать prompts lean: не дублировать правила owner-документов, не перечислять очевидные шаги, которые модель может вывести из цели, и удалять повторение только после проверки behavioral regression.
- Для retrieval, tool и validation loops задавать stop rules: продолжать только если не хватает обязательного факта, проверки, evidence, side-effect confirmation или явно запрошенного exhaustive coverage.
- После изменений запускать релевантные и все обязательные проверки по `testing-baseline`; если проверку нельзя выполнить, явно указывать причину и next-best check. Общий stop rule не отменяет mandatory suite или behavioral smoke.
- Не сокращать final answer так, чтобы исчезли обязательный outcome, validation evidence, ограничения, residual risks или следующий шаг.
- Подтверждать исходный пользовательский сценарий и обычный путь использования: тест отдельного свойства, специальная диагностическая сборка или последний исправленный экран не доказывают готовность всей обещанной функции. Если обычная сборка/запуск не проверены, сообщать точную границу evidence.
- Визуальным evidence считать только просмотренное изображение нужного состояния актуального артефакта. Закрытая панель не доказывает исправность открытого фильтра; неподходящий кадр отклонить и получить нужное состояние. При требовании сходства с референсом выделить сохраняемые признаки и сравнить результат в сопоставимом масштабе/состоянии.
- Различать «сохранено», «собрано», «установлено», «активно» и «проверено после перезапуска»; каждое утверждение требует собственного наблюдения. Не приписывать persistence по одному факту записи настройки.
- При массовой работе отдельно отражать найденные, классифицированные, контекстно проверенные и содержательно продвинутые элементы. Полнота охвата не требует одинакового документа на каждый элемент; полезность определяется конкретным результатом для пользователя. Сохранять его согласованную стратегию продвижения нескольких целей, не подменять её выбором одной цели или числом карточек.
- Для задач, которые меняют UI layout, визуальное состояние, навигационный flow, feedback/error/success state или другое UI-facing поведение, на этапе планирования/SPEC фиксировать visual planning artifact до реализации: wireframe, annotated screenshot, storyboard, lightweight render/mockup или другой доступный render, показывающий целевую структуру экрана и ключевые состояния/переходы. Артефакт должен быть доступен reviewer в spec, PR, repo-relative path или приложении; local-only evidence нужно явно помечать. Если артефакт недоступен или непропорционален, явно указать `Не применимо` и дать текстовую fallback-схему layout/states. Copy-only изменения без влияния на layout, flow, state или visual acceptance не требуют visual artifact.
- Не добавлять current date в центральные инструкции без business-specific причины: timezone, policy-effective date, локальная дата пользователя или другой не-UTC контекст.

## SHOULD

- На product surfaces начинать с доступного default reasoning level. При API-миграции сохранять effective effort, если выбранная модель его поддерживает: для Astra `none` заменять стартовым `low`, для любой GPT-6 модели `minimal` заменять стартовым `low`; Sol и Luna поддерживают `none`. Проверять точный контракт по API owner. Если baseline отсутствует, `medium` допустим как локальная стартовая эвристика, а не универсальное требование OpenAI; сравнивать варианты на репрезентативных задачах.
- Управлять длиной через output contract, word budgets и section limits; не смешивать краткость финального ответа с глубиной reasoning.
- По умолчанию писать краткими связными абзацами: главный результат в начале, простые слова и конкретные глаголы. Использовать списки и таблицы для параллельных пунктов, последовательностей и сравнения; не добавлять шаблонные заключения, выдуманный жаргон и лишние противопоставления. Required templates и exact-output requests имеют приоритет над стилевым default, а evidence и существенные ограничения сохраняются.
- Для factual и retrieval задач заранее определять, какие claims требуют evidence, что считается minimum sufficient evidence и когда отсутствие evidence означает неопределённость, а не отрицательный факт.
- Для tool-heavy workflows держать tool-specific guidance в описаниях инструментов, а в системных инструкциях оставлять только общие policy, authorization, side-effect и retry rules.
- Для visual planning artifact выбирать минимальную достаточную fidelity; для frontend, visual и generated artifact задач рендерить или инспектировать результат доступными инструментами перед завершением.
- Сохранять стабильные части prompt/context раньше динамических данных, чтобы не ухудшать prompt caching в API-интеграциях.
- Сравнивать tiers, reasoning levels, Pro или Ultra только на representative eval set с метриками качества, полноты, latency, token usage и cost per successful task, включая повторные исправления и интеграцию результата; цена токена сама по себе не доказывает экономию. Cross-tier benchmark не является обязательным для каждой обычной задачи.

## MAY

- Использовать компактные блоки `Goal`, `Success criteria`, `Constraints`, `Output`, `Stop rules` для сложных prompt/workflow artifacts.
- Снижать verbosity, если продукту нужен короткий ответ и это не удаляет обязательные evidence, reasoning summary или completion checks.
- Добавлять domain-specific validation budget, если workflow дорогой и full validation не нужна на каждом шаге.

## Команды

```powershell
# Поиск target markers, surface contract и API owner
rg -n "GPT-6 (Astra|Sol|Luna)|gpt-6-(astra|sol|luna)|GPT-5\.6|gpt-5\.6|Surface Contract|openai-responses-api|reasoning|Pro|Ultra" AGENTS.md README.md instructions templates
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/governance/routing-matrix.md](../governance/routing-matrix.md)
- [instructions/governance/openai-responses-api.md](../governance/openai-responses-api.md)
- [instructions/core/collaboration-baseline.md](./collaboration-baseline.md)
- [instructions/core/testing-baseline.md](./testing-baseline.md)
- [instructions/core/quest-mode.md](./quest-mode.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
- [templates/specs/_template.md](../../templates/specs/_template.md)
- [OpenAI: Using GPT-6 Astra — prompting и migration](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra)
- [OpenAI: Models в Codex и ChatGPT Work](https://learn.chatgpt.com/docs/models)
