# Governance: Model Surface Reference

## Когда применять

- При выборе/миграции модели, reasoning или speed tier, проверке product availability либо пересмотре исторических model evals.
- Не загружать для обычной задачи только потому, что агент использует модель; постоянный behavior contract остаётся в model-behavior-baseline.

## MUST

- Считать раздел «Исторический снимок» выдержкой из прежнего каталога, а не подтверждением текущей доступности, цены, API contract или runtime. Перед выбором модели или настроек проверить актуальные официальные источники для конкретной поверхности, account/workspace и фактические effective metadata; сохранить источник и дату проверки в evidence задачи.
- Не выводить полномочие менять настройки или запускать другую модель из справочных сведений; границы определяет model-behavior-baseline. Wire-level API contract принадлежит openai-responses-api.
- Отличать скорость output tokens от времени всей задачи, учитывать стоимость и residency при разрешённом speed selection. Старый text smoke не доказывает vision capability; пересмотр eval требует проверки затронутого сценария на actual runtime.

## Выбор модели в Codex и ChatGPT Work

Для задач без явно закреплённой модели сначала проверьте, что выбранная модель есть в фактическом списке клиента. Доступность в App, CLI и IDE зависит от клиента, способа входа, плана и политики workspace.

| Модель | Когда рекомендовать |
| --- | --- |
| `GPT-6.2 Sol` | Повседневная разработка, ревью и обычная многошаговая работа. |
| `GPT-6.2 Astra` | Сложная сквозная работа, диагностика нескольких систем или высокая цена ошибки. |
| `GPT-6.1 Terra` | Визуальный анализ, интерпретация скриншотов и работа в приложениях через computer use. |
| `GPT-6.1 Sol` | Проверенные длительные задачи и совместимые клиенты, где 6.2 недоступна. |
| `GPT-6 Astra` | Сложная работа, если 6.2 Astra недоступна в текущем клиенте. |
| `GPT-6 Luna` | Ограниченные повторяемые задачи с проверяемым результатом. |

Для перехода с прежней модели сверяйте её статус и доступные замены для конкретного клиента. Рассматривайте Standard, Fast и Ultrafast по продуктовым источникам ниже.

## Исторический снимок

Источник: содержимое model-behavior-baseline в Git baseline `9eec83237f86f4c02a903a6f6e3b09b59a68bb1c`, выделенное 12 ноября 2026. Это дата переноса, а не свежей проверки первоисточников. Утверждения о rollout/исправлениях ниже относятся к указанным историческим датам; даже прежние названия и ограничения моделей не следует переносить на текущую среду без проверки. Следующие цитаты сохраняют прежние рекомендации для объяснения старых решений, а не задают действующие defaults.

> Сохранять явный выбор модели пользователем; целевой baseline не разрешает менять настройки текущего продукта или все fallback-модели. Для разрешённого model selection в семействе GPT-6 учитывать workload: `Astra` для сложной сквозной работы и высокой цены ошибки, `GPT-6.1 Sol` при доступности для сложной повседневной и длительной работы с балансом качества, времени и стоимости; прежний `GPT-6 Sol` остаётся отдельной моделью с собственным API contract, `Luna` для ограниченных повторяемых задач с проверяемым выходом. Явные pins `GPT-5.6 Sol/Terra/Luna` сохранять как legacy workload choices; не изобретать `GPT-6 Terra` и не заменять pin одной рекомендацией. Не повышать tier, effort, Pro или Ultra без риска либо измеримого выигрыша.

> На product surfaces начинать с доступного default reasoning level. При API-миграции сохранять effective effort, если выбранная модель его поддерживает: для Astra и GPT-6.1 Sol `none` заменять стартовым `low`, для любой GPT-6 модели `minimal` заменять стартовым `low`; прежний GPT-6 Sol и Luna поддерживают `none`. Проверять точный контракт по API owner. Если baseline отсутствует, `medium` допустим как локальная стартовая эвристика, а не универсальное требование OpenAI; сравнивать варианты на репрезентативных задачах.

> В Work/Codex рекомендовать GPT-6.1 Sol только при доступности account/client/workspace; новая рекомендация не заменяет explicit pin. Launch rollout включает Plus/Pro/Business/Enterprise/Edu; Free/Go не включены, в Enterprise/Edu модель по умолчанию выключена и требует admin enablement по [product Models](https://learn.chatgpt.com/docs/models). GPT-5.5 прекращает доступность в ChatGPT/Work/Codex при ChatGPT sign-in 14 октября 2026; это не retirement модели из OpenAI API. Проверять поверхность, способ входа и поддерживаемый replacement до изменения config.

> Для speed selection различать API и product доступность Standard/Fast/Ultrafast; ускорение output tokens не гарантирует такое же ускорение всей задачи. Повышать speed tier только при оправданной стоимости и совместимой residency. На Work/Codex Astra Ultrafast подтверждён для Pro $500 и eligible Enterprise/Edu; launch GPT-6.1 Sol поддерживает Standard/Fast, Ultrafast объявлен на позднейшую дату. Перед изменением settings сверять доступность плана и workspace по [product Speed](https://learn.chatgpt.com/docs/agent-configuration/speed).

> Для visual evals прежнего GPT-6 Sol/Luna учитывать upstream image-encoding fix 25 сентября 2026: пересматривать старые failure conclusions и повторять затронутые проверки на actual runtime. Исторический Astra text smoke не является vision evidence.

## Связанные документы

- [Постоянный behavior contract](../core/model-behavior-baseline.md)
- [API owner](./openai-responses-api.md)
- [Routing](./routing-matrix.md)
- [OpenAI: выбор модели](https://learn.chatgpt.com/docs/model-selection)
- [Официальные product Models](https://learn.chatgpt.com/docs/models)
- [Официальные product Speed](https://learn.chatgpt.com/docs/agent-configuration/speed)
- [Официальный API model guide](https://developers.openai.com/api/docs/guides/latest-model)
