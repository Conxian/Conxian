import os
import re
import toml
from collections import defaultdict

def analyze_and_fix_trait_dependencies():
    """
    Analyzes trait files for dependencies, injects `use-trait` statements,
    and updates Clarinet.toml files with `depends_on` entries.
    """
    traits_dir = "contracts/traits"
    dependency_map = defaultdict(list)
    trait_files = []

    # First, gather all trait files
    for root, _, files in os.walk(traits_dir):
        for file in files:
            if file.endswith(".clar") and file not in ["all-traits.clar", "errors.clar", "trait-registry.clar"]:
                trait_files.append({"path": os.path.join(root, file), "name": file.replace('.clar', '')})

    # Analyze dependencies for each trait file
    trait_dependency_pattern = re.compile(r"<([a-zA-Z0-9-]+)>")
    for trait_file in trait_files:
        filepath = trait_file["path"]
        trait_name = trait_file["name"]

        with open(filepath, 'r') as f:
            content = f.read()

        dependencies = trait_dependency_pattern.findall(content)
        if dependencies:
            unique_deps = sorted(list(set(dependencies)))
            dependency_map[trait_name] = unique_deps

            # Prepare the `use-trait` statements to inject
            use_trait_statements = ""
            for dep in unique_deps:
                # Format: (use-trait <alias> .<trait-name>.<trait-name>)
                # By convention, the alias is often the same as the trait name
                use_trait_statements += f"(use-trait {dep} .{dep}.{dep})\n"

            # Inject the statements at the top of the file
            if use_trait_statements:
                new_content = use_trait_statements + "\n" + content
                with open(filepath, 'w') as f:
                    f.write(new_content)
                print(f"Injected {len(unique_deps)} dependencies into {filepath}")

    # Update both Clarinet.toml files
    update_toml_dependencies("Clarinet.toml", dependency_map)
    update_toml_dependencies("stacks/Clarinet.test.toml", dependency_map)

def update_toml_dependencies(toml_path, dependency_map):
    """Updates the depends_on field in a given TOML file."""
    with open(toml_path, 'r') as f:
        data = toml.load(f)

    if 'contracts' in data:
        for contract_name, dependencies in dependency_map.items():
            if contract_name in data['contracts']:
                # Ensure depends_on is a list and add new dependencies
                if 'depends_on' not in data['contracts'][contract_name]:
                    data['contracts'][contract_name]['depends_on'] = []

                for dep in dependencies:
                    if dep not in data['contracts'][contract_name]['depends_on']:
                        data['contracts'][contract_name]['depends_on'].append(dep)

                print(f"Updated '{contract_name}' dependencies in {toml_path}")

    with open(toml_path, 'w') as f:
        toml.dump(data, f)
    print(f"Finished updating dependencies for {toml_path}")


if __name__ == "__main__":
    print("--- Starting Trait Dependency Resolution ---")
    analyze_and_fix_trait_dependencies()
    print("\n--- Trait Dependency Resolution Complete ---")