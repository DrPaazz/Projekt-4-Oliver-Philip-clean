## Syfte

Syftet med projektet är att bygga en automatiserad filserverinfrastruktur med NFS. Lösningen använder Vagrant för att skapa virtuella maskiner och Ansible för att konfigurera användare, grupper, filserver, klientmontering, behörigheter och kvoter.

## Verktyg och miljö

| Verktyg | Syfte |
|---|---|
| VirtualBox | Kör virtuella maskiner |
| Vagrant | Skapar och hanterar VM:ar |
| Ubuntu | Operativsystem på server och klienter |
| Ansible | Automatiserar konfiguration |
| Git och GitHub | Versionshantering och samarbete |
| VS Code | Kodredigering |

## Virtuella maskiner

| VM | Roll | IP-adress |
|---|---|---|
| server | NFS-server | 192.168.56.10 |
| client-a | Klient | 192.168.56.21 |
| client-b | Klient | 192.168.56.22 |

## Användare och grupper

| Användare | Grupper |
|---|---|
| anna | alla, avd_a |
| bert | alla, avd_b |
| clara | alla, avd_a, avd_b |

## Katalogstruktur

| Serverkatalog | Klientmontering | Grupp |
|---|---|---|
| /shares/gemensam | /mnt/gemensam | alla |
| /shares/avdelning-a | /mnt/avdelning-a | avd_a |
| /shares/avdelning-b | /mnt/avdelning-b | avd_b |

## Behörigheter

Katalogerna använder gruppbaserade rättigheter:

| Katalog | Grupp | Mode |
|---|---|---|
| /shares/gemensam | alla | 2775 |
| /shares/avdelning-a | avd_a | 2770 |
| /shares/avdelning-b | avd_b | 2770 |

`2770` gör att ägare och grupp har åtkomst, andra användare saknar åtkomst, och setgid gör att nya filer ärver katalogens grupp.

## Automatisk montering

Klienterna monterar NFS-resurserna automatiskt via Ansible-modulen `mount`. Det innebär att NFS-mapparna monteras på klienterna under `/mnt`.

## Verifiering av G-nivå

G-nivån verifieras med följande kommandon:

```text
vagrant status
ansible all -i ansible/inventory.ini -m ping
ansible-playbook -i ansible/inventory.ini ansible/site.yml
ansible clients -i ansible/inventory.ini -m shell -a "findmnt | grep /mnt"
ansible client-a -i ansible/inventory.ini -m shell -a "bash /vagrant/tests/verify.sh"

Verifieringsskriptet testar att:

anna kan skriva till avdelning-a men inte till avdelning-b
bert kan skriva till avdelning-b men inte till avdelning-a
clara kan skriva till båda avdelningar
alla användare kan skriva till gemensam katalog

Förväntat resultat:

Alla tester lyckades.
Gruppkvoter

Projektet använder gruppkvoter på NFS-servern. /shares ligger på ett separat ext4-filsystem som monteras med usrquota och grpquota.

Grupp	Soft limit	Hard limit
avd_a	20 MB	25 MB
avd_b	20 MB	25 MB

Syftet med kvoterna är att förhindra att en grupp fyller upp hela filservern.

Verifiering av VG-nivå

VG-nivån verifieras genom att kontrollera att gruppkvoter är aktiva på filsystemet /shares.

Kvoterna kontrolleras med:

ansible server -i ansible/inventory.ini -b -m shell -a "repquota -g -s /shares && quotaon -p /shares"

Kommandot ska visa att grupperna avd_a och avd_b har konfigurerade kvoter och att group quota är aktiverad.

Därefter testas kvoten genom att användaren anna, som tillhör gruppen avd_a, försöker skapa en fil på 100 MB i /mnt/avdelning-a.

ansible client-a -i ansible/inventory.ini -m shell -a "sudo -u anna bash -lc 'dd if=/dev/zero of=/mnt/avdelning-a/quota-big-test.bin bs=1M count=100 status=progress; sync'"

Förväntat resultat:

Disk quota exceeded

Det visar att gruppkvoten fungerar och att användaren inte kan skriva mer än gruppens hårda gräns.

Jämförelse mellan NFS och Samba

NFS passar bra i Linux- och Unix-miljöer där server och klienter använder UID/GID och där filsystemet ska delas mellan Linux-maskiner. Det är enkelt att automatisera med Ansible och passar bra i detta projekt eftersom alla maskiner kör Ubuntu.

Samba/SMB passar bättre i blandade miljöer med Windows-klienter eller Active Directory. Samba är vanligt i kontorsmiljöer där Windows-integration behövs.

I detta projekt valdes NFS eftersom miljön är Linux-baserad och eftersom NFS fungerar bra tillsammans med Ubuntu, användare, grupper och Ansible.

Kryptering och hotmodell

NFS-trafik är normalt inte krypterad som standard. I en produktionsmiljö bör trafiken därför skyddas med exempelvis VPN, WireGuard, IPsec eller Kerberos-baserad NFSv4.

Möjliga hot:

obehöriga klienter på nätverket
felaktiga UID/GID
avlyssning av nätverkstrafik
felaktiga filrättigheter
komprometterad klientmaskin
överfull filserver utan kvoter

I labbmiljön används ett privat VirtualBox-nätverk, vilket minskar exponeringen. I en riktig produktionsmiljö hade man behövt starkare autentisering, kryptering, loggning och övervakning.

Slutsats

Projektet skapar en automatiserad NFS-filservermiljö med separata delningar, användare, grupper, behörigheter, automatisk montering, verifieringsskript och gruppkvoter.

Lösningen uppfyller G-nivån genom fungerande NFS-delningar, användar- och gruppstyrda behörigheter samt verifiering med skript. VG-nivån uppfylls genom gruppkvoter, jämförelse mellan NFS och Samba samt diskussion om kryptering och hotmodell.