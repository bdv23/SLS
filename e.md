Ошибка `LDAP lookup found multiple results for user i.ivanov` означает, что поиск по `uid=i.ivanov` находит больше одной записи в LDAP.

---

Причина

Ваш `auth.ldap.filter` слишком широкий и находит дубликаты:

```yaml
auth.ldap.filter: '(objectClass=inetOrgPerson)'
```

Если в базе несколько записей с `uid=i.ivanov` (например, в разных OU или дубли), Salt не может определить, какую использовать.

---

Решение 1: Уточнить фильтр

```yaml
# /etc/salt/master.d/03-openldap.conf

auth.ldap.basedn: 'ou=users,dc=sc,dc=local'
auth.ldap.filter: '(&(objectClass=inetOrgPerson)(uid=%s))'
```

`%s` — подставляется логин пользователя. Теперь поиск будет точным: `(&(objectClass=inetOrgPerson)(uid=i.ivanov))`.

---

Решение 2: Проверить дубли в LDAP

```bash
# Найти все записи с uid=i.ivanov
docker exec openldap ldapsearch -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -b "dc=sc,dc=local" \
  "(uid=i.ivanov)" \
  dn uid

# Если выведено больше одной записи — удалите дубли
```

---

Решение 3: Полная пересоздание (чистый вариант)

Если структура запуталась, проще всё снести и создать заново:

```bash
# Остановить и удалить контейнер
docker stop openldap
docker rm openldap

# Запустить заново
docker run -d -p 389:389 -p 636:636 --name openldap \
  -e LDAP_ORGANISATION="SC" \
  -e LDAP_DOMAIN="sc.local" \
  -e LDAP_ADMIN_PASSWORD="admin123" \
  osixia/openldap:latest

# Подождать 10-15 секунд пока стартует
sleep 15

# Создать структуру
cat > /tmp/init.ldif <<'EOF'
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

dn: ou=users,dc=sc,dc=local
objectClass: organizationalUnit
ou: users

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

docker cp /tmp/init.ldif openldap:/tmp/
docker exec openldap ldapadd -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 \
  -f /tmp/init.ldif

# Добавить в группы
docker exec openldap ldapmodify -x \
  -D "cn=admin,dc=sc,dc=local" \
  -w admin123 <<'EOF'
dn: cn=salt-admins,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=i.ivanov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local

dn: cn=salt-operators,ou=groups,dc=sc,dc=local
changetype: modify
add: member
member: uid=p.petrov,ou=users,dc=sc,dc=local
-
delete: member
member: cn=placeholder,dc=sc,dc=local

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

Исправленный конфиг Salt

```yaml
# /etc/salt/master.d/03-openldap.conf

auth.ldap.server: localhost
auth.ldap.port: 389
auth.ldap.tls: False
auth.ldap.uri: 'ldap://localhost:389/'

auth.ldap.binddn: 'cn=admin,dc=sc,dc=local'
auth.ldap.bindpw: 'admin123'

auth.ldap.basedn: 'ou=users,dc=sc,dc=local'
auth.ldap.filter: '(&(objectClass=inetOrgPerson)(uid=%s))'

auth.ldap.accountattributename: 'uid'
auth.ldap.userattribute: 'uid'

auth.ldap.groupou: 'ou=groups,dc=sc,dc=local'
auth.ldap.groupclass: 'groupOfNames'
auth.ldap.groupattribute: 'member'

auth.ldap.activedirectory: False
auth.ldap.timeout: 10
```

---

Проверка

```bash
# Перезапуск Salt
sudo systemctl restart salt-master salt-api

# Проверка — должно работать
salt -a ldap test.ping '*' --username=i.ivanov
```

---

Почему `uid=%s` решает проблему

Без `%s`	С `%s`	
Поиск: `(objectClass=inetOrgPerson)`	Поиск: `(&(objectClass=inetOrgPerson)(uid=i.ivanov))`	
Находит ВСЕХ пользователей	Находит ТОЛЬКО одного	
Salt не понимает, кого выбрать	Однозначный результат