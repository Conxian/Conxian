import json
from graphlib import TopologicalSorter, CycleError
import toml
from collections import OrderedDict
from parse_tomls import get_contracts_from_toml

# The name of the contracts section in the TOML file
CONTRACTS_SECTION_KEY = "contracts"
DISABLED_SECTION_KEY = "disabled"

def align_clarinet_file(file_path, sorted_contract_names):
    """
    Rewrites a Clarinet TOML file with a sorted list of contracts.

    Args:
        file_path (str): The path to the Clarinet TOML file.
        sorted_contract_names (list): A topologically sorted list of contract names.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            # Use OrderedDict to preserve the order of sections in the TOML file
            data = toml.load(f, _dict=OrderedDict)
    except FileNotFoundError:
        print(f"Info: Skipping alignment for non-existent file: {file_path}")
        return
    except Exception as e:
        print(f"Error reading TOML file {file_path}: {e}")
        return

    # Get the full contract definitions from this specific toml file
    active_in_toml, disabled_in_toml = get_contracts_from_toml(file_path)
    contracts_in_this_file = {**active_in_toml, **disabled_in_toml}

    if not contracts_in_this_file:
        print(f"Info: No contracts found in {file_path}. Skipping.")
        return

    # Create new ordered dictionaries for the contract sections
    sorted_contracts_section = OrderedDict()
    sorted_disabled_section = OrderedDict()

    # Iterate through the globally sorted list of all contracts
    for contract_name in sorted_contract_names:
        if contract_name not in contracts_in_this_file:
            continue # Only process contracts that are actually in this file

        # Check if the contract is in the active or disabled list from the original file
        if contract_name in active_in_toml:
            sorted_contracts_section[contract_name] = active_in_toml[contract_name]
        elif contract_name in disabled_in_toml:
            sorted_disabled_section[contract_name] = disabled_in_toml[contract_name]

    # Replace the old contract sections with the new sorted ones
    data[CONTRACTS_SECTION_KEY] = sorted_contracts_section
    if sorted_disabled_section:
        data[DISABLED_SECTION_KEY] = sorted_disabled_section
    elif DISABLED_SECTION_KEY in data:
        # Remove the disabled section if it's now empty
        del data[DISABLED_SECTION_KEY]

    # Write the updated data back to the file
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            toml.dump(data, f)
        print(f"Successfully aligned {file_path}")
    except Exception as e:
        print(f"Error writing to TOML file {file_path}: {e}")


def align_contracts():
    """
    Main function to align contracts based on dependencies.
    """
    print("--- Starting Contract Alignment ---")

    # 1. Load the dependency graph
    try:
        with open('dependency-graph.json', 'r') as f:
            graph = json.load(f)
        print("Dependency graph loaded.")
    except FileNotFoundError:
        print("Error: dependency-graph.json not found. Please run build_graph.py first.")
        return

    # 2. Get all contract definitions from the main TOML files
    main_active, main_disabled = get_contracts_from_toml("Clarinet.toml")
    all_toml_contracts = set(main_active.keys()) | set(main_disabled.keys())

    test_active, test_disabled = get_contracts_from_toml("stacks/Clarinet.test.toml")
    all_toml_contracts.update(test_active.keys())
    all_toml_contracts.update(test_disabled.keys())

    # 3. Prepare the graph for sorting
    # Ensure all contracts from TOML files are in the graph.
    # If a contract is in the TOML but not the graph, it has no outgoing dependencies.
    for contract_name in all_toml_contracts:
        if contract_name not in graph:
            graph[contract_name] = []

    # 4. Topologically sort the graph
    try:
        ts = TopologicalSorter(graph)
        sorted_contracts = list(ts.static_order())
        print(f"Topological sort successful. {len(sorted_contracts)} contracts sorted.")
    except CycleError as e:
        print(f"Error: A dependency cycle was detected in your contracts: {e}")
        print("Please review your contract dependencies and break the cycle.")
        return
    except Exception as e:
        print(f"An unexpected error occurred during topological sort: {e}")
        return

    # 5. Rewrite the Clarinet configuration files
    print("\n--- Rewriting Configuration Files ---")
    align_clarinet_file("Clarinet.toml", sorted_contracts)
    align_clarinet_file("stacks/Clarinet.test.toml", sorted_contracts)

    print("\n--- Contract Alignment Complete ---")

if __name__ == "__main__":
    align_contracts()