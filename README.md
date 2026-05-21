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

```
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
├── .gitignore                     # Exkluderar .vagrant/, *.vdi, SSH-nycklar m.m.
└── README.md
```

---

## Komponenter

### Vagrantfile

Definierar tre virtuella maskiner i VirtualBox med ett gemensamt privat nätverk (`192.168.56.0/24`). `config.ssh.insert_key = false` gör att alla maskiner använder Vagrants gemensamma insecure key, vilket förenklar Ansible-konfigurationen. Ingen port forwarding — miljön är helt intern.

### ansible/inventory.ini

Grupperar maskinerna i `[nfs_server]` och `[clients]`. Ansible-playbooken använder dessa grupper för att avgöra vilka tasks som körs var — NFS-serverkonfigurationen körs bara mot `nfs_server` och klientmonterings-tasken körs bara mot `clients`.

### ansible/group_vars/all.yml

Samlar all konfiguration på ett ställe: nätverksinställningar, grupper med GIDs, användare med UIDs och grupptillhörighet, delningsdefinitioner med behörigheter och kvotvärden. Vill man lägga till en användare eller ändra en kvot behöver man bara ändra i denna fil.

### ansible/site.yml

Huvudplaybooken uppdelad i tre plays som körs i ordning:

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

- Minst 6 GB RAM (projektet använder ~3 GB)
- Minst 10 GB ledigt diskutrymme

---

## Kom igång

**1. Klona repot**

```bash
git clone https://github.com/malmpko/Projekt-4-Oliver-Philip.git
cd Projekt-4-Oliver-Philip
```

**2. Starta alla VMs (tar 5–10 minuter första gången)**

```bash
vagrant up
```

**3. Kopiera SSH-nyckeln till WSL2**

```bash
cp /mnt/c/Users/<dittanvändarnamn>/.vagrant.d/insecure_private_keys/vagrant.key.rsa ~/.ssh/server_key
chmod 600 ~/.ssh/server_key
```

**4. Kör Ansible-playbooken från WSL2**

```bash
cd /mnt/c/Users/<dittanvändarnamn>/Projekt-4-Oliver-Philip
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

**5. Verifiera att behörigheterna fungerar**

```bash
vagrant ssh client-a
sed -i 's/\r//' /vagrant/tests/verify.sh
/bin/bash /vagrant/tests/verify.sh
```

**Förväntat slutresultat:**

```
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
| Setgid på delningskataloger | NFS-server | `ls -la /shares/` ska visa `drwxrws---` |
| Dedikerat tjänstkonto för NFS | NFS-server | `getent passwd svc_nfs` |
| NFS exporterar enbart till privat nätverk | NFS-server | `sudo exportfs -v` ska visa 192.168.56.0/24 |
| root_squash aktiverat på alla exports | NFS-server | `sudo exportfs -v` ska visa root_squash |
| Kvoter per grupp (20 MB soft / 25 MB hard) | NFS-server | `sudo repquota -g /shares` |
| `_netdev` i fstab på klienter | Client-A, Client-B | `cat /etc/fstab \| grep nfs` |
| SSH-nycklar utanför Git | Alla | Nyckeln läggs i `~/.ssh/`, finns i `.gitignore` |
| Inga secrets i versionshanteringen | Alla | `git log --all -- *.key *.pem` |

---

## Säkerhetsanalys

### Kvarvarande brister

**Brist 1: NFS-trafik är okrypterad**

NFS v3/v4 utan Kerberos skickar all trafik i klartext över nätverket. En angripare med tillgång till det interna nätverket kan avlyssna filinnehåll och potentiellt utföra man-in-the-middle-attacker eller replay-attacker.

*Åtgärd i produktion:* WireGuard VPN.

*Accepterat i denna miljö eftersom:* Det privata nätverket (192.168.56.0/24) är isolerat och enbart tillgängligt från värddatorn.

---

**Brist 2: Ingen brandvägg (UFW) konfigurerad**

NFS-tjänsten (port 2049) och relaterade RPC-portar är öppna utan brandväggsbegränsningar. Alla maskiner i nätverket kan ansluta till NFS-servern.

*Åtgärd i produktion:*

```bash
ufw allow from 192.168.56.21 to any port 2049
ufw allow from 192.168.56.22 to any port 2049
ufw deny 2049
```

*Accepterat i denna miljö eftersom:* Nätverket innehåller enbart de tre projektmaskinerna och är inte exponerat mot internet.

---

**Brist 3: Ingen loggning eller övervakning**

Det finns ingen centraliserad loggsamling eller larmning vid ovanlig aktivitet — t.ex. upprepade misslyckade autentiseringsförsök, oväntat höga diskskrivningar eller kvotöverskridningar.

*Åtgärd i produktion:* Centraliserat SIEM med kvot- och disklarm.

*Accepterat i denna miljö eftersom:* Miljön används enbart lokalt för labbtestning och innehåller inga känsliga data.

---

### Vad som skyddar miljön

Trots ovanstående brister har miljön följande skyddslager:

- Nätverkssegmentering — det privata nätverket är isolerat från internet
- Setgid på delningskataloger — korrekt gruppägarskap på alla nyskapade filer
- Principen om minsta privilegium — anna kan inte skriva till berts avdelning
- Fasta UIDs/GIDs — konsekvent identitetshantering över alla maskiner
- `root_squash` — root-eskalering via NFS-klient förhindras
- Kvoter — en användare kan inte fylla hela diskutrymmet
- Inga secrets i Git — känsliga nycklar hanteras utanför versionshanteringen

---

## Verifiering

Kör det automatiserade verifieringsskriptet från en klientmaskin:

```bash
vagrant ssh client-a
sed -i 's/\r//' /vagrant/tests/verify.sh
/bin/bash /vagrant/tests/verify.sh
```

Skriptet kontrollerar:

- Att alla användare kan skriva till gemensam-delningen
- Att anna kan skriva till avdelning-a men INTE avdelning-b
- Att bert kan skriva till avdelning-b men INTE avdelning-a
- Att clara kan skriva till båda avdelningarna

---

## Designval och motivering

### Varför NFS och inte ett annat protokoll?

Vi valde NFS eftersom kursen fokuserar på Linux-miljöer och NFS är nativt integrerat i Linux-kärnan utan extra konfiguration. Det finns alternativ vi övervägde:

- **SSHFS** hade gett kryptering ur lådan men är betydligt långsammare och inte lämpat för flera parallella användare. I en miljö där prestanda spelar roll är NFS ett bättre val.
- **iSCSI** är blocklagring snarare än fillagring och hade krävt en helt annan arkitektur, vilket vi ansåg vara onödigt komplext för vårt användningsfall.

NFS passar bäst när alla maskiner kör Linux och befinner sig i ett kontrollerat nätverk, vilket stämmer med vår miljö.

### Varför ett separat filsystem för /shares?

`/shares` monteras från en dedikerad loop-enhet (`/srv/nfs-quota.img`) snarare än att ligga direkt på rot-filsystemet. Det finns två anledningar: kvoter i Linux kräver att de är aktiverade på filsystemsnivå (`usrquota,grpquota`), och ett separat filsystem förhindrar att NFS-användare fyller upp rot-partitionen och kraschar systemet.

### Varför fasta UIDs och GIDs?

NFS skickar inte användarnamn utan numeriska UIDs och GIDs. Om anna har UID 3001 på servern men UID 4001 på klienten ser NFS-servern en okänd användare och behörigheterna fungerar inte. Genom att definiera UIDs/GIDs explicit i `group_vars/all.yml` och applicera dem på alla maskiner via Ansible garanteras konsistens.

### Varför group_vars/all.yml istället för hårdkodade värden?

Att samla all konfiguration i en fil gör det enkelt att lägga till användare, ändra kvoter eller byta IP-adress utan att röra tasks-koden. Det följer principen om separation of concerns — koden beskriver *hur* man konfigurerar, variablerna beskriver *vad* som ska konfigureras.

### Varför bash -lc i verifieringsskriptet?

`sudo -u anna bash -lc 'kommando'` öppnar ett login-shell som anna, vilket laddar användarens grupptillhörighet korrekt. Utan `-lc` kan grupper saknas i sessionen och NFS-behörigheterna fungerar inte som förväntat, vilket skulle ge falska testresultat.

---

## Produktion vs labbmiljö

| Område | Labbmiljö (nuvarande) | Produktionsmiljö |
|---|---|---|
| Kryptering | Ingen kryptering av NFS-trafik | WireGuard VPN |
| SSH-nycklar | Vagrants gemensamma insecure key | Unika nycklar per maskin med regelbunden rotation |
| Brandvägg | Ingen UFW-konfiguration | UFW med allow-regler per IP och port |
| Autentisering | Lokala användare med statiska lösenord | Active Directory med centraliserad autentisering |
| Övervakning | Ingen loggning | Centraliserad SIEM, kvotlarm, diskutrymmelarm |
| Backup | Ingen backup | Automatiserade snapshots och off-site replikering |
| Tillgänglighet | Single point of failure — en NFS-server | En extra NFS-server som backup |
| Kvoter | 20 MB soft / 25 MB hard | Anpassade kvoter beroende på behov |
| Secrets | SSH-nyckel i `~/.ssh` | HashiCorp Vault |
| OS-härdning | Ingen härdning | CIS Benchmark |

---

*Skapad av: Oliver Paz och Philip Malm*  
*Kurs: Virtualiseringsteknik*  
*Datum: 2026-05-22*
