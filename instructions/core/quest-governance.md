# Core: Quest Governance

## Когда применять

- Для инженерных изменений кода, инфраструктуры или канонических документов, включая любые изменения этого каталога.
- Для управляемого цикла SPEC → EXEC с согласованием результата до реализации.

## Когда не применять

- Для справочных ответов и read-only анализа.
- Для выполнения существующего workflow с выдачей пользовательских артефактов, если не меняются код, инфраструктура или канонические файлы проекта.

## MUST

- Классифицировать риск и выбрать форму рабочей SPEC в локальном `./specs/` по таблице ниже. Фазовые мутации, approval и completion определяет только `quest-mode.md`; глубину review — `review-loops.md`.
- Брать выбранный шаблон из центрального каталога текущего instruction stack. Consumer-local template не является source of truth. Если canonical template отсутствует, сообщить onboarding blocker до реализации.
- Зафиксировать применимый профиль и выбранную форму с причиной. Число файлов/строк само по себе не определяет риск.

## Выбор формы SPEC

| Форма | Условия | Canonical template |
| --- | --- | --- |
| Short | Одновременно: один ограниченный outcome; локальное обратимое изменение; нет config/storage/security/публичного контракта/миграции/внешнего side effect; нет существенной межкомпонентной неопределённости | `templates/specs/_template-small.md` |
| Expanded | Хотя бы одно условие short не выполнено либо риск пока не установлен | `templates/specs/_template.md` |

Short сохраняет пять содержательных проверок по `spec-linter.md`: результат/границы; решения/разрешения; AC→evidence; существенный риск/rollback; findings/disposition/stop. Не требуются 20 отдельных оценок, числовой rubric или перечисление неприменимых ролей. Каждый из post-SPEC и post-EXEC может быть одним компактным evidence-based pass по `review-loops.md`; exact approval и журнал по фазовому owner сохраняются. Expanded сохраняет глубокий review, а large/high-risk — также independent reviewer при доступности. Обязательные условия безопасности, разрешений и валидации действуют для обеих форм. При обнаружении нового риска перейти к expanded до реализации; изменение scope согласуется по фазовому owner.

## SHOULD

- Описывать один связный outcome и измеримые критерии, не заполнять неприменимые матрицы ради формы.
- Для нескольких независимых частей фиксировать зависимости и ownership; порядок задавать только при реальном инварианте.

## Связанные документы

- [Фазы и разрешения](./quest-mode.md)
- [Review](../governance/review-loops.md)
- [Linter](../governance/spec-linter.md)
- [Rubric](../governance/spec-rubric.md)
- [Expanded template](../../templates/specs/_template.md)
- [Short template](../../templates/specs/_template-small.md)
- [Маршрутизация](../governance/routing-matrix.md)
