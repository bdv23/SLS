#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
С маппингом имён миньонов Salt на имена компьютеров в AD
"""

import socket

__virtualname__ = 'ldap_host'

LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'
LDAP_DOMAIN_BASE = 'DC=sc,DC=local'

# Маппинг: имя миньона Salt -> имя компьютера в AD
MINION_TO_AD_MAPPING = {
    'debian-minion-1': 'debian',
    'ubuntu-minion-1': 'ubuntu',
    'salt-master': 'salt-master',
    'usaltm': 'usaltm',
}


def __virtual__():
    return __virtualname__


def _extract_ous_from_dn(dn_str):
    """Извлекает все значения OU из строки DN."""
    if isinstance(dn_str, bytes):
        dn_str = dn_str.decode('utf-8')
    ous = []
    for part in dn_str.split(','):
        part = part.strip()
        if part.upper().startswith('OU='):
            ous.append(part[3:])
    return ous


def ldap_host():
    grains = {}

    minion_id = __opts__.get('id', socket.gethostname())
    
    # Получаем имя для поиска в AD (сначала из маппинга, потом как есть)
    if minion_id in MINION_TO_AD_MAPPING:
        computer_name = MINION_TO_AD_MAPPING[minion_id]
    else:        computer_name = minion_id.split('.')[0]
    
    name_upper = computer_name.upper()
    name_lower = computer_name.lower()

    default_grains = {
        'ldap_host_group': 'unassigned',
        'ldap_role': 'unassigned',
        'ldap_host_ous': [],
        'ldap_host_parent_ou': 'None',
        'ldap_host_groups': [],
        'ldap_host_id': minion_id,
        'ldap_search_name': computer_name,
    }

    try:
        import ldap
    except ImportError:
        default_grains.update({'ldap_error': 'python3-ldap not installed'})
        return default_grains

    conn = None
    try:
        conn = ldap.initialize(LDAP_SERVER)
        conn.set_option(ldap.OPT_REFERRALS, 0)
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(LDAP_BIND_DN, LDAP_BIND_PW)

        # Ищем компьютер
        search_filter = f"(&(objectClass=computer)(cn={computer_name}))"
        
        result = conn.search_s(
            LDAP_DOMAIN_BASE,
            ldap.SCOPE_SUBTREE,
            search_filter,
            ['dn', 'cn', 'memberOf']
        )

        if not result:
            grains.update(default_grains)
            grains['ldap_error'] = f'Computer {computer_name} not found in AD'
            return grains

        # Компьютер найден
        host_dn, attrs = result[0]
        host_dn_str = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn

        grains['ldap_full_dn'] = host_dn_str

        # Извлекаем OU из DN компьютера        ous = _extract_ous_from_dn(host_dn_str)
        grains['ldap_host_ous'] = ous
        if ous:
            grains['ldap_host_parent_ou'] = ous[0]

        # Парсим memberOf
        groups_cn = []
        if b'memberOf' in attrs:
            for group_dn in attrs[b'memberOf']:
                group_str = group_dn.decode('utf-8') if isinstance(group_dn, bytes) else group_dn
                parts = group_str.split(',')
                if parts and parts[0].upper().startswith('CN='):
                    groups_cn.append(parts[0][3:])
        grains['ldap_host_groups'] = groups_cn

        # Без приоритизации
        if groups_cn:
            grains['ldap_host_group'] = groups_cn[0]
        elif ous:
            grains['ldap_host_group'] = ous[0]

        if ous:
            grains['ldap_role'] = ous[0]
        elif groups_cn:
            grains['ldap_role'] = groups_cn[0]

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

вот код, он не находит ou
root@salt-master:/home/saltadm# salt '*' saltutil.sync_grains
usaltm:
debian-minion-1:
ubuntu-minion-1:
salt-master:
root@salt-master:/home/saltadm# journalctl -u salt-master -f
Jun 02 16:14:52 salt-master salt-master[3106632]: The salt master is shutdown. Master received a SIGTERM. Exited.
Jun 02 16:14:52 salt-master systemd[1]: salt-master.service: Deactivated successfully.
Jun 02 16:14:52 salt-master systemd[1]: Stopped salt-master.service - The Salt Master Server.
Jun 02 16:14:52 salt-master systemd[1]: salt-master.service: Consumed 16.561s CPU time.
Jun 02 16:14:52 salt-master systemd[1]: Starting salt-master.service - The Salt Master Server...
Jun 02 16:14:53 salt-master systemd[1]: Started salt-master.service - The Salt Master Server.
Jun 02 16:15:04 salt-master salt-master[3108201]: [WARNING ] Rejected authentication attempt using protocol version 2 (minimum required: 3)
Jun 02 16:15:10 salt-master salt-master[3108198]: [WARNING ] Rejected authentication attempt using protocol version 2 (minimum required: 3)
Jun 02 16:15:13 salt-master salt-master[3108202]: [WARNING ] Rejected authentication attempt using protocol version 2 (minimum required: 3)
Jun 02 16:15:48 salt-master salt-master[3108200]: [WARNING ] Rejected authentication attempt using protocol version 2 (minimum required: 3)
^C
root@salt-master:/home/saltadm# salt '*' grains.get ldap_role
usaltm:
    unassigned
debian-minion-1:
    unassigned
ubuntu-minion-1:
    unassigned
salt-master:
    unassigned
root@salt-master:/home/saltadm# salt '*' grains.get ldap_host_ous
usaltm:
debian-minion-1:
salt-master:
ubuntu-minion-1:
root@salt-master:/home/saltadm#
