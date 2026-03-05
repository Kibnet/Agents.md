# Profile: .NET + RavenDB

## Когда применять

- Проект на .NET использует RavenDB как основное хранилище.
- Изменяются документы, индексы, запросы, проекции или слой доступа к данным.

## Когда не применять

- Для .NET проектов без RavenDB.
- Для frontend и Python-проектов.

## MUST

- Любые изменения структуры данных/индексов сопровождать планом миграции и отката.
- Проверять обратную совместимость чтения существующих документов.
- Для изменений запросов и индексов добавлять integration тесты.
- Перед завершением запускать `dotnet build` и `dotnet test`.

## SHOULD

- Проверять идемпотентность инициализации БД/индексов на первом запуске.
- Документировать требования к локальному окружению (порт, имя БД, seed).

## MAY

- Использовать локальный контейнер RavenDB для smoke/integration проверки.

## Команды

```powershell
docker-compose up
dotnet build
dotnet test
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-dotnet.md](../contexts/testing-dotnet.md)
- [instructions/profiles/dotnet-backend-api.md](./dotnet-backend-api.md)
