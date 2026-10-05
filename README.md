# terraform-hetzner-infra

Infrastruttura come codice per i server su **Hetzner Cloud**: crea i server di `staging` e `prod` già messi in sicurezza e li mantiene configurati nel tempo.

- **Terraform** crea l'infrastruttura: server, firewall, chiavi SSH, rete privata, volumi dati.
- **cloud-init** applica l'hardening al primo avvio, così il server è protetto da subito.
- **Ansible** mantiene la configurazione sui server esistenti (hardening, chiavi SSH, mount dei volumi) senza ricrearli.

Tutto ciò che definisce l'infrastruttura sta nel repo e cambia solo via PR. I segreti (token Hetzner) restano fuori.

## Cosa crea, per ambiente

| Componente | Dettaglio |
|---|---|
| Hetzner Project | uno per ambiente (`staging`, `prod`), ciascuno con il proprio token |
| Server | uno per voce della mappa `servers` nei `tfvars` (es. `nautica`), Ubuntu 24.04 |
| Firewall | deny-by-default: SSH solo dagli IP ammessi, 80/443 solo se richiesti |
| Chiavi SSH | una per persona, da `envs/<env>/ssh_keys/*.pub` |
| Rete privata | una per ambiente (`10.10.0.0/16` staging, `10.20.0.0/16` prod) |
| Volume dati | opzionale per server, separato dal disco del server: sopravvive alla sua ricreazione |
| Hardening | utente `deploy` solo con chiave, niente root né password, fail2ban, ufw, sysctl, aggiornamenti di sicurezza automatici |

## Struttura

```
modules/              # moduli riusabili: server, network, volume
envs/<env>/           # composizione di un ambiente: <env>.tfvars, ssh_keys/
ansible/              # inventario (da terraform output) e ruoli: hardening, data_volume
docs/                 # documentazione di moduli, ambienti e Ansible
```

## Uso rapido

```bash
# 1. Infrastruttura (da envs/<env>/)
export TF_VAR_hcloud_token="..."         # token del Project Hetzner, mai nel repo
terraform init
terraform plan  -var-file=<env>.tfvars
terraform apply -var-file=<env>.tfvars

# 2. Configurazione (da ansible/, in WSL o Linux)
ansible-playbook -i inventory/<env>.py site.yml --check --diff
ansible-playbook -i inventory/<env>.py site.yml
```

Dopo la creazione di un server: [Verifiche](#verifiche).

## Documentazione

| Documento | Contenuto |
|---|---|
| [docs/envs/STAGING.md](docs/envs/STAGING.md) | Ambiente staging: configurazione, operazioni comuni, problemi |
| [docs/modules/SERVER.md](docs/modules/SERVER.md) | Modulo `server`: firewall, cloud-init, input/output |
| [docs/modules/NETWORK.md](docs/modules/NETWORK.md) | Modulo `network`: rete privata |
| [docs/modules/VOLUME.md](docs/modules/VOLUME.md) | Modulo `volume`: disco dati |
| [docs/ANSIBLE.md](docs/ANSIBLE.md) | Inventario, ruoli, prerequisiti e uso di Ansible |

## Prerequisiti

- Terraform ≥ 1.10, `tflint`, `gitleaks`, `pre-commit` (`pre-commit install` dopo il clone).
- Ansible da WSL o Linux (non gira su Windows): vedi [ANSIBLE.md](docs/ANSIBLE.md).
- Accesso al Project Hetzner dell'ambiente e la propria chiave pubblica in `envs/<env>/ssh_keys/`.

## Verifiche

Da fare dopo ogni creazione (o ricreazione) di un server, per confermare che il cloud-init abbia applicato l'hardening.

### 1. Accesso

Attendere 2-3 minuti dopo l'`apply`, poi:

```bash
terraform -chdir=envs/<env> output servers     # IP del server
ssh -i ~/.ssh/<chiave_privata> deploy@<ipv4>
```

Prima del login deve comparire il banner legale.

| Sintomo | Causa | Soluzione |
|---|---|---|
| `Connection timed out` | il proprio IP pubblico non è in `allowed_ssh_cidrs` (cambia passando da ufficio a casa o hotspot) | `curl -4 ifconfig.me`, aggiornare `<env>.tfvars`, `terraform apply` (tocca solo il firewall) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | server ricreato sullo stesso IP, chiave host nuova | se il server è stato ricreato da voi: `ssh-keygen -R <ipv4>` e riconnettersi. **Altrimenti fermarsi**: potrebbe essere un attacco man-in-the-middle |
| `Permission denied (publickey)` | chiave non autorizzata | la propria `.pub` deve essere in `envs/<env>/ssh_keys/` **prima** della creazione del server |

Per verificare la chiave host senza fidarsi della rete, dalla console web Hetzner (server → `>_`): `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`. Il fingerprint deve coincidere con quello mostrato da SSH.

### 2. Sul server

| Controllo | Comando | Atteso |
|---|---|---|
| Bootstrap | `sudo cloud-init status --long` | `status: done`, `errors: []` |
| Marker hardening | `cat /var/log/cloud-init-hardening.done` | `fail2ban: active`, `ufw: Status: active` |
| Hostname / timezone | `hostnamectl; timedatectl` | `<env>-<server>`, `UTC` |
| SSH | `sudo sshd -T \| grep -Ei 'permitrootlogin\|passwordauthentication\|allowusers\|maxauthtries\|allowtcpforwarding\|banner'` | `no`, `no`, `deploy`, `3`, `no`, `/etc/issue.net` |
| fail2ban | `sudo fail2ban-client status sshd` | jail `sshd` attiva |
| ufw | `sudo ufw status verbose` | `deny (incoming)`, `22/tcp LIMIT IN` (+ 80/443 se HTTP aperto) |
| sysctl | `sysctl kernel.kptr_restrict net.ipv4.conf.all.rp_filter net.ipv4.tcp_syncookies` | `2`, `1`, `1` |
| journald | `journalctl --disk-usage` | sotto `journald_max_use` |
| Aggiornamenti | `cat /etc/apt/apt.conf.d/52unattended-upgrades-local` | solo origini `-security`, `Automatic-Reboot "false"` |

In caso di errori: `sudo grep -iE 'error|warn|fail' /var/log/cloud-init-output.log`.

`last_update: 1970` in `cloud-init status` è un'anomalia nota di cloud-init e si può ignorare.

### 3. Prove negative (dal proprio PC)

```bash
ssh -i ~/.ssh/<chiave_privata> root@<ipv4>          # rifiutato
ssh -o PubkeyAuthentication=no deploy@<ipv4>        # Permission denied (publickey), nessuna richiesta di password
```

Non serve provare il ban di fail2ban: gli IP in `allowed_ssh_cidrs` sono esclusi dal ban.
