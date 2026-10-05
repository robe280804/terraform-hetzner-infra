# Modulo `network`

Crea la **rete privata dell'ambiente**: una per ambiente, condivisa da tutti i server. Il traffico tra server passa da qui e non da internet.

```
modules/network/
├── main.tf        # rete + subnet
├── variables.tf
├── outputs.tf
└── versions.tf
```

## Cosa crea

| Risorsa | Nome su Hetzner | Scopo |
|---|---|---|
| `hcloud_network` | `<environment>` | Rete privata (es. `10.10.0.0/16`) |
| `hcloud_network_subnet` | — | Subnet dei server (es. `10.10.1.0/24`) nella network zone delle location |

I server si collegano alla rete dal modulo `server` (input `network`), con una risorsa `hcloud_server_network` separata: collegare o scollegare un server esistente **non lo ricrea**.

## Sicurezza

- **Il firewall Hetzner non filtra la rete privata**, solo le interfacce pubbliche.
- Sulla rete privata l'unica barriera è **ufw** sul server, che è deny-by-default: tra server non passa nulla finché non si aggiunge una regola esplicita, per esempio `ufw allow from 10.10.1.0/24 to any port 5432`.
- Range diversi e mai sovrapposti per ambiente: `10.10.0.0/16` staging, `10.20.0.0/16` prod.

## Input

| Variabile | Tipo | Default | Descrizione |
|---|---|---|---|
| `environment` | string | — | `staging` o `prod`, usato come nome |
| `ip_range` | string | — | Range della rete (es. `10.10.0.0/16`) |
| `subnet_ip_range` | string | — | Range della subnet, contenuto in `ip_range` |
| `network_zone` | string | `eu-central` | Deve contenere le location dei server (`eu-central` = `nbg1`, `fsn1`, `hel1`) |
| `protection` | bool | `false` | `delete_protection` (usare in prod) |
| `labels` | map(string) | `{}` | Label extra |

## Output

| Output | Descrizione |
|---|---|
| `network_id` | ID della rete |
| `subnet_id` | ID della subnet, da passare al modulo `server` |
| `ip_range` | Range della rete |
