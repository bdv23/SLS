```
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Custom Salt grain: ldap_host для Active Directory
Возвращает список доменных групп, в которых состоит компьютер.
Поддерживает фильтрацию групп по родительскому OU.
"""

import socket

__virtualname__ = 'ldap_host'

# ================= LDAP-конфигурация =================
LDAP_SERVER = 'ldap://172.18.84.18:389'
LDAP_BIND_DN = 'CN=Administrator,CN=Users,DC=sc,DC=local'
LDAP_BIND_PW = 'qwe123!@#'  # ⚠️ Рекомендуется использовать secrets management
LDAP_SEARCH_BASE = 'DC=sc,DC=local'

# Фильтрация групп по родительскому OU.
# Пустой список = возвращать все группы.
# Пример: ['OU=SaltGroups,DC=sc,DC=local']
# Группа включается, если её полный DN находится ВНУТРИ указанного OU.
FILTER_OUS = []
# =====================================================


def __virtual__():
    return __virtualname__


def _parse_dn(dn_str):
    """
    Парсит DN в словарь компонентов.
    Пример: 'CN=minions,CN=Users,DC=sc,DC=local'
    -> {'CN': ['minions', 'Users'], 'DC': ['sc', 'local'], 'OU': []}
    """
    result = {}
    for part in dn_str.split(','):
        if '=' in part:
            key, value = part.split('=', 1)
            key = key.strip().upper()
            value = value.strip()
            result.setdefault(key, []).append(value)
    return result


def _is_group_in_ou(group_dn, ou_filter):
    """
    Проверяет, находится ли группа внутри указанного фильтра OU.
    Сравнивает DN в нормализованном виде (без пробелов, нижний регистр).    """
    g_dn = group_dn.lower().replace(' ', '')
    f_ou = ou_filter.lower().replace(' ', '')
    return g_dn == f_ou or g_dn.endswith(',' + f_ou)


def ldap_host():
    # Инициализация зерен с дефолтными значениями
    grains = {
        'ldap_host_groups': [],
        'ldap_host_groups_full': [],
        'ldap_host_id': None,
        'ldap_full_dn': None,
        'ldap_host_ou': [],
        'ldap_error': None
    }

    # Проверка зависимости
    try:
        import ldap
        from ldap.filter import escape_filter_chars
    except ImportError:
        grains['ldap_error'] = 'python-ldap not installed. Run: apt install python3-ldap'
        return grains

    minion_id = __opts__.get('id', socket.gethostname())
    computer_name = minion_id.rstrip('$').upper()
    grains['ldap_host_id'] = minion_id

    conn = None
    try:
        # Подключение к LDAP
        conn = ldap.initialize(LDAP_SERVER)
        conn.set_option(ldap.OPT_REFERRALS, 0)
        conn.set_option(ldap.OPT_TIMEOUT, 10)
        conn.simple_bind_s(LDAP_BIND_DN, LDAP_BIND_PW)

        # Поиск компьютера (учитываем варианты имени)
        safe_name = escape_filter_chars(computer_name)
        search_filter = (
            f"(&(objectClass=computer)"
            f"(|(sAMAccountName={safe_name}$)(cn={safe_name})(sAMAccountName={safe_name})))"
        )

        result = conn.search_s(
            LDAP_SEARCH_BASE,
            ldap.SCOPE_SUBTREE,
            search_filter,
            ['dn', 'cn', 'memberOf']
        )
        if not result or not result[0][0]:
            grains['ldap_error'] = f'Computer not found: {computer_name}'
            return grains

        # Обработка найденного компьютера
        host_dn, attrs = result[0]
        host_dn_str = host_dn.decode('utf-8') if isinstance(host_dn, bytes) else host_dn
        grains['ldap_full_dn'] = host_dn_str

        # Парсим OU компьютера для дополнительной информации
        host_dn_parts = _parse_dn(host_dn_str)
        grains['ldap_host_ou'] = host_dn_parts.get('OU', [])

        # Сбор групп
        groups = []
        member_of = attrs.get(b'memberOf', [])
        if member_of:
            for group_dn in member_of:
                group_str = group_dn.decode('utf-8') if isinstance(group_dn, bytes) else group_dn

                # Применяем фильтр по OU, если задан
                if FILTER_OUS:
                    if not any(_is_group_in_ou(group_str, ou) for ou in FILTER_OUS):
                        continue

                # Парсим информацию о группе
                group_parts = _parse_dn(group_str)
                cn_list = group_parts.get('CN', [])
                group_name = cn_list[0] if cn_list else group_str.split(',')[0].replace('CN=', '', 1)

                groups.append({
                    'name': group_name,
                    'dn': group_str,
                    'ou': group_parts.get('OU', []),  # OU, в котором лежит сама группа
                    'components': group_parts
                })

        grains['ldap_host_groups'] = [g['name'] for g in groups]
        grains['ldap_host_groups_full'] = groups

    except ldap.SERVER_DOWN:
        grains['ldap_error'] = 'LDAP server unreachable'
    except ldap.INVALID_CREDENTIALS:
        grains['ldap_error'] = 'Invalid bind credentials'
    except ldap.FILTER_ERROR:
        grains['ldap_error'] = 'Invalid LDAP search filter syntax'
    except Exception as e:
        grains['ldap_error'] = f'{type(e).__name__}: {str(e)}'
    finally:        if conn:
            try:
                conn.unbind_s()
            except Exception:
                pass  # Игнорируем ошибки при закрытии

    return grains
```