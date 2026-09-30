# Ambiente `staging`

Ambiente di test, nel **Project Hetzner `staging`** con il suo API token. Si parte da qui: quello che funziona in staging si replica poi in prod.

```
envs/staging/
├── versions.tf          # versioni Terraform e provider
├── providers.tf         # provider hcloud (token da variabile)
├── variables.tf         # input dell'ambiente
├── main.tf              # chiavi SSH + chiamata al modulo server
├── outputs.tf           # IP e ID dei server
├── staging.tfvars       # config condivisa (versionata)
├── ssh_keys/            # chiavi SSH pubbliche del team (versionate)
│   └── roberto.pub
└── .terraform.lock.hcl  # versioni esatte dei provider (versionato)
```

## Cosa crea

| Risorsa | Nome su Hetzner | Quante |
|---|---|---|
| `hcloud_ssh_key` | `staging-<persona>` | una per file in `ssh_keys/` |
| modulo `server` | `staging-<server>` | una per voce in `servers` |

Il modulo `server` è documentato in [SERVER.md](../modules/SERVER.md).

## Configurazione

Tutto ciò che definisce l'ambiente è nel repo e cambia **solo via PR**.

### `staging.tfvars`

```hcl
admin_user = "deploy"

servers = {
  nautica = {
    server_type        = "cx23"
    location           = "nbg1"
    allowed_ssh_cidrs  = ["1.2.3.4/32"]
    allowed_http_cidrs = []
    backups            = false
  }
}
```

| Campo per server | Obbligatorio | Default | Note |
|---|---|---|---|
| `server_type` | sì | — | `cx23` è il più economico |
| `location` | sì | — | `nbg1`, `fsn1`, `hel1` |
| `allowed_ssh_cidrs` | sì | — | IP ammessi su SSH, in `/32` |
| `allowed_http_cidrs` | no | `[]` | IP ammessi su 80/443 |
| `image` | no | `ubuntu-24.04` | |
| `backups` | no | `true` | In staging tenerlo `false` (+20% del costo) |

In staging la protezione da cancellazione è sempre spenta.

### `ssh_keys/`

Una chiave **pubblica** per persona: `ssh_keys/<nome>.pub`. Ogni file diventa una chiave Hetzner `staging-<nome>` e viene autorizzato per l'utente `deploy` su tutti i server.

Le `.pub` sono pubbliche per definizione: si possono committare. La chiave privata non esce mai dal proprio `~/.ssh`.

### Token

Il token **non** sta nel repo. Si passa come variabile d'ambiente:

```bash
export TF_VAR_hcloud_token="..."
```

## Uso

Da `envs/staging/`:

```bash
export TF_VAR_hcloud_token="..."
terraform init
terraform plan  -var-file=staging.tfvars
terraform apply -var-file=staging.tfvars
```

`-var-file` è obbligatorio: senza, Terraform non legge `staging.tfvars` e chiede `servers` a mano.

Collegamento, 1-2 minuti dopo l'`apply`:

```bash
terraform output servers
ssh -i ~/.ssh/hetzner_staging_id_ed25519 deploy@<ipv4>
```

Distruggere tutto (staging, per i test):

```bash
terraform destroy -var-file=staging.tfvars
```

## Operazioni comuni

| Voglio... | Cosa cambiare | Effetto |
|---|---|---|
| Aggiungere un server | nuova voce in `servers` | crea server + firewall |
| Aggiornare il mio IP | `allowed_ssh_cidrs` | aggiorna solo il firewall |
| Dare accesso a una persona | aggiungere `ssh_keys/<nome>.pub` | nuova chiave su Hetzner, attiva sui **nuovi** server |
| Togliere accesso | cancellare `ssh_keys/<nome>.pub` | chiave rimossa da Hetzner, ma resta sui server esistenti |
| Cambiare taglia | `server_type` | resize del server con riavvio |

Sui server già creati `authorized_keys` non cambia (il cloud-init gira solo al primo avvio): aggiunte e revoche vanno applicate anche con Ansible.

## State

Per ora lo state è **locale** (`envs/staging/terraform.tfstate`, ignorato da git).

- Fare backup del file: se si perde, Terraform non sa più cosa ha creato.
- Va bene **solo finché lavora una persona**. Prima di lavorare in team: bucket S3 Hetzner con lock e `terraform init -migrate-state` (vedi [PLAN.md](../PLAN.md), Step 2).

## Problemi comuni

| Sintomo | Causa | Soluzione |
|---|---|---|
| Terraform chiede `var.servers` | manca `-var-file` | `-var-file=staging.tfvars` |
| Terraform chiede `var.hcloud_token` | token non impostato | `export TF_VAR_hcloud_token=...` |
| SSH in timeout | IP cambiato o collegamento via IPv6 | `curl -4 ifconfig.me`, aggiornare `allowed_ssh_cidrs`, `apply`; collegarsi all'IPv4 |
| `Permission denied (publickey)` | chiave sbagliata o utente `root` | usare `-i <chiave privata>` e utente `deploy` |
| Errore `SSH key not unique` | la chiave è già caricata a mano su Hetzner | cancellarla dalla console e rifare `apply` |
