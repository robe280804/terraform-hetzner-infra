## Implementazioni

1. Production and Staging enviroment
2. Server + SSH + Firewall
3. Hardening del server (cloud-init al primo avvio, Ansible nel tempo: [docs/ANSIBLE.md](docs/ANSIBLE.md))

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
