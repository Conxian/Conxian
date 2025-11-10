import os
import re
import json

def parse_clarity_files(contracts_dir="contracts"):
    """
    Parses all .clar files in a directory to extract contract and trait dependencies
    using a set of specific, high-confidence patterns.
    """
    dependency_graph = {}

    # Pattern 1: (contract-call? '<principal>.<contract-name> ...)
    call_literal_pattern = re.compile(r"\(\s*contract-call\?\s+'[A-Z0-9]+\.([a-zA-Z0-9_-]+)")

    # Pattern 2: (contract-call? .<contract-name> ...)
    call_relative_pattern = re.compile(r"\(\s*contract-call\?\s+\.([a-zA-Z0-9_-]+)")

    # Pattern 3: (use-trait <alias> '<principal>.<contract-name>)
    use_trait_pattern = re.compile(r"\(\s*use-trait\s+[^\s]+\s+'[A-Z0-9]+\.([a-zA-Z0-9_-]+)")

    # Pattern 4: (impl-trait .all-traits.<trait-name>)
    # This is the most important pattern for dependency resolution.
    impl_trait_pattern = re.compile(r"\(\s*impl-trait\s+\.all-traits\.([a-zA-Z0-9_-]+)")

    # Pattern 5: (contract-of <trait-alias>)
    contract_of_pattern = re.compile(r"\(\s*contract-of\s+([a-zA-Z0-9_-]+)\)")

    # Find all trait definitions in all-traits.clar to resolve contract-of dependencies.
    all_traits_path = os.path.join(contracts_dir, "traits", "all-traits.clar")
    defined_traits = set()
    if os.path.exists(all_traits_path):
        with open(all_traits_path, 'r', encoding='utf-8') as f:
            content = f.read()
            defined_traits.update(re.findall(r"\(\s*define-trait\s+([a-zA-Z0-9_-]+)", content))

    for root, _, files in os.walk(contracts_dir):
        for file in files:
            if not file.endswith(".clar"):
                continue

            contract_name = os.path.splitext(file)[0]
            if contract_name not in dependency_graph:
                dependency_graph[contract_name] = set()

            file_path = os.path.join(root, file)
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

                # Find dependencies from `impl-trait` statements
                for dep in impl_trait_pattern.findall(content):
                    dependency_graph[contract_name].add(dep)

                # Find dependencies from literal contract calls
                for dep in call_literal_pattern.findall(content):
                    dependency_graph[contract_name].add(dep)

                # Find dependencies from relative contract calls
                for dep in call_relative_pattern.findall(content):
                    dependency_graph[contract_name].add(dep)

                # Find dependencies from use-trait
                for dep in use_trait_pattern.findall(content):
                    dependency_graph[contract_name].add(dep.split('.')[0])

                # Find dependencies from (contract-of <trait>)
                for trait_alias in contract_of_pattern.findall(content):
                    if trait_alias in defined_traits:
                        dependency_graph[contract_name].add("all-traits")

    # Clean up self-dependencies
    for contract, deps in dependency_graph.items():
        if contract in deps:
            deps.remove(contract)

    return dependency_graph

if __name__ == "__main__":
    print("Parsing Clarity files for dependencies with corrected impl-trait logic...")
    graph = parse_clarity_files()

    # Filter out contracts with no dependencies for a cleaner output file
    cleaned_graph = {k: sorted(list(v)) for k, v in graph.items() if v}

    with open('clar_deps.json', 'w') as f:
        json.dump(cleaned_graph, f, indent=2)

    print("Dependency parsing complete. Output written to clar_deps.json")
    # Print a summary
    for contract, deps in sorted(cleaned_graph.items()):
        print(f"\n- {contract}")
        for dep in deps:
            print(f"  - depends on: {dep}")