Вот исправленный вариант — ищем OU, а не компьютер:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Ищет OU, в которой находится компьютер
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

        # Извлекаем OU из DN компьютера (ближайшая OU = первая в списке)
        ous = _extract_ous_from_dn(host_dn_str)
        grains['ldap_host_ous'] = ous
        if ous:
            grains['ldap_host_parent_ou'] = ous[0]

        # Парсим memberOf
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

Если OU всё равно пустые — проверь структуру AD:

```bash
# На любом Linux с ldapsearch:
ldapsearch -x -H ldap://172.18.84.18:389 \
  -D "CN=Administrator,CN=Users,DC=sc,DC=local" \
  -w 'qwe123!@#' \
  -b "DC=sc,DC=local" \
  "(&(objectClass=computer)(sAMAccountName=debian$))" \
  distinguishedName

# Должно вернуть что-то вроде:
# dn: CN=debian,OU=Servers,OU=Production,DC=sc,DC=local
```

Если компьютер лежит прямо в `DC=sc,DC=local` без OU — `ldap_host_ous` будет пустым.