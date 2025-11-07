"""Refresh repo-managed SSH known_hosts entries from inventory hosts."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Iterable, Set

import yaml


PROJECT_ROOT = Path(__file__).resolve().parent.parent
INVENTORY_FILE = PROJECT_ROOT / "inventory" / "hosts.yml"
KNOWN_HOSTS_FILE = PROJECT_ROOT / ".ssh" / "known_hosts"


def load_inventory_hosts(inventory_path: Path) -> Set[str]:
    if not inventory_path.exists():
        raise FileNotFoundError(f"Inventory file not found: {inventory_path}")

    with inventory_path.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}

    hosts: Set[str] = set()

    def walk(node: object) -> None:
        if isinstance(node, dict):
            if "hosts" in node and isinstance(node["hosts"], dict):
                for name, params in node["hosts"].items():
                    hosts.add(str(name))
                    if isinstance(params, dict) and params.get("ansible_host"):
                        hosts.add(str(params["ansible_host"]))
            for child in node.values():
                walk(child)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(data)
    return hosts


def ssh_keyscan(host: str) -> Iterable[str]:
    proc = subprocess.run(
        ["ssh-keyscan", "-H", host],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    if proc.returncode != 0:
        print(f"⚠️  ssh-keyscan failed for {host}: {proc.stderr.strip()}", file=sys.stderr)
        return []

    lines = [line for line in proc.stdout.splitlines() if line and not line.startswith("#")] 
    if not lines:
        print(f"⚠️  No host keys discovered for {host}", file=sys.stderr)
    return lines


def main() -> int:
    hosts = sorted(load_inventory_hosts(INVENTORY_FILE))
    if not hosts:
        print("No hosts found in inventory; nothing to update.")
        return 0

    KNOWN_HOSTS_FILE.parent.mkdir(parents=True, exist_ok=True)

    all_entries: list[str] = []
    for host in hosts:
        print(f"Gathering SSH keys for {host}...")
        entries = list(ssh_keyscan(host))
        if entries:
            all_entries.append(f"# {host}")
            all_entries.extend(entries)

    if not all_entries:
        print("⚠️  No host keys collected; known_hosts not modified.", file=sys.stderr)
        return 1

    KNOWN_HOSTS_FILE.write_text("\n".join(all_entries) + "\n", encoding="utf-8")
    print(f"✅ Updated known_hosts with {len(all_entries)} entries at {KNOWN_HOSTS_FILE}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
