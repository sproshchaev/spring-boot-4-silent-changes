# spring-boot-4-silent-changes

[![check](https://github.com/sproshchaev/spring-boot-4-silent-changes/actions/workflows/check.yml/badge.svg)](https://github.com/sproshchaev/spring-boot-4-silent-changes/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Эксперимент к статье на Хабре
«[Рецепт отработал, сборка зелёная, а API уже другой](https://habr.com/ru/companies/otus/articles/1088906/)».

Небольшой сервис заказов переводится со Spring Boot 3.5 на 4.0 рецептом OpenRewrite. Рецепт
справляется с кодом и зависимостями, `mvn verify` зелёный, а все девять ответов API отличаются
от прежних. Скрипт снимка контракта ничего не знает о Spring и при миграции не меняется, поэтому
видит то, чего не видят тесты сервиса.

## Запуск

Нужны JDK 21, Maven и `curl`. Свободный порт 18080 (другой задаётся переменной `PORT`).

```bash
git clone https://github.com/sproshchaev/spring-boot-4-silent-changes.git
cd spring-boot-4-silent-changes
./run.sh
```

Первый запуск скачивает зависимости обеих версий Spring Boot и рецепты. `run.sh` собирает всё
с нуля во временном каталоге, клон не меняет и сверяет итог с `expected.txt`. При расхождении
код выхода 1.

## Результат

| Шаг | Сборка и тесты | Ответов изменилось |
|---|---|---|
| Spring Boot 3.5, исходный сервис | зелёная, 2 из 2 | 0 из 9 |
| Spring Boot 4.0 после рецепта | зелёная, 2 из 2 | 9 из 9 |
| плюс `spring.jackson.use-jackson2-defaults=true` | | 1 из 9 |
| плюс `management.endpoint.health.probes.enabled=false` | | 0 из 9 |
| вместо общего флага пять явных настроек Jackson и probes | | 0 из 9 |

Что изменилось после рецепта:

| Ответ | Spring Boot 3.5 | Spring Boot 4.0 |
|---|---|---|
| `01`–`03`, `06`: тело заказа | `"id"` первым, `"status":"PAID"` | `"createdAt"` первым, `"status":"Оплачен"` |
| `04`: `"discountPercent":null` | 201 | 400 |
| `05`: нет поля `discountPercent` | 201 | 400 |
| `07`: лишний JSON после тела | 201 | 400 |
| `08`: на входе `{"status":"PAID"}` | 200 | 400 |
| `09`: `/actuator/health` | `{"status":"UP"}` | добавилось `"groups":["liveness","readiness"]` |

Контрольный тест `OrderContractCheck` сверяет тело ответа точно и отправляет `null`. На 3.5 он
зелёный, на 4.0 падают оба его теста. Обычный `mvn verify` его не запускает: имя класса не подходит
под шаблон Surefire. Так и видно, что дело в глубине проверки: тот же Spring Boot 4 с тестом на
контракт сборку бы уронил.

Пять явных настроек:

```properties
spring.jackson.mapper.sort-properties-alphabetically=false
spring.jackson.datatype.enum.write-enums-using-to-string=false
spring.jackson.datatype.enum.read-enums-using-to-string=false
spring.jackson.deserialization.fail-on-null-for-primitives=false
spring.jackson.deserialization.fail-on-trailing-tokens=false
```

## Границы эксперимента

- Ловушки заложены намеренно: enum с собственным `toString()`, примитив `int` в запросе, обычный
  класс вместо record, тесты без проверки `status`. Девять из девяти показывают механизм, а не долю
  таких поломок в реальных сервисах.
- Рецепт зафиксирован (`rewrite-maven-plugin` 6.46.1, `rewrite-spring` 6.37.1), но выбирает
  свежую версию линейки 4.0. В прогоне это 4.0.9, `run.sh` печатает точную версию отдельной строкой
  и не сверяет её. Новая версия линейки или рецепта может изменить итог, тогда `run.sh` покажет,
  что именно.
- База H2 в памяти: сервис нужен ради HTTP-контракта, поведение СУБД здесь не проверяется.
- OpenRewrite пропускает файлы, игнорируемые git, и при этом пишет `BUILD SUCCESS`. Поэтому
  `run.sh` работает во временном каталоге вне клона и падает, если родитель не сменился на 4.x.

## Структура

```text
service/                  сервис на Spring Boot 3.5
  .../OrderControllerTest.java   обычные тесты, идут в mvn verify
  .../OrderContractCheck.java    контрольный тест на точный контракт
contract/capture.sh       снимок контракта: запускает jar и записывает девять ответов
contract/golden/          эталонные ответы версии 3.5
run.sh                    вся цепочка
expected.txt              ожидаемый итог run.sh
```

## Источники

- [Spring Boot 4.0 Migration Guide](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide)
- [Introducing Jackson 3 support in Spring](https://spring.io/blog/2025/10/07/introducing-jackson-3-support-in-spring)
- [Migrating to Jackson 3](https://github.com/FasterXML/jackson/blob/main/jackson3/MIGRATING_TO_JACKSON_3.md)
- [Рецепт UpgradeSpringBoot_4_0](https://docs.openrewrite.org/recipes/java/spring/boot4/upgradespringboot_4_0-community-edition)

## Лицензия

[MIT](LICENSE)
