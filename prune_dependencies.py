import toml
from collections import defaultdict

def get_all_deps(contract, contracts_data, visited=None):
    """Recursively get all dependencies for a contract."""
    if visited is None:
        visited = set()
    if contract in visited:
        return set()
    visited.add(contract)

    direct_deps = set(contracts_data.get(contract, {}).get('depends_on', []))
    all_dependencies = set(direct_deps)

    for dep in direct_deps:
        all_dependencies.update(get_all_deps(dep, contracts_data, visited))

    return all_dependencies

def prune_toml_dependencies(filepath):
    """
    Prunes redundant transitive dependencies from the depends_on lists
    in a Clarinet.test.toml file.
    """
    try:
        with open(filepath, 'r') as f:
            data = toml.load(f)
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return

    contracts_data = data.get('contracts', {})
    if not contracts_data:
        print("No contracts found in the TOML file.")
        return

    # For each contract, prune its direct dependencies
    for contract_name, contract_info in contracts_data.items():
        direct_deps = contract_info.get('depends_on', [])
        if not direct_deps:
            continue

        pruned_deps = list(direct_deps)

        for dep1 in direct_deps:
            # Get all dependencies of dep1
            deps_of_dep1 = get_all_deps(dep1, contracts_data)

            # Check against other direct dependencies
            for dep2 in direct_deps:
                if dep1 == dep2:
                    continue
                # If dep2 is a transitive dependency of dep1, it's redundant
                if dep2 in deps_of_dep1 and dep2 in pruned_deps:
                    pruned_deps.remove(dep2)
                    print(f"Pruning '{dep2}' from '{contract_name}' dependencies (covered by '{dep1}')")

        if len(pruned_deps) < len(direct_deps):
            contract_info['depends_on'] = pruned_deps
            if not contract_info['depends_on']:
                del contract_info['depends_on']

    # Write the pruned data back to the file
    try:
        with open(filepath, 'w') as f:
            toml.dump(data, f)
        print(f"\nSuccessfully pruned dependencies in {filepath}")
    except Exception as e:
        print(f"Error writing to {filepath}: {e}")

if __name__ == "__main__":
    print("--- Starting Dependency Pruning ---")
    prune_toml_dependencies("stacks/Clarinet.test.toml")
    print("\n--- Dependency Pruning Complete ---")