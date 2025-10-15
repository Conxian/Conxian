import json
from parse_clar_files import parse_clarity_files

def build_dependency_graph():
    """
    Builds a complete dependency graph for all Clarity contracts.

    This function reads dependencies parsed from .clar files and
    constructs a graph suitable for topological sorting.

    Returns:
        dict: A dictionary where keys are contract names and values are
              sets of their dependencies.
    """
    # Use the enhanced Clarity parser
    clar_deps = parse_clarity_files()

    # The dependency graph is now directly the output of the parser
    # The keys are the contracts, and the values are their dependencies
    dependency_graph = {
        contract: set(deps)
        for contract, deps in clar_deps.items()
    }

    # Ensure all dependencies are also present as keys in the graph
    all_contracts = set(dependency_graph.keys())
    all_dependencies = set()
    for deps in dependency_graph.values():
        all_dependencies.update(deps)

    for dep in all_dependencies:
        if dep not in all_contracts:
            # This dependency is a contract that exists but might not have
            # its own outgoing dependencies. Add it to the graph with an
            # empty set of dependencies.
            dependency_graph[dep] = set()

    return dependency_graph

if __name__ == "__main__":
    print("Building dependency graph...")
    graph = build_dependency_graph()

    # Save the graph for other tools to use
    # Convert sets to lists for JSON serialization
    serializable_graph = {k: sorted(list(v)) for k, v in graph.items()}
    with open('dependency-graph.json', 'w') as f:
        json.dump(serializable_graph, f, indent=2)

    print(f"Dependency graph built with {len(graph)} nodes.")
    print("Graph saved to dependency-graph.json")

    # Optional: Print the graph in a human-readable format
    for contract, deps in sorted(serializable_graph.items()):
        print(f"\n- {contract}")
        if deps:
            for dep in deps:
                print(f"  - depends on: {dep}")
        else:
            print("  - no dependencies")