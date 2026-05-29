Проблема найдена: `member: cn=placeholder,dc=sc,dc=local` — пользователь не добавлен в группу `salt-admins`. Добавление в группы не сработало.

Давай сделаем всё с нуля, пошагово, и проверим каждый шаг.

---

Шаг 1: Удалить старый контейнер

```bash
docker stop openldap
docker rm openldap
```

---

Шаг 2: Запустить новый контейнер

```bash
docker run -d -p 389:389 -p 636:636 --name openldap \
  -e LDAP_ORGANISATION="SC" \
  -e LDAP_DOMAIN="sc.local" \
  -e LDAP_ADMIN_PASSWORD="admin123" \
  osixia/openldap:latest
```

---

Шаг 3: Подождать 15 секунд

```bash
sleep 15
```

---

Шаг 4: Создать полный LDIF

```bash
cat > /tmp/full.ldif <<'EOF'
# Структура
dn: ou=groups,dc=sc,dc=local
objectClass: organizationalUnit
ou: groups

dn: ou=users,dc=sc,dc=local
objectClass: organizationalUnit
ou: users

# Группы (без placeholder — сразу с правильными member)
dn: cn=salt-admins,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-admins
member: uid=i.ivanov,ou=users,dc=sc,dc=local

dn: cn=salt-operators,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-operators
member: uid=p.petrov,ou=users,dc=sc,dc=local

dn: cn=salt-users,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-users
member: uid=s.sidorov,ou=users,dc=sc,dc=local

# Пользователи
dn: uid=i.ivanov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: i.ivanov
cn: Ivan Ivanov
sn: Ivanov
givenName: Ivan
userPassword: Qwerty123!
mail: i.ivanov@sc.local

dn: uid=p.petrov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: p.petrov
cn: Petr Petrov
sn: Petrov
givenName: Petr
userPassword: Qwerty123!
mail: p.petrov@sc.local

dn: uid=s.sidorov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: s.sidorov
cn: Sidor Sidorov
sn: Sidorov
givenName: Sidor
userPassword: Qwerty123!
mail: s.sidorov@sc.local
EOF
```

---

Шаг 5: Загрузить в LDAP

```bash
docker cp /tmp/full.ldif openldap:/tmp/
docker exec openldap ldapadd -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -f /tmp/full.ldif
```

---

Шаг 6: Проверить структуру

```bash
# Все записи
docker exec openldap ldapsearch -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -b "dc=sc,dc=local" \
  "(objectClass=*)" \
  dn

# Должно быть:
# dn: dc=sc,dc=local
# dn: cn=admin,dc=sc,dc=local
# dn: ou=groups,dc=sc,dc=local
# dn: ou=users,dc=sc,dc=local
# dn: cn=salt-admins,ou=groups,dc=sc,dc=local
# dn: cn=salt-operators,ou=groups,dc=sc,dc=local
# dn: cn=salt-users,ou=groups,dc=sc,dc=local
# dn: uid=i.ivanov,ou=users,dc=sc,dc=local
# dn: uid=p.petrov,ou=users,dc=sc,dc=local
# dn: uid=s.sidorov,ou=users,dc=sc,dc=local
```

---

Шаг 7: Проверить группу

```bash
docker exec openldap ldapsearch -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -b "cn=salt-admins,ou=groups,dc=sc,dc=local" \
  member

# Должно быть:
# member: uid=i.ivanov,ou=users,dc=sc,dc=local
# НЕ должно быть placeholder!
```

---

Шаг 8: Проверить аутентификацию

```bash
docker exec openldap ldapwhoami -x \
  -D "uid=i.ivanov,ou=users,dc=sc,dc=local" \
  -w "Qwerty123!"
```

---

Шаг 9: Конфиг Salt Master

Создайте файл `/etc/salt/master.d/03-openldap.conf`:

```yaml
auth.ldap.server: localhost
auth.ldap.port: 389
auth.ldap.tls: False
auth.ldap.uri: 'ldap://localhost:389/'

auth.ldap.binddn: 'cn=admin,dc=sc,dc=local'
auth.ldap.bindpw: 'admin123'

auth.ldap.basedn: 'dc=sc,dc=local'
auth.ldap.filter: '(uid=%s)'

auth.ldap.accountattributename: 'uid'
auth.ldap.userattribute: 'uid'

auth.ldap.groupou: 'ou=groups,dc=sc,dc=local'
auth.ldap.groupclass: 'groupOfNames'
auth.ldap.groupattribute: 'member'

auth.ldap.activedirectory: False
auth.ldap.timeout: 10
```

---

Шаг 10: Конфиг eAuth

Создайте файл `/etc/salt/master.d/04-openldap-auth.conf`:

```yaml
external_auth:
  ldap:
    'cn=salt-admins,ou=groups,dc=sc,dc=local':
      - .*:
        - .*
      - '@runner':
        - .*
      - '@wheel':
        - .*
      - '@jobs':
        - .*

    'cn=salt-operators,ou=groups,dc=sc,dc=local':
      - test.ping:
        - 'web*'
        - 'db*'
      - state.apply:
        - 'web*'
        - 'db*'
      - '@runner':
        - manage.status
      - '@wheel':
        - key.list_all

    'cn=salt-users,ou=groups,dc=sc,dc=local':
      - test.ping:
        - '*'
      - grains.items:
        - '*'
```

---

Шаг 11: Перезапуск и проверка

```bash
sudo systemctl restart salt-master salt-api

# Проверка
salt -a ldap test.ping '*' --username=i.ivanov
```

---

Если всё ещё падает

Включите дебаг:

```bash
sudo systemctl stop salt-master salt-api

sudo salt-master -l debug > /tmp/salt-debug.log 2>&1 &
sudo salt-api -l debug > /tmp/api-debug.log 2>&1 &

# В другом терминале
salt -a ldap test.ping '*' --username=i.ivanov

# Посмотрите логи
grep -i "ldap\|auth\|bind" /tmp/salt-debug.log
```

Пришлите вывод — разберёмся.