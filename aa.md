(salt-venv) root@salt-master:/home/saltadm# docker exec openldap ldapwhoami -x -D "uid=i.ivanov,ou=users,dc=sc,dc=local" -w "Qwerty123!"
dn:uid=i.ivanov,ou=users,dc=sc,dc=local
(salt-venv) root@salt-master:/home/saltadm# docker exec openldap ldapsearch -x -D "cn=admin,dc=sc,dc=local" -w admin123 -b  "cn=salt-admins,ou=groups,dc=sc,dc=local" "(objectClass=groupOfNames)" member
# extended LDIF
#
# LDAPv3
# base <cn=salt-admins,ou=groups,dc=sc,dc=local> with scope subtree
# filter: (objectClass=groupOfNames)
# requesting: member
#

# salt-admins, groups, sc.local
dn: cn=salt-admins,ou=groups,dc=sc,dc=local
member: cn=placeholder,dc=sc,dc=local

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
(salt-venv) root@salt-master:/home/saltadm# nano /etc/salt/master.d/api.conf
(salt-venv) root@salt-master:/home/saltadm# sudo systemctl restart salt-master salt-api
(salt-venv) root@salt-master:/home/saltadm# tail /var/log/salt/master
2026-05-29 12:58:51,348 [salt.utils.parsers:1074][WARNING ][2758196] Master received a SIGTERM. Exiting.
2026-05-29 12:59:01,297 [salt.auth        :313 ][WARNING ][2759053] Authentication failure of type "eauth" occurred.
2026-05-29 12:59:01,297 [salt.master      :2194][WARNING ][2759053] Authentication failure of type "eauth" occurred.
2026-05-29 12:59:25,223 [salt.auth        :313 ][WARNING ][2759045] Authentication failure of type "eauth" occurred.
2026-05-29 12:59:25,223 [salt.master      :2194][WARNING ][2759045] Authentication failure of type "eauth" occurred.
2026-05-29 13:05:52,824 [salt.utils.parsers:1074][WARNING ][2758960] Master received a SIGTERM. Exiting.
2026-05-29 13:05:57,268 [salt.loaded.int.auth.ldap:285 ][WARNING ][2760070] Unable to find user i.ivanov
2026-05-29 13:05:57,268 [salt.loaded.int.auth.ldap:370 ][ERROR   ][2760070] LDAP _bind authentication FAILED
2026-05-29 13:05:58,127 [salt.auth        :313 ][WARNING ][2760070] Authentication failure of type "eauth" occurred.
2026-05-29 13:05:58,127 [salt.master      :2117][WARNING ][2760070] Authentication failure of type "eauth" occurred.
