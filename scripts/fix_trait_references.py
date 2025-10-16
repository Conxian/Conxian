#!/usr/bin/env python3
"""
Updates trait references to use canonical format
"""

import os
import re
from pathlib import Path

# Configuration
ROOT_DIR = Path(__file__).resolve().parent.parent
PATTERN = r"'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.all-traits\.([\w-]+)"
REPLACEMENT = r".all-traits.\1"

print("Updating trait references...")

for file in Path(ROOT_DIR).glob("**/*.clar"):
    try:
        content = file.read_text(encoding='utf-8')
        new_content = re.sub(PATTERN, REPLACEMENT, content)
        
        if new_content != content:
            file.write_text(new_content, encoding='utf-8')
            print(f"Updated {file.relative_to(ROOT_DIR)}")
    except Exception as e:
        print(f"Error processing {file}: {e}")

print("Trait references updated successfully.")
