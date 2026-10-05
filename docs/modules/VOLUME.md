# Modulo `volume`

Crea un **disco dati Hetzner separato dal server** e lo collega al server. I dati sul volume sopravvivono alla ricreazione del server: è ciò che rende un server ricreabile senza perdite.

```
modules/volume/
├── main.tf        # volume + attachment
├── variables.tf
├── outputs.tf
└── versions.tf
```

## Cosa crea

| Risorsa | Nome su Hetzner | Scopo |
|---|---|---|
| `hcloud_volume` | `<environment>-<name>-data` | Il disco, con filesystem creato da Hetzner (`ext4`) |
| `hcloud_volume_attachment` | — | Collegamento al server |

Volume e attachment sono separati: se il server viene ricreato si ricrea solo l'attachment, il volume resta.

## Mount

Il modulo **non** monta il volume (`automount = false`). Lo monta Ansible con il ruolo `data_volume` (vedi [ANSIBLE.md](../ANSIBLE.md)):

- mount per **UUID** del filesystem, non per nome del device (che può cambiare);
- opzione `nofail`: se il volume manca, il server si avvia comunque;
- mount point predefinito `/srv/data`.

Così funziona anche su server già esistenti, senza ricrearli.

## Da sapere

- **La location del volume deve essere quella del server.**
- **La dimensione si può solo aumentare.** Dopo l'aumento in Terraform, il playbook Ansible allarga il filesystem.
- **In prod** usare `protection = true`: con `delete_protection` il volume non si cancella né da Terraform né dalla console.
- Un volume costa a parte rispetto al server (prezzo al GB/mese).
- Il volume **non è un backup**: per i backup vedi Step 8 di `PLAN.md`.

## Input

| Variabile | Tipo | Default | Descrizione |
|---|---|---|---|
| `name` | string | — | Nome logico del server (es. `nautica`) |
| `environment` | string | — | `staging` o `prod` |
| `size` | number | — | GB, da 10 a 10240 |
| `location` | string | — | Stessa location del server |
| `server_id` | string | — | ID del server a cui collegarlo |
| `format` | string | `ext4` | `ext4` o `xfs` |
| `protection` | bool | `false` | `delete_protection` (usare in prod) |
| `labels` | map(string) | `{}` | Label extra |

## Output

| Output | Descrizione |
|---|---|
| `id` | ID del volume |
| `linux_device` | Device sul server, usato da Ansible |
| `size` | Dimensione in GB |
