"""Inventario Ansible letto da `terraform output`.

Gli host, l'utente e i CIDR ammessi sono definiti una volta sola nei tfvars:
questo modulo li legge dall'output `ansible_inventory` dell'ambiente. Non serve
il token Hetzner, basta l'accesso in lettura allo state.

Non si usa direttamente: ogni ambiente ha il suo entrypoint (es. staging.py).
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def _terraform() -> str:
    # In WSL il binario può essere quello Windows (terraform.exe).
    for name in ("terraform", "terraform.exe"):
        if shutil.which(name):
            return name
    sys.exit("terraform non trovato nel PATH")


def _output(env: str) -> dict:
    env_dir = REPO_ROOT / "envs" / env
    # cwd invece di -chdir: con terraform.exe da WSL i path /mnt/c non
    # sarebbero comprensibili, mentre la cwd viene tradotta.
    result = subprocess.run(
        [_terraform(), "output", "-json", "ansible_inventory"],
        cwd=env_dir,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.exit(f"terraform output fallito in {env_dir}:\n{result.stderr}")
    return json.loads(result.stdout)


def _admin_keys(env: str) -> list[str]:
    keys_dir = REPO_ROOT / "envs" / env / "ssh_keys"
    return [p.read_text(encoding="utf-8").strip() for p in sorted(keys_dir.glob("*.pub"))]


def build(env: str) -> dict:
    data = _output(env)
    inventory: dict = {
        "_meta": {"hostvars": {}},
        "all": {"children": [env]},
        env: {"hosts": [], "children": []},
    }
    for name, host in data["hosts"].items():
        group = host.pop("group")
        inventory[env]["hosts"].append(name)
        inventory.setdefault(group, {"hosts": []})["hosts"].append(name)
        if group not in inventory[env]["children"]:
            inventory[env]["children"].append(group)
        inventory["_meta"]["hostvars"][name] = {
            **host,
            "ansible_user": data["admin_user"],
            "server_environment": data["environment"],
            "admin_user": data["admin_user"],
            "admin_ssh_public_keys": _admin_keys(env),
        }
    return inventory


def main(env: str) -> None:
    if "--host" in sys.argv:
        # Le hostvars sono già tutte in _meta.
        print("{}")
        return
    print(json.dumps(build(env), indent=2))
