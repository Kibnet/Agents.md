# Governance: OpenAI Responses API

## Когда применять

- При проектировании, реализации или review интеграций с OpenAI Responses API.
- Когда задача затрагивает API model/tier selection, persisted reasoning, `reasoning.context`, stateless replay, Programmatic Tool Calling, Responses multi-agent, async tool calls, mid-turn steering или `configuration_update`.

## Когда не применять

- Для обычного использования standard ChatGPT или Work/Codex без проектирования API payload и orchestration.
- Как общую замену model behavior, collaboration, security, product profile или testing owner-документам.

## MUST

- Точный versioned machine contract model/effort/endpoint/unsupported parameters: [openai-api-model-contract.json](../../schemas/openai-api-model-contract.json). Значения ниже — пояснение этого API contract, не сведения о Desktop availability. При обновлении сверять JSON и пояснения с официальными источниками.

- Фиксировать поверхность как `OpenAI API`, точный model ID либо осознанное использование alias, `reasoning.effort`, `reasoning.mode` и `reasoning.context`, если они влияют на контракт или eval evidence.
- Для GPT-6 использовать точные model ID `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6-sol` и `gpt-6-luna`; не вводить непроверенный alias `gpt-6` или модель `gpt-6-terra`. Сохранять осознанно выбранные workload-роли `gpt-5.6-sol`, `gpt-5.6-terra` и `gpt-5.6-luna`; не заменять весь router семейством GPT-6. Alias `gpt-5.6` направляет на текущий Sol tier и не является alias GPT-6; использовать его только при принятии возможного будущего обновления routing.
- Для `gpt-6-astra` и `gpt-6.1-sol` допустимы `low`, `medium`, `high`, `xhigh`, `max`; `none` и `minimal` не поддерживаются; default GPT-6.1 Sol — `medium`. Для `gpt-6-sol` и `gpt-6-luna` допустимы `none`, `low`, `medium`, `high`, `xhigh`, `max`, а `minimal` не поддерживается; их default effort — `medium`. Для GPT-5.6 отдельно допустимы `none`, `low`, `medium`, `high`, `xhigh`, `max`. Не переносить Codex Ultra в API `reasoning.effort` и не приравнивать его к `reasoning.mode: "pro"`; самый высокий effort не является автоматическим optimum.
- Для reasoning с tools в семействе GPT-6 использовать Responses API. Astra и GPT-6.1 Sol поддерживают Chat Completions без tools; tool calling требует Responses. Прежний GPT-6 Sol и Luna поддерживают там function calling только при `reasoning_effort: "none"`.
- Для `gpt-6-astra` и `gpt-6.1-sol` не передавать `temperature`, `top_p`, `top_logprobs`, в Chat Completions также `logprobs`, а в Responses исключить `message.output_text.logprobs` из `include`. Для прежнего GPT-6 Sol и Luna применять те же запреты при effort, отличном от `none`; исключение для `none` не означает автоматическую поддержку любого параметра выбранным endpoint/SDK.
- JSON schema 2 заменяет ошибочное `euRequiredServiceTier` на списки подтверждённых `euSupportedProcessingModes` и `euSupportedServiceTiers`. Для GPT-6.1 Sol, GPT-6 Sol и Luna EU residency поддерживается в Standard, Flex и Batch; Standard соответствует `service_tier: "default"`, Flex — `"flex"`, а Batch — отдельный `/v1/batches` workflow, не значение `service_tier`. Для Astra подтверждены Standard и Batch по residency table. `euSupportCoverage: "confirmed-only"` означает, что отсутствие режима в списке не является доказанным запретом; неподтверждённый режим требует текущей проверки. Fast/priority и Ultrafast с EU несовместимы. Не обещать latency SLA для Astra Fast.
- Astra Ultrafast в API использует `gpt-6-astra`, Responses и `service_tier: "ultrafast"`; поддерживает global processing и US residency, исключая EU и остальные non-US regional endpoints. GPT-6.1 Sol Ultrafast не доступен на дату проверенного контракта. Для tool-heavy flows учитывать overhead HTTP и рекомендацию persistent WebSocket; ускорение token generation не выдавать за end-to-end SLA. API availability не переносить на Work/Codex планы.
- Проверять поддержку выбранного `reasoning.context` моделью и читать effective `response.reasoning.context` на каждом ответе; не считать requested value фактически применённым без этого evidence.
- Для multi-turn reasoning использовать `previous_response_id`, conversation state либо полный manual replay. При manual replay сохранять все output items в исходном порядке, включая reasoning items, assistant messages, tool calls, tool outputs и имеющийся `phase`.
- Для stateless/ZDR replay запрашивать `include: ["reasoning.encrypted_content"]` на каждом вызове и возвращать encrypted reasoning items без преобразования.
- Не добавлять `phase` к user messages. Если используемая модель/flow возвращает assistant `phase`, сохранять его при replay; `commentary` не считать финальным ответом, а `final_answer` — промежуточным сообщением.
- В Programmatic Tool Calling объявлять вызываемые из hosted program functions с `allowed_callers: ["programmatic"]` и добавлять tool типа `programmatic_tool_calling`.
- Для nested `function_call` возвращать `function_call_output` с тем же `call_id` и без потери `caller`; `caller.type: "program"` и `caller.caller_id` связывают nested call с исходным program call.
- Считать `program_output.result` отдельным application-level JSON-string contract внутри wire-level item; продолжать Responses loop до получения финального `message`, потому что `program_output` может прийти раньше него.
- Проверять exact model applicability Responses Multi-agent beta: официально доступны GPT-6.1 Sol и GPT-5.6 models. Использовать beta Responses SDK с `responses_multi_agent=v1` либо header `OpenAI-Beta: responses_multi_agent=v1`, и `multi_agent.enabled: true` только для разрешённого orchestration scope. Наличие capability не включает delegation автоматически.
- Все Responses subagents получают общий набор request tools. Per-agent authority и ограничения side effects должен обеспечивать application/tool backend; не обещать техническую изоляцию tools по одному распределению задач. Root отвечает за синтез и проверку финального ответа.
- Hosted `multi_agent_call` и `multi_agent_call_output` исполняются API: приложение не выполняет их как function calls и не отправляет собственный hosted result. Developer-defined `function_call` исполняется приложением с matching output. При replay сохранять исходный порядок всех items, включая `agent_message`, encrypted content, `call_id` и agent attribution; выбирать final message root `/root` с phase `final_answer`, а не commentary/subagent finals.
- При `multi_agent.enabled: true` server-side compaction включена implicit для каждого агента; standalone `/responses/compact`, `reasoning.summary` и `max_tool_calls` не поддерживаются. `max_concurrent_subagents` default 3 ограничивает active descendants, исключая root; SDK beta schemas сверять перед интеграцией. Не переносить эти API limits на Codex product harness.
- При async function/custom tools приложение выполняет вызов и хранит pending state; результат возвращать с исходным `call_id`. Продолжать только независимую работу до получения нужного результата; поддержка async моделью не создаёт scheduler или новые полномочия приложения.
- Для API mid-turn steering проверять поддержку Astra и WebSocket transport. Считать `response.steer.accepted` подтверждением очереди, а не применения input: ранее запущенные tools не отменяются автоматически, для continuation могут требоваться tool results/approval. Сохранять их идентификаторы и не повторять уже принятое уточнение. Не переносить API event names на Codex App Server.
- Использовать `configuration_update` только в поддерживаемой модели семейства GPT-6, standard single-agent; режимы pro и multi-agent не поддерживаются. Оставлять request-level `reasoning.effort` прежним для стабильного prefix; effective effort отслеживать по упорядоченной истории updates, потому что `response.reasoning.effort` продолжает показывать request-level значение.
- Не сочетать `configuration_update` с automatic compaction/truncation или standalone `/responses/compact`; не помещать два updates рядом. Сохранять updates на исходных позициях при replay. Если выбран поддерживаемый ручной `compaction_trigger`, после compaction добавлять свежий update перед следующим user message по текущему reasoning guide.
- Если приложение обслуживает отдельных end users, передавать стабильный privacy-preserving `safety_identifier` с каждым запросом.
- Учитывать safeguards и возможную синхронную задержку/отказ в dual-use областях как runtime outcome, а не автоматически классифицировать их как network failure.

## SHOULD

- Использовать Responses API для reasoning и multi-turn workflows Astra и GPT-5.6; обязательность Responses для Astra tools определена выше.
- При миграции в семейство GPT-6 сохранять текущий effective effort, если он поддерживается; для Astra/GPT-6.1 Sol `none` и для любой GPT-6 модели `minimal` начинать с `low` и проверять результат. Прежний GPT-6 Sol/Luna `none` сохранять только для latency-critical работы без reasoning/tools либо для явно совместимого Chat Completions function calling. Затем сравнивать поддерживаемые уровни на representative eval set; если baseline отсутствует, `medium` допустим как локальная стартовая эвристика.
- Включать `reasoning.mode: "pro"` на том же выбранном model ID только для quality-first workload после сравнения standard/pro по качеству, полноте, latency, tokens и cost.
- Применять Programmatic Tool Calling только к bounded tool-heavy подзадачам, где между вызовами не требуется новое model judgement.
- Применять Responses multi-agent только когда задача естественно делится на независимые workstreams и выигрыш покрывает orchestration overhead.
- Для prompt caching держать стабильный reusable prefix раньше динамических данных и измерять cache hit/write behavior до ручной оптимизации.
- При миграции с GPT-5.5 и ранее на поддерживаемую GPT-6 модель проверить замену `prompt_cache_retention` на `prompt_cache_options.ttl: "30m"`, cache boundaries и cache-write billing по текущему caching guide. Не переписывать unrelated cache configuration.
- При cache-aware model comparison учитывать модельные ставки: GPT-6.1 Sol cache reads стоят 5% uncached input, прежний GPT-6 Sol — 10%; write billing и фактический hit rate входят в cost per successful task. Точные актуальные цены проверять по official pricing, не выводить экономию только из коэффициента.
- Для image inputs выбирать `original` только когда исходные размеры materially нужны для результата и дополнительная token/latency стоимость оправдана.

## MAY

- Использовать `reasoning.context: "all_turns"`, если модель поддерживает его и запрос имеет доступ к полному предыдущему response history.
- Использовать explicit prompt caching, Programmatic Tool Calling, multi-agent beta или Pro mode после отдельной оценки применимости и стоимости.
- Использовать alias `gpt-5.6` для API workload, который намеренно должен следовать за Sol routing семейства GPT-5.6.
- Включать async tools, steering и configuration updates только при подтверждённой поддержке выбранного harness и их применимости к задаче; не подключать новые runtime features автоматически из-за смены baseline каталога.

## Команды

```powershell
# Поиск API-specific contract markers
rg -n "Responses API|gpt-6(\.1)?-(astra|sol|luna)|gpt-5\.6-(sol|terra|luna)|reasoning\.context|reasoning\.mode|configuration_update|response\.steer|encrypted_content|allowed_callers|program_output|safety_identifier" .
```

## Связанные документы

- [instructions/governance/routing-matrix.md](./routing-matrix.md)
- [instructions/core/model-behavior-baseline.md](../core/model-behavior-baseline.md)
- [instructions/core/collaboration-baseline.md](../core/collaboration-baseline.md)
- [instructions/governance/review-loops.md](./review-loops.md)
- [instructions/profiles/product-system-design.md](../profiles/product-system-design.md)
- [OpenAI: Using GPT-6 Astra](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra)
- [OpenAI: GPT-6 Astra model](https://developers.openai.com/api/docs/models/gpt-6-astra)
- [OpenAI: GPT-6.1 Sol model](https://developers.openai.com/api/docs/models/gpt-6.1-sol)
- [OpenAI: EU data residency](https://developers.openai.com/api/docs/guides/your-data#which-models-and-features-are-eligible-for-data-residency)
- [OpenAI: Ultrafast](https://developers.openai.com/api/docs/guides/ultrafast-mode)
- [OpenAI: Responses Multi-agent](https://developers.openai.com/api/docs/guides/responses-multi-agent)
- [OpenAI: GPT-6 Sol model](https://developers.openai.com/api/docs/models/gpt-6-sol)
- [OpenAI: GPT-6 Luna model](https://developers.openai.com/api/docs/models/gpt-6-luna)
- [OpenAI: Async tool calling](https://developers.openai.com/api/docs/guides/async-tool-calling)
- [OpenAI: Mid-turn steering](https://developers.openai.com/api/docs/guides/steering)
- [OpenAI: Change reasoning mid-conversation](https://developers.openai.com/api/docs/guides/reasoning#change-reasoning-mid-conversation)
- [OpenAI: Prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
