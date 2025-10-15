import toml
import json
import re

def get_contracts_from_toml(file_path):
    """
    Reads a TOML file and extracts all contract definitions.

    A contract definition is any section that looks like [contracts.<name>]
    or [disabled.<name>]

    Args:
        file_path (str): The path to the TOML file.

    Returns:
        dict: A dictionary containing all contract definitions,
              preserving their structure.
    """
    contracts = {}
    disabled_contracts = {}
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = toml.load(f)
            if 'contracts' in data:
                contracts.update(data['contracts'])
            # Also capture disabled contracts to ensure they are preserved
            if 'disabled' in data:
                disabled_contracts.update(data['disabled'])

    except FileNotFoundError:
        print(f"Warning: Could not find TOML file at {file_path}")
        return {}, {}
    except Exception as e:
        print(f"Error parsing TOML file at {file_path}: {e}")
        return {}, {}

    return contracts, disabled_contracts

if __name__ == "__main__":
    # This script is now intended to be used as a module,
    # but we can add a simple main block for testing.
    print("Parsing TOML files for contract lists...")

    clarinet_toml_path = "Clarinet.toml"
    clarinet_test_toml_path = "stacks/Clarinet.test.toml"

    active_contracts, disabled_contracts = get_contracts_from_toml(clarinet_toml_path)
    print(f"Found {len(active_contracts)} active contracts in {clarinet_toml_path}")
    print(f"Found {len(disabled_contracts)} disabled contracts in {clarinet_toml_path}")

    test_active, test_disabled = get_contracts_from_toml(clarinet_test_toml_path)
    print(f"Found {len(test_active)} active contracts in {clarinet_test_toml_path}")
    print(f"Found {len(test_disabled)} disabled contracts in {clarinet_test_toml_path}")

    # For compatibility with other scripts, we can output a simple list of names
    all_contract_names = list(active_contracts.keys()) + list(disabled_contracts.keys())
    output = {"contracts": sorted(all_contract_names)}

    with open('toml_deps.json', 'w') as f:
        json.dump(output, f, indent=2)

    print("TOML parsing complete. Output written to toml_deps.json")