# Governance: Unlimotion Result Tracking

## Когда применять

- Агентское поручение создаёт standalone artifact, implementation или проверяемый результат, который нужно сопоставить задаче Unlimotion.
- Пользователь поручил claim, запись результата или изменение существующей задачи.

## Когда не применять

- Короткий factual ответ без самостоятельного deliverable не создаёт задачу.
- Наличие artifact при read-only поручении не разрешает изменять tracker.

## MUST

- Через task-context искать и использовать существующую задачу в подтверждённом source; не создавать duplicate. Новый task только если создание входит в действующее поручение. При недоступном source или отсутствии mutation authority сохранить точное предложение в разрешённом месте.
- Разделять консультацию, готовый deliverable, proposal и применённый tracker result. Учёт не заменяет работу; ResultRecord содержит summary, verified outcome, checks и limits, artifact links, remaining agent work и отдельно required decision/authority.
- Claim только если Prepared, agent execution применим и мутация разрешена. Claim не даёт разрешение на project EXEC, external effects или completion. Проверить существующий lease/владельца; чужой lease не перехватывать.
- Lease-bound команды выполнять только с точной парой agentId + leaseId по установленному контракту/skill. Result отдельно от complete: failed/unfinished result не complete; критерии и ожидаемый пользовательский outcome должны быть достигнуты. Готовность ребёнка не доказывает достигнутость родителя.
- Перед разрешённой записью прочитать текущие task/ETag, задать permitted fields и changedIDs, сохранить защищённые поля. Для apply обязателен успешный apply --dry-run по установленному skill; отказ preview запрещает write. Поддерживаемый guard полного preview применять по свежему CLI contract. Preview не создаёт разрешения: при конкретном действующем approval тот же проверенный request отправляется один раз без повторного human gate. Остальные мутации идут по собственному контракту, без придуманного apply wrapper.
- После записи читать все changedTaskIds/createdTaskIds тем же бинарником/source, сравнивать разрешённый diff и защищённые статус, dates, criteria, relations, repeater, отличая допустимые derived effects; выполнить validate выбранного пространства. Exit code/receipt/validate сами по себе не доказывают исходный outcome.
- При timeout/outcomeUnknown сначала проверить завершение процесса, дождаться lock, выполнить inspect/readback согласно CLI, затем определить исход. Не повторять вслепую, не удалять lock и не обходить CLI прямым JSON редактированием. Receipt подтверждает историю точного request hash; текущее desired state отдельно. Stale ETag/lease — перечитать и сверить scope, не force write.
- Не исправлять посторонние graph/availability ошибки ради своей записи. Недостаток команды сначала сверить по help/schema; отдельную подзадачу создать только при разрешённом создании, иначе предложить.
- Existing user gates сохраняются: project SPEC approval, result-write, parent-write, activation и внешние действия имеют собственный scope. Night protocol читается свежим по текущему pointer, не копируется в этот owner; запрет original task mutation остаётся запретом.

## Связанные документы

- [Task/source context](../contexts/unlimotion-task-context.md)
- [Parent enrichment](./goal-context-enrichment.md)
- [Routing/conflicts](./routing-matrix.md)
- [Authority](../core/collaboration-baseline.md)
- [QUEST phases](../core/quest-mode.md)
