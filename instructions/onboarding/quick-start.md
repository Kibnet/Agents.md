# Onboarding: Quick Start

## Когда применять

- Нужно подключить единый каталог агентских инструкций к новому локальному репозиторию.
- Нужно быстро стартовать без копирования большого объема правил.

## Когда не применять

- Если репозиторий уже использует этот каталог и контракт подключения не меняется.

## MUST

- Создать в репозитории-потребителе локальный `AGENTS.md` на основе шаблона.
- Указать в нем источник через переменную пути каталога (например, `$env:AGENTS_ROOT\AGENTS.md`).
- Если нужны проектные уточнения, добавлять только `AGENTS.override.md` (только ужесточение MUST).
- Проверить, что локальный `AGENTS.md` не дублирует центральные правила.
- Для `QUEST`-задач сохранять рабочие spec-файлы в локальном `./specs/` репозитория-потребителя.
- Для `QUEST`-задач всегда использовать central template `$env:AGENTS_ROOT\templates\specs\_template.md`.

## SHOULD

- Добавлять краткое описание, какой профиль использовать по умолчанию в этом репозитории.
- Проверять актуальность ссылок при обновлении центрального каталога.

## MAY

- Добавлять локальные команды проекта в `AGENTS.override.md`, если они не конфликтуют с центральными MUST.

## Команды

```powershell
# Рекомендуемые переменные пути каталога инструкций
$env:AGENTS_ROOT = "C:\path\to\agents-catalog"
# или
$env:AGENTS_ROOT = "/path/to/agents-catalog"

# 1) В репозитории-потребителе создать AGENTS.md по шаблону
# 2) При необходимости создать AGENTS.override.md
# 3) Для QUEST использовать центральный $env:AGENTS_ROOT\templates\specs\_template.md
# 4) Проверить, что ссылки на центральный каталог валидны
```

## 2) Пример быстрого подключения из внешнего репозитория

```powershell
git clone https://github.com/<owner>/<repo>.git .agents-catalog
$env:AGENTS_ROOT = "$PWD\.agents-catalog"
```

В локальном `AGENTS.md` укажите `<AGENTS_ROOT>\AGENTS.md`.
Для `QUEST`-workflow агент создаёт итоговую спецификацию в локальном `.\specs\`, а canonical template берёт из `<AGENTS_ROOT>\templates\specs\_template.md`.

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/onboarding/AGENTS.consumer.template.md](./AGENTS.consumer.template.md)
- [instructions/onboarding/AGENTS.override.template.md](./AGENTS.override.template.md)
- [instructions/governance/document-contract.md](../governance/document-contract.md)
