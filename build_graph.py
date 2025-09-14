import json

# Load the dependencies from the toml files
with open('toml_deps.json', 'r') as f:
    toml_deps = json.load(f)

# Load the dependencies from the clar files
with open('clar_deps.json', 'r') as f:
    clar_deps = json.load(f)

# The master dependency graph
dependency_graph = {}

# Add all contracts from both sources to the graph
for contract_name in list(toml_deps.keys()) + list(clar_deps.keys()):
    if contract_name not in dependency_graph:
        dependency_graph[contract_name] = []

# Process toml dependencies
for contract_name, deps in toml_deps.items():
    for dep in deps:
        if dep not in dependency_graph[contract_name]:
            dependency_graph[contract_name].append(dep)

# Process clar dependencies
for contract_name, deps in clar_deps.items():
    # Add trait dependencies
    for trait in deps.get("traits", []):
        if trait not in dependency_graph[contract_name]:
            dependency_graph[contract_name].append(trait)
    # Add contract dependencies
    for contract in deps.get("contracts", []):
        # Filter out noise
        if contract.startswith("(") or contract == "self":
            continue
        if contract not in dependency_graph[contract_name]:
            dependency_graph[contract_name].append(contract)

# Sort the dependencies for consistent output
for contract_name in dependency_graph:
    dependency_graph[contract_name].sort()

# Print the graph in a markdown-friendly format
for contract_name, deps in sorted(dependency_graph.items()):
    print(f"### {contract_name}")
    if deps:
        for dep in deps:
            print(f"- `{dep}`")
    else:
        print("- No explicit dependencies found.")
    print()
