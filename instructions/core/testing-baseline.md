# Core: Testing Baseline

## Когда применять

- Для любых изменений кода, влияющих на поведение системы.
- Для исправления багов и регрессий.

## Когда не применять

- Для чисто документальных правок без изменения поведения.
- Для временных черновиков, которые не попадают в основной поток изменений.

## MUST

- Любые изменения поведения покрывать автоматическими тестами.
- При багфиксе использовать `Test-Driven Debug`: сначала падающий тест, потом фикс.
- Выполнять staged validation: characterization/failing check -> targeted tests -> affected build -> полный набор тестов.
- До длинного шага сообщать команду, repo-specific expected duration и способ получить progress/log evidence; универсальный time budget не вводить.
- После timeout не повторять идентичную команду. Сначала получить progress/root-cause evidence, изменить scope/ресурсы или устранить lock/environment blocker.
- Перед завершением behavior-changing задачи получать successful full test run. Authoritative CI допустим как эквивалент только если это прямо разрешает repo owner contract и итоговый статус green; `pending`, `timeout`, `cancelled` и red не являются evidence.
- Expected TDD red считать запланированным только когда failing check создан до fix и причина падения подтверждена; wrong runner, compile error и unrelated failure ожидаемым red не являются.
- Оставлять regression-тест в кодовой базе.

## SHOULD

- Покрывать happy path, граничные условия, невалидные входы и edge cases.
- Сохранять тесты независимыми и детерминированными.
- В отчете указывать, какие команды запускались и что они подтвердили.
- При невозможности получить full green run завершать задачу как incomplete/blocker с next-best evidence, а не как успешно проверенную.

## MAY

- Использовать дополнительные профильные требования по coverage/типам тестов.

## Команды

```powershell
# Универсальные этапы проверки
# 1) characterization / expected red
# 2) targeted tests
# 3) affected build
# 4) полный прогон тестов или repo-approved authoritative CI до final green
```

## Связанные документы

- [AGENTS.md](../../AGENTS.md)
- [instructions/contexts/testing-dotnet.md](../contexts/testing-dotnet.md)
- [instructions/contexts/testing-frontend.md](../contexts/testing-frontend.md)
