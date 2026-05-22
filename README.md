# NFS-filserverinfrastruktur

En automatiserad NFS-filserverinfrastruktur med strukturerad katalogorganisation, dedikerade tjänstkonton och automatisk montering på klientmaskiner. Miljön består av en NFS-server och två klienter, helt konfigurerade via Ansible med behörighetsstyrning, gruppkvoter och ett automatiserat verifieringsskript.

---

## Innehållsförteckning

- [Arkitektur](#arkitektur)
- [Miljöer och IP-adresser](#miljöer-och-ip-adresser)
- [Mappstruktur](#mappstruktur)
- [Komponenter](#komponenter)
- [Krav och förutsättningar](#krav-och-förutsättningar)
- [Kom igång](#kom-igång)
- [Säkerhetsåtgärder](#säkerhetsåtgärder)
- [Säkerhetsanalys](#säkerhetsanalys)
- [Verifiering](#verifiering)
- [Designval och motivering](#designval-och-motivering)
- [Produktion vs labbmiljö](#produktion-vs-labbmiljö)

---

## Arkitektur

![Arkitektur](docs/architecture.png)

**Användare**

- Anna (UID 3001) — kan skriva till avd-a och gemensam
- Bert (UID 3002) — kan skriva till avd-b och gemensam
- Clara (UID 3003) — kan skriva till alla avdelningar

---

## Miljöer och IP-adresser

| VM | Roll | IP-adress | Beskrivning |
|---|---|---|---|
| Server | NFS-filserver | 192.168.56.10 | Exporterar tre NFS-delningar med behörighetsstyrning och kvoter |
| Client-A | NFS-klient | 192.168.56.21 | Monterar alla delningar automatiskt via fstab vid uppstart |
| Client-B | NFS-klient | 192.168.56.22 | Monterar alla delningar automatiskt via fstab vid uppstart |

---

## Mappstruktur

```text
repo/
├── Vagrantfile                    # Definierar alla VMs och nätverksinställningar
│
├── ansible/
│   ├── inventory.ini              # Maskinlista med IP-adresser och SSH-nyckelvägar
│   ├── site.yml                   # Huvudplaybook — kör alla tasks i rätt ordning
│   │
│   └── group_vars/
│       └── all.yml                # Alla variabler: användare, grupper, delningar, kvoter
│
├── tests/
│   └── verify.sh                  # Automatiserat behörighetsverifieringsskript
│
├── docs/
│   └── architecture.png           # Arkitekturbild
│
├── .gitignore                     # Exkluderar .vagrant/, *.vdi, SSH-nycklar m.m.
└── README.md
```

---

## Komponenter

### Vagrantfile

Definierar tre virtuella maskiner i VirtualBox med ett gemensamt privat nätverk (`192.168.56.0/24`). `config.ssh.insert_key = false` gör att Vagrant använder sina standardnycklar för SSH-autentisering, vilket förenklar automatisering och Ansible-integration i labbmiljön.

Ingen applikations-portforwarding används. Endast Vagrants automatiska SSH-portforwarding används för administration av VM:arna.

### ansible/inventory.ini

Grupperar maskinerna i `[nfs_server]` och `[clients]`. Ansible-playbooken använder dessa grupper för att avgöra vilka tasks som körs var — NFS-serverkonfigurationen körs bara mot `nfs_server` och klientmonterings-tasken körs bara mot `clients`.

Inventory-filen använder SSH-användaren `vagrant` och en lokal kopia av Vagrants SSH-nyckel. Nyckeln ligger inte i Git-repot utan skapas lokalt av Vagrant och kopieras sedan till `~/.ssh/server_key`.

### ansible/group_vars/all.yml

Samlar all konfiguration på ett ställe: nätverksinställningar, grupper med GIDs, användare med UIDs och grupptillhörighet, delningsdefinitioner med behörigheter och kvotvärden. Vill man lägga till en användare eller ändra en kvot behöver man bara ändra i denna fil.

### ansible/site.yml

Huvudplaybooken är uppdelad i tre plays som körs i ordning:

1. **Alla maskiner** — skapar grupper och användare med identiska UIDs/GIDs på server och klienter
2. **NFS-server** — installerar NFS, skapar filsystem för kvoter, konfigurerar exports och aktiverar kvoter
3. **NFS-klienter** — installerar NFS-klient och konfigurerar automount via fstab

### tests/verify.sh

Automatiserat skript som testar att behörighetsstyrningen fungerar korrekt:

| Test | Resultat |
|---|---|
| Anna skriver till `/mnt/avdelning-a` | Tillåten |
| Anna skriver till `/mnt/avdelning-b` | Nekad |
| Bert skriver till `/mnt/avdelning-b` | Tillåten |
| Bert skriver till `/mnt/avdelning-a` | Nekad |
| Clara skriver till `/mnt/avdelning-a` | Tillåten |
| Clara skriver till `/mnt/avdelning-b` | Tillåten |
| Alla tre skriver till `/mnt/gemensam` | Tillåten |

---

## Krav och förutsättningar

**Programvara på Windows-hosten:**

- [VirtualBox](https://www.virtualbox.org/) — testat med version 7.2
- [Vagrant](https://www.vagrantup.com/) — testat med version 2.4.9
- [Git](https://git-scm.com/)
- [WSL2 med Ubuntu](https://learn.microsoft.com/en-us/windows/wsl/install) — krävs för att köra Ansible

**Ansible i WSL2:**

```bash
sudo apt update
sudo apt install ansible -y
```

**Hårdvarukrav:**

- Minst 6 GB RAM
- Minst 10 GB ledigt diskutrymme

---

## Kom igång

### 1. Klona repot

Kör från valfri terminal:

```bash
git clone https://github.com/malmpko/Projekt-4-Oliver-Philip.git
```

---

### 2. Starta alla VMs från PowerShell

Öppna PowerShell och gå in i projektmappen:

```powershell
cd "C:\Users\<dittanvändarnamn>\Projekt-4-Oliver-Philip"
```

Starta alla virtuella maskiner:

```powershell
vagrant up
```

Detta kan ta 5–10 minuter första gången.

Kontrollera att alla maskiner körs:

```powershell
vagrant status
```

Förväntat resultat:

```text
server    running
client-a  running
client-b  running
```

---

### 3. Gå in i projektmappen från WSL2

Öppna WSL2 och gå till samma projektmapp via `/mnt/c`:

```bash
cd /mnt/c/Users/<dittanvändarnamn>/Projekt-4-Oliver-Philip
```

Exempel:

```bash
cd /mnt/c/Users/Phili/Projekt-4-Oliver-Philip
```

---

### 4. Kopiera Vagrants SSH-nyckel till WSL2

Eftersom Ansible körs från WSL2 behöver SSH-nyckeln finnas på Linux-sidan med korrekta rättigheter.

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<dittanvändarnamn>/.vagrant.d/insecure_private_keys/vagrant.key.rsa ~/.ssh/server_key
chmod 600 ~/.ssh/server_key
```

Exempel:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/Phili/.vagrant.d/insecure_private_keys/vagrant.key.rsa ~/.ssh/server_key
chmod 600 ~/.ssh/server_key
```

---

### 5. Kör Ansible-playbooken från WSL2

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

Playbooken skapar användare och grupper, konfigurerar NFS-servern, exporterar delningar, monterar dem på klienterna och aktiverar gruppkvoter.

---

### 6. Kontrollera att Ansible når alla maskiner

```bash
ansible all -i ansible/inventory.ini -m ping
```

Förväntat resultat:

```text
server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
client-a | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
client-b | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

---

### 7. Verifiera att behörigheterna fungerar

Kör verifieringsskriptet via Ansible mot `client-a`:

```bash
ansible client-a -i ansible/inventory.ini -m shell -a "bash /vagrant/tests/verify.sh"
```

Förväntat slutresultat:

```text
Rensar gamla testfiler...
Testar gemensam katalog...
Testar att anna kan skriva till avdelning-a...
Testar att anna INTE kan skriva till avdelning-b...
OK: anna nekades till avdelning-b
Testar att bert kan skriva till avdelning-b...
Testar att bert INTE kan skriva till avdelning-a...
OK: bert nekades till avdelning-a
Testar att clara kan skriva till båda avdelningar...
Alla tester lyckades.
```

---

## Säkerhetsåtgärder

| Åtgärd | Var | Verifikation |
|---|---|---|
| Fasta UID/GID för alla användare och grupper | Alla VMs | `id anna` ska ge uid=3001 på alla maskiner |
| Setgid på delningskataloger | NFS-server | `ls -la /shares/` ska visa `drwxrws---` eller motsvarande setgid-rättigheter |
| Dedikerat tjänstkonto för NFS | NFS-server | `getent passwd svc_nfs` |
| NFS exporterar enbart till privat nätverk | NFS-server | `sudo exportfs -v` ska visa 192.168.56.0/24 |
| root_squash aktiverat på alla exports | NFS-server | `sudo exportfs -v` ska visa root_squash |
| Kvoter per grupp | NFS-server | `sudo repquota -g /shares` |
| `_netdev` i fstab på klienter | Client-A, Client-B | `cat /etc/fstab \| grep nfs` |
| SSH-nycklar utanför Git | Alla | Nyckeln läggs i `~/.ssh/`, inte i repot |
| Inga secrets i versionshanteringen | Alla | `.gitignore` exkluderar `.vagrant/`, nycklar och VM-filer |

---

## Säkerhetsanalys

### Kvarvarande brister

**Brist 1: NFS-trafik är okrypterad**

NFS utan Kerberos-baserad säkerhet skickar trafik okrypterat över nätverket. En angripare med tillgång till det interna nätverket kan avlyssna filinnehåll och potentiellt utföra man-in-the-middle-attacker eller replay-attacker.

*Åtgärd i produktion:* WireGuard VPN eller Kerberos-baserad NFS-säkerhet.

*Accepterat i denna miljö eftersom:* Det privata nätverket (`192.168.56.0/24`) är isolerat och enbart tillgängligt från värddatorn.

---

**Brist 2: Ingen brandvägg (UFW) konfigurerad**

NFS-tjänsten och relaterade portar är öppna inom det privata nätverket. Alla maskiner i nätverket kan ansluta till NFS-servern.

*Åtgärd i produktion:*

```bash
ufw allow from 192.168.56.21 to any port 2049
ufw allow from 192.168.56.22 to any port 2049
ufw deny 2049
```

*Accepterat i denna miljö eftersom:* Nätverket innehåller enbart de tre projektmaskinerna och är inte exponerat mot internet.

---

**Brist 3: Ingen loggning eller övervakning**

Det finns ingen centraliserad loggsamling eller larmning vid ovanlig aktivitet, till exempel upprepade misslyckade autentiseringsförsök, oväntat höga diskskrivningar eller kvotöverskridningar.

*Åtgärd i produktion:* Centraliserad loggning, SIEM, kvotlarm och diskutrymmesövervakning.

*Accepterat i denna miljö eftersom:* Miljön används enbart lokalt för labbtestning och innehåller inga känsliga data.

---

### Vad som skyddar miljön

Trots ovanstående brister har miljön följande skyddslager:

- Nätverkssegmentering — det privata nätverket är isolerat från internet
- Setgid på delningskataloger — korrekt gruppägarskap på alla nyskapade filer
- Principen om minsta privilegium — användare får bara skriva där de ska ha åtkomst
- Fasta UIDs/GIDs — konsekvent identitetshantering över alla maskiner
- `root_squash` — root-eskalering via NFS-klient begränsas
- Kvoter — en grupp kan inte fylla hela filsystemet
- Inga secrets i Git — känsliga nycklar hanteras utanför versionshanteringen

---

## Verifiering

### Verifiering av behörigheter

Kör det automatiserade verifieringsskriptet via Ansible mot `client-a`:

```bash
ansible client-a -i ansible/inventory.ini -m shell -a "bash /vagrant/tests/verify.sh"
```

Skriptet kontrollerar:

- Att alla användare kan skriva till gemensam-delningen
- Att anna kan skriva till avdelning-a men inte avdelning-b
- Att bert kan skriva till avdelning-b men inte avdelning-a
- Att clara kan skriva till båda avdelningarna

Förväntat resultat:

```text
Alla tester lyckades.
```

---

### Verifiering av kvoter

Kvoter verifieras genom att försöka skriva både små och stora filer till en delning.

Rensa gamla quota-testfiler:

```bash
ansible server -i ansible/inventory.ini -b -m shell -a "rm -f /shares/avdelning-a/quota-big-test.bin /shares/avdelning-a/quota-small-test.bin"
```

Liten fil, ska lyckas:

```bash
ansible client-a -i ansible/inventory.ini -m shell -a "sudo -u anna bash -lc 'dd if=/dev/zero of=/mnt/avdelning-a/quota-small-test.bin bs=1M count=10 status=none; sync'"
```

Stor fil, ska stoppas av kvoten:

```bash
ansible client-a -i ansible/inventory.ini -m shell -a "sudo -u anna bash -lc 'dd if=/dev/zero of=/mnt/avdelning-a/quota-big-test.bin bs=1M count=100 status=progress; sync'"
```

Förväntat resultat:

```text
Disk quota exceeded
```

Det verifierar att gruppkvoterna fungerar korrekt.

---

### Kontroll av quota-status

Quota-status kan kontrolleras på servern:

```bash
ansible server -i ansible/inventory.ini -b -m shell -a "repquota -g -s /shares"
```

Det ska visa gruppkvoter för bland annat `avd_a` och `avd_b`.

---

## Designval och motivering

### Varför NFS?

Vi valde NFS eftersom projektmiljön består av Linux-maskiner och NFS är ett naturligt val för filserverdelning mellan Linux-system. NFS är integrerat i Linux-miljön, fungerar väl med UID/GID-baserade behörigheter och passar bra för en intern server-klient-miljö.

NFS passar särskilt bra i detta projekt eftersom:

- alla klienter och servern kör Linux
- miljön ligger i ett isolerat privat nätverk
- behörigheter kan styras med Linux-grupper
- klienterna kan montera delningar automatiskt via `/etc/fstab`
- Ansible kan konfigurera både server och klienter på ett konsekvent sätt

---

### Varför inte Samba (SMB/CIFS)?

Vi övervägde Samba eftersom det är vanligt i blandade Windows/Linux-miljöer och ger bra kompatibilitet mot Windows-klienter. Vi valde dock bort Samba av flera skäl:

- Projektmiljön består enbart av Linux-maskiner, vilket gör NFS mer naturligt och enklare att konfigurera.
- NFS är integrerat direkt i Linux-kärnan och kräver mindre overhead än SMB/CIFS.
- Behörighetsstyrning med UID/GID fungerar mer konsekvent i rena Linux-miljöer.
- NFS ger generellt bättre prestanda än Samba mellan Linux-system.
- Projektets fokus låg på Linux-baserad filserverarkitektur snarare än kompatibilitet mellan operativsystem.

Samba hade varit ett bättre val om klienterna huvudsakligen körde Windows eller om Active Directory-integration varit ett krav.

---

### Varför inte SSHFS?

SSHFS hade gett kryptering via SSH, men valdes bort eftersom det inte är lika lämpligt för flera samtidiga användare och permanenta servermonteringar. SSHFS passar bättre för enklare personliga monteringar än för en central filservermiljö med flera användare, grupper och kvoter.

---

### Varför inte iSCSI?

iSCSI är blocklagring snarare än fillagring. Det hade krävt en annan arkitektur där klienterna får tillgång till blockenheter snarare än gemensamma kataloger. För vårt användningsfall behövdes delade kataloger med Linux-behörigheter, vilket gör NFS mer passande.

---

### Varför ett separat filsystem för /shares?

`/shares` monteras från en dedikerad loop-enhet (`/srv/nfs-quota.img`) snarare än att ligga direkt på rot-filsystemet.

Det finns två huvudanledningar:

1. Kvoter i Linux aktiveras på filsystemsnivå med exempelvis `usrquota` och `grpquota`.
2. Ett separat filsystem förhindrar att NFS-användare fyller upp rot-partitionen och kraschar systemet.

Detta gör lagringen mer kontrollerad och säkrare även i en labbmiljö.

---

### Varför fasta UIDs och GIDs?

NFS skickar inte användarnamn utan numeriska UIDs och GIDs. Om `anna` har UID 3001 på servern men UID 4001 på klienten kommer servern inte att tolka användaren korrekt, och behörigheterna kan bli fel.

Genom att definiera UIDs och GIDs explicit i `group_vars/all.yml` och applicera dem på alla maskiner via Ansible garanteras konsistens mellan server och klienter.

---

### Varför group_vars/all.yml istället för hårdkodade värden?

Att samla all konfiguration i en variabelfil gör det enkelt att lägga till användare, ändra kvoter eller byta IP-adresser utan att ändra själva task-koden.

Det följer principen separation of concerns:

- playbooken beskriver hur systemet konfigureras
- variabelfilen beskriver vad som ska konfigureras

Det gör lösningen lättare att underhålla och vidareutveckla.

---

### Varför bash -lc i verifieringsskriptet?

`sudo -u anna bash -lc 'kommando'` öppnar ett login-shell som användaren `anna`. Det gör att användarens grupptillhörighet laddas korrekt innan testkommandot körs.

Utan `bash -lc` kan vissa gruppbehörigheter saknas i sessionen, vilket kan ge falska testresultat.

---

## Produktion vs labbmiljö

| Område | Labbmiljö | Produktionsmiljö |
|---|---|---|
| Kryptering | Ingen kryptering av NFS-trafik | WireGuard VPN eller Kerberos |
| SSH-nycklar | Vagrants standardnycklar | Unika nycklar per maskin med rotation |
| Brandvägg | Ingen UFW-konfiguration | UFW med allow-regler per klient och port |
| Autentisering | Lokala användare med fasta UID/GID | Active Directory, LDAP eller annan central identitetshantering |
| Övervakning | Ingen central loggning | SIEM, logginsamling, kvotlarm och diskutrymmeslarm |
| Backup | Ingen backup | Automatiserade snapshots och off-site backup |
| Tillgänglighet | En NFS-server | Redundans eller backup-server |
| Kvoter | 20 MB soft / 25 MB hard | Anpassade kvoter beroende på verksamhetens behov |
| Secrets | SSH-nyckel i `~/.ssh` lokalt | HashiCorp Vault eller annan secret manager |
| OS-härdning | Grundläggande standardinstallation | CIS Benchmark och regelbunden patchning |

---


---
*Skapad av: Oliver Paz och Philip Malm*  
*Kurs: Virtualiseringsteknik*  
*Datum: 2026-05-22*