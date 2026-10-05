# Modulo `server`

Crea **un server Hetzner con il suo firewall e l'hardening di base**. Si usa una volta per server: l'ambiente lo richiama con `for_each` sulla mappa `servers`.

```
modules/server/
├── main.tf                         # firewall + server
├── variables.tf                    # input
├── outputs.tf                      # id, nome, IP
├── versions.tf                     # versioni Terraform e provider
└── templates/cloud-init.yaml.tftpl # hardening al primo avvio
```

## Cosa crea

| Risorsa | Nome su Hetzner | Scopo |
|---|---|---|
| `hcloud_firewall` | `<environment>-<name>` | Blocca tutto il traffico in ingresso tranne le regole qui sotto |
| `hcloud_server` | `<environment>-<name>` | Il server, con firewall, chiavi SSH e cloud-init |
| `hcloud_server_network` | — | Collegamento alla rete privata, se `network` non è `null`. Separato dal server: collegarlo non ricrea il server |

Label standard su entrambi: `env`, `project`, `managed-by=terraform`.

La chiave SSH (`hcloud_ssh_key`) **non** sta nel modulo: la crea l'ambiente, una per persona, e la passa con `ssh_key_ids`. Hetzner rifiuta la stessa chiave caricata due volte nello stesso Project.

## Firewall

Un firewall Hetzner applicato blocca tutto l'ingresso non esplicitamente ammesso. L'uscita resta libera.

| Regola | Porta | Aperta se | Da dove |
|---|---|---|---|
| SSH | 22/tcp | `allowed_ssh_cidrs` non è vuoto | `allowed_ssh_cidrs` |
| HTTP/HTTPS | 80, 443/tcp | `allowed_http_cidrs` non è vuoto | `allowed_http_cidrs` |
| Ping | ICMP | `allow_icmp = true` (default) | ovunque |

Lista vuota = porta chiusa.

## Hardening (cloud-init)

Eseguito **solo al primo avvio**:

- hostname `<environment>-<name>`, timezone `timezone` (default UTC);
- utente `admin_user` (default `deploy`) con sudo, accesso **solo con chiave SSH**, password bloccata;
- **SSH** (`/etc/ssh/sshd_config.d/10-hardening.conf`): niente root né password, solo `admin_user`, `MaxAuthTries 3`, `LoginGraceTime 30`, forwarding (X11, agent, TCP, tunnel) disattivato, sessioni inattive chiuse dopo 10 minuti. La config viene verificata con `sshd -t` prima del restart: con un errore sshd resta sulla config precedente;
- **banner legale** pre-autenticazione (`login_banner`) in `/etc/issue`, `/etc/issue.net` e `Banner` di sshd. Stringa vuota = nessun banner;
- **fail2ban** su SSH (`mode = aggressive`, backend systemd), con `bantime`/`findtime`/`maxretry` parametrizzati. Gli IP in `allowed_ssh_cidrs` non vengono mai bannati;
- **sysctl** (`/etc/sysctl.d/99-hardening.conf`): anti-spoofing (`rp_filter`), niente redirect né source route, SYN cookies, `kptr_restrict`, `dmesg_restrict`, `ptrace_scope`, niente core dump di binari setuid. L'IP forwarding resta spento: se si installa Docker va riattivato;
- **unattended-upgrades** solo per gli aggiornamenti di sicurezza, **senza reboot automatico** (controllare `/var/run/reboot-required`);
- **journald** persistente, con tetto `journald_max_use` e retention di un mese;
- **ufw** come seconda barriera dietro al firewall Hetzner: 22 con rate limit, 80/443 se HTTP è aperto.

Verifica dopo il boot: vedi la sezione [Verifiche](../../README.md#verifiche) del README.

## Input

| Variabile | Tipo | Default | Descrizione |
|---|---|---|---|
| `name` | string | — | Nome logico (es. `nautica`) |
| `environment` | string | — | `staging` o `prod` |
| `server_type` | string | — | Tipo Hetzner (es. `cx23`) |
| `location` | string | — | Location (es. `nbg1`, `fsn1`, `hel1`) |
| `image` | string | `ubuntu-24.04` | Sistema operativo |
| `ssh_key_ids` | list(string) | — | ID delle chiavi Hetzner da installare |
| `admin_user` | string | `deploy` | Utente non-root con sudo |
| `admin_ssh_public_keys` | list(string) | — | Chiavi pubbliche dell'utente admin (almeno una) |
| `allowed_ssh_cidrs` | list(string) | — | CIDR ammessi su SSH (es. `1.2.3.4/32`) |
| `allowed_http_cidrs` | list(string) | `[]` | CIDR ammessi su 80/443 |
| `allow_icmp` | bool | `true` | Ammette il ping |
| `backups` | bool | `true` | Backup Hetzner (+20% del costo) |
| `network` | object | `null` | Rete privata: `{ subnet_id, ip }` (`ip` opzionale). `null` = nessuna rete |
| `protection` | bool | `false` | `delete_protection` e `rebuild_protection` (usare in prod) |
| `labels` | map(string) | `{}` | Label extra |
| `timezone` | string | `UTC` | Timezone del server |
| `fail2ban_bantime` | string | `1h` | Durata del ban |
| `fail2ban_findtime` | string | `10m` | Finestra in cui contare i tentativi falliti |
| `fail2ban_maxretry` | number | `5` | Tentativi tollerati (1-20) |
| `journald_max_use` | string | `500M` | Spazio massimo del journal |
| `login_banner` | string | banner "ACCESSO RISERVATO" | Banner legale pre-login, vuoto = nessuno |

I CIDR vengono validati: un valore non valido fa fallire il `plan`.

## Output

| Output | Descrizione |
|---|---|
| `id` | ID del server |
| `name` | Nome del server |
| `ipv4_address` | IPv4 pubblico |
| `ipv6_address` | IPv6 pubblico |
| `firewall_id` | ID del firewall |
| `private_ipv4` | IP sulla rete privata (`null` senza rete) |

## Esempio

```hcl
module "server" {
  source   = "../../modules/server"
  for_each = var.servers

  name        = each.key
  environment = "staging"
  server_type = each.value.server_type
  location    = each.value.location

  ssh_key_ids           = [for k in hcloud_ssh_key.admin : k.id]
  admin_ssh_public_keys = values(local.admin_ssh_public_keys)

  allowed_ssh_cidrs  = each.value.allowed_ssh_cidrs
  allowed_http_cidrs = each.value.allowed_http_cidrs
}
```

Accesso dopo l'`apply` (attendere 1-2 minuti per il cloud-init):

```bash
ssh -i ~/.ssh/hetzner_staging_id_ed25519 deploy@<ipv4_address>
```

## Da sapere

- **Cambiare `user_data`, `ssh_keys` o `image` non fa nulla sui server esistenti.** Sono in `ignore_changes`, perché modificarli ricreerebbe il server da zero, con perdita dei dati. Le modifiche successive al primo avvio vanno fatte con Ansible.
- **Cambiare gli IP ammessi** aggiorna solo il firewall, senza toccare il server.
- **In prod** usare `protection = true`. `prevent_destroy` non può dipendere da una variabile, quindi la protezione passa da qui.
- **SSH via IPv4.** Il firewall confronta l'IP di origine: se ci si collega via IPv6, serve anche il proprio IPv6 in `allowed_ssh_cidrs`.
