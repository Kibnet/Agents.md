# Profile: Python Hardware GPIO

## Когда применять

- Python-приложение управляет железом (GPIO/serial/PWM/sensor IO).
- Есть разделение между реальным hardware layer и mock/simulation режимом.

## Когда не применять

- Для .NET и frontend проектов.
- Для Python backend задач без аппаратного взаимодействия.

## MUST

- Сохранять совместимость поведения между mock-слоем и реальным hardware API.
- Гарантировать освобождение ресурсов (cleanup GPIO, закрытие портов/дескрипторов).
- Критические аппаратные параметры хранить в конфигурации, а не в hardcoded значениях.
- Изменения логики сопровождать автотестами на mock-режиме.

## SHOULD

- Отдельно проверять сценарии безопасной остановки и повторного запуска устройства.
- По возможности подтверждать ключевые сценарии на реальном оборудовании.

## MAY

- Добавлять диагностическое логирование для фоновых hardware-thread/process задач.

## Команды

```powershell
python -m pytest
python <path-to-app-entrypoint.py>
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/core/testing-baseline.md](../core/testing-baseline.md)
