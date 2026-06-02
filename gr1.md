```
ldapsearch -H ldap://172.18.84.18 -x -D "Administrator@sc.local" -W -b "OU=deb-ou,OU=deb-minions,DC=sc,DC=local" "(objectClass=*)" dn
Enter LDAP Password:
# extended LDIF
#
# LDAPv3
# base <OU=deb-ou,OU=deb-minions,DC=sc,DC=local> with scope subtree
# filter: (objectClass=*)
# requesting: dn
#

# deb-ou, deb-minions, sc.local
dn: OU=deb-ou,OU=deb-minions,DC=sc,DC=local

# ubuntu, deb-ou, deb-minions, sc.local
dn: CN=ubuntu,OU=deb-ou,OU=deb-minions,DC=sc,DC=local

# debian, deb-ou, deb-minions, sc.local
dn: CN=debian,OU=deb-ou,OU=deb-minions,DC=sc,DC=local

# search result
search: 2
result: 0 Success

# numResponses: 4
# numEntries: 3


```
