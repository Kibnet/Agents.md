# Обязательный Mermaid lint и auto-fix loop в process prompts

## 0. Метаданные
- Тип (профиль): business-process-automation
- Владелец: Codex
- Масштаб: small
- Целевой релиз / ветка: 1.1.2 / текущая рабочая ветка
- Ограничения:
  - соблюдать `instructions/governance/document-contract.md` для `instructions/*`;
  - соблюдать `instructions/governance/versioning-policy.md` и обновить `CHANGELOG.md`;
  - не менять канонический порядок workflow `AS-IS -> automation opportunities -> TO-BE -> skill graph`;
  - не менять формат итоговых артефактов: успешный результат по-прежнему остается Mermaid-кодом без обрамления.
- Связанные ссылки:
  - `instructions/profiles/business-process-automation.md`
  - `prompts/business-process-automation/02-as-is-process-modeling.md`
  - `prompts/business-process-automation/04-to-be-process-design.md`
  - `prompts/business-process-automation/05-ai-agent-skill-graph.md`
  - `instructions/governance/document-contract.md`
  - `instructions/governance/versioning-policy.md`

## 1. Overview / Цель
Сделать обязательным внешний lint/validation для всех канонических инструкций, которые генерируют Mermaid-диаграммы, и явно потребовать автоматическое исправление ошибок до тех пор, пока диаграмма не пройдет проверку.

## 2. Текущее состояние (AS-IS)
- Профиль `business-process-automation` сейчас только рекомендует self-check Mermaid-артефактов перед выдачей результата.
- Prompt templates шагов 2, 4 и 5 описывают структурные ограничения Mermaid, но не требуют обязательного прогонки через формальный validator/linter.
- В результате валидность диаграмм зависит от ручной внимательности агента, а не от обязательного внешнего контроля.
- Канонический quality gate репозитория проверяет структуру каталогов инструкций, но не обеспечивает валидность Mermaid-артефактов, которые эти инструкции требуют от агента.

## 3. Проблема
В каталоге нет обязательного и проверяемого правила, которое заставляет агента валидировать Mermaid-диаграммы внешним инструментом и автоматически исправлять найденные ошибки до получения корректного артефакта.

## 4. Цели дизайна
- Сделать требование lint/validation обязательным, а не рекомендательным.
- Зафиксировать единый цикл `generate -> lint -> fix -> relint` для всех Mermaid-артефактов в `business-process-automation`.
- Сохранить совместимость с текущими output contracts: на успешном пути пользователь получает только Mermaid-код.
- Явно определить поведение при недоступности validator/linter, чтобы агент не выдавал неподтвержденную диаграмму как готовую.

## 5. Non-Goals (чего НЕ делаем)
- Не добавляем в репозиторий новый исполняемый Mermaid validator или CI pipeline для реального рендеринга диаграмм.
- Не меняем входные артефакты, последовательность шагов workflow или формат файлов-артефактов.
- Не расширяем задачу на любые прочие диаграммы вне prompt templates `business-process-automation`, если там Mermaid не генерируется.
- Не переписываем весь набор prompts; меняем только минимально необходимый набор правил.

## 6. Предлагаемое решение (TO-BE)
### 6.1 Распределение ответственности
- `instructions/profiles/business-process-automation.md` -> зафиксировать обязательность Mermaid lint/validation и auto-fix loop на уровне workflow-профиля.
- `prompts/business-process-automation/02-as-is-process-modeling.md` -> требовать обязательную проверку `sequenceDiagram` перед финальным выводом.
- `prompts/business-process-automation/04-to-be-process-design.md` -> требовать обязательную проверку `sequenceDiagram` перед финальным выводом.
- `prompts/business-process-automation/05-ai-agent-skill-graph.md` -> требовать обязательную проверку `graph TD` перед финальным выводом.
- `CHANGELOG.md` -> зафиксировать изменение как значимое изменение каталога.

### 6.2 Детальный дизайн
- В профиль `business-process-automation` добавить MUST-правило:
  - для шагов, создающих Mermaid-артефакт, агент обязан прогонять результат через Mermaid lint/validator перед выдачей пользователю;
  - при любой ошибке синтаксиса или рендеринга агент обязан автоматически исправить диаграмму и повторять проверку до успешного результата;
  - если validator/linter недоступен в среде выполнения, шаг считается заблокированным и не должен завершаться выдачей неподтвержденного Mermaid-артефакта.
- В prompt templates шагов 2, 4 и 5 добавить явный внутренний цикл:
  - сгенерировать диаграмму;
  - запустить Mermaid lint/validation;
  - при ошибке исправить код;
  - повторять цикл до PASS;
  - только после PASS выводить финальный Mermaid-код.
- Формулировку tooling сделать нейтральной и исполнимой:
  - предпочтителен официальный Mermaid syntax validation через `mermaid.parse(...)`;
  - допустим render-check через `@mermaid-js/mermaid-cli` (`mmdc`), если он используется как доступный validator;
  - в текстах инструкций именовать это как `Mermaid lint/validator`, чтобы правило не было привязано к единственной установке.
- Output Contract в prompt templates сохранить без изменения успешного формата вывода, но добавить правило, что финальный вывод возможен только после успешного lint/validation.

## 7. Бизнес-правила / Алгоритмы (если есть)
- Для шага генерации Mermaid действует инвариант:
  - `artifact-ready = mermaid-generated AND lint-passed`.
- Алгоритм завершения шага:
  1. Сгенерировать Mermaid-код.
  2. Прогнать код через Mermaid lint/validator.
  3. Если проверка не пройдена, исправить код на основе ошибки validator.
  4. Повторять шаги 2-3, пока validator не подтвердит корректность.
  5. Только после успешной проверки отдавать Mermaid-код как артефакт шага.
- Если validator/linter недоступен, шаг не считается завершенным и агент обязан явно обозначить блокер вместо молчаливой выдачи непроверенной диаграммы.

## 8. Точки интеграции и триггеры
- Триггер: выполнение шага 2 `AS-IS Process Modeling`.
- Триггер: выполнение шага 4 `TO-BE Process Design`.
- Триггер: выполнение шага 5 `AI Agent Skill Graph`.
- Интеграция: профиль `business-process-automation` задает общее обязательное правило, prompt templates конкретизируют его для каждого артефакта.

## 9. Изменения модели данных / состояния
- Новых persisted-данных нет.
- Меняется только нормативное состояние workflow: Mermaid-артефакт считается готовым только после успешного lint/validation.

## 10. Миграция / Rollout / Rollback
- Поведение после изменения:
  - новые запуски Mermaid-генерирующих prompts обязаны проходить через lint/auto-fix loop.
- Обратная совместимость:
  - формат успешного артефакта сохраняется;
  - потребители prompts не обязаны менять входы или downstream-обработку.
- Rollback:
  - удалить новые формулировки про обязательный lint/validation и auto-fix loop из профиля и prompts;
  - откат не требует миграции данных.

## 11. Тестирование и критерии приёмки
- Acceptance Criteria:
  - в `instructions/profiles/business-process-automation.md` lint/validation Mermaid-артефактов переведен из необязательной проверки в обязательное правило workflow;
  - prompts `02-as-is-process-modeling.md`, `04-to-be-process-design.md`, `05-ai-agent-skill-graph.md` явно требуют auto-fix loop до успешного lint/validation;
  - инструкции не меняют успешный output format: результатом остается только Mermaid-код соответствующего типа;
  - при недоступности validator/linter инструкции явно запрещают считать шаг завершенным.
- Какие тесты добавить/изменить:
  - новые автоматические тесты не планируются;
  - обязательны existing quality gate проверки каталога инструкций.
- Команды для проверки:
  - `pwsh -File scripts/validate-instructions.ps1`
  - `pwsh -File scripts/test-validate-instructions.ps1`
  - `rg -n "lint|validator|auto-fix|Mermaid" instructions\profiles\business-process-automation.md prompts\business-process-automation\02-as-is-process-modeling.md prompts\business-process-automation\04-to-be-process-design.md prompts\business-process-automation\05-ai-agent-skill-graph.md`

## 12. Риски и edge cases
- Риск: формулировка будет слишком привязана к конкретному инструменту.
  - Смягчение: использовать термин `Mermaid lint/validator` и привести `mermaid.parse` / `mmdc` как допустимые варианты.
- Риск: prompt output contract конфликтует с сообщением о блокере.
  - Смягчение: трактовать output contract как контракт успешного пути; профиль отдельно описывает, что при недоступном validator шаг не может считаться завершенным.
- Риск: разные среды имеют только parser или только render-check.
  - Смягчение: разрешить любой доступный validator, если он реально подтверждает корректность Mermaid.

## 13. План выполнения
1. Обновить профиль `business-process-automation` обязательными правилами lint/auto-fix loop.
2. Обновить prompt templates шагов 2, 4 и 5 одинаковым обязательным паттерном проверки перед финальным выводом.
3. Обновить `CHANGELOG.md`.
4. Прогнать validator и тесты validator.

## 14. Открытые вопросы
- Блокирующих вопросов нет.

## 15. Соответствие профилю
- Профиль: `business-process-automation`
- Выполненные требования профиля:
  - изменение адресует канонические Mermaid-артефакты шагов 2, 4 и 5;
  - сохраняется трассировка артефактов и порядок workflow;
  - усиливается требование валидности Mermaid-артефактов перед их выдачей.

## 16. Таблица изменений файлов
| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/profiles/business-process-automation.md` | Ужесточить правила Mermaid validation | Сделать lint/auto-fix loop обязательной частью workflow |
| `prompts/business-process-automation/02-as-is-process-modeling.md` | Добавить обязательный lint/validation и auto-fix loop | Гарантировать корректный `AS-IS` Mermaid `sequenceDiagram` |
| `prompts/business-process-automation/04-to-be-process-design.md` | Добавить обязательный lint/validation и auto-fix loop | Гарантировать корректный `TO-BE` Mermaid `sequenceDiagram` |
| `prompts/business-process-automation/05-ai-agent-skill-graph.md` | Добавить обязательный lint/validation и auto-fix loop | Гарантировать корректный Mermaid `graph TD` |
| `CHANGELOG.md` | Добавить запись о новом обязательном lint-правиле | Соблюсти versioning policy |

## 17. Таблица соответствий (было -> стало)
| Область | Было | Стало |
| --- | --- | --- |
| Профиль workflow | Mermaid self-check рекомендован (`SHOULD`) | Mermaid lint/validation обязателен (`MUST`) |
| Prompt steps 2/4/5 | Формальные ограничения Mermaid без обязательного внешнего validator | Обязательный цикл `generate -> lint -> fix -> relint` до PASS |
| Готовность артефакта | Диаграмма считается готовой после генерации | Диаграмма считается готовой только после успешного validator/lint |

## 18. Альтернативы и компромиссы
- Вариант: ограничиться формулировкой "проверь синтаксис вручную".
- Плюсы:
  - не требуется описывать tooling.
- Минусы:
  - правило остается непроверяемым и легко игнорируется;
  - не решает запрос пользователя про обязательный lint и автоисправление.
- Почему выбранное решение лучше в контексте этой задачи:
  - оно вводит конкретный и повторяемый quality gate для Mermaid-артефактов без изменения формата итогового результата.

## 19. Результат прогона линтера
### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, проблема, границы и non-goals зафиксированы |
| B. Качество дизайна | 6-10 | PASS | Ответственность, алгоритм, интеграции и rollback описаны |
| C. Безопасность изменений | 11-13 | PASS | Совместимость и поведение при блокере описаны явно |
| D. Проверяемость | 14-16 | PASS | Есть acceptance criteria и команды quality gate |
| E. Готовность к автономной реализации | 17-19 | PASS | План по шагам и объем файлов определены, блокирующих вопросов нет |
| F. Соответствие профилю | 20 | PASS | Изменение напрямую связано с Mermaid-артефактами профиля |

Итог: ГОТОВО

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---|---|
| 1. Ясность цели и границ | 5 | Цель и non-goals сформулированы без двусмысленностей |
| 2. Понимание текущего состояния | 5 | Зафиксированы текущие профиль и prompts, где отсутствует обязательный lint |
| 3. Конкретность целевого дизайна | 5 | Указаны файлы, новые правила и цикл `generate -> lint -> fix -> relint` |
| 4. Безопасность (миграция, откат) | 5 | Формат артефактов сохраняется, rollback прост |
| 5. Тестируемость | 5 | Есть четкие acceptance criteria и команды quality gate |
| 6. Готовность к автономной реализации | 5 | Объем малый, открытых вопросов нет, изменения локализованы |

Итоговый балл: 30 / 30
Зона: готово к автономному выполнению

## Approval
Ожидается фраза: "Спеку подтверждаю"
