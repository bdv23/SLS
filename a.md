# RBAC в SaltStack

## Оглавление

1. [Общие сведения](#общие-сведения)
2. [Архитектура](#архитектура)
3. [Подготовка](#подготовка)
4. [Конфигурация eAuth](#конфигурация-eauth)
5. [Конфигурация Salt API](#конфигурация-salt-api)
6. [Роли](#роли)
7. [Права доступа](#права-доступа)
8. [SaltGUI](#saltgui)
9. [Диагностика](#диагностика)
10. [Решение проблем](#решение-проблем)

---

## Общие сведения

RBAC (Role-Based Access Control) в SaltStack реализуется через механизм **eAuth** (external authentication). Salt не имеет встроенной системы пользователей — аутентификация делегируется внешним системам: PAM, LDAP, Active Directory, REST API, базы данных.

### Компоненты

| Компонент | Назначение |
|-----------|-----------|
| `external_auth` | Конфигурация аутентификации и прав |
| `salt-api` | REST API для внешних клиентов (GUI, скрипты) |
| `salt-master` | Проверяет права перед выполнением команд |
| PAM / LDAP | Внешний источник проверки логина/пароля |

---

## Архитектура

```
Пользователь → SaltGUI / CLI → Salt API (:8000) → Salt Master → eAuth → PAM/LDAP
                                                          ↓
                                               Проверка прав в master.conf
                                                          ↓
                                               Execution / Runner / Wheel / Jobs
```

### Типы модулей

| Тип | Где выполняется | Примеры |
|-----|----------------|---------|
| **Execution** | На minion | `test.ping`, `state.apply`, `cmd.run` |
| **Runner** | На master | `manage.status`, `jobs.list_jobs` |
| **Wheel** | На master | `key.list_all`, `key.accept` |
| **Jobs** | На master | Управление асинхронными задачами |

---

## Подготовка

### 1. Создание системных пользователей

```bash
# Администратор
useradd -m -s /bin/bash saltadmin
passwd saltadmin

# Оператор
useradd -m -s /bin/bash saltuser
passwd saltuser

# Добавление в группу salt (опционально)
usermod -aG salt saltadmin
usermod -aG salt saltuser
```

### 2. Установка salt-api

```bash
# Debian/Ubuntu
apt-get install salt-api

# RHEL/CentOS/Rocky
dnf install salt-api

# Включение в автозагрузку
systemctl enable salt-api
```

### 3. Генерация SSL-сертификатов

```bash
mkdir -p /etc/pki/tls/certs /etc/pki/tls/private

openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout /etc/pki/tls/private/salt-api.key \
  -out /etc/pki/tls/certs/salt-api.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=salt-master"

chmod 600 /etc/pki/tls/private/salt-api.key
```

---

## Конфигурация eAuth

### Файл: `/etc/salt/master.d/01-rbac.conf`

```yaml
external_auth:
  pam:
    saltadmin:
      - .*:
        - .*
      - '@runner':
        - .*
      - '@wheel':
        - .*
      - '@jobs':
        - .*

    saltuser:
      - test.ping:
        - 'web*'
        - 'db*'
        - 'app*'
      - state.apply:
        - 'web*'
        - 'db*'
        - 'app*'
      - state.sls:
        - 'web*'
        - 'db*'
        - 'app*'
      - state.highstate:
        - 'web*'
        - 'db*'
        - 'app*'
      - grains.items:
        - 'web*'
        - 'db*'
        - 'app*'
      - grains.get:
        - 'web*'
        - 'db*'
        - 'app*'
      - '@runner':
        - manage.status
      - '@wheel':
        - key.list_all
      - '@jobs':
        - .*
```

### Синтаксис прав

```
- <модуль.функция>:
    - '<шаблон minion>'
```

| Символ | Значение |
|--------|----------|
| `.*` | Все символы (все модули / все minion'ы) |
| `*` | В шаблоне minion — любые символы |
| `web*` | Имена, начинающиеся с `web` |
| `@runner` | Специальный тип — runner-модули |
| `@wheel` | Специальный тип — wheel-модули |
| `@jobs` | Специальный тип — управление задачами |

---

## Конфигурация Salt API

### Файл: `/etc/salt/master.d/02-api.conf`

```yaml
rest_cherrypy:
  port: 8000
  host: 0.0.0.0
  ssl_crt: /etc/pki/tls/certs/salt-api.crt
  ssl_key: /etc/pki/tls/private/salt-api.key

token_expire: 43200
```

### Параметры

| Параметр | Значение | Описание |
|----------|----------|----------|
| `port` | `8000` | TCP-порт API |
| `host` | `0.0.0.0` | Слушать на всех интерфейсах |
| `ssl_crt` | путь | Сертификат HTTPS |
| `ssl_key` | путь | Приватный ключ |
| `token_expire` | `43200` | Время жизни токена (сек) = 12 часов |

### Применение конфигурации

```bash
systemctl restart salt-master
systemctl restart salt-api
```

---

## Роли

### saltadmin (полный доступ)

| Право | Область |
|-------|---------|
| Все execution-модули | Все minion'ы |
| Все runner'ы | Все данные master |
| Все wheel-команды | Управление ключами, конфигурацией |
| Все jobs | Полный доступ к задачам |

### saltuser (ограниченный доступ)

| Право | Область |
|-------|---------|
| `test.ping` | `web*`, `db*`, `app*` |
| `state.apply`, `state.sls`, `state.highstate` | `web*`, `db*`, `app*` |
| `grains.items`, `grains.get` | `web*`, `db*`, `app*` |
| `manage.status` (runner) | Все (только чтение статуса) |
| `key.list_all` (wheel) | Все (только чтение ключей) |
| Все jobs | Все (только просмотр) |

**Запрещено:** `cmd.run`, `pkg.install`, управление ключами (`key.accept`, `key.delete`), доступ к `cache*`, `mon*`, `log*` и другим группам minion'ов.

---

## Права доступа

### Execution-модули

| Модуль | Описание | Требуется для GUI |
|--------|----------|-------------------|
| `test.ping` | Проверка доступности | Да |
| `state.apply` | Применить state | Да |
| `state.sls` | Применить SLS-файл | Да |
| `state.highstate` | Полный прогон | Да |
| `grains.items` | Все grain'ы | Да |
| `grains.get` | Один grain | Нет |
| `cmd.run` | Выполнить команду | Нет |
| `pkg.install` | Установить пакет | Нет |

### Runner-модули

| Модуль | Описание | Требуется для GUI |
|--------|----------|-------------------|
| `manage.status` | Up/down minion'ов | **Критично** |
| `manage.list_state` | Список состояний | Нет |
| `jobs.list_jobs` | История задач | Да |
| `jobs.active` | Активные задачи | Да |
| `jobs.lookup_jid` | Результат задачи | Да |
| `fileserver.*` | Файловый сервер | Нет |

### Wheel-модули

| Модуль | Описание | Требуется для GUI |
|--------|----------|-------------------|
| `key.list_all` | Список ключей | **Критично** |
| `key.finger` | Отпечатки | Нет |
| `key.accept` | Принять ключ | Нет (только админ) |
| `key.delete` | Удалить ключ | Нет (только админ) |
| `config.update` | Изменить конфиг | Нет (только админ) |

---

## SaltGUI

### Подключение

```
https://salt-master:8000/
```

### Вход

| Поле | Значение для saltadmin | Значение для saltuser |
|------|------------------------|----------------------|
| Username | `saltadmin` | `saltuser` |
| Password | пароль из `passwd` | пароль из `passwd` |
| eAuth | `pam` | `pam` |

### Поведение ролей в GUI

| Функция GUI | saltadmin | saltuser |
|-------------|-----------|----------|
| Видеть все minion'ы | Да | Только `web*`, `db*`, `app*` |
| Запускать команды | Все | `test.ping`, `state.*` |
| Видеть статус up/down | Да | Да |
| Видеть ключи | Да | Да (только список) |
| Принимать/удалять ключи | Да | Нет |
| Видеть историю задач | Да | Да |
| Видеть grain'ы | Да | Да |

---

## Диагностика

### Проверка конфигурации

```bash
salt-master --verify-config
```

### Проверка eAuth через CLI

```bash
# Администратор
salt -a pam test.ping '*' --username=saltadmin

# Пользователь (разрешено)
salt -a pam test.ping 'web*' --username=saltuser

# Пользователь (запрещено — должна быть ошибка)
salt -a pam cmd.run 'whoami' 'web*' --username=saltuser
```

### Проверка через API (curl)

```bash
# 1. Получить токен
curl -k https://localhost:8000/login \
  -d username=saltuser \
  -d password=PASSWORD \
  -d eauth=pam

# 2. Вызвать execution (test.ping)
curl -k https://localhost:8000 \
  -H "X-Auth-Token: TOKEN" \
  -d client=local \
  -d tgt='web*' \
  -d fun=test.ping

# 3. Вызвать runner (manage.status)
curl -k https://localhost:8000 \
  -H "X-Auth-Token: TOKEN" \
  -d client=runner \
  -d fun=manage.status

# 4. Вызвать wheel (key.list_all)
curl -k https://localhost:8000 \
  -H "X-Auth-Token: TOKEN" \
  -d client=wheel \
  -d fun=key.list_all
```

### Логи

```bash
# Логи API
journalctl -u salt-api -f

# Логи master
tail -f /var/log/salt/master

# Дебаг-режим API
salt-api -l debug
```

---

## Решение проблем

### Ошибка: `Authorization error occurred`

| Причина | Решение |
|---------|---------|
| Нет прав на модуль | Добавить модуль в `external_auth` |
| Нет прав на minion | Добавить шаблон minion'а |
| Нет `@runner` | Добавить блок `@runner` с нужными runner'ами |
| Нет `@wheel` | Добавить блок `@wheel` с нужными wheel-командами |

### Ошибка: `Pam unable to dlopen(pam_lastlog.so)`

```bash
# Найти и закомментировать
grep -rl "pam_lastlog" /etc/pam.d/ | xargs sed -i 's/^.*pam_lastlog/# &/'

# Или заменить на pam_lastlog2
sed -i 's/pam_lastlog\.so/pam_lastlog2.so/g' /etc/pam.d/*

systemctl restart salt-api salt-master
```

### Ошибка: SaltGUI не пускает пользователя

**Причина:** GUI требует `manage.status` (runner) и `key.list_all` (wheel).

**Решение:**

```yaml
saltuser:
  # ... execution модули ...
  - '@runner':
    - manage.status
  - '@wheel':
    - key.list_all
```

### Ошибка: `Token expired`

```yaml
# Увеличить время жизни в 02-api.conf
token_expire: 86400  # 24 часа
```

### Ошибка: SSL certificate verify failed

```bash
# Для curl использовать -k (insecure)
curl -k https://localhost:8000/...

# Или добавить сертификат в доверенные
cp /etc/pki/tls/certs/salt-api.crt /usr/local/share/ca-certificates/
update-ca-certificates
```

---

## Справочник шаблонов minion'ов

| Шаблон | Значение | Примеры |
|--------|----------|---------|
| `*` | Все minion'ы | Любое имя |
| `web*` | Начинается с `web` | web01, web-prod |
| `web??` | web + 2 символа | web01, web02 |
| `L@web01,web02` | Список (literal) | Только web01 и web02 |
| `N@webservers` | Nodegroup | Группа из master.conf |
| `G@os:Ubuntu` | По grain | Все Ubuntu |
| `E@web.*\.prod` | Регулярное выражение | web01.prod, web02.prod |
| `web* and G@env:staging` | Compound | web + staging |

---

## Изменения и версионирование

| Дата | Автор | Изменение |
|------|-------|-----------|
| 2026-05-29 | — | Начальная версия |
