# Projekt 4 – Filserverinfrastruktur

Detta projekt bygger en NFS-baserad filservermiljö med Vagrant, VirtualBox och Ansible.

## Syfte

Syftet är att skapa en automatiserad filservermiljö med:

- NFS-filserver
- strukturerade kataloger
- användare och grupper
- behörighetsstyrning
- automatisk montering på klienter
- verifieringsskript
- gruppkvoter
- dokumentation kring NFS, Samba, kryptering och hotmodell
-------------------------------------------------------------------------------------------
# Projekt 4 – Filserverinfrastruktur

## Starta miljön

```text
vagrant up
vagrant status

Kör ansible:
cd /mnt/c/Users/User/Projekt-4-Oliver-Philip
ansible all -i ansible/inventory.ini -m ping
ansible-playbook -i ansible/inventory.ini ansible/site.yml

Verifiera behörigheter: 
ansible client-a -i ansible/inventory.ini -m shell -a "bash /vagrant/tests/verify.sh"

kontrollera kvoter: 
ansible server -i ansible/inventory.ini -b -m shell -a "repquota -g -s /shares && quotaon -p /shares"

Testa kvotgräns:
ansible client-a -i ansible/inventory.ini -m shell -a "sudo -u anna bash -lc 'dd if=/dev/zero of=/mnt/avdelning-a/quota-big-test.bin bs=1M count=100 status=progress; sync'"

Förväntat resultat = Disk quota exceeded 