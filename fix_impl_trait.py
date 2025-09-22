import os
import re

contracts_dir = "contracts"
deployer_principal = "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"

# Regex to find all `(impl-trait ...)` statements.
impl_trait_pattern = re.compile(r"\(\s*impl-trait\s+([^\s\)]+)\s*\)")
# Regex to find all `(use-trait ...)` statements.
use_trait_pattern = re.compile(r"\(\s*use-trait\s+([^\s\)]+)\s+'([^\s\)]+)\s*\)")

for root, _, files in os.walk(contracts_dir):
    for file in files:
        if file.endswith(".clar"):
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
                continue

            new_content = content

            # Find all use-trait aliases in the file
            use_trait_aliases = {}
            use_trait_matches = use_trait_pattern.findall(content)
            for match in use_trait_matches:
                alias = match[0]
                principal = match[1]
                use_trait_aliases[alias] = principal

            # Find all impl-trait statements and fix them if they use an alias
            impl_trait_matches = impl_trait_pattern.findall(content)
            for alias in impl_trait_matches:
                if alias in use_trait_aliases:
                    correct_principal = use_trait_aliases[alias]
                    original_statement = f"(impl-trait {alias})"
                    corrected_statement = f"(impl-trait '{correct_principal})"

                    if original_statement in new_content:
                        print(f"In {file}: Replacing '{original_statement}' with '{corrected_statement}'")
                        new_content = new_content.replace(original_statement, corrected_statement)

            if new_content != content:
                try:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                except Exception as e:
                    print(f"Error writing to {file_path}: {e}")

print("Trait implementation fixing script finished.")
