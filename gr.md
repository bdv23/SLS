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
