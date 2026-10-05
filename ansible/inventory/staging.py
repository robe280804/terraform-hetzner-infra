#!/usr/bin/env python3
"""Inventario Ansible dell'ambiente staging (vedi tf_inventory.py)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from tf_inventory import main  # noqa: E402

main("staging")
