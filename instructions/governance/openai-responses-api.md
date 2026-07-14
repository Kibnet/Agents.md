# Governance: OpenAI Responses API

## Когда применять

- При проектировании, реализации или review интеграций с OpenAI Responses API.
- Когда задача затрагивает API model/tier selection, persisted reasoning, `reasoning.context`, stateless replay, Programmatic Tool Calling или Responses multi-agent.

## Когда не применять

- Для обычного использования standard ChatGPT или Work/Codex без проектирования API payload и orchestration.
- Как общую замену model behavior, collaboration, security, product profile или testing owner-документам.

## MUST

- Фиксировать поверхность как `OpenAI API`, точный model ID либо осознанное использование alias, `reasoning.effort`, `reasoning.mode` и `reasoning.context`, если они влияют на контракт или eval evidence.
- Для воспроизводимого routing использовать точный tier `gpt-5.6-sol`, `gpt-5.6-terra` или `gpt-5.6-luna`; alias `gpt-5.6` использовать только когда намеренно принимается его API-routing на текущий Sol tier и возможное будущее обновление alias.
- Задавать `reasoning.effort` осознанно из поддерживаемых GPT-5.6 значений `none`, `low`, `medium`, `high`, `xhigh`, `max`; не считать самый высокий уровень автоматическим optimum.
- Проверять поддержку выбранного `reasoning.context` моделью и читать effective `response.reasoning.context` на каждом ответе; не считать requested value фактически применённым без этого evidence.
- Для multi-turn reasoning использовать `previous_response_id`, conversation state либо полный manual replay. При manual replay сохранять все output items в исходном порядке, включая reasoning items, assistant messages, tool calls, tool outputs и имеющийся `phase`.
- Для stateless/ZDR replay запрашивать `include: ["reasoning.encrypted_content"]` на каждом вызове и возвращать encrypted reasoning items без преобразования.
- Не добавлять `phase` к user messages. Если используемая модель/flow возвращает assistant `phase`, сохранять его при replay; `commentary` не считать финальным ответом, а `final_answer` — промежуточным сообщением.
- В Programmatic Tool Calling объявлять вызываемые из hosted program functions с `allowed_callers: ["programmatic"]` и добавлять tool типа `programmatic_tool_calling`.
- Для nested `function_call` возвращать `function_call_output` с тем же `call_id` и без потери `caller`; `caller.type: "program"` и `caller.caller_id` связывают nested call с исходным program call.
- Считать `program_output.result` отдельным application-level JSON-string contract внутри wire-level item; продолжать Responses loop до получения финального `message`, потому что `program_output` может прийти раньше него.
- В multi-agent workflow сохранять authority boundaries и разрешённые tools каждого subagent, не расширять side effects через delegation и оставлять root agent ответственным за синтез и проверку финального ответа.
- Если приложение обслуживает отдельных end users, передавать стабильный privacy-preserving `safety_identifier` с каждым запросом.
- Учитывать safeguards и возможную синхронную задержку/отказ в dual-use областях как runtime outcome, а не автоматически классифицировать их как network failure.

## SHOULD

- Использовать Responses API для reasoning, tool-calling и multi-turn workflows семейства `GPT-5.6`.
- При миграции с `GPT-5.5` начинать с текущего `reasoning.effort`, затем сравнивать тот же уровень и один уровень ниже на representative eval set; `medium` использовать как balanced starting point, если baseline отсутствует.
- Включать `reasoning.mode: "pro"` на том же выбранном model ID только для quality-first workload после сравнения standard/pro по качеству, полноте, latency, tokens и cost.
- Применять Programmatic Tool Calling только к bounded tool-heavy подзадачам, где между вызовами не требуется новое model judgement.
- Применять Responses multi-agent только когда задача естественно делится на независимые workstreams и выигрыш покрывает orchestration overhead.
- Для prompt caching держать стабильный reusable prefix раньше динамических данных и измерять cache hit/write behavior до ручной оптимизации.
- Для image inputs выбирать `original` только когда исходные размеры materially нужны для результата и дополнительная token/latency стоимость оправдана.

## MAY

- Использовать `reasoning.context: "all_turns"`, если модель поддерживает его и запрос имеет доступ к полному предыдущему response history.
- Использовать explicit prompt caching, Programmatic Tool Calling, multi-agent beta или Pro mode после отдельной оценки применимости и стоимости.
- Использовать alias `gpt-5.6` для API workload, который намеренно должен следовать за текущим flagship routing.

## Команды

```powershell
# Поиск API-specific contract markers
rg -n "Responses API|gpt-5\.6-(sol|terra|luna)|reasoning\.context|reasoning\.mode|encrypted_content|allowed_callers|program_output|safety_identifier" .
```

## Связанные документы

- [instructions/governance/routing-matrix.md](./routing-matrix.md)
- [instructions/core/model-behavior-baseline.md](../core/model-behavior-baseline.md)
- [instructions/core/collaboration-baseline.md](../core/collaboration-baseline.md)
- [instructions/governance/review-loops.md](./review-loops.md)
- [instructions/profiles/product-system-design.md](../profiles/product-system-design.md)
