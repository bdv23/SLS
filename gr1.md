```
root@salt-master:/home/saltadm# salt '*' grains.get ldap_host_ous
usaltm:
debian-minion-1:
ubuntu-minion-1:
salt-master:
root@salt-master:/home/saltadm# salt '*' grains.get ldap_host
usaltm:
ubuntu-minion-1:
salt-master:
debian-minion-1:
root@salt-master:/home/saltadm# nano  /srv/salt/_grains/ldap_host.py
root@salt-master:/home/saltadm# salt '*' grains.get ldap_role
debian-minion-1:
    unassigned
usaltm:
    unassigned
ubuntu-minion-1:
    unassigned
salt-master:
    unassigned
root@salt-master:/home/saltadm# nano  /srv/salt/_grains/ldap_host.py
root@salt-master:/home/saltadm# salt '*' grains.get domain_group
usaltm:
debian-minion-1:
salt-master:
    unassigned
ubuntu-minion-1:
root@salt-master:/home/saltadm# nano  /srv/salt/_grains/ldap_host.py
root@salt-master:/home/saltadm# salt '*' grains.get ldap_host_ous
usaltm:
debian-minion-1:
ubuntu-minion-1:
salt-master:
root@salt-master:/home/saltadm# nano  /srv/salt/_grains/ldap_host.py
root@salt-master:/home/saltadm# salt '*' grains.get ldap_host_groups
usaltm:
debian-minion-1:
ubuntu-minion-1:
salt-master:
root@salt-master:/home/saltadm#

```
