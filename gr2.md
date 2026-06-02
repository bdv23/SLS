```
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Ищет OU, в которой находится компьютер, и группы в каждой OU
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
    """Извлекает все значения OU из строки DN (сверху вниз)."""
    if isinstance(dn_str, bytes):
        dn_str = dn_str.decode('utf-8')
    ous = []
    for part in dn_str.split(','):
        part = part.strip()
        if part.upper().startswith('OU='):
            ous.append(part[3:])
    return ous


def _get_groups_in_ou(conn, ou_dn):
    """Ищет все группы (objectClass=group) внутри указанной OU."""
    groups = []
    try:
        result = conn.search_s(
            ou_dn,
            ldap.SCOPE_SUBTREE,
            '(objectClass=group)',
            ['cn']
        )
        for dn, attrs in result:
            if not dn:
                continue
            for key in attrs:
                if (isinstance(key, bytes) and key.lower() == b'cn') or \
                   (isinstance(key, str) and key.lower() == 'cn'):
                    for val in attrs[key]:
                        name = val.decode('utf-8') if isinstance(val, bytes) else val
                        groups.append(name)
                    break
    except Exception:
        pass
    return groups


def ldap_host():
    grains = {}

    minion_id = __opts__.get('id', socket.gethostname())

    if minion_id in MINION_TO_AD_MAPPING:
        computer_name = MINION_TO_AD_MAPPING[minion_id]
    else:
        computer_name = minion_id.split('.')[0]

    default_grains = {
        'ldap_host_group': 'unassigned',
        'ldap_role': 'unassigned',
        'ldap_host_ous': [],
        'ldap_host_parent_ou': 'None',
        'ldap_host_groups': [],
        'ldap_host_id': minion_id,
        'ldap_search_name': computer_name,
        'ldap_ou_groups': {},
    }

    grains.update(default_grains)

    try:
        import ldap
    except ImportError:
        grains['ldap_error'] = 'python3-ldap not installed'
        return grains

    conn = None
    try:
        conn = ldap.initialize(LDAP_SERVER)
        conn.set_option(ldap.OPT_REFERRALS, 0)
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(LDAP_BIND_DN, LDAP_BIND_PW)

        # Ищем компьютер по sAMAccountName (с $ в конце)
        search_filter = f"(&(objectClass=computer)(sAMAccountName={computer_name}$))"

        result = conn.search_s(
            LDAP_DOMAIN_BASE,
            ldap.SCOPE_SUBTREE,
            search_filter,
            ['distinguishedName', 'memberOf']
        )

        if not result:
            grains['ldap_error'] = f'Computer {computer_name} not found in AD'
            return grains

        host_dn, attrs = result[0]
        host_dn_str = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn

        grains['ldap_full_dn'] = host_dn_str

        # Извлекаем OU из DN компьютера (сверху вниз: deb-ou, deb-minions)
        ous = _extract_ous_from_dn(host_dn_str)
        grains['ldap_host_ous'] = ous
        if ous:
            grains['ldap_host_parent_ou'] = ous[0]

        # Для каждой OU ищем группы внутри неё
        ou_groups = {}
        for ou_name in ous:
            # Формируем DN OU: ищем OU в базе домена
            ou_filter = f"(ou={ou_name})"
            ou_result = conn.search_s(
                LDAP_DOMAIN_BASE,
                ldap.SCOPE_SUBTREE,
                ou_filter,
                ['distinguishedName']
            )
            if ou_result:
                ou_dn_found = ou_result[0][0]
                ou_dn_str = ou_dn_found.decode('utf-8') if isinstance(ou_dn_found, bytes) else ou_dn_found
                groups = _get_groups_in_ou(conn, ou_dn_str)
                ou_groups[ou_name] = groups

        grains['ldap_ou_groups'] = ou_groups

        # Парсим memberOf компьютера
        groups_cn = []
        memberOf_key = None
        for key in attrs:
            if (isinstance(key, bytes) and key.lower() == b'memberof') or \
               (isinstance(key, str) and key.lower() == 'memberof'):
                memberOf_key = key
                break

        if memberOf_key:
            for group_dn in attrs[memberOf_key]:
                group_str = group_dn.decode('utf-8') if isinstance(group_dn, bytes) else group_dn
                parts = group_str.split(',')
                if parts and parts[0].upper().startswith('CN='):
                    groups_cn.append(parts[0][3:])

        grains['ldap_host_groups'] = groups_cn

        # ldap_host_group = первая группа или первая OU
        if groups_cn:
            grains['ldap_host_group'] = groups_cn[0]
        elif ous:
            grains['ldap_host_group'] = ous[0]

        # ldap_role = ближайшая OU (первая в списке) или первая группа
        if ous:
            grains['ldap_role'] = ous[0]
        elif groups_cn:
            grains['ldap_role'] = groups_cn[0]

    except ldap.SERVER_DOWN:
        grains['ldap_error'] = 'LDAP server unreachable'
    except ldap.INVALID_CREDENTIALS:
        grains['ldap_error'] = 'Invalid bind credentials'
    except Exception as e:
        grains['ldap_error'] = str(e)
    finally:
        if conn:
            try:
                conn.unbind_s()
            except:
                pass

    return grains
```