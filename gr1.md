```
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Читает membership миньона в LDAP-группах AD и возвращает:
  - ldap_host_groups: список имен групп (CN)
  - ldap_host_ous: список OU, в которых находятся группы
  - ldap_role: роль на основе группы (server, master)
  - ldap_full_dn: DN хоста
"""

import socket

__virtualname__ = 'ldap_host'

# LDAP-конфиг
LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'
LDAP_COMPUTERS_BASE = 'CN=Computers,DC=sc,DC=local'
LDAP_GROUPS_BASE = 'CN=Users,DC=sc,DC=local'


def __virtual__():
    return __virtualname__


def _parse_dn_component(dn_str, component_type):
    """
    Универсальная функция для извлечения компонента из DN.
    
    :param dn_str: Строка DN (bytes или str)
    :param component_type: 'OU' или 'CN'
    :return: Значение первого найденного компонента или None
    """
    if isinstance(dn_str, bytes):
        dn_str = dn_str.decode('utf-8')
    
    # Приводим к верхнему регистру для поиска префикса, но сохраняем оригинал для возврата
    parts = dn_str.split(',')
    prefix = f"{component_type.upper()}="
    
    for part in parts:
        part_stripped = part.strip()
        if part_stripped.upper().startswith(prefix):
            # Возвращаем значение после префикса (например, после 'OU=')
            return part_stripped[len(prefix):]
    return None

def ldap_host():
    grains = {}
    
    # Инициализация дефолтных значений
    default_grains = {
        'ldap_host_group': 'unassigned',
        'ldap_role': 'unassigned',
        'ldap_host_groups': [],
        'ldap_host_ous': [],
        'ldap_host_full_groups': [],
        'ldap_host_id': __opts__.get('id', socket.gethostname())
    }
    
    # Пробуем импортировать ldap
    try:
        import ldap
    except ImportError:
        default_grains.update({
            'ldap_error': 'python-ldap not installed. Run: apt install python3-ldap',
            'ldap_host_group': 'no-ldap-module',
            'ldap_role': 'no-ldap-module'
        })
        return default_grains
    
    minion_id = default_grains['ldap_host_id']
    computer_name = minion_id.upper().rstrip('$')
    dn = f"CN={computer_name},{LDAP_COMPUTERS_BASE}"
    
    ldap_config = {
        'server': LDAP_SERVER,
        'binddn': LDAP_BIND_DN,
        'bindpw': LDAP_BIND_PW,
    }
    
    conn = None
    try:
        conn = ldap.initialize(ldap_config['server'])
        conn.set_option(ldap.OPT_REFERRALS, 0)
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(ldap_config['binddn'], ldap_config['bindpw'])
        
        # Проверяем существование компьютера
        try:
            result = conn.search_s(
                dn,
                ldap.SCOPE_BASE,
                '(objectClass=computer)',
                ['dn', 'cn', 'memberOf']
            )
        except ldap.NO_SUCH_OBJECT:            grains.update(default_grains)
            grains['ldap_full_dn'] = dn
            grains['ldap_error'] = 'Computer object not found in AD'
            return grains
        
        if not result:
            grains.update(default_grains)
            return grains
            
        host_dn, attrs = result[0]
        grains['ldap_full_dn'] = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn
        grains['ldap_host_id'] = minion_id
        
        # Парсим memberOf
        groups_cn = []
        groups_ou = []
        groups_full_dn = []
        
        if b'memberOf' in attrs:
            for group_dn in attrs[b'memberOf']:
                group_dn_str = group_dn.decode('utf-8') if isinstance(group_dn, bytes) else group_dn
                groups_full_dn.append(group_dn_str)
                
                # Извлекаем CN (имя группы)
                cn = _parse_dn_component(group_dn_str, 'CN')
                if cn:
                    groups_cn.append(cn)
                
                # Извлекаем OU (подразделение, где лежит группа)
                ou = _parse_dn_component(group_dn_str, 'OU')
                if ou:
                    groups_ou.append(ou)
        
        grains['ldap_host_groups'] = groups_cn
        grains['ldap_host_ous'] = groups_ou
        grains['ldap_host_full_groups'] = groups_full_dn
        
        # Определяем роль по приоритету (по имени группы CN)
        role = 'unassigned'
        primary_group = 'unassigned'
        
        priority = [
            ('salt-masters', 'master'),
            ('minions', 'server'),
            ('linux-servers', 'server'),
            ('web-servers', 'web'),
            ('db-servers', 'db'),
        ]
        
        for group_name, group_role in priority:            if group_name in groups_cn:
                primary_group = group_name
                role = group_role
                break
        
        grains['ldap_host_group'] = primary_group
        grains['ldap_role'] = role
        grains['domain_group'] = primary_group
        grains['salt_role'] = role
        
    except ldap.SERVER_DOWN:
        grains.update(default_grains)
        grains['ldap_error'] = 'LDAP server unreachable'
        grains['ldap_host_group'] = 'error'
        grains['ldap_role'] = 'error'
        
    except ldap.INVALID_CREDENTIALS:
        grains.update(default_grains)
        grains['ldap_error'] = 'Invalid bind credentials'
        grains['ldap_host_group'] = 'error'
        grains['ldap_role'] = 'error'
        
    except Exception as e:
        grains.update(default_grains)
        grains['ldap_error'] = str(e)
        grains['ldap_host_group'] = 'error'
        grains['ldap_role'] = 'error'
        
    finally:
        if conn:
            try:
                conn.unbind_s()
            except:
                pass
    
    return grains
```