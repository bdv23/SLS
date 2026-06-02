```
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Извлекает именно OU (Organizational Unit) из DN групп, игнорируя CN.
"""

import socket

__virtualname__ = 'ldap_host'

# LDAP-конфиг
LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'
LDAP_COMPUTERS_BASE = 'CN=Computers,DC=sc,DC=local'

def __virtual__():
    return __virtualname__


def _extract_ous_from_dn(dn_str):
    """
    Извлекает ВСЕ значения OU из строки DN.
    
    Пример: 
      'CN=grp,OU=Infra,OU=Servers,DC=dom' -> ['Infra', 'Servers']
      'CN=grp,CN=Users,DC=dom' -> [] (нет OU)
    """
    if isinstance(dn_str, bytes):
        dn_str = dn_str.decode('utf-8')
    
    ous = []
    parts = dn_str.split(',')
    
    for part in parts:
        part = part.strip()
        # Проверяем, начинается ли компонент с OU= (регистронезависимо)
        if part.upper().startswith('OU='):
            # Извлекаем значение после OU=
            ou_value = part[3:]  # отрезаем 'OU='
            ous.append(ou_value)
    
    return ous


def ldap_host():
    grains = {}
    
    # Дефолтные значения    default_grains = {
        'ldap_host_group': 'unassigned',
        'ldap_role': 'unassigned',
        'ldap_host_groups': [],       # Имена групп (CN)
        'ldap_host_ous': [],          # <-- ИМЕННО ЭТО ПОЛЕ: список OU из групп
        'ldap_host_full_groups': [],  # Полные DN для отладки
        'ldap_host_id': __opts__.get('id', socket.gethostname())
    }
    
    try:
        import ldap
    except ImportError:
        default_grains.update({'ldap_error': 'python3-ldap not installed'})
        return default_grains
    
    minion_id = default_grains['ldap_host_id']
    computer_name = minion_id.upper().rstrip('$')
    dn = f"CN={computer_name},{LDAP_COMPUTERS_BASE}"
    
    conn = None
    try:
        conn = ldap.initialize(LDAP_SERVER)
        conn.set_option(ldap.OPT_REFERRALS, 0)
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(LDAP_BIND_DN, LDAP_BIND_PW)
        
        # Поиск объекта компьютера
        try:
            result = conn.search_s(
                dn,
                ldap.SCOPE_BASE,
                '(objectClass=computer)',
                ['dn', 'memberOf']
            )
        except ldap.NO_SUCH_OBJECT:
            grains.update(default_grains)
            grains['ldap_error'] = f'Computer not found: {dn}'
            return grains
        
        if not result:
            grains.update(default_grains)
            return grains
            
        host_dn, attrs = result[0]
        grains['ldap_full_dn'] = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn
        
        # Парсинг memberOf
        groups_cn = []
        all_ous = []        # Список всех найденных OU
        full_dns = []        
        if b'memberOf' in attrs:
            for group_dn in attrs[b'memberOf']:
                group_str = group_dn.decode('utf-8') if isinstance(group_dn, bytes) else group_dn
                full_dns.append(group_str)
                
                # Извлекаем имя группы (первый компонент CN)
                parts = group_str.split(',')
                if parts and parts[0].upper().startswith('CN='):
                    groups_cn.append(parts[0][3:])
                
                # Извлекаем ВСЕ OU из этого DN
                ous = _extract_ous_from_dn(group_str)
                all_ous.extend(ous)  # Добавляем в общий список
        
        # Убираем дубликаты из списка OU, сохраняя порядок
        seen = set()
        unique_ous = []
        for ou in all_ous:
            if ou not in seen:
                seen.add(ou)
                unique_ous.append(ou)
        
        grains['ldap_host_groups'] = groups_cn
        grains['ldap_host_ous'] = unique_ous      # <--- ПРОВЕРЯЙТЕ ЭТО ПОЛЕ
        grains['ldap_host_full_groups'] = full_dns
        
        # Логика определения роли (по имени группы)
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
        
        grains['ldap_host_group'] = primary_group
        grains['ldap_role'] = role
        grains['domain_group'] = primary_group
        grains['salt_role'] = role
        
    except ldap.SERVER_DOWN:        grains.update(default_grains)
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
