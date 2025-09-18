import toml
import json

files_to_parse = [
    "Clarinet.base.toml",
    "Clarinet.enhanced.toml",
    "Clarinet.lending.toml",
    "Clarinet.minimal.toml",
    "Clarinet.simple.toml",
    "Clarinet.test.toml",
    "Clarinet.tokens.toml",
    "Clarinet.toml",
    "Testnet.toml",
    "settings/Devnet.toml",
    "settings/Testnet.toml",
    "stacks/Clarinet.test.toml",
    "stacks/Clarinet.toml",
    "stacks/settings/Devnet.toml"
]

all_dependencies = {}

for file_path in files_to_parse:
    try:
        with open(file_path, 'r') as f:
            data = toml.load(f)
            if 'contracts' in data:
                for contract_name, contract_data in data['contracts'].items():
                    if 'depends_on' in contract_data:
                        if contract_name not in all_dependencies:
                            all_dependencies[contract_name] = []

                        for dep in contract_data['depends_on']:
                            if dep not in all_dependencies[contract_name]:
                                all_dependencies[contract_name].append(dep)
    except FileNotFoundError:
        # It's okay if some files are not found, they might be optional configs
        pass
    except Exception as e:
        # It's also okay if some files have parsing errors, we'll just skip them
        pass

with open('toml_deps.json', 'w') as f:
    json.dump(all_dependencies, f, indent=2)
