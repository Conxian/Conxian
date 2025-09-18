import os
import re

contracts_dir = "contracts"
deployer_principal = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"

# This regex will find all `(use-trait ...)` statements and capture the alias and the principal.
# It's designed to be a bit loose to capture the various incorrect formats.
use_trait_pattern = re.compile(r"\(\s*use-trait\s+([^\s\)]+)\s+([^\s\)]+)\s*\)")

def fix_principal(principal_str):
    """
    Corrects common errors in principal strings used in `use-trait`.
    """
    # Remove leading quote if it exists
    if principal_str.startswith("'"):
        principal_str = principal_str[1:]

    # Case 1: Incorrect relative path (e.g., .sip-010-trait.sip-010-trait)
    if principal_str.startswith("."):
        parts = principal_str.split('.')
        # Assume the contract name is the second part
        contract_name = parts[1]
        return f"'{deployer_principal}.{contract_name}"

    # Case 2: Incorrect fully qualified path with extra parts (e.g., 'A.B.C')
    parts = principal_str.split('.')
    if len(parts) > 2:
        return f"'{parts[0]}.{parts[1]}"

    # Case 3: Correct format already, just ensure it's quoted
    if not principal_str.startswith("'"):
        return f"'{principal_str}"

    return principal_str


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
            matches = use_trait_pattern.findall(content)

            for match in matches:
                alias = match[0]
                old_principal = match[1]

                # Skip if it looks like a valid alias is already being used
                if not old_principal.startswith("'") and not old_principal.startswith("."):
                    continue

                corrected_principal = fix_principal(old_principal)

                original_statement = f"(use-trait {alias} {old_principal})"
                corrected_statement = f"(use-trait {alias} {corrected_principal})"

                if original_statement in new_content:
                    print(f"In {file}: Replacing '{original_statement}' with '{corrected_statement}'")
                    new_content = new_content.replace(original_statement, corrected_statement)

            if new_content != content:
                try:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                except Exception as e:
                    print(f"Error writing to {file_path}: {e}")

print("Trait fixing script finished.")
