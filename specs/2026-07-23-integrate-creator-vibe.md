# Интеграция `creator-vibe` в центральный каталог инструкций

## 0. Метаданные

- Тип (профиль): `catalog-governance`; профиль `product-system-design`; context `session-insights-context`.
- Владелец: пользователь / владелец `C:\Projects\My\Agents`.
- Масштаб: medium.
- Целевое семейство / behavior baseline: `GPT-5.6`.
- Поверхность: Work / Codex; постоянная линза применяется центральным `AGENTS.md`, полный skill загружается только по триггеру.
- Effective runtime: текущая сессия — Codex Desktop; для воспроизводимого before/after smoke — `codex-cli 0.144.4`, explicit `gpt-5.6-sol`, reasoning `medium`, `read-only`, `--ephemeral`. Если этот model ID или auth недоступны, EXEC останавливается до активации каталога.
- Eval baseline / evidence: три одинаковых representative prompt-сценария до и после активации; outputs сохраняются во временном каталоге вне репозитория и суммируются в Post-EXEC review.
- Целевой релиз / ветка: `3.2.0`, текущая ветка `main`; commit/push/PR не входят в scope.
- Ограничения:
  - до фразы `Спеку подтверждаю` изменяется только эта спецификация;
  - upstream skill не vendored и не модифицируется;
  - внешний источник pinned на commit `58642d69fafc5768627ed16215723c19198c4b4b`;
  - у upstream на проверенном commit нет файла лицензии, поэтому его текст не копируется в versioned каталог;
  - активный каталог подключён через `C:\Users\Kibnet\.codex\agents` к этому checkout, поэтому candidate authoring и первая валидация выполняются в изолированном worktree.
- Связанные ссылки:
  - upstream: <https://github.com/bish-x/creator-vibe>
  - pinned commit: <https://github.com/bish-x/creator-vibe/commit/58642d69fafc5768627ed16215723c19198c4b4b>
  - skill source: <https://github.com/bish-x/creator-vibe/blob/58642d69fafc5768627ed16215723c19198c4b4b/SKILL.md>

## 1. Overview / Цель

Интегрировать идею `creator-vibe` в центральный instruction stack так, чтобы агент постоянно удерживал реальный человеческий outcome и авторский замысел, но загружал полный внешний skill только для задач, где успех зависит от вкуса, голоса, ощущения, UX или недосказанного намерения.

Outcome contract:

- Success means:
  - central routing применяет лёгкую `creator-vibe`-линзу до классификации задачи;
  - творческие и product/UX-задачи получают полный skill, когда он реально нужен;
  - factual, mechanical, exact-output и полностью специфицированные задачи не получают творческого расширения;
  - линза не ослабляет explicit instructions, factual accuracy, safety, QUEST, authorization и scope;
  - локально установлен исходный skill с проверенного pinned commit;
  - static validation и before/after behavioral smoke проходят.
- Итоговый артефакт / output:
  - новый versioned owner-документ `instructions/core/creator-vibe-lens.md`;
  - синхронизированные routing, entry point, onboarding, README, validator/tests и changelog;
  - установленный вне репозитория `%USERPROFILE%\.codex\skills\creator-vibe`;
  - validation и behavioral evidence.
- Stop rules:
  - не переходить к EXEC без точной фразы `Спеку подтверждаю`;
  - не активировать candidate, если pinned source изменился, skill install не прошёл, candidate validators не прошли или before-smoke не удалось получить на фиксированном runtime;
  - после активации откатить prepared change set, если critical validators или after-smoke выявили регрессию explicit/exact behavior;
  - не продолжать улучшение формулировок после PASS всех acceptance criteria и review gates.

## 2. Текущее состояние (AS-IS)

- `C:\Projects\My\Agents` — clean checkout ветки `main`, commit `a0e56fb789e23153a05a070ec7cb25c47ee452d7`.
- `C:\Users\Kibnet\.codex\agents` разрешается Git в тот же top-level `C:\Projects\My\Agents`; root `AGENTS.md` идентичен active central file.
- `creator-vibe` не установлен в `C:\Users\Kibnet\.codex\skills\creator-vibe`.
- Central stack уже содержит близкие, но не эквивалентные правила:
  - outcome-first и lean prompts — `model-behavior-baseline`;
  - authorization, scope и communication — `collaboration-baseline`;
  - task routing и conflict ownership — `routing-matrix`;
  - user-observable evidence — QUEST template/review loops.
- Отдельного owner для interpretive lens, taste/voice/human-experience trigger и conditional skill loading нет.
- Upstream на commit `58642d69...` содержит `README.md`, `README.ru.md`, `SKILL.md`, `SKILL.ru.md`; исполняемых файлов нет; `LICENSE` отсутствует.
- Upstream `SKILL.md` описывает creative-first trigger и исключает factual lookup, mechanical/exact tasks и fully specified work.
- Интеграционный риск: буквальное копирование полного текста создаст дублирование owner-правил и неясное право на redistribution; без routing boundaries линза может начать изобретать требования или расширять scope.

## 3. Проблема

Каталог хорошо управляет инженерной корректностью, но не имеет отдельного, явно маршрутизируемого контракта, который сохраняет человеческий outcome и авторский замысел в задачах с неполным или эмоциональным brief. Простая установка skill не сделает его постоянной частью central stack, а буквальное vendoring создаст governance, duplication и licensing риски.

## 4. Цели дизайна

- Один короткий owner для interpretive lens без дублирования QUEST, safety, factual и authorization правил.
- Лёгкая always-on интерпретация плюс conditional loading полного skill.
- Предсказуемое отсутствие creative expansion в exact/factual/mechanical задачах.
- Воспроизводимая локальная установка pinned upstream.
- Graceful fallback: отсутствие внешнего skill не блокирует обычную задачу; агент применяет lightweight owner и сообщает о missing skill только при явном запросе использовать его.
- Проверяемая интеграция через validator contract и same-runtime before/after smoke.
- Обратимость active activation и отсутствие скрытого commit/push.

## 5. Non-Goals (чего НЕ делаем)

- Не копировать, переводить, редактировать или публиковать upstream `SKILL.md` в этом репозитории.
- Не создавать fork, submodule, plugin или собственный installer внешнего skill.
- Не делать `creator-vibe` заменой `model-behavior-baseline`, `collaboration-baseline`, QUEST, testing, safety или domain profiles.
- Не применять полный skill к factual lookup, mechanical transformations, exact-output requests и fully specified work.
- Не менять глобальный pointer `C:\Users\Kibnet\.codex\AGENTS.md`, config, hooks, sandbox или approval policy.
- Не commit, push, tag, release или PR.
- Не обновлять pinned upstream автоматически с `main`.

## 6. Предлагаемое решение (TO-BE)

### 6.1 Распределение ответственности

- `%USERPROFILE%\.codex\skills\creator-vibe\` -> неизменённая локальная копия upstream skill на pinned commit; runtime dependency вне Git-каталога.
- `instructions/core/creator-vibe-lens.md` -> owner lightweight lens, trigger полного skill, fallback и conflict boundaries.
- `AGENTS.md` -> entry-point ссылка на нового owner без самостоятельной conflict model.
- `instructions/governance/routing-matrix.md` -> mandatory lightweight lens до task classification; conditional full-skill trigger; точное место в stack assembly и conflict ownership.
- `README.md` -> архитектура, external dependency/provenance, local setup и поведение без установленного skill.
- `instructions/onboarding/quick-start.md` -> optional full-skill setup как отдельный шаг после central pointer; отсутствие skill не ломает onboarding.
- `scripts/validate-instructions.ps1` -> обязательный путь и semantic contracts для routing/boundaries.
- `scripts/test-validate-instructions.ps1` -> negative regression scenarios: missing owner и weakened mandatory routing/boundary.
- `CHANGELOG.md` -> release `3.2.0`, impact, migration и rollback.
- `specs/2026-07-23-integrate-creator-vibe.md` -> approved scope, journal и evidence.

### 6.2 Детальный дизайн

#### Lightweight owner

Новый core-документ следует `document-contract` и формулирует собственными словами:

- перед буквальной классификацией определить, что пользователь реально хочет сделать возможным и что в результате должно остаться узнаваемо его;
- использовать линзу легко для всех сообщений, но не превращать интерпретацию в отдельный ритуал или пересказ пользователю;
- если успех зависит от taste, voice, feeling, human experience, UX/product defaults или unstated choices, загрузить установленный `creator-vibe` до более узких skills/profiles;
- не загружать полный skill для factual, mechanical, exact и fully specified tasks;
- никогда не переопределять explicit instructions, factual accuracy, safety, exact-output, QUEST, authorization, scope и owner conflict rules;
- не изобретать требования и не расширять scope «ради замысла»;
- при отсутствии внешнего skill использовать lightweight owner, не блокировать задачу и не заявлять, что полный skill был применён.

#### Routing order

Stack assembly становится:

1. применить `creator-vibe-lens` как lightweight interpretive owner;
2. классифицировать задачу;
3. подключить `model-behavior-baseline` и task-type core;
4. добавить tool/context/profile/governance owners как сейчас;
5. если trigger creative/human-experience сработал и skill доступен, загрузить `creator-vibe` до narrower task skills; конкретные owner-документы всё равно имеют приоритет для safety, facts, authorization, exact output и phase gates.

`creator-vibe-lens` не считается дополнительным scenario profile и не расходует лимит двух profiles.

#### Local skill installation

После approval используется canonical `skill-installer` helper:

```powershell
python "$env:USERPROFILE\.codex\skills\.system\skill-installer\scripts\install-skill-from-github.py" `
  --repo bish-x/creator-vibe `
  --path . `
  --ref 58642d69fafc5768627ed16215723c19198c4b4b `
  --name creator-vibe
```

Перед установкой повторно проверяется, что destination отсутствует. После установки проверяются:

- наличие `SKILL.md`;
- exact SHA-256 против файла из detached upstream checkout на том же commit;
- отсутствие неожиданных исполняемых файлов;
- сохранение upstream файлов без модификации.

Skill становится доступен новым Codex-turn/session; текущая сессия не объявляет его загруженным задним числом.

#### Isolated candidate and active activation

1. После approval создать detached worktree от текущего active `HEAD`.
2. Внести весь versioned candidate в isolated worktree и выполнить static validators, tests и `git diff --check`.
3. До active patch выполнить before-smoke на текущем central stack.
4. Установить pinned skill; если установка/проверка неуспешна, не применять active patch.
5. Сформировать один prepared patch из validated candidate, исключая уже существующую active spec.
6. Повторно проверить active `HEAD`, status и отсутствие drift/unrelated changes.
7. Применить prepared patch к active checkout одной операцией.
8. Повторить critical validators на active path и выполнить after-smoke на том же runtime.
9. При critical failure применить reverse patch; installer-created skill переместить в recovery-каталог вне active skills; повторить critical validation текущего AS-IS.

#### Behavioral smoke

Одинаковые prompts до и после, без tool use:

1. Creative ambiguous:
   - brief про спокойный, «свой» первый экран сервиса заметок;
   - ожидается human outcome, несколько высоковлияющих решений, отсутствие архитектурного ухода и выдуманного scope.
2. Product/UX incomplete:
   - brief про лёгкий, но не инфантильный onboarding;
   - ожидается сохранение авторского стандарта, challenge поверхностного решения и максимум один sharp question только при реальной блокировке.
3. Exact/mechanical control:
   - exact JSON output с фиксированными ключами;
   - ожидается byte/structure-level compliance без объяснений, новых полей и creative interpretation.

Сравнение фиксирует:

- intent preservation;
- scope discipline;
- explicit/exact compliance;
- factual/safety boundary;
- unnecessary ceremony/overengineering;
- отсутствие заявления о применении skill в control-сценарии.

Visual planning artifact: `Не применимо`, UI/layout не изменяются; меняется agent behavior и документация.

UI test video evidence: `Не применимо`, UI automation отсутствует.

### 6.3 User-Observable Scenarios

| Scenario | User action / trigger | Expected visible result / output | Evidence required | Covered by AC |
| --- | --- | --- | --- | --- |
| Неполный творческий brief | Пользователь описывает ощущение/намерение, но не все решения | Агент сохраняет замысел, выбирает минимальные высоковлияющие решения и не уходит в machinery | after-smoke vs before-smoke | AC-2, AC-6 |
| Product/UX задача с taste | Результат зависит от voice, defaults или human experience | Новый turn загружает полный `creator-vibe`, оставаясь в scope и под owner-ограничениями | installed-skill check + after-smoke | AC-1, AC-3, AC-6 |
| Exact/factual/mechanical задача | Пользователь задаёт точный output или полностью определённую работу | Агент выполняет буквально, без creative expansion | control smoke | AC-3, AC-4, AC-6 |
| Skill недоступен | Runtime не видит `%USERPROFILE%\.codex\skills\creator-vibe` | Обычная задача не блокируется; используется lightweight lens; явный запрос на skill получает честный blocker | semantic scan / manual contract check | AC-5 |
| Новый consumer читает quick start | Пользователь подключает central catalog | Видит optional full-skill setup, pinned provenance и fallback | docs review + link check | AC-5, AC-7 |

### 6.4 State / Interaction Matrix

| Current state | Trigger | Expected transition/result | Empty/error/disabled/concurrent case | Notes |
| --- | --- | --- | --- | --- |
| Skill absent, lens absent | Approved EXEC + candidate PASS | Pinned skill installed, then owner/routing activated | Install failure -> active catalog unchanged | Spec остаётся единственным versioned change до EXEC |
| Skill present, lens active | Creative/taste trigger | Runtime loads full skill before narrower skills | Runtime cannot load -> lightweight fallback, no false claim | Новый turn/session видит installed skill |
| Skill present, lens active | Exact/factual trigger | Full skill skipped; literal task behavior | Не применимо | Control scenario protects this boundary |
| Active patch applied | Critical validation PASS | Integration remains active | Failure -> reverse patch + recoverable skill move | No commit/push |
| Destination unexpectedly exists | Install step | Stop and inspect provenance | Не overwrite и не merge | Требуется новый user decision при foreign content |

### 6.5 Decision Ledger

| Decision | Owner | Default / chosen option | Confidence | Risk if assumed | Needs user before EXEC |
| --- | --- | --- | ---: | --- | --- |
| Режим интеграции | agent | Always-on lightweight lens + conditional full skill | 0.92 | Меняет интерпретацию всех prompts, но минимально для exact tasks | Нет; утверждение spec подтверждает |
| Размещение owner | agent | Новый `instructions/core/creator-vibe-lens.md` | 0.96 | Inline rules в `AGENTS.md` нарушили бы owner model | Нет |
| Работа с upstream текстом | agent | Local install only; no vendoring/translation | 0.99 | Без лицензии redistribution рискован | Нет |
| Upstream version policy | agent | Pin exact commit; manual future update | 0.97 | Tracking `main` нерепродуцируем | Нет |
| Версия каталога | agent | Minor `3.2.0` | 0.95 | Поведение расширено без breaking contract | Нет |
| Git delivery | user | Не commit/push без отдельной просьбы | 1.00 | Неавторизованный delivery side effect | Нет |

### 6.6 Runtime / Config / Data Contract Matrix

| Contract area | Current source of truth | Expected change | Compatibility / migration | Verification |
| --- | --- | --- | --- | --- |
| Central routing | `AGENTS.md`, `routing-matrix.md` | Добавить lightweight owner до classification | Existing owners сохраняют приоритет | semantic validator + manual review |
| Skill runtime | `%USERPROFILE%\.codex\skills` | Новый `creator-vibe` с pinned upstream | Новые turns видят skill; старые могут не перечитать catalog | file/hash check + new ephemeral session |
| Catalog version | `CHANGELOG.md` | `3.2.0` | Minor, без удаления старых правил | changelog review |
| Validator contract | validation scripts | Required path + boundary markers | Existing valid catalog остаётся valid после seed update | positive + negative validator tests |
| User config/hooks | Codex home | Без изменений | Полная совместимость | status/config scope review |

## 7. Бизнес-правила / Алгоритмы (если есть)

1. Lightweight lens применяется всегда, но не обязана быть видна в ответе.
2. Full-skill trigger срабатывает, если хотя бы один существенный критерий успеха зависит от:
   - taste/voice/feeling;
   - human experience/UX;
   - недосказанного авторского намерения;
   - риска буквального выполнения с потерей смысла.
3. Full-skill trigger не срабатывает, если задача factual, mechanical, exact-output или fully specified и не содержит отдельного creative judgement.
4. При конфликте приоритет имеют:
   - explicit user instructions и exact-output contract;
   - factual accuracy и safety;
   - authorization/scope/QUEST phase;
   - specific artifact/workflow/stack owner;
   - затем interpretive recommendations `creator-vibe`.
5. Линза не разрешает агенту изобретать requirements, расширять scope или скрывать предположения.
6. Missing external skill не является blocker обычной задачи; blocker возникает только для явного требования применить полный skill.

## 8. Точки интеграции и триггеры

- Root entry point направляет к `creator-vibe-lens`.
- Routing assembly применяет lightweight owner до classification.
- Creative/human-experience trigger загружает installed skill перед narrower skills.
- Onboarding сообщает optional installation и fallback.
- Validator обнаруживает удаление owner, ослабление routing и boundary.
- New Codex turn/session является runtime trigger для обнаружения установленного skill.

## 9. Изменения модели данных / состояния

- Новых application data/model полей нет.
- Persisted local state: новый каталог `%USERPROFILE%\.codex\skills\creator-vibe`.
- Versioned state: новый owner-документ и синхронизированные docs/scripts/changelog/spec.
- Calculated state: trigger decision `load full skill / lightweight only` принимается на каждый prompt.

## 10. Миграция / Rollout / Rollback

- Rollout:
  1. validated candidate в isolated worktree;
  2. before-smoke;
  3. pinned skill install + hash verification;
  4. drift check active checkout;
  5. single prepared patch;
  6. active validation + after-smoke.
- Compatibility:
  - existing owners и profiles не удаляются;
  - consumer без installed full skill продолжает работать через lightweight owner;
  - exact/factual tasks защищены отдельным negative/control contract.
- Rollback:
  - reverse prepared patch для versioned files;
  - installer-created skill перемещается в timestamped recovery directory вне `%USERPROFILE%\.codex\skills`;
  - повторяются `validate-instructions.ps1`, `test-validate-instructions.ps1` и `git diff --check`;
  - spec и evidence сохраняются для аудита, если пользователь не попросит удалить их.

## 11. Тестирование и критерии приёмки

### Acceptance Criteria

- AC-1: `%USERPROFILE%\.codex\skills\creator-vibe\SKILL.md` установлен canonical helper-ом из commit `58642d69...`, hash совпадает с detached upstream source, неожиданных executable files нет.
- AC-2: central stack применяет lightweight `creator-vibe-lens` до task classification и условно загружает полный skill для taste/voice/human-experience/implicit-intent задач.
- AC-3: owner и routing явно сохраняют explicit instructions, factual accuracy, safety, exact-output, authorization, scope, QUEST и specific owners; requirements не изобретаются.
- AC-4: factual/mechanical/exact/fully specified tasks явно исключены из full-skill trigger.
- AC-5: новый документ соответствует `document-contract`; entry point, routing, README/onboarding, validator/tests и changelog синхронизированы.
- AC-6: same-runtime before/after smoke улучшает или сохраняет creative/product intent metrics и не ухудшает exact control.
- AC-7: upstream skill не vendored/modified; versioned docs содержат attribution, pinned provenance и fallback, но не заявляют отсутствующую лицензию.
- AC-8: candidate проверен из isolated worktree, active patch применён только после drift check; rollback подготовлен и не потребовался либо проверяемо выполнен.
- AC-9: standard validation, validator regression suite, `git diff --check` и post-EXEC full review PASS.

### Команды для проверки

```powershell
pwsh -File scripts/validate-instructions.ps1
pwsh -File scripts/test-validate-instructions.ps1
git diff --check
git status --short
git diff --stat
rg -n "creator-vibe|creator-vibe-lens" AGENTS.md README.md CHANGELOG.md instructions scripts
```

Behavioral smoke выполняется через `codex exec` с одинаковыми explicit model, reasoning, sandbox и `--ephemeral`; точные команды и output paths фиксируются в журнале EXEC без commit generated evidence.

Stop rules:

- не повторять network/auth/model failure без новой гипотезы;
- не считать static validator заменой behavioral smoke;
- не активировать или завершать с FAIL exact control;
- после PASS всех AC и review остановиться.

### Acceptance-to-Test Matrix

| Acceptance criterion | Automated test | Manual / visual / log check | Evidence artifact | If not tested, why |
| --- | --- | --- | --- | --- |
| AC-1 | SHA-256/file inventory | Installer stdout/provenance review | temp install log + hashes | — |
| AC-2 | validator semantic contract + negative scenario | routing diff review + creative smoke | validator output + after outputs | — |
| AC-3 | boundary marker contract + negative scenario | adversarial review | validator/test output | — |
| AC-4 | exact control smoke | full-skill skip review | before/after control outputs | — |
| AC-5 | standard validator + test suite | docs/link review | command logs | — |
| AC-6 | fixed smoke harness/scorecard | same-profile qualitative comparison | temp before/after outputs + scorecard | — |
| AC-7 | scan versioned diff for upstream long-form text/executable files | provenance/license observation review | `git diff` + upstream tree | — |
| AC-8 | active/candidate HEAD and status checks | prepared/reverse patch inspection | logs + diff stats | — |
| AC-9 | validators + `git diff --check` | full post-EXEC review | spec section 19/20 | — |

## 12. Риски и edge cases

- Upstream destination появляется между preflight и install.
  - Stop; не overwrite и не merge foreign content.
- Pinned commit становится недоступен по сети.
  - Не активировать catalog; классифицировать как network/source blocker.
- CLI model/auth недоступны для same-runtime smoke.
  - Не активировать versioned patch; сообщить blocker и required next step.
- Always-on lens дублирует outcome-first baseline.
  - Новый owner ограничивается intent/taste trigger; technical/tool/validation правила остаются у существующих owners.
- Creative interpretation расширяет scope.
  - Negative boundary, exact control и explicit conflict precedence.
- Missing license создаёт redistribution risk.
  - Не vendor/translate/modify upstream; локальная установка из original source и attribution only.
- Изменение active junction влияет на текущую среду.
  - Candidate first, one prepared patch, drift check, reverse patch and active critical validation.
- Installed skill доступен только следующему turn/session.
  - Проверять новым ephemeral `codex exec`; в финале явно сообщить об этом.

### Expected User Review Objections

| Likely objection | Why likely | Mitigation in spec/code plan | Status |
| --- | --- | --- | --- |
| «Не хочу, чтобы vibe мешал точным задачам» | Линза always-on | Full skill исключён для exact/factual/mechanical; отдельный control smoke | mitigated |
| «Не копируй чужой skill без лицензии» | Upstream без `LICENSE` | No vendoring/translation; local original-source install + attribution | mitigated |
| «Не раздувай central stack» | Новый always-on owner может стать prompt bloat | Короткий owner, ссылки на существующих owners, no duplication validator/review | mitigated |
| «Не ломай активный каталог во время эксперимента» | `.codex\agents` указывает на active checkout | Isolated candidate, prepared patch, drift check, rollback | mitigated |
| «Почему skill не работает прямо в этом же ответе?» | Skill discovery происходит на новом turn/session | New ephemeral session for evidence; final сообщает next-turn availability | mitigated |

### Rework Prevention Checklist

- [x] Spec называет user-visible agent behavior и setup outcome.
- [x] Каждый observable scenario имеет evidence.
- [x] Все materially relevant решения внесены в Decision Ledger.
- [x] Likely objections перечислены и закрыты.
- [x] Role-based review применимость задана.
- [x] Acceptance criteria являются проверками результата.
- [x] EXEC имеет путь доказать scenarios до финала.

## 13. План выполнения

1. После approval создать isolated detached worktree и перенести туда approved spec как implementation input.
2. Повторно проверить upstream pinned tree, active/candidate HEAD, skill destination и tool/runtime availability.
3. Выполнить before-smoke в isolated empty consumer workspace на фиксированном runtime.
4. Реализовать candidate owner/routing/docs/validator/tests/changelog в isolated worktree.
5. Запустить candidate validators, regression suite, semantic scan, link checks и `git diff --check`; исправить findings и повторить проверки.
6. Установить pinned external skill canonical helper-ом и проверить hash/tree.
7. Сформировать prepared patch и reverse path; проверить active drift и применить versioned change set к active checkout.
8. Повторить critical static checks на active path и выполнить after-smoke.
9. Выполнить User-Observable Completion Gate и full post-EXEC review; при однозначных findings исправить через новый isolated candidate/re-apply цикл.
10. Обновить журнал/section 19, остановиться без stage/commit/push и выдать outcome/evidence/risks.

## 14. Открытые вопросы

Блокирующих вопросов нет. Выбранный режим `always-on lightweight + conditional full skill` является наиболее прямой интеграцией в «набор инструкций» и сохраняет upstream boundary для exact tasks. Любое изменение этого materially visible режима до EXEC будет отражено в spec и потребует нового approval.

## 15. Соответствие профилю

- Профиль: `product-system-design`.
- Выполненные требования профиля:
  - цели и non-goals зафиксированы;
  - архитектура owner/routing/runtime dependency разделена;
  - публичный behavior contract и compatibility определены;
  - security/config/integration risks и rollback описаны;
  - UX/output scenarios и alternatives рассмотрены.
- Context: `session-insights-context`.
  - Memory-derived workflow использован только как hint о прежнем QUEST/delivery процессе;
  - текущие branch, HEAD, worktree, active junction и validators проверены live;
  - session insight не подменяет owner docs.

## 16. Таблица изменений файлов

| Файл | Изменения | Причина |
| --- | --- | --- |
| `instructions/core/creator-vibe-lens.md` | Новый owner lightweight lens/trigger/boundaries/fallback | Каноническая ответственность без inline conflict model |
| `AGENTS.md` | Ссылка на owner и краткий routing pointer | Entry point central stack |
| `instructions/governance/routing-matrix.md` | Always-on lens, conditional skill trigger, order/conflict rules | Канонический routing |
| `README.md` | Архитектура, provenance, setup/fallback | User-facing onboarding |
| `instructions/onboarding/quick-start.md` | Optional full-skill setup note | Consumer onboarding |
| `scripts/validate-instructions.ps1` | Required path и semantic contracts | Защита интеграции |
| `scripts/test-validate-instructions.ps1` | Negative regression cases | Доказательство validator behavior |
| `scripts/test-agent-operations.ps1` | Разрешить `CRLF` перед концом строки в двух существующих installer assertions | Устранить доказанный baseline false negative, блокирующий обязательный full gate, без изменения installer behavior |
| `CHANGELOG.md` | `3.2.0` Added/Changed/Migration/Rollback | Versioning policy |
| `specs/2026-07-23-integrate-creator-vibe.md` | Approval, journal, EXEC evidence | QUEST audit |
| `%USERPROFILE%\.codex\skills\creator-vibe\*` | Unmodified pinned upstream installation, не Git | Полный runtime skill |

## 17. Таблица соответствий (было -> стало)

| Область | Было | Стало |
| --- | --- | --- |
| Intent interpretation | Outcome-first, но без отдельного taste/voice owner | Lightweight creator lens до classification |
| Skill loading | `creator-vibe` отсутствует | Conditional full skill на pinned commit |
| Exact tasks | Защищены общими explicit/output rules | Дополнительно исключены из full-skill trigger и покрыты control smoke |
| Consumer without skill | Не применимо | Lightweight fallback без ложного claims/blocker |
| Upstream content | Не используется | External local dependency, no vendoring |
| Validation | Нет creator-vibe contracts | Required owner/routing/boundary regressions |

## 18. Альтернативы и компромиссы

- Вариант A: только установить skill.
  - Плюсы: минимальная Git-мутация.
  - Минусы: не интегрирует его в central routing; skill сработает только при явном/manual trigger.
- Вариант B: скопировать upstream lens прямо в root `AGENTS.md`.
  - Плюсы: коротко и близко к README upstream.
  - Минусы: root summary станет скрытым owner, появится дублирование и licensing ambiguity.
- Вариант C: vendor/fork полного skill в каталог.
  - Плюсы: offline reproducibility и полный контроль.
  - Минусы: нет license file; появляется update/attribution/derivative maintenance burden.
- Вариант D: новый lightweight owner + external pinned skill (выбран).
  - Плюсы: соответствует central governance, сохраняет attribution и runtime richness, имеет fallback и точные boundaries.
  - Минусы: локальная dependency устанавливается отдельно; future upstream updates ручные.
- Почему выбранное решение лучше:
  - единственное одновременно интегрирует behavior в central stack, не превращает root index в owner, не vendored чужой текст и сохраняет exact/factual predictability.

## 19. Результат quality gate и review

### SPEC Linter Result

| Блок | Пункты | Статус | Комментарий |
|---|---|---|---|
| A. Полнота спеки | 1-5 | PASS | Цель, AS-IS, корневая проблема, design goals и non-goals конкретны. |
| B. Качество дизайна | 6-10 | PASS | Owner/routing/runtime dependency, trigger algorithm, state и rollback разделены. |
| C. Безопасность изменений | 11-13 | PASS | No-vendoring, active-junction isolation, prepared rollback и scope boundaries зафиксированы. |
| D. Проверяемость | 14-16 | PASS | AC, same-runtime smoke, validator regressions и acceptance mapping полны. |
| E. Готовность к автономной реализации | 17-19 | PASS | Этапы, stop rules и отсутствие blocking questions определены. |
| F. Соответствие профилю | 20 | PASS | Product-system-design contracts и session-insights verification отражены. |

Итог: ГОТОВО.

### SPEC Rubric Result

| Критерий | Балл (0/2/5) | Обоснование |
|---|---:|---|
| 1. Ясность цели и границ | 5 | Always-on/conditional split, no-vendoring и no-delivery scope явны. |
| 2. Понимание текущего состояния | 5 | Live repo/active path, отсутствующий skill и upstream tree проверены. |
| 3. Конкретность целевого дизайна | 5 | Ответственности, routing order, trigger и fallback заданы. |
| 4. Безопасность (миграция, откат) | 5 | Isolated candidate, drift gate, reverse patch и recoverable skill rollback. |
| 5. Тестируемость | 5 | Static/negative contracts и same-runtime before/after smoke. |
| 6. Готовность к автономной реализации | 5 | Нет blocking decisions; точные stop rules и последовательность. |

Итоговый балл: 30 / 30.

Зона: готово к автономному выполнению после approval.

### Role-Based Review Result

| Role | Applicability | Review question | Verdict | Required spec changes |
| --- | --- | --- | --- | --- |
| Business analyst / domain workflow | applicable | Сохраняет ли routing реальный intent без изобретения требований? | PASS | Не требуются |
| UX / designer | applicable | Улучшается ли human-facing output без вторжения в exact tasks? | PASS | Control smoke и creative scenarios включены |
| Tester / validation | applicable | Каждый AC имеет evidence и negative case? | PASS | Не требуются |
| Developer / architect | applicable | Owner boundaries, dependency и compatibility согласованы? | PASS | Не требуются |
| Delivery / operations / security | applicable | Active junction, external install, provenance и rollback безопасны? | PASS | Не требуются |

### Post-SPEC Review

- Статус: PASS.
- Scope reviewed: эта spec; `AGENTS.md`; `routing-matrix`; `model-behavior-baseline`; `tool-execution-baseline`; `quest-governance`; `quest-mode`; `collaboration-baseline`; `document-contract`; `versioning-policy`; `review-loops`; `product-system-design`; `session-insights-context`; validator/test scripts; README onboarding; upstream tree/SKILL at pinned commit; current active/branch/HEAD/skill state.
- Decision: можно запрашивать подтверждение.
- Review passes:
  - Scope/Evidence pass: planned files соответствуют одной корневой задаче; commit/push и upstream vendoring исключены.
  - Contract pass: root остаётся entry point, routing — owner порядка, новый core — owner intent lens; QUEST/authorization/facts/exact output не ослабляются.
  - Adversarial risk pass: проверены over-trigger, prompt bloat, missing skill, license absence, upstream drift, exact-output regression, active junction и partial install.
  - Role-Based pass: все пять ролей применимы и PASS; UX покрыт output scenarios, delivery — reversible activation.
  - Re-review after fixes / Fix and re-review: initial design с возможным inline root snippet заменён новым owner + external dependency; повторная проверка boundaries и file map PASS.
  - Stop decision: PASS, потому что blocking decisions отсутствуют и no-evidence areas не осталось.
- Evidence inspected:
  - live `git` state и active central resolution;
  - upstream commit/tree/full `SKILL.md`;
  - отсутствие upstream `LICENSE`;
  - отсутствие installed destination;
  - canonical skill-installer implementation и root-path support через `--path . --name`;
  - validator semantic contracts/tests;
  - current README onboarding и changelog version.
- Depth checklist:
  - Scope drift / unrelated changes: current tree clean до создания этой spec; planned scope отделён.
  - Acceptance criteria: AC-1..AC-9 проверяемы.
  - User-observable scenarios / Decision ledger / Expected objections: заполнены.
  - Validation evidence: candidate/active validators и same-runtime smoke обязательны.
  - Unsupported claims: license сформулирована как наблюдение об отсутствии файла, не как юридический вывод.
  - Regression / edge case: exact control, missing destination, model/auth failure, rollback.
  - Comments/docs/changelog: README/onboarding/changelog включены; code comments не применимы.
  - Hidden contract change: always-on behavior явно назван и требует approval этой spec.
  - Manual-review challenge: отдельный review мог бы найти, что «установить skill» недостаточно для central routing или что inline snippet нарушает owner model; оба риска закрыты выбранным design.
- No-findings justification: после замены inline/vendoring вариантов на owner + external pinned dependency все проверенные risks имеют mitigation и evidence path; BLOCKER/HIGH findings отсутствуют.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | design / licensing | Полное vendoring upstream без license file создаёт неопределённый redistribution contract | Использовать local external install и не копировать long-form skill text | fixed |
| MEDIUM | routing / regression | Always-on creative lens может вмешаться в exact/factual tasks | Conditional full trigger, explicit precedence и exact control smoke | fixed |
| MEDIUM | delivery | Active central path связан с текущим checkout | Isolated candidate + prepared patch + drift/rollback gates | fixed |

- Fixed before continuing: design переведён на отдельный owner; добавлены no-vendoring, exact control и active-junction activation gates.
- Checks rerun: ручной linter/rubric/review по обновлённой spec; live repo/upstream/tool checks.
- Needs human: только обязательный переход фразой `Спеку подтверждаю`.
- Residual risks / follow-ups:
  - upstream может выпустить лицензию/новую версию; update не входит в scope;
  - qualitative smoke оценивает representative prompts, а не все возможные creative workloads.

### Post-EXEC Review

- Статус: PASS.
- Scope reviewed: approved spec; active `git status --short`, `git diff --stat`, full tracked diff и оба untracked files; prepared patch SHA-256 `c7b61bea29b0b142455fc39d8ddc1c38b04ed98f40cdea5d4c230db4a3a8f5a5`; active/candidate blob comparison; installed skill tree/blob IDs; before/after/explicit-load CLI outputs; candidate и active validation logs; README/onboarding/changelog impact.
- Decision: реализация и локальная интеграция завершены; можно выдавать финальный отчёт без stage/commit/push.
- Review passes:
  - Scope/Evidence pass: все девять candidate-файлов byte-equivalent active-файлам по Git blob; spec — единственный дополнительный versioned artifact; global mutation ограничена `%USERPROFILE%\.codex\skills\creator-vibe`.
  - Contract pass: lightweight owner подключён до classification; full skill conditional; factual/mechanical/exact/fully specified exclusions и explicit/factual/safety/authorization/QUEST precedence присутствуют; no-vendoring и pinned provenance соблюдены.
  - Adversarial risk pass: проверены exact-output drift, over-trigger, missing-skill fallback, ложный skill-load claim, active-junction partial activation, upstream byte drift, CRLF test false negative и hook-concurrency flake.
  - Role-Based pass: business/UX — output intent и one-sharp-question discipline PASS; tester — AC-1..AC-9 имеют evidence; architect — owner/routing boundaries PASS; delivery/security — isolated candidate, drift check, prepared/reverse patch и pinned blob verification PASS.
  - Re-review after fixes / Fix and re-review: README canonical entry добавлен; CRLF-only test assertions исправлены без installer behavior change; installer-area, candidate full suite, active hook-area и active full suite повторены до green.
  - Stop decision: PASS; BLOCKER/HIGH/MEDIUM незакрытых findings нет.
- Evidence inspected:
  - skill install: 4/4 repository blobs совпадают с pinned commit `58642d69...`; только `.md`;
  - behavioral smoke: creative output сохранил scope и усилил «свой» через обжитость/отсутствие давления; UX output задал ровно один materially relevant вопрос; exact output before/after byte-identical `{"status":"ok","count":2}`;
  - explicit-load smoke: новый session прочитал полный skill и вернул H1 `Creator Vibe` с корректной exclusion boundary;
  - candidate: `validate-instructions` PASS; 21/21 catalog regressions PASS; installer-area 155 assertions PASS; full agent-operations 326 assertions PASS; `git diff --check` PASS;
  - active: `validate-instructions` PASS; hook-area 74 assertions PASS после transient concurrency-flake; финальный full suite 21/21 + 326 assertions PASS; `git diff --check` PASS.
- Depth checklist:
  - Scope drift / unrelated changes: единственное отклонение — test-only `CRLF` compatibility в двух существующих assertions, напрямую необходимое для обязательного full gate и доказанное на unchanged active HEAD; installer/runtime behavior не менялся.
  - Acceptance criteria: AC-1..AC-9 закрыты automation/manual evidence.
  - User-observable scenarios / Acceptance-to-test matrix / Expected objections: creative, product/UX, exact, skill-load и onboarding scenarios проверены; все пять objections mitigated.
  - Validation evidence: candidate и active full green runs получены.
  - Unsupported claims: initial SHA-256 working-tree mismatch отклонён как `core.autocrlf` artifact; authoritative Git blob comparison использован вместо удобного, но неверного claim.
  - Regression / edge case: exact output byte-equal; один UX-вопрос; full-skill explicit load; missing-skill fallback закреплён semantic contract; hook timing-flake отдельно воспроизведена targeted green и закрыта final full green.
  - Comments/docs/changelog: owner, entry point, routing, canonical README list, onboarding setup и `3.2.0` changelog согласованы; устаревших code comments не добавлено.
  - Hidden contract change: always-on lightweight behavior явно описан в approved spec, root entry point, routing и README.
  - Manual-review challenge: отдельный reviewer мог бы найти непроверенную фактическую загрузку skill, ложный hash claim или скрытую exact regression; explicit-load session, blob equality и byte-level exact control закрывают эти риски.
- No-findings justification: после исправлений и повторных green runs diff соответствует approved outcome, owners не конфликтуют, external content не vendored, skill provenance доказан; незакрытых actionable findings нет.

| Severity | Area | Finding | Required action | Status |
| --- | --- | --- | --- | --- |
| MEDIUM | validation | Existing installer assertions rejected valid Windows `CRLF` before end-of-line | Разрешить `\r?` только перед `$`, не ослабляя value/comment match; повторить installer/full suites | fixed |
| LOW | evidence | Working-tree SHA-256 отличался из-за `core.autocrlf` | Сравнить installed bytes с authoritative repository blob IDs | fixed |
| LOW | validation | Первый active full run потерял 1/12 concurrent hook records | Проверить hook-area отдельно и повторить full suite после targeted green | fixed |

- Fixed before final report:
  - добавлен README canonical entry;
  - исправлены две CRLF-only test assertions;
  - заменена некорректная working-tree SHA гипотеза на Git blob verification;
  - transient hook failure закрыт targeted и final full green runs.
- Checks rerun:
  - `pwsh -File scripts/validate-instructions.ps1`;
  - `pwsh -File scripts/test-validate-instructions.ps1 -SkipAgentOperations`;
  - `pwsh -File scripts/test-agent-operations.ps1 -Area Installer`;
  - `pwsh -File scripts/test-agent-operations.ps1 -Area Hooks`;
  - `pwsh -File scripts/test-validate-instructions.ps1`;
  - `git diff --check`;
  - same-runtime before/after/explicit-load CLI smokes.
- Validation evidence: PASS; финальный active full run — 21/21 catalog scenarios и 326 agent-operations assertions.
- Unrelated changes: отсутствуют; test-harness remediation явно включена в diff/changelog/spec как validation dependency.
- Needs human: нет.
- Residual risks / follow-ups:
  - behavioral smoke покрывает representative, а не все creative workloads;
  - upstream update остаётся manual pinned migration;
  - CLI выводил существующие environment warnings о fixture agent-role discovery и model cache TTL; они присутствовали независимо от creator-vibe и не повлияли на exit code/output.

## Approval

Получена фраза: `Спеку подтверждаю`.

## 20. Журнал действий агента

| Фаза (SPEC/EXEC) | Тип намерения/сценария | Уверенность в решении (0.0-1.0) | Каких данных не хватает | Следующее действие | Нужна ли передача управления/решения человеку | Было ли фактическое обращение к человеку / решение человека | Короткое объяснение выбора | Затронутые артефакты/файлы |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC | Собрать central instruction stack и live repo preflight | 0.99 | Нет | Проверить upstream и интеграционные точки | Нет | Нет | Задача классифицирована как `catalog-governance` + tool-heavy + instruction migration | Read-only owner docs, Git state |
| SPEC | Аудитировать upstream skill, tree, commit, installability и license marker | 0.98 | Нет | Спроектировать безопасную форму интеграции | Нет | Нет | Upstream содержит только Markdown, skill отсутствует локально, license file не найден | Read-only upstream checkout и skill-installer |
| SPEC | Выбрать owner/routing/runtime dependency design | 0.95 | Нет | Создать и проверить рабочую spec | Нет | Нет | Always-on lightweight owner + conditional external full skill лучше install-only, inline и vendoring | Эта spec |
| SPEC | Выполнить linter/rubric/full post-SPEC review | 0.96 | Только approval | Запросить `Спеку подтверждаю` | Да | Да, запрос approval в текущем ответе | Spec получила 30/30, PASS и не содержит blocking questions | Эта spec |
| SPEC | Проверить versioned scope и текущую валидность каталога | 0.98 | Полный regression suite оставлен EXEC-гейтом | Остановиться на approval gate | Да | Да, запрос approval в текущем ответе | `validate-instructions.ps1` и `git diff --check` PASS; вне spec изменений нет; длинный regression suite не завершён в pre-approval лимите и остановлен без finding | Эта spec, read-only validation logs |
| EXEC | Зафиксировать переход SPEC -> EXEC | 1.00 | Нет | Создать isolated candidate worktree | Нет | Да: пользователь ответил точной фразой `Спеку подтверждаю` | Approval соответствует единственному разрешённому transition signal | Эта spec |
| EXEC | Выполнить active/candidate/runtime preflight | 0.99 | `git ls-remote` не принимает raw commit как ref; exact source проверяется install/hash gate | Снять before behavioral smoke | Нет | Нет | Active и central pointer разрешаются в `C:\Projects\My\Agents` на `a0e56fb`; skill/destination отсутствует; detached candidate создан на том же HEAD | Active repo, `C:\Users\Kibnet\.codex\worktrees\creator-vibe-20260723\Agents`, runtime inventory |
| EXEC | Снять before-smoke и проверить candidate catalog regressions | 0.98 | Полный gate выявил baseline installer-test failure | Локализовать failure на active HEAD | Нет | Нет | Три CLI-сценария завершились успешно; exact control точен; `validate-instructions` и 21/21 catalog regression PASS | Temp eval outputs, isolated candidate |
| EXEC | Диагностировать full-gate installer failure | 0.99 | Нет | Исправить test-only CRLF assertion и повторить full gate | Нет | Нет | Active и candidate одинаково падали; probe доказал корректные values/comments с `CRLF`, а regex ошибочно требовал LF-only end-of-line | `scripts/test-agent-operations.ps1`, temp installer probe |
| EXEC | Завершить candidate validation | 0.99 | Нет | Установить pinned skill | Нет | Нет | После CRLF fix installer-area PASS 155 assertions; полный gate PASS 21/21 catalog scenarios и 326 agent-operations assertions; validator/diff-check PASS | Isolated candidate, validation logs |
| EXEC | Установить и верифицировать upstream skill | 0.99 | Нет | Подготовить и применить active patch | Нет | Нет | Canonical helper установил 4 Markdown-файла; authoritative Git blob IDs всех файлов совпали с pinned commit `58642d69...`; executable files отсутствуют | `%USERPROFILE%\.codex\skills\creator-vibe`, detached upstream source |
| EXEC | Активировать validated candidate и выполнить behavior smoke | 0.99 | Нет | Повторить active full gate | Нет | Нет | Prepared patch применён после HEAD/status drift check; exact before/after byte-identical; creative intent сохранён; UX задал один sharp question; explicit session прочитал полный skill | Active catalog, temp eval outputs |
| EXEC | Закрыть active validation и full post-EXEC review | 0.99 | Нет | Выдать финальный отчёт без Git delivery | Нет | Нет | После transient hook flake targeted Hooks PASS 74; финальный active full suite PASS 21/21 + 326; AC-1..AC-9 и user-observable gate закрыты | Active diff, validation logs, section 19 |
