Понял. Динамический grain, который на основании полного DN пользователя в LDAP определяет, к какой группе (OU/CN) относится minion.

---

Custom Grain: `/srv/salt/_grains/ldap_dynamic_group.py`

```python
import ldap
import socket

def ldap_dynamic_group():
    """
    Определяет группу minion'а на основе полного DN пользователя в LDAP.
    Смотрит OU и CN, присваивает роль: admin, operator, user.
    """
    grains = {}
    
    # Получаем идентификатор minion'а
    minion_id = socket.gethostname()
    minion_fqdn = socket.getfqdn()
    
    # Настройки LDAP (можно вынести в minion config)
    ldap_config = {
        'server': 'ldap://localhost:389',
        'binddn': 'cn=admin,dc=sc,dc=local',
        'bindpw': 'admin123',
        'user_base': 'ou=users,dc=sc,dc=local',
        'group_base': 'ou=groups,dc=sc,dc=local',
    }
    
    try:
        conn = ldap.initialize(ldap_config['server'])
        conn.simple_bind_s(ldap_config['binddn'], ldap_config['bindpw'])
        
        # Ищем пользователя по uid = hostname minion'а
        uid = minion_id.split('.')[0]
        search_filter = f'(uid={uid})'
        
        result = conn.search_s(
            ldap_config['user_base'],
            ldap.SCOPE_SUBTREE,
            search_filter,
            ['dn', 'memberOf', 'ou', 'cn', 'uid']
        )
        
        if not result:
            grains['ldap_role'] = 'unassigned'
            grains['ldap_group'] = 'none'
            grains['ldap_full_dn'] = 'not_found'
            return grains
        
        user_dn, attrs = result[0]
        
        # Полный DN пользователя
        grains['ldap_full_dn'] = user_dn
        
        # Парсим DN на компоненты
        dn_parts = user_dn.split(',')
        dn_dict = {}
        for part in dn_parts:
            key, value = part.strip().split('=', 1)
            dn_dict[key] = value
        
        # Извлекаем OU и CN
        grains['ldap_uid'] = dn_dict.get('uid', uid)
        grains['ldap_ou'] = dn_dict.get('ou', 'unknown')
        grains['ldap_dc'] = [v for k, v in dn_dict.items() if k == 'dc']
        
        # Получаем группы (memberOf)
        memberOf = attrs.get('memberOf', [])
        groups = []
        group_details = []
        
        for group_dn in memberOf:
            # Парсим DN группы
            group_parts = group_dn.split(',')
            group_dict = {}
            for part in group_parts:
                if '=' in part:
                    key, value = part.strip().split('=', 1)
                    group_dict[key] = value
            
            cn = group_dict.get('cn', 'unknown')
            ou = group_dict.get('ou', 'unknown')
            
            groups.append(cn)
            group_details.append({
                'cn': cn,
                'ou': ou,
                'full_dn': group_dn
            })
        
        grains['ldap_groups'] = groups
        grains['ldap_group_details'] = group_details
        
        # Определяем роль на основе групп
        role = 'unassigned'
        primary_group = 'none'
        
        # Приоритет: admins > operators > users
        if 'salt-admins' in groups:
            role = 'admin'
            primary_group = 'salt-admins'
        elif 'salt-operators' in groups:
            role = 'operator'
            primary_group = 'salt-operators'
        elif 'salt-users' in groups:
            role = 'user'
            primary_group = 'salt-users'
        
        grains['ldap_role'] = role
        grains['ldap_primary_group'] = primary_group
        
        # Дополнительные метки на основе OU
        ou = grains['ldap_ou']
        if ou == 'users':
            grains['ldap_user_type'] = 'regular_user'
        elif ou == 'serviceaccounts':
            grains['ldap_user_type'] = 'service_account'
        else:
            grains['ldap_user_type'] = 'other'
        
        # Группа для targeting (совместимость с nodegroups)
        grains['salt_group'] = primary_group
        grains['salt_role'] = role
        
        conn.unbind_s()
        
    except Exception as e:
        grains['ldap_error'] = str(e)
        grains['ldap_role'] = 'error'
        grains['salt_group'] = 'error'
    
    return grains
```

---

Синхронизация и проверка

```bash
# На master
salt '*' saltutil.sync_grains

# Проверка всех grains
salt '*' grains.items | grep ldap

# Конкретные grains
salt '*' grains.get ldap_role
salt '*' grains.get ldap_primary_group
salt '*' grains.get ldap_full_dn
salt '*' grains.get ldap_groups
salt '*' grains.get ldap_group_details
salt '*' grains.get salt_group
```

---

Примеры вывода

Для minion'а `i.ivanov` (входит в `salt-admins`):

```yaml
ldap_full_dn: uid=i.ivanov,ou=users,dc=sc,dc=local
ldap_uid: i.ivanov
ldap_ou: users
ldap_dc:
  - sc
  - local
ldap_groups:
  - salt-admins
ldap_group_details:
  - cn: salt-admins
    ou: groups
    full_dn: cn=salt-admins,ou=groups,dc=sc,dc=local
ldap_role: admin
ldap_primary_group: salt-admins
ldap_user_type: regular_user
salt_group: salt-admins
salt_role: admin
```

Для minion'а `p.petrov` (входит в `salt-operators`):

```yaml
ldap_full_dn: uid=p.petrov,ou=users,dc=sc,dc=local
ldap_role: operator
ldap_primary_group: salt-operators
salt_group: salt-operators
salt_role: operator
```

---

Использование в targeting

```bash
# По роли
salt -G 'ldap_role:admin' test.ping
salt -G 'ldap_role:operator' state.apply
salt -G 'ldap_role:user' grains.items

# По группе
salt -G 'salt_group:salt-admins' cmd.run 'whoami'
salt -G 'ldap_primary_group:salt-operators' test.ping

# По OU в LDAP
salt -G 'ldap_ou:users' test.ping

# По домену (DC)
salt -G 'ldap_dc:sc' test.ping

# Compound: админы на production
salt -C 'G@ldap_role:admin and G@env:production' state.apply

# Все кроме unassigned
salt -G 'ldap_role:unassigned' test.ping
# (или)
salt -C 'not G@ldap_role:unassigned' test.ping
```

---

Использование в SLS

```sls
# /srv/salt/role-based-config.sls

{% set role = grains.get('ldap_role', 'unassigned') %}
{% set group = grains.get('ldap_primary_group', 'none') %}
{% set dn = grains.get('ldap_full_dn', 'unknown') %}

role-config-file:
  file.managed:
    - name: /etc/salt/role.conf
    - contents: |
        # Generated by Salt
        # LDAP DN: {{ dn }}
        # Role: {{ role }}
        # Group: {{ group }}
        ROLE={{ role }}
        GROUP={{ group }}
        
        {% if role == 'admin' %}
        FULL_ACCESS=true
        SUDO_NOPASSWD=true
        {% elif role == 'operator' %}
        LIMITED_ACCESS=true
        ALLOWED_ENVS=staging,development
        {% elif role == 'user' %}
        READONLY=true
        {% endif %}

# Установка пакетов по роли
{% if role == 'admin' %}
admin-tools:
  pkg.installed:
    - names:
      - htop
      - vim
      - curl
      - tcpdump
{% elif role == 'operator' %}
operator-tools:
  pkg.installed:
    - names:
      - htop
      - curl
{% endif %}
```

---

Использование в top.sls

```sls
# /srv/salt/top.sls

base:
  # Все minion'ы
  '*':
    - base
  
  # По роли из LDAP grain
  'G@ldap_role:admin':
    - admin_policy
    - monitoring
    - security_hardening
  
  'G@ldap_role:operator':
    - operator_policy
    - monitoring
  
  'G@ldap_role:user':
    - user_policy
  
  # По группе
  'G@salt_group:salt-admins':
    - admin_tools
  
  'G@salt_group:salt-operators':
    - operator_tools
  
  # По OU в LDAP
  'G@ldap_ou:serviceaccounts':
    - service_account_policy
  
  # По домену
  'G@ldap_dc:sc':
    - sc_local_dns
```

---

Использование в pillar

```sls
# /srv/pillar/top.sls

base:
  'G@ldap_role:admin':
    - match: grain
    - admin_secrets
  
  'G@ldap_role:operator':
    - match: grain
    - operator_config
  
  'G@ldap_role:user':
    - match: grain
    - user_config
```

---

Расширенная версия: сравнение нескольких OU

Если нужно учитывать вложенные OU:

```python
# Добавить в grain функцию

def parse_dn(dn_string):
    """Парсит DN в список компонентов с сохранением порядка"""
    parts = dn_string.split(',')
    result = []
    for part in reversed(parts):  # С конца (root -> leaf)
        if '=' in part:
            key, value = part.strip().split('=', 1)
            result.append({'key': key, 'value': value})
    return result

# В основной функции:
dn_tree = parse_dn(user_dn)
grains['ldap_dn_tree'] = dn_tree

# Найти все OU в пути
ou_path = [p['value'] for p in dn_tree if p['key'] == 'ou']
grains['ldap_ou_path'] = ou_path  # ['users', 'SaltStack'] например
```

Тогда targeting:

```bash
# Minion'ы в любом OU под SaltStack
salt -G 'ldap_ou_path:SaltStack' test.ping
```

---

Итоговые grains

Grain	Описание	Пример	
`ldap_full_dn`	Полный DN пользователя	`uid=i.ivanov,ou=users,dc=sc,dc=local`	
`ldap_uid`	UID пользователя	`i.ivanov`	
`ldap_ou`	Ближайшая OU	`users`	
`ldap_ou_path`	Путь OU	`['users']`	
`ldap_dc`	Компоненты DC	`['sc', 'local']`	
`ldap_groups`	Список групп	`['salt-admins']`	
`ldap_group_details`	Детали групп	`[{cn, ou, full_dn}]`	
`ldap_role`	Роль (admin/operator/user)	`admin`	
`ldap_primary_group`	Основная группа	`salt-admins`	
`ldap_user_type`	Тип (regular/service)	`regular_user`	
`salt_group`	Для targeting	`salt-admins`	
`salt_role`	Для targeting	`admin`