# Ansible

Terraform **crea** i server, Ansible li **mantiene configurati**. Il cloud-init del modulo `server` mette in sicurezza il server al primo avvio. Da lì in poi le modifiche si applicano con Ansible, senza ricreare il server.

```
ansible/
├── ansible.cfg
├── requirements.yml          # collection richieste
├── site.yml                  # playbook principale
├── inventory/
│   ├── tf_inventory.py       # legge `terraform output ansible_inventory`
│   ├── staging.py            # inventario di staging
│   └── group_vars/           # variabili per server (<server>.yml) o ambiente (<env>.yml)
└── roles/
    ├── hardening/            # stesso hardening del cloud-init (sshd, fail2ban, sysctl, ufw, ...)
    ├── data_volume/          # mount del volume dati per UUID
    └── docker/               # Docker Engine + Compose dal repository ufficiale
```

## Inventario

L'inventario non si scrive a mano: `inventory/<env>.py` lo legge dall'output `ansible_inventory` di `envs/<env>`. In questo modo IP, utente e CIDR ammessi sono definiti **solo** nei `tfvars`, e le chiavi SSH **solo** in `envs/<env>/ssh_keys/`.

- Serve l'accesso in lettura allo state Terraform dell'ambiente, non il token Hetzner.
- Gruppi: uno per ambiente (`staging`) e uno per server (`nautica`, `ai`, ...).
- Dopo aver aggiunto un server o cambiato i CIDR serve un `terraform apply`, perché l'output venga aggiornato.
- Le variabili Ansible per server stanno in `inventory/group_vars/<server>.yml` (es. `nautica.yml`) e valgono in tutti gli ambienti. Quelle di un solo ambiente vanno in `group_vars/<env>.yml`.

## Prerequisiti

Ansible non gira su Windows come nodo di controllo: va usato da **WSL** (Ubuntu) o dalla CI.

```bash
sudo apt install -y python3-venv
python3 -m venv ~/.venvs/ansible
~/.venvs/ansible/bin/pip install ansible-core
source ~/.venvs/ansible/bin/activate
cd ansible
ansible-galaxy collection install -r requirements.yml
```

Servono anche `terraform` nel PATH (vale anche `terraform.exe` di Windows, da WSL) e la chiave SSH privata, caricata in `ssh-agent` o passata con `--private-key`.

**Repo su `/mnt/c` (WSL):** la directory risulta scrivibile da tutti e Ansible **ignora** `ansible.cfg` per sicurezza. Va indicato in modo esplicito:

```bash
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
```

## Uso

Da `ansible/`:

```bash
# 1. Cosa cambierebbe, senza toccare nulla (come terraform plan)
ansible-playbook -i inventory/staging.py site.yml --check --diff

# 2. Applica
ansible-playbook -i inventory/staging.py site.yml

# Solo un server
ansible-playbook -i inventory/staging.py site.yml --limit nautica
```

Il playbook è idempotente: rilanciato su un server già conforme non cambia nulla (`changed=0`).

## Ruolo `hardening`

Applica la stessa configurazione del cloud-init del modulo `server` (vedi [SERVER.md](modules/SERVER.md)), più due cose che il cloud-init non può fare:

- **Chiavi SSH esclusive**: `authorized_keys` di `deploy` contiene **solo** le chiavi presenti in `envs/<env>/ssh_keys/`. Togliere un file `.pub` e rilanciare il playbook revoca l'accesso su tutti i server.
- **Correzione delle modifiche manuali**: un file di configurazione modificato a mano sul server torna allo stato dichiarato.

La config di sshd viene validata (`sshd -t`) prima di essere scritta: se non è valida, il task fallisce e sshd resta sulla config precedente.

| Variabile | Default | Descrizione |
|---|---|---|
| `hardening_timezone` | `UTC` | Timezone |
| `hardening_fail2ban_bantime` | `1h` | Durata del ban |
| `hardening_fail2ban_findtime` | `10m` | Finestra in cui contare i tentativi falliti |
| `hardening_fail2ban_maxretry` | `5` | Tentativi tollerati |
| `hardening_journald_max_use` | `500M` | Spazio massimo del journal |
| `hardening_login_banner` | banner "ACCESSO RISERVATO" | Vuoto = nessun banner |

`admin_user`, `admin_ssh_public_keys`, `allowed_ssh_cidrs` e `allowed_http_cidrs` arrivano dall'inventario.

**I default devono restare allineati a quelli del modulo Terraform `server`.** Un valore cambiato da una parte sola crea differenze tra server nuovi (cloud-init) e server esistenti (Ansible).

## Ruolo `data_volume`

Applicato solo ai server con un volume (`volume_size > 0` nei `tfvars`). Il device arriva dall'inventario.

- Monta il volume per **UUID** in `data_volume_mount_path` (default `/srv/data`), con `nofail`, e scrive la voce in `/etc/fstab`.
- **Non formatta mai** un volume che ha già un filesystem (Hetzner lo crea alla creazione del volume).
- Se il volume è stato ingrandito in Terraform, allarga il filesystem.

| Variabile | Default | Descrizione |
|---|---|---|
| `data_volume_mount_path` | `/srv/data` | Mount point |
| `data_volume_fstype` | `ext4` | Deve coincidere con `format` del modulo `volume` |
| `data_volume_mount_opts` | `defaults,nofail,discard` | Opzioni di mount |

## Ruolo `docker`

Installa Docker Engine e il plugin `docker compose` dal **repository ufficiale Docker**, in **modalità rootless**: il daemon gira come utente senza privilegi (`app`), non come root. Si attiva per server con `docker_enabled: true` in `inventory/group_vars/<server>.yml`.

### Perché rootless

Con Docker classico il daemon è root: chi controlla Docker (o esce da un container) è root sull'host. In rootless:

- daemon e container girano come l'utente `app`, i cui UID sono rimappati (subuid): **chi esce da un container si ritrova `app`, non root**;
- **nessuno è nel gruppo `docker`**. Il daemon di sistema (root) è fermato e mascherato;
- le porte pubblicate sono socket normali dell'host, quindi **ufw le filtra** (con Docker classico invece le scavalca).

### Uso

```bash
sudo -iu app                  # tutti i comandi docker si danno come utente app
docker ps
docker compose up -d
systemctl --user status docker   # il daemon è un servizio dell'utente app
```

Il daemon parte al boot anche senza login (linger). Immagini, container e volumi Docker stanno in `/home/app/.local/share/docker`.

### Sicurezza dell'installazione

- La chiave GPG del repository viene confrontata con il **fingerprint ufficiale**: se non corrisponde, il ruolo si ferma.
- I pacchetti non ufficiali in conflitto (`docker.io`, `podman-docker`, ...) vengono rimossi.
- Su Ubuntu 24.04 gli user namespace non privilegiati sono vietati salvo profilo AppArmor: il ruolo installa quello per `rootlesskit`.
- I controller cgroup sono delegati alle sessioni utente, così i limiti di memoria e CPU dei container funzionano.

`~app/.config/docker/daemon.json`:

| Opzione | Valore | Perché |
|---|---|---|
| `ip` | `127.0.0.1` | le porte pubblicate sono solo locali, salvo richiesta esplicita |
| `log-opts` | 10m × 3 file | rotazione dei log: senza, i log dei container riempiono il disco |
| `no-new-privileges` | `true` | i processi nei container non acquisiscono privilegi (setuid) |
| `icc` | `false` | niente traffico tra container sulla rete `bridge` predefinita; le reti di Compose non sono toccate |

### Porte e firewall

- `ports: "8080:80"` pubblica su `127.0.0.1`: raggiungibile solo dal server (es. da un reverse proxy).
- Per esporre una porta: `ports: "0.0.0.0:8080:80"`. Deve essere aperta anche **in ufw e nel firewall Hetzner**.
- **Porte sotto 1024 (80/443)**: di default un utente non root non può aprirle. Per un reverse proxy impostare `docker_unprivileged_port_start: 80` (la 22 resta riservata a root).

### Limiti di rootless

- **IP dei client**: con il port driver predefinito, i container vedono come sorgente un IP interno e non quello reale del client. Conta per i log e i rate limit di un reverse proxy: va configurato quando lo si introduce.
- La rete in user-mode è più lenta di quella del kernel. Per traffico normale non è un problema.
- Niente profili AppArmor sui container, niente `--privileged` reale, niente reti overlay (Swarm).

| Variabile | Default | Descrizione |
|---|---|---|
| `docker_enabled` | `false` | Abilita il ruolo sul server |
| `docker_rootless_user` | `app` | Utente che esegue daemon e container |
| `docker_default_bind_ip` | `127.0.0.1` | IP predefinito delle porte pubblicate |
| `docker_unprivileged_port_start` | `1024` | Porta più bassa apribile senza root (`80` per un reverse proxy) |
| `docker_log_max_size` / `docker_log_max_file` | `10m` / `3` | Rotazione dei log dei container |

Verifica sul server:

```bash
systemctl is-active docker.service                 # inactive: il daemon root non gira
sudo -iu app docker info --format '{{.SecurityOptions}}'   # contiene name=rootless
sudo -iu app docker compose version
sudo -iu app docker run --rm hello-world
ps -o user= -C dockerd                             # app, non root
```
