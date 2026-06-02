```
ldapsearch -x -H ldap://192.168.1.12:389   -D "CN=Administrator,CN=Users,DC=sc,DC=local"   -w 'qwe123!@#'   -b "DC=sc,DC=local"   "(objectClass=*)"   distinguishedName | grep OU= -A 5 -B 5
# Computers, sc.local
dn: CN=Computers,DC=sc,DC=local
distinguishedName: CN=Computers,DC=sc,DC=local

# Domain Controllers, sc.local
dn: OU=Domain Controllers,DC=sc,DC=local
distinguishedName: OU=Domain Controllers,DC=sc,DC=local

# System, sc.local
dn: CN=System,DC=sc,DC=local
distinguishedName: CN=System,DC=sc,DC=local

--
# Server, System, sc.local
dn: CN=Server,CN=System,DC=sc,DC=local
distinguishedName: CN=Server,CN=System,DC=sc,DC=local

# DC1, Domain Controllers, sc.local
dn: CN=DC1,OU=Domain Controllers,DC=sc,DC=local
distinguishedName: CN=DC1,OU=Domain Controllers,DC=sc,DC=local

# krbtgt, Users, sc.local
dn: CN=krbtgt,CN=Users,DC=sc,DC=local
distinguishedName: CN=krbtgt,CN=Users,DC=sc,DC=local

--
# RID Manager$, System, sc.local
dn: CN=RID Manager$,CN=System,DC=sc,DC=local
distinguishedName: CN=RID Manager$,CN=System,DC=sc,DC=local

# RID Set, DC1, Domain Controllers, sc.local
dn: CN=RID Set,CN=DC1,OU=Domain Controllers,DC=sc,DC=local
distinguishedName: CN=RID Set,CN=DC1,OU=Domain Controllers,DC=sc,DC=local

# DnsAdmins, Users, sc.local
dn: CN=DnsAdmins,CN=Users,DC=sc,DC=local
distinguishedName: CN=DnsAdmins,CN=Users,DC=sc,DC=local

--
 ngs,CN=System,DC=sc,DC=local
distinguishedName: CN=WIN-ELG3JUM4EMG,CN=Topology,CN=Domain System Volume,CN=D
 FSR-GlobalSettings,CN=System,DC=sc,DC=local

# DFSR-LocalSettings, DC1, Domain Controllers, sc.local
dn: CN=DFSR-LocalSettings,CN=DC1,OU=Domain Controllers,DC=sc,DC=local
distinguishedName: CN=DFSR-LocalSettings,CN=DC1,OU=Domain Controllers,DC=sc,DC
 =local

# Domain System Volume, DFSR-LocalSettings, DC1, Domain Controllers, sc.local
dn: CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC1,OU=Domain Controllers
 ,DC=sc,DC=local
distinguishedName: CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC1,OU=Dom
 ain Controllers,DC=sc,DC=local

# SYSVOL Subscription, Domain System Volume, DFSR-LocalSettings, DC1, Domain Co
 ntrollers, sc.local
dn: CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC
 1,OU=Domain Controllers,DC=sc,DC=local
distinguishedName: CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-Loca
 lSettings,CN=DC1,OU=Domain Controllers,DC=sc,DC=local

# DHCP Users, Users, sc.local
dn: CN=DHCP Users,CN=Users,DC=sc,DC=local
distinguishedName: CN=DHCP Users,CN=Users,DC=sc,DC=local

--
# BCKUPKEY_PREFERRED Secret, System, sc.local
dn: CN=BCKUPKEY_PREFERRED Secret,CN=System,DC=sc,DC=local
distinguishedName: CN=BCKUPKEY_PREFERRED Secret,CN=System,DC=sc,DC=local

# SaltStack, sc.local
dn: OU=SaltStack,DC=sc,DC=local
distinguishedName: OU=SaltStack,DC=sc,DC=local

# Users, SaltStack, sc.local
dn: OU=Users,OU=SaltStack,DC=sc,DC=local
distinguishedName: OU=Users,OU=SaltStack,DC=sc,DC=local

# salt.adm, Users, SaltStack, sc.local
dn: CN=salt.adm,OU=Users,OU=SaltStack,DC=sc,DC=local
distinguishedName: CN=salt.adm,OU=Users,OU=SaltStack,DC=sc,DC=local

# minions, Users, sc.local
dn: CN=minions,CN=Users,DC=sc,DC=local
distinguishedName: CN=minions,CN=Users,DC=sc,DC=local

# SALT-MASTER, Computers, sc.local
dn: CN=SALT-MASTER,CN=Computers,DC=sc,DC=local
distinguishedName: CN=SALT-MASTER,CN=Computers,DC=sc,DC=local

# deb-minions, sc.local
dn: OU=deb-minions,DC=sc,DC=local
distinguishedName: OU=deb-minions,DC=sc,DC=local

# rpm-minions, sc.local
dn: OU=rpm-minions,DC=sc,DC=local
distinguishedName: OU=rpm-minions,DC=sc,DC=local

# ubuntu, deb-ou, deb-minions, sc.local
dn: CN=ubuntu,OU=deb-ou,OU=deb-minions,DC=sc,DC=local
distinguishedName: CN=ubuntu,OU=deb-ou,OU=deb-minions,DC=sc,DC=local

# debian, deb-ou, deb-minions, sc.local
dn: CN=debian,OU=deb-ou,OU=deb-minions,DC=sc,DC=local
distinguishedName: CN=debian,OU=deb-ou,OU=deb-minions,DC=sc,DC=local

# fedora, rpm-minions, sc.local
dn: CN=fedora,OU=rpm-minions,DC=sc,DC=local
distinguishedName: CN=fedora,OU=rpm-minions,DC=sc,DC=local

# deb-ou, deb-minions, sc.local
dn: OU=deb-ou,OU=deb-minions,DC=sc,DC=local
distinguishedName: OU=deb-ou,OU=deb-minions,DC=sc,DC=local

# search reference
ref: ldap://ForestDnsZones.sc.local/DC=ForestDnsZones,DC=sc,DC=local

# search reference

```
