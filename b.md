# RBAC в SaltStack через LDAP / Active Directory

## Оглавление

1. [Общие сведения](#общие-сведения)
2. [Архитектура](#архитектура)
3. [Подготовка LDAP](#подготовка-ldap)
4. [Конфигурация Salt Master](#конфигурация-salt-master)
5. [Конфигурация eAuth через LDAP](#конфигурация-eauth-через-ldap)
6. [Роли и группы AD](#роли-и-группы-ad)
7. [Проверка и диагностика](#проверка-и-диагностика)
8. [Интеграция с SaltGUI](#интеграция-сaltgui)
9. [Решение проблем](#решение-проблем)
10. [Миграция с PAM на LDAP](#миграция-с-pam-на-ldap)

---

## Общие сведения

LDAP-аутентификация позволяет централизованно управлять пользователями и ролями через Active Directory или OpenLDAP. В отличие от PAM, где пользователи создаются локально на сервере Salt Master, LDAP позволяет:

- Аутентифицировать существующих доменных пользователей
- Использовать группы AD для назначения ролей
- Централизованно управлять доступом через групповые политики
- Автоматически отзывать доступ при блокировке учетной записи в AD

### Сравнение PAM vs LDAP

| Критерий | PAM | LDAP / AD |
|----------|-----|-----------|
| Управление пользователями | Локально на каждом master | Централизованно в AD |
| Групповые роли | Нет (только `%group` через системные группы) | Да, через `memberOf` |
| Блокировка доступа | `userdel` / `passwd -l` | Блокировка в AD |
| Много master'ов | Синхронизация пользователей | Одна точка управления |
| Зависимость от сети | Нет | Да, требуется связь с DC |
| SSL/TLS | Не требуется | Обязателен |

---

## Архитектура

```
Пользователь → SaltGUI / CLI → Salt API → Salt Master
                                              |
                                              ▼
                                        LDAP BIND (поиск)
                                              |
                                              ▼
                                    Active Directory / OpenLDAP
                                              |
                                              ▼
                                        Проверка пароля (BIND)
                                              |
                                              ▼
                                        Получение групп (memberOf)
                                              |
                                              ▼
                                        Сопоставление групп → роли Salt
```

### Поток аутентификации

1. Пользователь вводит логин/пароль в SaltGUI
2. Salt Master выполняет LDAP BIND служебной учетной записью для поиска
3. Найден DN пользователя, выполняется BIND с паролем пользователя
4. При успехе — запрашиваются группы (`memberOf`)
5. Группы сопоставляются с ролями в `external_auth`
6. Возвращается токен с правами

---

## Подготовка LDAP

### Требования к Active Directory

| Параметр | Описание |
|----------|----------|
| Сервер(ы) DC | Домен-контроллеры с LDAPS (порт 636) |
| Служебная учетная запись | Для поиска пользователей и групп |
| Группы безопасности | `CN=salt-admins,OU=Groups,...` и `CN=salt-users,OU=Groups,...` |
| SSL-сертификат | Доменный CA или публичный |
| Атрибут `memberOf` | Должен присутствовать у пользователей |

### Создание групп в AD

```powershell
# PowerShell на контроллере домена

# Создать OU для Salt
New-ADOrganizationalUnit -Name "SaltStack" -Path "DC=company,DC=com"

# Создать группы
New-ADGroup -Name "salt-admins" -GroupScope Global -Path "OU=SaltStack,DC=company,DC=com"
New-ADGroup -Name "salt-users" -GroupScope Global -Path "OU=SaltStack,DC=company,DC=com"
New-ADGroup -Name "salt-operators" -GroupScope Global -Path "OU=SaltStack,DC=company,DC=com"

# Добавить пользователей в группы
Add-ADGroupMember -Identity "salt-admins" -Members "ivanov","petrov"
Add-ADGroupMember -Identity "salt-users" -Members "sidorov","kuznetsov"
Add-ADGroupMember -Identity "salt-operators" -Members "smirnov"
```

### Создание служебной учетной записи

```powershell
# Служебный пользователь для Salt (только чтение)
New-ADUser -Name "salt-ldap" `
    -UserPrincipalName "salt-ldap@company.com" `
    -Path "OU=SaltStack,DC=company,DC=com" `
    -AccountPassword (ConvertTo-SecureString "ComplexPassword123!" -AsPlainText -Force) `
    -PasswordNeverExpires $true `
    -CannotChangePassword $true `
    -Enabled $true

# Добавить в группу "Пользователи домена" (уже есть по умолчанию)
```

### Проверка LDAP-запросов (ldapsearch)

```bash
# Установка клиента
apt-get install ldap-utils

# Поиск пользователя
ldapsearch -x -H ldaps://dc.company.com:636 \
    -D "CN=salt-ldap,OU=SaltStack,DC=company,DC=com" \
    -w "ComplexPassword123!" \
    -b "OU=Users,DC=company,DC=com" \
    "(sAMAccountName=ivanov)" \
    memberOf

# Поиск группы
ldapsearch -x -H ldaps://dc.company.com:636 \
    -D "CN=salt-ldap,OU=SaltStack,DC=company,DC=com" \
    -w "ComplexPassword123!" \
    -b "OU=SaltStack,DC=company,DC=com" \
    "(cn=salt-admins)" \
    member
```

---

## Конфигурация Salt Master

### Файл: `/etc/salt/master.d/03-ldap.conf`

```yaml
auth.ldap.server: dc01.company.com
auth.ldap.port: 636
auth.ldap.tls: True
auth.ldap.uri: 'ldaps://dc01.company.com:636/'

# Для нескольких DC (резервирование)
# auth.ldap.server: dc01.company.com,dc02.company.com

# Привязка для поиска (служебная учетная запись)
auth.ldap.binddn: 'CN=salt-ldap,OU=SaltStack,DC=company,DC=com'
auth.ldap.bindpw: 'ComplexPassword123!'

# База поиска пользователей
auth.ldap.basedn: 'OU=Users,DC=company,DC=com'

# Фильтр поиска пользователей
auth.ldap.filter: '(objectClass=user)'

# Альтернативно: фильтр по группе
# auth.ldap.filter: '(memberOf=CN=salt-users,OU=SaltStack,DC=company,DC=com)'

# Атрибут с логином
auth.ldap.accountattributename: 'sAMAccountName'

# Атрибут с именем пользователя для поиска
auth.ldap.userattribute: 'sAMAccountName'

# Группы
auth.ldap.groupou: 'OU=SaltStack'
auth.ldap.groupclass: 'group'
auth.ldap.groupattribute: 'memberOf'

# Для Active Directory специфично
auth.ldap.activedirectory: True

# Таймауты
auth.ldap.timeout: 10
```

### Параметры конфигурации

| Параметр | Значение | Описание |
|----------|----------|----------|
| `auth.ldap.server` | `dc01.company.com` | Сервер LDAP/AD |
| `auth.ldap.port` | `636` | Порт LDAPS (SSL) |
| `auth.ldap.tls` | `True` | Использовать TLS/SSL |
| `auth.ldap.uri` | `ldaps://...` | Полный URI сервера |
| `auth.ldap.binddn` | DN служебной учетки | Для поиска пользователей |
| `auth.ldap.bindpw` | Пароль | Пароль служебной учетки |
| `auth.ldap.basedn` | `OU=Users,...` | Где искать пользователей |
| `auth.ldap.filter` | `(objectClass=user)` | Фильтр поиска |
| `auth.ldap.accountattributename` | `sAMAccountName` | Атрибут логина (AD) |
| `auth.ldap.groupattribute` | `memberOf` | Атрибут групп (AD) |
| `auth.ldap.activedirectory` | `True` | Специфика AD |

---

## Конфигурация eAuth через LDAP

### Файл: `/etc/salt/master.d/04-ldap-auth.conf`

```yaml
external_auth:
  ldap:
    # ========================================
    # Группа: salt-admins (полный доступ)
    # ========================================
    'CN=salt-admins,OU=SaltStack,DC=company,DC=com':
      - .*:
        - .*
      - '@runner':
        - .*
      - '@wheel':
        - .*
      - '@jobs':
        - .*

    # ========================================
    # Группа: salt-operators (управление группами)
    # ========================================
    'CN=salt-operators,OU=SaltStack,DC=company,DC=com':
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
        - jobs.list_jobs
        - jobs.active
      - '@wheel':
        - key.list_all
      - '@jobs':
        - .*

    # ========================================
    # Группа: salt-users (только чтение)
    # ========================================
    'CN=salt-users,OU=SaltStack,DC=company,DC=com':
      - test.ping:
        - '*'
      - grains.items:
        - '*'
      - grains.get:
        - '*'
      - status.uptime:
        - '*'
      - '@runner':
        - manage.status
      - '@wheel':
        - key.list_all
```

### Важные нюансы синтаксиса

| Правило | Описание |
|---------|----------|
| Ключ — полный DN группы | `'CN=salt-admins,OU=SaltStack,DC=company,DC=com'` |
| Кавычки обязательны | Из-за запятых и спецсимволов в DN |
| Регистр важен | `CN=` не то же самое, что `cn=` в некоторых LDAP |
| Пробелы после запятых | В DN обычно нет пробелов: `DC=company,DC=com` |

---

## Роли и группы AD

### Матрица доступа

| Группа AD | Execution | Runner | Wheel | Jobs | Minion'ы |
|-----------|-----------|--------|-------|------|----------|
| `salt-admins` | `.*` | `.*` | `.*` | `.*` | `*` |
| `salt-operators` | `test.*`, `state.*`, `grains.*` | `manage.status`, `jobs.*` | `key.list_all` | `.*` | `web*`, `db*`, `app*` |
| `salt-users` | `test.ping`, `grains.*`, `status.uptime` | `manage.status` | `key.list_all` | Нет | `*` |

### Дополнительные группы (примеры)

```yaml
    # Только production
    'CN=salt-prod,OU=SaltStack,DC=company,DC=com':
      - state.apply:
        - 'G@env:production'
      - test.ping:
        - 'G@env:production'

    # Только staging
    'CN=salt-staging,OU=SaltStack,DC=company,DC=com':
      - state.apply:
        - 'G@env:staging'
      - test.ping:
        - 'G@env:staging'

    # Только конкретный датацентр
    'CN=salt-dc1,OU=SaltStack,DC=company,DC=com':
      - state.apply:
        - 'G@dc:dc1'
      - test.ping:
        - 'G@dc:dc1'
```

---

## Проверка и диагностика

### 1. Проверка подключения к LDAP

```bash
# Проверка порта
nc -zv dc01.company.com 636

# Проверка SSL
openssl s_client -connect dc01.company.com:636 </dev/null

# Проверка LDAPS с ldapsearch
ldapsearch -x -H ldaps://dc01.company.com:636 \
    -D "CN=salt-ldap,OU=SaltStack,DC=company,DC=com" \
    -w 'ComplexPassword123!' \
    -b "DC=company,DC=com" \
    "(sAMAccountName=ivanov)" \
    sAMAccountName memberOf
```

### 2. Проверка через Salt CLI

```bash
# Проверка с указанием eauth
salt -a ldap test.ping '*' --username=ivanov

# Проверка конкретной группы
salt -a ldap state.apply 'web*' --username=smirnov
```

### 3. Проверка через API

```bash
# Получение токена
curl -k https://salt-master:8000/login \
    -d username=ivanov \
    -d password='AD_PASSWORD' \
    -d eauth=ldap

# Вызов с токеном
curl -k https://salt-master:8000 \
    -H "X-Auth-Token: TOKEN" \
    -d client=local \
    -d tgt='*' \
    -d fun=test.ping
```

### 4. Дебаг-режим

```bash
# Остановить службы
systemctl stop salt-api salt-master

# Запуск в дебаг-режиме
salt-master -l debug &
salt-api -l debug &

# В другом терминале — попытка входа
salt -a ldap test.ping '*' --username=ivanov

# Смотреть логи — должны быть строки с "ldap", "bind", "search"
```

### 5. Проверка групп пользователя

```bash
# На контроллере домена (PowerShell)
Get-ADUser -Identity "ivanov" -Properties MemberOf | Select-Object -ExpandProperty MemberOf

# Через ldapsearch
ldapsearch -x -H ldaps://dc01.company.com:636 \
    -D "CN=salt-ldap,OU=SaltStack,DC=company,DC=com" \
    -w 'ComplexPassword123!' \
    -b "OU=Users,DC=company,DC=com" \
    "(sAMAccountName=ivanov)" \
    memberOf
```

---

## Интеграция с SaltGUI

### Настройка входа

| Поле | Значение |
|------|----------|
| URL | `https://salt-master:8000` |
| Username | `ivanov` (sAMAccountName без домена) |
| Password | Пароль из AD |
| eAuth | `ldap` |

### Особенности

- SaltGUI кэширует токен в `localStorage` браузера
- При смене групп в AD токен нужно обновить (выйти и войти)
- Если пользователь удален из группы AD, но токен еще активен — права сохранятся до истечения токена

---

## Решение проблем

### Ошибка: `Failed to authenticate, is this user permitted to execute commands?`

| Причина | Проверка | Решение |
|---------|----------|---------|
| Неверный пароль | Попробовать вход на Windows | Сбросить пароль в AD |
| Пользователь не найден | `ldapsearch` с фильтром | Проверить `basedn` и `filter` |
| Нет прав на выполнение | Пользователь не в группе | Добавить в группу AD |
| LDAPS не работает | `openssl s_client` | Проверить сертификат, порт |

### Ошибка: `LDAPError: invalid credentials`

```yaml
# Проверить binddn и bindpw
auth.ldap.binddn: 'CN=salt-ldap,OU=SaltStack,DC=company,DC=com'
auth.ldap.bindpw: 'ExactPassword!'
```

### Ошибка: `LDAPError: connect error`

```bash
# Проверить сетевую доступность
ping dc01.company.com
telnet dc01.company.com 636

# Проверить DNS
nslookup dc01.company.com

# Проверить SSL-сертификат AD
echo | openssl s_client -connect dc01.company.com:636 2>/dev/null | openssl x509 -noout -dates
```

### Ошибка: Пользователь аутентифицирован, но нет прав

```bash
# Проверить memberOf пользователя
ldapsearch ... "(sAMAccountName=ivanov)" memberOf

# Убедиться, что DN группы в external_auth совпадает с memberOf
# AD обычно возвращает memberOf в формате:
# CN=salt-admins,OU=SaltStack,DC=company,DC=com
```

### Ошибка: Группы не определяются

```yaml
# Для Active Directory важен порядок:
auth.ldap.activedirectory: True
auth.ldap.groupattribute: 'memberOf'
auth.ldap.groupclass: 'group'

# Альтернативно — использовать атрибут user для групп
# (некоторые конфигурации AD требуют this)
auth.ldap.groupattribute_is_dn: True
```

### Токен не обновляет группы

```yaml
# Уменьшить время жизни токена для быстрого применения изменений
# Файл: /etc/salt/master.d/02-api.conf
token_expire: 3600  # 1 час
```

---

## Миграция с PAM на LDAP

### Шаг 1: Подготовка

- Создать группы в AD
- Добавить пользователей в группы
- Создать служебную учетную запись
- Проверить LDAPS

### Шаг 2: Параллельная конфигурация

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
  ldap:
    'CN=salt-admins,OU=SaltStack,DC=company,DC=com':
      - .*:
        - .*
      - '@runner':
        - .*
      - '@wheel':
        - .*
```

### Шаг 3: Тестирование

```bash
# Проверить оба метода
salt -a pam test.ping '*' --username=saltadmin
salt -a ldap test.ping '*' --username=ivanov
```

### Шаг 4: Удаление PAM

```yaml
# Удалить блок pam, оставить только ldap
external_auth:
  ldap:
    ...
```

```bash
systemctl restart salt-master salt-api
```

### Шаг 5: Удаление локальных пользователей

```bash
userdel saltadmin
userdel saltuser
```

---

## Полный пример конфигурации

### `/etc/salt/master.d/03-ldap.conf`

```yaml
auth.ldap.server: dc01.company.com,dc02.company.com
auth.ldap.port: 636
auth.ldap.tls: True
auth.ldap.uri: 'ldaps://dc01.company.com:636/'
auth.ldap.binddn: 'CN=salt-ldap,OU=ServiceAccounts,DC=company,DC=com'
auth.ldap.bindpw: 'SuperSecretPassword!'
auth.ldap.basedn: 'OU=Users,DC=company,DC=com'
auth.ldap.filter: '(objectClass=user)'
auth.ldap.accountattributename: 'sAMAccountName'
auth.ldap.userattribute: 'sAMAccountName'
auth.ldap.groupou: 'OU=SaltStack,DC=company,DC=com'
auth.ldap.groupclass: 'group'
auth.ldap.groupattribute: 'memberOf'
auth.ldap.activedirectory: True
auth.ldap.timeout: 10
```

### `/etc/salt/master.d/04-ldap-auth.conf`

```yaml
external_auth:
  ldap:
    'CN=salt-admins,OU=SaltStack,DC=company,DC=com':
      - .*:
        - .*
      - '@runner':
        - .*
      - '@wheel':
        - .*
      - '@jobs':
        - .*

    'CN=salt-operators,OU=SaltStack,DC=company,DC=com':
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
        - jobs.list_jobs
        - jobs.active
      - '@wheel':
        - key.list_all
      - '@jobs':
        - .*

    'CN=salt-users,OU=SaltStack,DC=company,DC=com':
      - test.ping:
        - '*'
      - grains.items:
        - '*'
      - grains.get:
        - '*'
      - status.uptime:
        - '*'
      - '@runner':
        - manage.status
      - '@wheel':
        - key.list_all
```

---

## Справочник LDAP-фильтров

| Фильтр | Описание |
|--------|----------|
| `(objectClass=user)` | Все пользователи |
| `(sAMAccountName=ivanov)` | Конкретный пользователь |
| `(memberOf=CN=salt-admins,...)` | Пользователи в группе |
| `(&(objectClass=user)(memberOf=...))` | Пользователи в группе (AND) |
| `(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))` | Только активные пользователи |

---

## Изменения и версионирование

| Дата | Автор | Изменение |
|------|-------|-----------|
| 2026-05-29 | — | Начальная версия |
