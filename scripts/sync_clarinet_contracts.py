#!/usr/bin/env python3
"""
Sync Clarinet.toml [contracts] with all .clar files under contracts/.

- Computes missing entries by path.
- Generates unique keys based on path (e.g., dex-dex-pool) with collision handling.
- Uses the first existing deployer address prefix from Clarinet.toml.
- Supports --dry-run to preview, and --write to persist changes.
"""
import argparse
import os
from pathlib import Path
from typing import Dict, List, Set
import toml

ROOT = Path(__file__).parent.parent
CONTRACTS_DIR = ROOT / "contracts"
TOML_PATH = ROOT / "Clarinet.toml"


def load_toml() -> Dict:
    with open(TOML_PATH, "r", encoding="utf-8") as f:
        return toml.load(f)


def save_toml(data: Dict):
    # backup
    backup = TOML_PATH.with_suffix(".toml.bak")
    if TOML_PATH.exists():
        backup.write_text(TOML_PATH.read_text(encoding="utf-8"), encoding="utf-8")
    with open(TOML_PATH, "w", encoding="utf-8") as f:
        toml.dump(data, f)


def derive_key(rel_path: str, existing_keys: Set[str]) -> str:
    # rel_path like 'contracts/dex/dex-pool.clar' or 'dex/dex-pool.clar'
    p = rel_path.replace("\\", "/")
    if p.startswith("contracts/"):
        p = p[len("contracts/"):]
    parts = p.split("/")
    stem = Path(parts[-1]).stem
    key = "-".join([parts[0]] + ([stem] if len(parts) > 1 else [])) if len(parts) > 1 else stem
    base = key.lower().replace("_", "-")
    candidate = base
    i = 2
    while candidate in existing_keys:
        candidate = f"{base}-{i}"
        i += 1
    return candidate


def extract_deployer_prefix(contracts_table: Dict) -> str:
    # Try to get the prefix from any existing contract address
    for entry in contracts_table.values():
        if isinstance(entry, dict):
            addr = entry.get("address")
            if addr and "." in addr:
                return addr.split(".")[0]
    # Fallback to default placeholder
    return "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="Preview changes only")
    ap.add_argument("--write", action="store_true", help="Write changes to Clarinet.toml")
    args = ap.parse_args()

    cfg = load_toml()
    contracts_table: Dict = cfg.get("contracts", {})

    # Collect existing paths and keys
    existing_paths: Set[str] = set()
    existing_keys: Set[str] = set(contracts_table.keys())
    for name, entry in contracts_table.items():
        if isinstance(entry, dict) and "path" in entry:
            existing_paths.add(entry["path"].replace("\\", "/"))

    # Enumerate all .clar files
    all_files: List[Path] = list(CONTRACTS_DIR.rglob("*.clar"))
    missing = []
    for f in all_files:
        rel = str(f.relative_to(ROOT)).replace("\\", "/")
        rel2 = str(f.relative_to(CONTRACTS_DIR)).replace("\\", "/")
        # accept either style in TOML: with or without leading 'contracts/'
        if rel not in existing_paths and rel2 not in existing_paths:
            missing.append(rel)

    if not missing:
        print("No missing contract entries. Clarinet.toml is in sync.")
        return

    prefix = extract_deployer_prefix(contracts_table)

    # Prepare additions
    additions = []
    for rel in sorted(missing):
        key = derive_key(rel, existing_keys)
        address = f"{prefix}.{key}"
        entry = {"path": rel, "address": address}
        additions.append((key, entry))
        existing_keys.add(key)

    print(f"Found {len(additions)} missing contracts to add:\n")
    for key, entry in additions[:20]:
        print(f"  + {key} = {{ path = \"{entry['path']}\", address = \"{entry['address']}\" }}")
    if len(additions) > 20:
        print(f"  ... and {len(additions) - 20} more")

    if args.dry_run and not args.write:
        print("\nDry run complete. No changes written.")
        return

    if args.write:
        # Append to contracts table
        for key, entry in additions:
            contracts_table[key] = entry
        cfg["contracts"] = contracts_table
        save_toml(cfg)
        print(f"\nWrote {len(additions)} entries to Clarinet.toml")


if __name__ == "__main__":
    main()
