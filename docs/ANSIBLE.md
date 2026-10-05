# Ansible

Terraform **crea** i server, Ansible li **mantiene configurati**. Il cloud-init del modulo `server` mette in sicurezza il server al primo avvio. Da lì in poi le modifiche si applicano con Ansible, senza ricreare il server.

```
ansible/
├── ansible.cfg
├── requirements.yml          # collection richieste
├── site.yml                  # playbook principale
├── inventory/
│   ├── tf_inventory.py       # legge `terraform output ansible_inventory`
│   └── staging.py            # inventario di staging
└── roles/
    └── hardening/            # stesso hardening del cloud-init (sshd, fail2ban, sysctl, ufw, ...)
```

## Inventario

L'inventario non si scrive a mano: `inventory/<env>.py` lo legge dall'output `ansible_inventory` di `envs/<env>`. In questo modo IP, utente e CIDR ammessi sono definiti **solo** nei `tfvars`, e le chiavi SSH **solo** in `envs/<env>/ssh_keys/`.

- Serve l'accesso in lettura allo state Terraform dell'ambiente, non il token Hetzner.
- Gruppi: uno per ambiente (`staging`) e uno per server (`nautica`, `ai`, ...).
- Dopo aver aggiunto un server o cambiato i CIDR serve un `terraform apply`, perché l'output venga aggiornato.

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
