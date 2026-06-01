```

dn: dc=sc,dc=local
objectClass: top
objectClass: dcObject
objectClass: organization
o: SC
dc: sc

dn: ou=groups,dc=sc,dc=local
objectClass: organizationalUnit
ou: groups

dn: ou=users,dc=sc,dc=local
objectClass: organizationalUnit
ou: users

dn: cn=salt-admins,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-admins
member: uid=i.ivanov,ou=users,dc=sc,dc=local

dn: cn=salt-operators,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-operators
member: uid=p.petrov,ou=users,dc=sc,dc=local

dn: cn=salt-users,ou=groups,dc=sc,dc=local
objectClass: groupOfNames
cn: salt-users
member: uid=s.sidorov,ou=users,dc=sc,dc=local

dn: uid=i.ivanov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: i.ivanov
cn: Ivan Ivanov
sn: Ivanov
givenName: Ivan
mail: i.ivanov@sc.local
userPassword:: UXdlcnR5MTIzIQ==

dn: uid=p.petrov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: p.petrov
cn: Petr Petrov
sn: Petrov
givenName: Petr
userPassword:: UXdlcnR5MTIzIQ==
mail: p.petrov@sc.local

dn: uid=s.sidorov,ou=users,dc=sc,dc=local
objectClass: inetOrgPerson
uid: s.sidorov
cn: Sidor Sidorov
sn: Sidorov
givenName: Sidor
userPassword:: UXdlcnR5MTIzIQ==
mail: s.sidorov@sc.local
```
