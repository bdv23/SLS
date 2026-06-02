```
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Находит объект компьютера в AD (в любом OU) и извлекает OU, в которых он находится.
"""

import socket

__virtualname__ = 'ldap_host'

# LDAP-конфиг
LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'
LDAP_DOMAIN_BASE = 'DC=sc,DC=local'

def __virtual__():
    return __virtualname__

def _extract_ous_from_dn(dn_str):
    """Извлекает все значения OU из строки DN."""
    if isinstance(dn_str, bytes):
        dn_str = dn_str.decode('utf-8')
    
    ous = []
    parts = dn_str.split(',')
    for part in parts:
        part = part.strip()
        if part.upper().startswith('OU='):
            ous.append(part[3:])
    return ous

def ldap_host():
    grains = {}
    
    default_grains = {
        'ldap_host_group': 'unassigned',
        'ldap_role': 'unassigned',
        'ldap_host_ous': [],
        'ldap_host_parent_ou': 'None',
        'ldap_host_id': __opts__.get('id', socket.gethostname())
    }
    
    try:
        import ldap
    except ImportError:
        default_grains.update({'ldap_error': 'python3-ldap not installed'})
        return default_grains
    minion_id = default_grains['ldap_host_id']
    computer_name = minion_id.upper().rstrip('$')
    
    conn = None
    try:
        conn = ldap.initialize(LDAP_SERVER)
        conn.set_option(ldap.OPT_REFERRALS, 0)
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(LDAP_BIND_DN, LDAP_BIND_PW)
        
        # Ищем компьютер по всему домену, так как он лежит в OU, а не в CN=Computers
        search_filter = f"(&(objectClass=computer)(cn={computer_name}))"
        
        result = conn.search_s(
            LDAP_DOMAIN_BASE,
            ldap.SCOPE_SUBTREE,
            search_filter,
            ['dn', 'cn', 'memberOf']
        )
        
        if not result:
            grains.update(default_grains)
            grains['ldap_error'] = f'Computer {computer_name} not found in {LDAP_DOMAIN_BASE}'
            return grains
            
        host_dn, attrs = result[0]
        host_dn_str = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn
        
        grains['ldap_full_dn'] = host_dn_str
        
        # Извлекаем OU из DN самого компьютера
        ous = _extract_ous_from_dn(host_dn_str)
        grains['ldap_host_ous'] = ous
        
        # Самый ближний (родительский) OU - это первый элемент в списке
        # DN: CN=ubuntu,OU=deb-ou,OU=deb-minions... -> ous[0] будет 'deb-ou'
        if ous:
            grains['ldap_host_parent_ou'] = ous[0]
            
        # Парсинг memberOf (если вы всё еще используете группы для ролей)
        groups_cn = []
        if b'memberOf' in attrs:
            for group_dn in attrs[b'memberOf']:
                group_str = group_dn.decode('utf-8') if isinstance(group_dn, bytes) else group_dn
                parts = group_str.split(',')
                if parts and parts[0].upper().startswith('CN='):
                    groups_cn.append(parts[0][3:])
        
        grains['ldap_host_groups'] = groups_cn
                # Логика ролей
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
            if group_name in groups_cn:
                primary_group = group_name
                role = group_role
                break
                
        # Если роль не назначена по группам, можно назначить её на основе OU
        if role == 'unassigned' and ous:
            if 'deb-minions' in ous:
                role = 'minion'
                primary_group = 'deb-minions-ou'
            elif 'deb-ou' in ous:
                role = 'test-server'
                primary_group = 'deb-ou-ou'
                
        grains['ldap_host_group'] = primary_group
        grains['ldap_role'] = role
        grains['domain_group'] = primary_group
        grains['salt_role'] = role
        
    except ldap.SERVER_DOWN:
        grains.update(default_grains)
        grains['ldap_error'] = 'LDAP server unreachable'
    except ldap.INVALID_CREDENTIALS:
        grains.update(default_grains)
        grains['ldap_error'] = 'Invalid bind credentials'
    except Exception as e:
        grains.update(default_grains)
        grains['ldap_error'] = str(e)
    finally:
        if conn:
            try:
                conn.unbind_s()
            except:
                pass
    
    return grains
```
