Да, сможешь. Вот как это работает:

---

Твой LDAP конфиг

```
dc=sc,dc=local
├── ou=groups
│   ├── cn=salt-admins (member: uid=i.ivanov)
│   ├── cn=salt-operators (member: uid=p.petrov)
│   └── cn=salt-users (member: uid=s.sidorov)
└── ou=users
    ├── uid=i.ivanov
    ├── uid=p.petrov
    └── uid=s.sidorov
```

---

Как grain определяет группу

1. Minion запускается, получает свой hostname (например `i.ivanov`)
2. Ищет в LDAP: `(uid=i.ivanov)`
3. Находит `uid=i.ivanov,ou=users,dc=sc,dc=local`
4. Смотрит `memberOf`: `cn=salt-admins,ou=groups,dc=sc,dc=local`
5. Парсит CN → `salt-admins`
6. Устанавливает grains:
   - `salt_group: salt-admins`
   - `salt_role: admin`

---

Управление через targeting

```bash
# Все minion'ы в группе salt-admins
salt -G 'salt_group:salt-admins' test.ping

# Все операторы
salt -G 'salt_group:salt-operators' state.apply

# Все пользователи
salt -G 'salt_group:salt-users' grains.items

# Админы на production
salt -C 'G@salt_group:salt-admins and G@env:production' state.apply
```

---

Но есть нюанс

Grain устанавливается на minion'е при его старте. Если:
- Minion называется `web01.sc.local` (не `i.ivanov`)
- В LDAP uid=`i.ivanov`, но hostname minion'а `web01`

Тогда поиск `(uid=web01)` не найдёт пользователя.

Решение 1: Minion ID = uid пользователя

При установке minion'а задать id:

```bash
# /etc/salt/minion_id
i.ivanov
```

Или при установке:

```bash
salt-minion -i i.ivanov
```

Решение 2: Добавить атрибут host в LDAP

```ldif
dn: uid=i.ivanov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
objectClass: hostObject
uid: i.ivanov
host: web01.sc.local
host: web02.sc.local
```

Тогда grain ищет `(host=web01.sc.local)` вместо `(uid=...)`.

Решение 3: Использовать FQDN в grain

Изменить grain, чтобы он искал по `host` или `cn`:

```python
# В grain заменить:
search_filter = f'(uid={minion_id})'

# На:
# Вариант 1: поиск по host
search_filter = f'(host={minion_fqdn})'

# Вариант 2: поиск по cn (если cn = hostname)
search_filter = f'(cn={minion_id})'
```

---

Проверка перед использованием

```bash
# 1. Синхронизировать grain
salt '*' saltutil.sync_grains

# 2. Проверить, что grain установился
salt '*' grains.get salt_group

# Ожидаемый вывод:
# i.ivanov:
#     salt-admins
# p.petrov:
#     salt-operators
# s.sidorov:
#     salt-users

# 3. Проверить targeting
salt -G 'salt_group:salt-admins' test.ping
# Должен ответить только i.ivanov
```

---

Итог

Условие	Результат	
Minion ID = uid в LDAP	✅ Работает без изменений	
Minion ID = hostname	❌ Нужно менять grain или добавить `host` в LDAP	
Нужно управлять группой	`salt -G 'salt_group:salt-admins' ...`	

Если твои minion'ы называются `i.ivanov`, `p.petrov`, `s.sidorov` — всё работает сразу. Если нет — скажи, как называются minion'ы, подправлю grain.