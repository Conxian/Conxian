import os
import re
import json

contracts_dir = "contracts"
all_dependencies = {}

# Regex to capture the full trait principal, e.g., "'SP...contract.trait-name"
use_trait_pattern = re.compile(r"\(use-trait\s+([^\s]+)\s+'([^\s]+)\)")

# An improved regex for contract-calls. It will capture the first argument after `contract-call?`
# This argument could be a literal principal or a variable name.
contract_call_pattern = re.compile(r"\(contract-call\?\s+([^\s\)]+)")

for root, _, files in os.walk(contracts_dir):
    for file in files:
        if file.endswith(".clar"):
            # Use the filename (without extension) as the contract name
            contract_name = os.path.splitext(file)[0]

            if contract_name not in all_dependencies:
                all_dependencies[contract_name] = {"traits": [], "contracts": []}

            file_path = os.path.join(root, file)
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

                # Find trait dependencies
                trait_matches = use_trait_pattern.findall(content)
                for match in trait_matches:
                    trait_full_principal = match[1]
                    trait_name = trait_full_principal.split('.')[-1]
                    if trait_name not in all_dependencies[contract_name]["traits"]:
                        all_dependencies[contract_name]["traits"].append(trait_name)

                # Find contract call dependencies
                contract_call_matches = contract_call_pattern.findall(content)
                for match in contract_call_matches:
                    # The called contract could be a variable or a literal principal
                    called_contract = match
                    # Let's try to clean it up. If it's a literal, it will have a dot.
                    if '.' in called_contract:
                        called_contract_name = called_contract.split('.')[-1]
                        # remove the starting single quote if it exists
                        if called_contract_name.startswith("'"):
                            called_contract_name = called_contract_name[1:]

                        if called_contract_name not in all_dependencies[contract_name]["contracts"]:
                            all_dependencies[contract_name]["contracts"].append(called_contract_name)
                    # If it's a variable, we'll just add it as is.
                    # This is not perfect but better than nothing.
                    else:
                        if called_contract not in all_dependencies[contract_name]["contracts"]:
                            all_dependencies[contract_name]["contracts"].append(called_contract)


# Remove contracts with no found dependencies to keep the output clean
cleaned_dependencies = {k: v for k, v in all_dependencies.items() if v["traits"] or v["contracts"]}

with open('clar_deps.json', 'w') as f:
    json.dump(cleaned_dependencies, f, indent=2)
