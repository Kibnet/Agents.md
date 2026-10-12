# Agents.md

Каталог инструкций для AI-агентов разработки. Версия 7.0.0 сохраняет все тематические правила и маршрутизацию; встроенные инструменты, тестовый стенд и настройки hooks больше не поставляются.

## Скачать и подключить

Скачайте ZIP нужной версии или клонируйте [репозиторий](https://github.com/Kibnet/Agents.md). Содержательные инструкции одинаковы; Git checkout дополнительно содержит служебные Git metadata и историю. Распакуйте каталог в постоянное место, например `C:\Tools\Agents.md`.

Создайте `AGENTS.md` в проекте-потребителе:

```markdown
# AGENTS

Используй центральный каталог инструкций: C:\Tools\Agents.md\AGENTS.md
Локальный AGENTS.override.md дополняет central stack и только ужесточает применимые MUST.
Рабочие SPEC сохраняй в .\specs\ проекта; canonical templates бери из C:\Tools\Agents.md\templates\specs\.
```

Замените путь на свой. Шаблоны: [consumer pointer](instructions/onboarding/AGENTS.consumer.template.md), [local override](instructions/onboarding/AGENTS.override.template.md); подробности — в [quick-start](instructions/onboarding/quick-start.md).

## Состав

| Каталог | Назначение |
| --- | --- |
| `instructions/` | Все общие правила, маршрутизация, контексты и технологические профили |
| `prompts/` | Рабочие запросы STORM и анализа бизнес-процессов |
| `templates/` | Формы SPEC/STORM и текстовая инструкция проверки среды |
| `schemas/` | Нормативные форматы STORM и OpenAI API contract |

[AGENTS.md](AGENTS.md) направляет к [routing-matrix](instructions/governance/routing-matrix.md). Маршрутизация выбирает применимые документы: профили .NET, Frontend, GPIO, STORM и Unlimotion остаются доступными в одном каталоге.

Для [STORM](instructions/profiles/storm-product-development.md) сохраняются продуктовые workflows, шаблоны и правила валидации/ранжирования. Агент выполняет логическую проверку или использует явно доступный инструмент проекта; каталог не содержит STORM CLI и не подтверждает его исполнение.

[Unlimotion context](instructions/contexts/unlimotion-task-context.md) и [result tracking](instructions/governance/unlimotion-result-tracking.md) сохраняют правила контекста задач, всех ветвей родителей и разрешённых результатов. Private pointers и установленный CLI задаются в соответствующем проекте.

## Проверки и переход с прежней версии

При изменении правил обязательны structural/link/format checks, релевантные behavioral scenarios и [review](instructions/governance/review-loops.md); результат фиксируется в локальной SPEC. Инструменты проверки предоставляет рабочая среда агента. Тестирование кода потребительских проектов регулируется прежними [testing rules](instructions/core/testing-baseline.md).

Python/PowerShell tools, installer/probe/analyzer, hook/reviewer config, CI, fixtures и авторская история удалены из текущей поставки. Копирование каталога не меняет установленные tools/config и не активирует hooks. Если ваш проект или host ссылается на прежние scripts, согласуйте отдельную миграцию перед обновлением активного пути.

Рабочие SPEC, runbooks и evidence хранятся локально в проекте. История каталога доступна в Git; правила версий — в [versioning-policy](instructions/governance/versioning-policy.md).
