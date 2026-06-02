```
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Читает membership миньона в LDAP-группах AD и возвращает:
  - ldap_host_group: имя группы (например minions, salt-masters)
  - ldap_role: роль на основе группы (server, master)
  - ldap_full_dn: DN хоста
"""

import socket

__virtualname__ = 'ldap_host'

# LDAP-конфиг (складываем в переменные для удобства)
LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'
LDAP_COMPUTERS_BASE = 'CN=Computers,DC=sc,DC=local'
LDAP_GROUPS_BASE = 'CN=Users,DC=sc,DC=local'


def __virtual__():
    return __virtualname__


def ldap_host():
    grains = {}
    
    # Пробуем импортировать ldap
    try:
        import ldap
    except ImportError:
        return {
            'ldap_host_group': 'no-ldap-module',
            'ldap_role': 'no-ldap-module',
            'ldap_error': 'python-ldap not installed. Run: apt install python3-ldap'
        }
    
    minion_id = __opts__.get('id', socket.gethostname())
    # В AD имя компьютера в верхнем регистре, без $ в конце
    computer_name = minion_id.upper().rstrip('$')
    dn = f"CN={computer_name},{LDAP_COMPUTERS_BASE}"
    
    ldap_config = {
        'server': LDAP_SERVER,
        'binddn': LDAP_BIND_DN,
        'bindpw': LDAP_BIND_PW,
        'hosts_base': LDAP_COMPUTERS_BASE,
        'group_base': LDAP_GROUPS_BASE,
    }
    
    try:
        conn = ldap.initialize(ldap_config['server'])
        # Отключаем referrals для AD
        conn.set_option(ldap.OPT_REFERRALS, 0)
        # Устанавливаем таймаут
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(ldap_config['binddn'], ldap_config['bindpw'])
        
        # Проверяем, существует ли компьютер в AD
        try:
            result = conn.search_s(
                dn,
                ldap.SCOPE_BASE,
                '(objectClass=computer)',
                ['dn', 'cn', 'memberOf']
            )
        except ldap.NO_SUCH_OBJECT:
            grains['ldap_host_group'] = 'unassigned'
            grains['ldap_role'] = 'unassigned'
            grains['ldap_full_dn'] = dn
            grains['ldap_host_id'] = minion_id
            conn.unbind_s()
            return grains
        
        host_dn, attrs = result[0]
        grains['ldap_full_dn'] = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn
        grains['ldap_host_id'] = minion_id
        
        # Читаем memberOf (атрибут, который содержит группы, где компьютер — член)
        groups = []
        if b'memberOf' in attrs:
            for group_dn in attrs[b'memberOf']:
                group_str = group_dn.decode('utf-8')
                # Извлекаем CN из DN: CN=minions,CN=Users,DC=sc,DC=local → minions
                cn = group_str.split(',')[0].replace('CN=', '')
                groups.append(cn)
        
        grains['ldap_host_groups'] = groups
        
        # Определяем основную группу и роль по приоритету
        role = 'unassigned'
        primary_group = 'unassigned'
        
        # Приоритет групп (первая подходящаяwins)
        priority = [
            ('salt-masters', 'master'),
            ('minions', 'server'),
            ('linux-servers', 'server'),
            ('web-servers', 'web'),
            ('db-servers', 'db'),
        ]
        
        for group_name, group_role in priority:
            if group_name in groups:
                primary_group = group_name
                role = group_role
                break
        
        grains['ldap_host_group'] = primary_group
        grains['ldap_role'] = role
        grains['domain_group'] = primary_group
        grains['salt_role'] = role
        
        conn.unbind_s()
        
    except ldap.SERVER_DOWN:
        grains['ldap_error'] = 'LDAP server unreachable'
        grains['ldap_host_group'] = 'error'
        grains['ldap_role'] = 'error'
    except ldap.INVALID_CREDENTIALS:
        grains['ldap_error'] = 'Invalid bind credentials'
        grains['ldap_host_group'] = 'error'
        grains['ldap_role'] = 'error'
    except ldap.NO_SUCH_OBJECT:
        grains['ldap_error'] = f'Computer object not found: {dn}'
        grains['ldap_host_group'] = 'unassigned'
        grains['ldap_role'] = 'unassigned'
    except Exception as e:
        grains['ldap_error'] = str(e)
        grains['ldap_host_group'] = 'error'
        grains['ldap_role'] = 'error'
    
    return grains
```


---
---
---
---

Понял задачу. Переделаю grain с поиска по `CN` на поиск по `OU` (организационным юнитам), чтобы он возвращал список доменных групп.

Вот обновлённый grain:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Читает membership миньона в LDAP-группах AD и возвращает:
  - ldap_host_groups: список доменных групп (memberOf)
  - ldap_host_ous: список OU, в которых находится компьютер
  - ldap_role: роль на основе группы (server, master)
  - ldap_full_dn: DN хоста
"""

import socket

__virtualname__ = 'ldap_host'

# LDAP-конфиг (складываем в переменные для удобства)
LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'
LDAP_SEARCH_BASE = 'DC=sc,DC=local'  # База для поиска по всему домену


def __virtual__():
    return __virtualname__


def ldap_host():
    grains = {}
    
    # Пробуем импортировать ldap
    try:
        import ldap
    except ImportError:
        return {
            'ldap_host_groups': [],
            'ldap_host_ous': [],
            'ldap_role': 'no-ldap-module',
            'ldap_error': 'python-ldap not installed. Run: apt install python3-ldap'
        }
    
    minion_id = __opts__.get('id', socket.gethostname())
    # В AD имя компьютера в верхнем регистре
    computer_name = minion_id.upper().rstrip('$')
    
    ldap_config = {
        'server': LDAP_SERVER,
        'binddn': LDAP_BIND_DN,
        'bindpw': LDAP_BIND_PW,
        'search_base': LDAP_SEARCH_BASE,
    }
    
    try:
        conn = ldap.initialize(ldap_config['server'])
        # Отключаем referrals для AD
        conn.set_option(ldap.OPT_REFERRALS, 0)
        # Устанавливаем таймаут
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(ldap_config['binddn'], ldap_config['bindpw'])
        
        # === ПОИСК ПО ВСЕМУ ДОМЕНУ ПО ИМЕНИ КОМПЬЮТЕРА ===
        # Ищем компьютер по sAMAccountName (имя$) или по cn
        search_filter = (
            '(&(objectClass=computer)'
            '(|(sAMAccountName={}$)(cn={}))'
            ')'.format(computer_name, computer_name)
        )
        
        result = conn.search_s(
            ldap_config['search_base'],
            ldap.SCOPE_SUBTREE,
            search_filter,
            ['dn', 'cn', 'sAMAccountName', 'memberOf', 'distinguishedName']
        )
        
        if not result:
            grains['ldap_host_groups'] = []
            grains['ldap_host_ous'] = []
            grains['ldap_role'] = 'unassigned'
            grains['ldap_error'] = f'Computer not found: {computer_name}'
            grains['ldap_host_id'] = minion_id
            conn.unbind_s()
            return grains
        
        host_dn, attrs = result[0]
        host_dn_str = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn
        grains['ldap_full_dn'] = host_dn_str
        grains['ldap_host_id'] = minion_id
        
        # === ИЗВЛЕКАЕМ OU ИЗ DN ===
        # DN: CN=WS01,OU=Workstations,OU=Moscow,DC=sc,DC=local
        # OU: ['Workstations', 'Moscow']
        ous = []
        for part in host_dn_str.split(','):
            part = part.strip()
            if part.upper().startswith('OU='):
                ou_name = part[3:]  # Убираем "OU="
                ous.append(ou_name)
        grains['ldap_host_ous'] = ous
        
        # === ЧИТАЕМ memberOf (доменные группы) ===
        groups = []
        if b'memberOf' in attrs:
            for group_dn in attrs[b'memberOf']:
                group_str = group_dn.decode('utf-8')
                # Извлекаем CN из DN: CN=minions,CN=Users,DC=sc,DC=local → minions
                cn = group_str.split(',')[0].replace('CN=', '')
                groups.append(cn)
        
        grains['ldap_host_groups'] = groups
        
        # === ОПРЕДЕЛЯЕМ РОЛЬ ПО ПРИОРИТЕТУ ГРУПП ===
        role = 'unassigned'
        primary_group = 'unassigned'
        
        priority = [
            ('salt-masters', 'master'),
            ('minions', 'server'),
            ('linux-servers', 'server'),
            ('web-servers', 'web'),
            ('db-servers', 'db'),
        ]
        
        for group_name, group_role in priority:
            if group_name in groups:
                primary_group = group_name
                role = group_role
                break
        
        grains['ldap_host_group'] = primary_group
        grains['ldap_role'] = role
        grains['domain_group'] = primary_group
        grains['salt_role'] = role
        
        conn.unbind_s()
        
    except ldap.SERVER_DOWN:
        grains['ldap_error'] = 'LDAP server unreachable'
        grains['ldap_host_groups'] = []
        grains['ldap_host_ous'] = []
        grains['ldap_role'] = 'error'
    except ldap.INVALID_CREDENTIALS:
        grains['ldap_error'] = 'Invalid bind credentials'
        grains['ldap_host_groups'] = []
        grains['ldap_host_ous'] = []
        grains['ldap_role'] = 'error'
    except Exception as e:
        grains['ldap_error'] = str(e)
        grains['ldap_host_groups'] = []
        grains['ldap_host_ous'] = []
        grains['ldap_role'] = 'error'
    
    return grains
```

Что изменилось:

Было	Стало	
Поиск по фиксированному `CN=...,CN=Computers,DC=sc,DC=local`	Поиск по всему домену (`DC=sc,DC=local`) по `sAMAccountName` или `cn`	
`ldap_host_group` — одна группа	`ldap_host_groups` — список всех доменных групп	
Нет информации об OU	`ldap_host_ous` — список OU из DN компьютера	
`LDAP_COMPUTERS_BASE` + `LDAP_GROUPS_BASE`	`LDAP_SEARCH_BASE = 'DC=sc,DC=local'`	

Пример результата:

```yaml
ldap_host_id: ws01
ldap_full_dn: CN=WS01,OU=Workstations,OU=Moscow,DC=sc,DC=local
ldap_host_ous:
  - Workstations
  - Moscow
ldap_host_groups:
  - minions
  - linux-servers
  - web-servers
ldap_host_group: minions      # первая по приоритету
ldap_role: server
salt_role: server
domain_group: minions
```

Если нужно, могу добавить фильтрацию групп по OU (например, возвращать только группы из определённого OU) или изменить логику определения роли.


---
---

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Возвращает список доменных групп, в которых состоит компьютер.
Можно фильтровать группы по OU, в котором они находятся.
"""

import socket

__virtualname__ = 'ldap_host'

# LDAP-конфиг
LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'
LDAP_SEARCH_BASE = 'DC=sc,DC=local'

# Если нужны только группы из определённых OU, укажи их тут.
# Пустой список = все группы.
# Пример: ['OU=SaltGroups,DC=sc,DC=local']
FILTER_OUS = []


def __virtual__():
    return __virtualname__


def ldap_host():
    grains = {}
    
    try:
        import ldap
    except ImportError:
        return {
            'ldap_host_groups': [],
            'ldap_error': 'python-ldap not installed. Run: apt install python3-ldap'
        }
    
    minion_id = __opts__.get('id', socket.gethostname())
    computer_name = minion_id.upper().rstrip('$')
    
    try:
        conn = ldap.initialize(LDAP_SERVER)
        conn.set_option(ldap.OPT_REFERRALS, 0)
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(LDAP_BIND_DN, LDAP_BIND_PW)
        
        # Поиск компьютера по всему домену
        search_filter = (
            '(&(objectClass=computer)'
            '(|(sAMAccountName={}$)(cn={}))'
            ')'.format(computer_name, computer_name)
        )
        
        result = conn.search_s(
            LDAP_SEARCH_BASE,
            ldap.SCOPE_SUBTREE,
            search_filter,
            ['dn', 'cn', 'memberOf']
        )
        
        if not result:
            grains['ldap_host_groups'] = []
            grains['ldap_error'] = f'Computer not found: {computer_name}'
            grains['ldap_host_id'] = minion_id
            conn.unbind_s()
            return grains
        
        host_dn, attrs = result[0]
        host_dn_str = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn
        grains['ldap_full_dn'] = host_dn_str
        grains['ldap_host_id'] = minion_id
        
        # Список доменных групп с фильтрацией по OU
        groups = []
        if b'memberOf' in attrs:
            for group_dn in attrs[b'memberOf']:
                group_str = group_dn.decode('utf-8')
                
                # Фильтр по OU: если FILTER_OUS задан, проверяем,
                # что группа находится в одном из указанных OU
                if FILTER_OUS:
                    match = any(
                        ou.lower() in group_str.lower()
                        for ou in FILTER_OUS
                    )
                    if not match:
                        continue
                
                # Извлекаем CN из DN: CN=minions,CN=Users,DC=sc,DC=local → minions
                cn = group_str.split(',')[0].replace('CN=', '')
                groups.append({
                    'name': cn,
                    'dn': group_str
                })
        
        grains['ldap_host_groups'] = [g['name'] for g in groups]
        grains['ldap_host_groups_full'] = groups  # полный DN каждой группы
        
        conn.unbind_s()
        
    except ldap.SERVER_DOWN:
        grains['ldap_error'] = 'LDAP server unreachable'
        grains['ldap_host_groups'] = []
    except ldap.INVALID_CREDENTIALS:
        grains['ldap_error'] = 'Invalid bind credentials'
        grains['ldap_host_groups'] = []
    except Exception as e:
        grains['ldap_error'] = str(e)
        grains['ldap_host_groups'] = []
    
    return grains
