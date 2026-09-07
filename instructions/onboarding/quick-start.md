# Onboarding: Quick Start

## Когда применять

- Нужно подключить единый каталог агентских инструкций к новому локальному репозиторию.
- Нужно быстро стартовать без копирования большого объема правил.

## Когда не применять

- Если репозиторий уже использует этот каталог и контракт подключения не меняется.

## MUST

- Выбрать схему подключения: local pointer как portable default либо global pointer при проверенном native host loading. В обоих случаях проверить canonical root и применить optional local override после central stack.
- Для local схемы создать `AGENTS.md` по consumer template и указать источник, например `$env:AGENTS_ROOT\AGENTS.md`. Global-only не требует дублирующего local pointer, но не гарантирует загрузку на другом host/CI.
- Если нужны проектные уточнения, добавлять только `AGENTS.override.md` как дополнительные локальные инструкции поверх central stack; этот файл не заменяет central `AGENTS.md` и может только ужесточать `MUST`.
- Проверить фактическую загрузку выбранной схемы; pointer не должен дублировать центральные правила.
- Для `QUEST`-задач сохранять рабочие spec-файлы в локальном `./specs/` репозитория-потребителя.
- Для QUEST выбирать central `_template-small.md` либо `_template.md` в `templates/specs/` по `quest-governance.md`; рабочие specs остаются локальными.
- Для repo-specific SDK/runtime/browser/native dependencies создать проверяемый local-environment preflight по central contract, не скрыто устанавливая toolchain.

## SHOULD

- Добавлять краткое описание, какой профиль использовать по умолчанию в этом репозитории.
- Проверять актуальность ссылок при обновлении центрального каталога.
- Если creative/human-experience задачи должны загружать полный `creator-vibe`, устанавливать его отдельно через системный `skill-installer` с pinned upstream commit; отсутствие полного skill не ломает lightweight central owner.

## MAY

- Добавлять локальные команды проекта в `AGENTS.override.md`, если они не конфликтуют с центральными MUST.

## Команды

```powershell
# Рекомендуемые переменные пути каталога инструкций
$env:AGENTS_ROOT = "C:\path\to\agents-catalog"
# или
$env:AGENTS_ROOT = "/path/to/agents-catalog"

# 1) Для portable схемы создать local AGENTS.md; для verified global-only проверить host loading
# 2) При необходимости создать AGENTS.override.md
# 3) Для QUEST выбрать central template по риску задачи
# 4) Проверить, что ссылки на центральный каталог валидны
# 5) При необходимости подключить templates\codex\local-environment\preflight.ps1 через поддерживаемый Codex Desktop local-environment flow

# 6) Опционально установить полный external creator-vibe
python "$env:USERPROFILE\.codex\skills\.system\skill-installer\scripts\install-skill-from-github.py" `
  --repo bish-x/creator-vibe `
  --path . `
  --ref 58642d69fafc5768627ed16215723c19198c4b4b `
  --name creator-vibe
```

## 2) Пример быстрого подключения из внешнего репозитория

```powershell
git clone https://github.com/<owner>/<repo>.git .agents-catalog
$env:AGENTS_ROOT = "$PWD\.agents-catalog"
```

Для local схемы в `AGENTS.md` укажите `<AGENTS_ROOT>\AGENTS.md`.
Для `QUEST`-workflow агент создаёт итоговую спецификацию в локальном `.\specs\`, а canonical template выбранной формы берёт из `<AGENTS_ROOT>\templates\specs\`.
Если нужен локальный `AGENTS.override.md`, применять его только после central stack как дополнительные локальные инструкции поверх него.

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/core/creator-vibe-lens.md](../core/creator-vibe-lens.md)
- [instructions/onboarding/AGENTS.consumer.template.md](./AGENTS.consumer.template.md)
- [instructions/onboarding/AGENTS.override.template.md](./AGENTS.override.template.md)
- [instructions/governance/document-contract.md](../governance/document-contract.md)
- [instructions/onboarding/local-environment.md](./local-environment.md)
- [templates/codex/local-environment/README.md](../../templates/codex/local-environment/README.md)
