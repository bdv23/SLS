Вот обновлённые LDIF-файлы с доменом `sc.local` и хешами паролей `Qwerty123!`:

---

`groups.ldif`

```ldif
dn: ou=groups,dc=sc,dc=local
objectClass: organizationalUnit
ou: groups

dn: cn=salt-admins,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-admins
member: cn=placeholder,dc=sc,dc=local

dn: cn=salt-operators,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-operators
member: cn=placeholder,dc=sc,dc=local

dn: cn=salt-users,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-users
member: cn=placeholder,dc=sc,dc=local
```

---

`users.ldif`

```ldif
dn: ou=users,dc=sc,dc=local
objectClass: organizationalUnit
ou: users

dn: uid=i.ivanov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: i.ivanov
cn: Ivan Ivanov
sn: Ivanov
givenName: Ivan
userPassword: {SSHA}Lx/ycws3bSH01DJZnLNFUlCjgYlAg/7Y
mail: i.ivanov@sc.local

dn: uid=p.petrov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: p.petrov
cn: Petr Petrov
sn: Petrov
givenName: Petr
userPassword: {SSHA}Lx/ycws3bSH01DJZnLNFUlCjgYlAg/7Y
mail: p.petrov@sc.local

dn: uid=s.sidorov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: s.sidorov
cn: Sidor Sidorov
sn: Sidorov
givenName: Sidor
userPassword: {SSHA}Lx/ycws3bSH01DJZnLNFUlCjgYlAg/7Y
mail: s.sidorov@sc.local
```

---

Конфиг Salt Master (`03-openldap.conf`)

```yaml
auth.ldap.server: localhost
auth.ldap.port: 389
auth.ldap.tls: False
auth.ldap.uri: 'ldap://localhost:389/'

auth.ldap.binddn: 'cn=admin,dc=sc,dc=local'
auth.ldap.bindpw: 'admin123'

auth.ldap.basedn: 'dc=sc,dc=local'
auth.ldap.filter: '(objectClass=inetOrgPerson)'

auth.ldap.accountattributename: 'uid'
auth.ldap.userattribute: 'uid'

auth.ldap.groupou: 'ou=groups'
auth.ldap.groupclass: 'groupOfNames'
auth.ldap.groupattribute: 'member'

auth.ldap.activedirectory: False
auth.ldap.timeout: 10
```

---

eAuth (`04-openldap-auth.conf`)

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

Команды для запуска и импорта

```bash
# Запуск контейнера
docker run -d -p 389:389 -p 636:636 --name openldap \
  -e LDAP_ORGANISATION="SC" \
  -e LDAP_DOMAIN="sc.local" \
  -e LDAP_ADMIN_PASSWORD="admin123" \
  osixia/openldap:latest

# Копировать LDIF
docker cp groups.ldif openldap:/tmp/
docker cp users.ldif openldap:/tmp/

# Импорт групп
docker exec openldap ldapadd -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -f /tmp/groups.ldif

# Импорт пользователей
docker exec openldap ldapadd -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -f /tmp/users.ldif

# Добавить i.ivanov в salt-admins
docker exec openldap ldapmodify -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 <<EOF
dn: cn=salt-admins,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=i.ivanov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local
EOF

# Добавить p.petrov в salt-operators
docker exec openldap ldapmodify -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 <<EOF
dn: cn=salt-operators,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=p.petrov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local
EOF

# Добавить s.sidorov в salt-users
docker exec openldap ldapmodify -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 <<EOF
dn: cn=salt-users,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=s.sidorov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local
EOF
```

---

Проверка

```bash
# Поиск пользователя
docker exec openldap ldapsearch -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -b "dc=sc,dc=local" \
  "(uid=i.ivanov)" \
  uid cn memberOf

# Проверка группы
docker exec openldap ldapsearch -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -b "cn=salt-admins,ou=groups,dc=sc,dc=local" \
  cn member
```

---

Проверка из Salt

```bash
# Проверка аутентификации
salt -a ldap test.ping '*' --username=i.ivanov
# Пароль: Qwerty123!
```





Вот обновлённые LDIF-файлы с доменом `sc.local` и хешами паролей `Qwerty123!`:

---

`groups.ldif`

```ldif
dn: ou=groups,dc=sc,dc=local
objectClass: organizationalUnit
ou: groups

dn: cn=salt-admins,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-admins
member: cn=placeholder,dc=sc,dc=local

dn: cn=salt-operators,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-operators
member: cn=placeholder,dc=sc,dc=local

dn: cn=salt-users,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-users
member: cn=placeholder,dc=sc,dc=local
```

---

`users.ldif`

```ldif
dn: ou=users,dc=sc,dc=local
objectClass: organizationalUnit
ou: users

dn: uid=i.ivanov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: i.ivanov
cn: Ivan Ivanov
sn: Ivanov
givenName: Ivan
userPassword: {SSHA}Lx/ycws3bSH01DJZnLNFUlCjgYlAg/7Y
mail: i.ivanov@sc.local

dn: uid=p.petrov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: p.petrov
cn: Petr Petrov
sn: Petrov
givenName: Petr
userPassword: {SSHA}Lx/ycws3bSH01DJZnLNFUlCjgYlAg/7Y
mail: p.petrov@sc.local

dn: uid=s.sidorov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: s.sidorov
cn: Sidor Sidorov
sn: Sidorov
givenName: Sidor
userPassword: {SSHA}Lx/ycws3bSH01DJZnLNFUlCjgYlAg/7Y
mail: s.sidorov@sc.local
```

---

Конфиг Salt Master (`03-openldap.conf`)

```yaml
auth.ldap.server: localhost
auth.ldap.port: 389
auth.ldap.tls: False
auth.ldap.uri: 'ldap://localhost:389/'

auth.ldap.binddn: 'cn=admin,dc=sc,dc=local'
auth.ldap.bindpw: 'admin123'

auth.ldap.basedn: 'dc=sc,dc=local'
auth.ldap.filter: '(objectClass=inetOrgPerson)'

auth.ldap.accountattributename: 'uid'
auth.ldap.userattribute: 'uid'

auth.ldap.groupou: 'ou=groups'
auth.ldap.groupclass: 'groupOfNames'
auth.ldap.groupattribute: 'member'

auth.ldap.activedirectory: False
auth.ldap.timeout: 10
```

---

eAuth (`04-openldap-auth.conf`)

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

Команды для запуска и импорта

```bash
# Запуск контейнера
docker run -d -p 389:389 -p 636:636 --name openldap \
  -e LDAP_ORGANISATION="SC" \
  -e LDAP_DOMAIN="sc.local" \
  -e LDAP_ADMIN_PASSWORD="admin123" \
  osixia/openldap:latest

# Копировать LDIF
docker cp groups.ldif openldap:/tmp/
docker cp users.ldif openldap:/tmp/

# Импорт групп
docker exec openldap ldapadd -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -f /tmp/groups.ldif

# Импорт пользователей
docker exec openldap ldapadd -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -f /tmp/users.ldif

# Добавить i.ivanov в salt-admins
docker exec openldap ldapmodify -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 <<EOF
dn: cn=salt-admins,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=i.ivanov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local
EOF

# Добавить p.petrov в salt-operators
docker exec openldap ldapmodify -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 <<EOF
dn: cn=salt-operators,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=p.petrov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local
EOF

# Добавить s.sidorov в salt-users
docker exec openldap ldapmodify -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 <<EOF
dn: cn=salt-users,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=s.sidorov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local
EOF
```

---

Проверка

```bash
# Поиск пользователя
docker exec openldap ldapsearch -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -b "dc=sc,dc=local" \
  "(uid=i.ivanov)" \
  uid cn memberOf

# Проверка группы
docker exec openldap ldapsearch -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -b "cn=salt-admins,ou=groups,dc=sc,dc=local" \
  cn member
```

---

Проверка из Salt

```bash
# Проверка аутентификации
salt -a ldap test.ping '*' --username=i.ivanov
# Пароль: Qwerty123!
```