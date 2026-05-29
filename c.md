Да, к этому OpenLDAP можно подключиться. Вот конфигурация для SaltStack:

---

Конфигурация Salt Master для OpenLDAP

Файл: `/etc/salt/master.d/03-openldap.conf`

```yaml
auth.ldap.server: localhost
auth.ldap.port: 389
auth.ldap.tls: False
auth.ldap.uri: 'ldap://localhost:389/'

# Привязка для поиска (админ OpenLDAP)
auth.ldap.binddn: 'cn=admin,dc=test,dc=local'
auth.ldap.bindpw: 'admin123'

# База поиска пользователей
auth.ldap.basedn: 'dc=test,dc=local'

# Фильтр поиска
auth.ldap.filter: '(objectClass=inetOrgPerson)'

# Атрибут с логином
auth.ldap.accountattributename: 'uid'
auth.ldap.userattribute: 'uid'

# Группы
auth.ldap.groupou: 'ou=groups'
auth.ldap.groupclass: 'groupOfNames'
auth.ldap.groupattribute: 'member'

# OpenLDAP (не Active Directory)
auth.ldap.activedirectory: False

auth.ldap.timeout: 10
```

---

Создание структуры в OpenLDAP

LDIF-файл для импорта

```ldif
# groups.ldif
dn: ou=groups,dc=test,dc=local
objectClass: organizationalUnit
ou: groups

dn: cn=salt-admins,ou=groups,dc=test,dc=local
objectClass: groupOfNames
cn: salt-admins
member: cn=placeholder,dc=test,dc=local

dn: cn=salt-operators,ou=groups,dc=test,dc=local
objectClass: groupOfNames
cn: salt-operators
member: cn=placeholder,dc=test,dc=local

dn: cn=salt-users,ou=groups,dc=test,dc=local
objectClass: groupOfNames
cn: salt-users
member: cn=placeholder,dc=test,dc=local
```

```ldif
# users.ldif
dn: ou=users,dc=test,dc=local
objectClass: organizationalUnit
ou: users

dn: uid=i.ivanov,ou=users,dc=test,dc=local
objectClass: inetOrgPerson
uid: i.ivanov
cn: Ivan Ivanov
sn: Ivanov
givenName: Ivan
userPassword: {SSHA}password_hash_here
mail: i.ivanov@test.local

dn: uid=p.petrov,ou=users,dc=test,dc=local
objectClass: inetOrgPerson
uid: p.petrov
cn: Petr Petrov
sn: Petrov
givenName: Petr
userPassword: {SSHA}password_hash_here
mail: p.petrov@test.local

dn: uid=s.sidorov,ou=users,dc=test,dc=local
objectClass: inetOrgPerson
uid: s.sidorov
cn: Sidor Sidorov
sn: Sidorov
givenName: Sidor
userPassword: {SSHA}password_hash_here
mail: s.sidorov@test.local
```

Импорт в контейнер

```bash
# Копировать LDIF в контейнер
docker cp groups.ldif openldap:/tmp/
docker cp users.ldif openldap:/tmp/

# Импорт
docker exec openldap ldapadd -x -D "cn=admin,dc=test,dc=local" -w admin123 -f /tmp/groups.ldif
docker exec openldap ldapadd -x -D "cn=admin,dc=test,dc=local" -w admin123 -f /tmp/users.ldif

# Добавить пользователей в группы
docker exec openldap ldapmodify -x -D "cn=admin,dc=test,dc=local" -w admin123 <<EOF
dn: cn=salt-admins,ou=groups,dc=test,dc=local
changetype: modify
add: member
member: uid=i.ivanov,ou=users,dc=test,dc=local
-
delete: member
member: cn=placeholder,dc=test,dc=local
EOF
```

---

Проверка подключения

```bash
# С Salt Master
ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=test,dc=local" \
    -w admin123 \
    -b "dc=test,dc=local" \
    "(uid=i.ivanov)" \
    uid memberOf
```

---

eAuth для OpenLDAP

```yaml
external_auth:
  ldap:
    'cn=salt-admins,ou=groups,dc=test,dc=local':
      - .*:
        - .*
      - '@runner':
        - .*
      - '@wheel':
        - .*
      - '@jobs':
        - .*

    'cn=salt-operators,ou=groups,dc=test,dc=local':
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

    'cn=salt-users,ou=groups,dc=test,dc=local':
      - test.ping:
        - '*'
      - grains.items:
        - '*'
```

---

Различия OpenLDAP vs Active Directory

Параметр	OpenLDAP	Active Directory	
`auth.ldap.activedirectory`	`False`	`True`	
`auth.ldap.accountattributename`	`uid`	`sAMAccountName`	
`auth.ldap.groupattribute`	`member` / `memberOf`	`memberOf`	
`auth.ldap.groupclass`	`groupOfNames`	`group`	
Порт (без TLS)	`389`	`389`	
Порт (LDAPS)	`636`	`636`	
Атрибут имени	`cn`	`cn`	
DN пользователя	`uid=xxx,ou=users`	`CN=xxx,OU=Users`	

---

Проблема: memberOf в OpenLDAP

В OpenLDAP `memberOf` — это overlay, который может быть не включён по умолчанию.

Проверка

```bash
docker exec openldap ldapsearch -x -D "cn=admin,dc=test,dc=local" -w admin123 \
    -b "uid=i.ivanov,ou=users,dc=test,dc=local" memberOf
```

Если `memberOf` пустой или отсутствует — нужно настроить overlay или использовать другой подход.

Альтернатива без memberOf

Если `memberOf` не работает, используйте фильтр по `member` в группе:

```yaml
auth.ldap.filter: '(&(objectClass=inetOrgPerson)(memberOf=cn=salt-admins,ou=groups,dc=test,dc=local))'
```

Или настройте `auth.ldap.groupattribute` на `member` и укажите `auth.ldap.groupou` правильно.

---

Итог

Вопрос	Ответ	
Можно ли подключиться?	Да	
Нужен TLS?	Нет, можно на 389 порту	
Нужен memberOf?	Желательно, но есть обход	
Отличия от AD?	`uid` вместо `sAMAccountName`, `groupOfNames` вместо `group`