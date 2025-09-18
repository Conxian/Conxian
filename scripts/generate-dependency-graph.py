import os
import json
import graphviz

# Parse Clarinet.toml to get contracts
def parse_clarinet_toml():
    # This is a placeholder - actual implementation would parse TOML
    return {
        "contracts": {
            "trait-registry": {"path": "contracts/traits/trait-registry.clar"},
            "cxd-token": {"path": "contracts/tokens/cxd-token.clar", "depends_on": ["sip-010-trait"]}
        }
    }

# Generate dependency graph
def main():
    config = parse_clarinet_toml()
    dot = graphviz.Digraph(comment='Contract Dependencies')
    
    for contract, details in config['contracts'].items():
        dot.node(contract)
        
        if 'depends_on' in details:
            for dep in details['depends_on']:
                dot.edge(contract, dep)
    
    dot.render('dependency-graph.gv', view=True)

if __name__ == '__main__':
    main()
