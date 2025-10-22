#!/usr/bin/env python3
"""
Removes deprecated trait files from the Conxian protocol
"""

import os
import shutil
from pathlib import Path

# Configuration
ROOT_DIR = Path(__file__).resolve().parent.parent
TRAITS_DIR = ROOT_DIR / "contracts" / "traits"
KEEP_FILES = {"all-traits.clar", "errors.clar", "README.md"}

print("Removing deprecated trait files...")

# Remove subdirectories
for subdir in ["core", "defi", "dimensional", "governance", "math", "protocol", "security", "sips"]:
    subdir_path = TRAITS_DIR / subdir
    if subdir_path.exists():
        shutil.rmtree(subdir_path)
        print(f"Removed directory: {subdir_path}")

# Remove individual files
for file in TRAITS_DIR.glob("*.clar"):
    if file.name not in KEEP_FILES:
        file.unlink()
        print(f"Removed file: {file}")

print("Deprecated trait files removed successfully.")
