# Core: Quest Prompt for Specification

## Когда применять

- Когда нужно запустить `QUEST MODE` и создать квалифицированную спецификацию.
- Когда задача требует уточнения границ, миграций и критериев приёмки до изменения кода.

## Когда не применять

- Для задач без изменений в коде/документации, где достаточно комментария.
- Когда уже есть утверждённая спецификация и нужна только реализация.

## MUST

- Использовать:
  - `instructions/core/model-behavior-baseline.md`
  - `instructions/core/quest-governance.md`
  - `instructions/core/quest-mode.md`
  - canonical `templates/specs/_template.md` из каталога текущих инструкций
  - `instructions/profiles/*`
  - `instructions/governance/spec-linter.md`
  - `instructions/governance/spec-rubric.md`
  - `instructions/governance/review-loops.md`
- Фазовые правила `SPEC`, включая допустимые изменения файлов, брать только из `instructions/core/quest-mode.md`.
- Уточнить профиль, если без него невозможно корректно определить требования.
- Задать вопросы только если они критичны для качества спеки.
- Создать или обновить рабочую спецификацию в локальном `specs/`.
- Прогнать `SPEC-LINTER` и `SPEC-RUBRIC`, зафиксировать результат в `specs`.
- Выполнить full `post-SPEC review-loop` в формате `instructions/governance/review-loops.md`, включая `Scope/Evidence pass`, `Contract pass`, `Adversarial risk pass`, `Re-review after fixes` / `Fix and re-review` и `Stop decision`; single-pass review summary недопустим.
- Перед `PASS` в `post-SPEC review-loop` проверить manual-review challenge: что бы пользовательский отдельный ручной review нашёл после моего `PASS`.
- Внести все findings с однозначным исправлением и повторить relevant review passes и quality gate, если review существенно изменил spec.
- Если review оставил несколько жизнеспособных вариантов без uniquely best option, задать пользователю один точный вопрос на выбор решения.
- До фразы пользователя `Спеку подтверждаю` не начинать `EXEC` и не менять файлы вне текущей рабочей спецификации.

## SHOULD

- Закрыть все `Открытые вопросы` до фазы исполнения.
- Привязать профиль к конкретной задаче и явно зафиксировать в `specs` в секции `Соответствие профилю`.
- Кратко показать, что именно улучшено на этапе full `post-SPEC review-loop`.

## MAY

- Добавить расширенные доменные проверки для крупного решения, если это повышает воспроизводимость.

## Команды

```text
Ты инженерный агент. Запусти QUEST MODE для подготовки спецификации.

# Goal
Создать или обновить рабочую спецификацию в локальном `specs/`, достаточную для безопасного перехода к `EXEC`.

# Success criteria
- Выбран и кратко обоснован профиль из `instructions/profiles`.
- Spec создана из canonical `templates/specs/_template.md` каталога текущих инструкций.
- Spec содержит цель, границы, acceptance criteria, проверочные команды, риски, stop rules и список файлов.
- SPEC-LINTER, SPEC-RUBRIC и full post-SPEC review-loop выполнены, а результаты зафиксированы в секции 19 в формате `instructions/governance/review-loops.md`.
- Если блокирующих вопросов нет, пользователь получает точную фразу подтверждения: "Спеку подтверждаю".

# Constraints
- Используй outcome-first contract из `instructions/core/model-behavior-baseline.md`.
- instructions/core/quest-governance.md
- instructions/core/quest-mode.md
- canonical /templates/specs/_template.md из каталога текущих инструкций
- instructions/governance/spec-linter.md
- instructions/governance/spec-rubric.md
- instructions/governance/review-loops.md
- На фазе `SPEC` меняй только текущую рабочую spec; не трогай код, инфраструктуру, `instructions/*`, `prompts/*`, `templates/*`, `scripts/*`, `README.md`, `CHANGELOG.md` и другие файлы проекта.
- Не используй локальный template репозитория задачи как source template.
- Задавай уточняющие вопросы только если без ответа нельзя написать проверяемую spec.
- Если canonical template не найден, остановись и явно укажи, что consumer-onboarding настроен неполно.

# Output
- Путь созданной/обновлённой spec.
- Краткое резюме выбранного профиля, quality gate результата и оставшихся blockers.
- Запрос подтверждения только если spec готова: "Спеку подтверждаю".

# Stop rules
- Остановись и спроси пользователя, если full post-SPEC review-loop оставил несколько жизнеспособных вариантов без uniquely best option.
- Остановись, если итог SPEC-RUBRIC < 21 и недостающие данные нельзя восстановить из репозитория.
- Не переходи к `EXEC` до явной фразы пользователя "Спеку подтверждаю".

# User task
<ОПИСАНИЕ ИДЕИ ПОЛЬЗОВАТЕЛЯ>
```

## Связанные документы

- [instructions/core/quest-governance.md](./quest-governance.md)
- [instructions/core/quest-mode.md](./quest-mode.md)
- [instructions/core/model-behavior-baseline.md](./model-behavior-baseline.md)
- [instructions/core/quest-prompt-exec.md](./quest-prompt-exec.md)
- [instructions/governance/review-loops.md](../governance/review-loops.md)
