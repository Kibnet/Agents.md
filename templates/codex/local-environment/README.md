# Local environment checklist

Текстовая инструкция read-only preflight для consumer-репозитория. Исполнимый `preflight.ps1` не поставляется; точные commands и actions задаются рядом с кодом проекта по [local-environment owner](../../../instructions/onboarding/local-environment.md).

## Проверка

1. Установите фактические required/optional commands, SDK/runtime/workloads, paths, browser/native dependencies и разрешённые endpoints проекта.
2. Выполните read-only discovery/проверки версии и доступности. Missing required dependency — failure, optional dependency — warning. Отделяйте auth/network blocker от product failure.
3. Не устанавливайте tools, certificates, browser или credentials без отдельного разрешения. Не храните secrets, private endpoints и author-specific paths в versioned шаблоне.
4. Setup/actions подключайте через поддерживаемую host поверхность; не изобретайте undocumented config schema и не заявляйте CLI support без подтверждённого contract.
5. Сохраняйте machine-readable summary и краткий human-readable результат, commands, длительность, progress/log и repo-specific timeout strategy. Затем выполняйте targeted/full tests и build проекта в их разрешённом scope.

Network checks выполняйте только для явно переданных endpoints. TCP-connect подтверждает только соединение; HTTP-ответ, TLS и авторизация требуют отдельных consumer checks. Доступный TCP-порт не доказывает готовность приложения. Указывайте уровень проверки и границы evidence.
