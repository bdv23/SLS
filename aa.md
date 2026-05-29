# /etc/salt/master.d/03-openldap.conf
```
auth.ldap.server: localhost
auth.ldap.port: 389
auth.ldap.tls: False
auth.ldap.uri: 'ldap://localhost:389/'

auth.ldap.binddn: 'cn=admin,dc=sc,dc=local'
auth.ldap.bindpw: 'admin123'

# Ищем от корня, чтобы не промахнуться
auth.ldap.basedn: 'dc=sc,dc=local'
auth.ldap.filter: '(uid=%s)'

auth.ldap.accountattributename: 'uid'
auth.ldap.userattribute: 'uid'

# Группы
auth.ldap.groupou: 'ou=groups,dc=sc,dc=local'
auth.ldap.groupclass: 'groupOfNames'
auth.ldap.groupattribute: 'member'

auth.ldap.activedirectory: False
auth.ldap.timeout: 10
```