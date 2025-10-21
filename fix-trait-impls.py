#!/usr/bin/env python3
import os
import re
from pathlib import Path

contracts_dir = Path('contracts')

# Find all .clar files
clar_files = list(contracts_dir.rglob('*.clar'))

fixed_count = 0

for file_path in clar_files:
    try:
        content = file_path.read_text(encoding='utf-8')
        original_content = content

        # Pattern: (impl-trait local-name) where local-name is not starting with .
        # We need to replace these with the full .all-traits.<trait-name> path
        # But we need to map the local name back to the trait name

        # First, find use-trait declarations to build a mapping
        use_trait_pattern = r'\(use-trait\s+(\w+)\s+\.all-traits\.(\w+)-trait\)'
        trait_mapping = {}

        for match in re.finditer(use_trait_pattern, content):
            local_name = match.group(1)
            trait_name = match.group(2)
            trait_mapping[local_name] = f'.all-traits.{trait_name}-trait'

        # Now fix impl-trait statements
        def replace_impl_trait(match):
            trait_ref = match.group(1)
            if trait_ref in trait_mapping:
                return f'(impl-trait {trait_mapping[trait_ref]})'
            # If it's already a full path, leave it
            if trait_ref.startswith('.'):
                return match.group(0)
            # Otherwise, try to guess - but this is risky, so leave as is for now
            return match.group(0)

        content = re.sub(r'\(impl-trait\s+([^)]+)\)', replace_impl_trait, content)

        # Also remove any merge conflict markers
        content = re.sub(r'^<<<<<<< .*$', '', content, flags=re.MULTILINE)
        content = re.sub(r'^=======$.*$', '', content, flags=re.MULTILINE)
        content = re.sub(r'^>>>>>>> .*$', '', content, flags=re.MULTILINE)

        if content != original_content:
            file_path.write_text(content, encoding='utf-8')
            fixed_count += 1
            print(f'Fixed {file_path}')

    except Exception as e:
        print(f'Error processing {file_path}: {e}')

print(f'Fixed {fixed_count} files')
