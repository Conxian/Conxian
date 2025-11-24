import os
import re
import sys
import toml

def read_all_clar_files(directory, clar_files=None):
    """Recursively read all .clar files"""
    if clar_files is None:
        clar_files = []
    for entry in os.listdir(directory):
        full_path = os.path.join(directory, entry)
        if os.path.isdir(full_path):
            read_all_clar_files(full_path, clar_files)
        elif os.path.isfile(full_path) and full_path.endswith('.clar'):
            clar_files.append(full_path)
    return clar_files

def load_clarinet_contracts():
    """Load contract name to file mapping from Clarinet.toml"""
    script_dir = os.path.dirname(__file__)
    clarinet_path = os.path.abspath(os.path.join(script_dir, '..', 'Clarinet.toml'))
    
    try:
        with open(clarinet_path, 'r') as f:
            config = toml.load(f)
        
        contract_map = {}
        for contract_name, contract_info in config.get('contracts', {}).items():
            if isinstance(contract_info, dict) and 'path' in contract_info:
                contract_map[contract_name] = contract_info['path']
        
        return contract_map
    except Exception as e:
        print(f"Warning: Could not load Clarinet.toml: {e}")
        return {}

def parse_impl_trait(content):
    """Parse all impl-trait statements from Clarity code"""
    impl_traits = []
    # Match (impl-trait .contract-name.trait-name) or commented versions
    pattern = re.compile(r'(?:;;)?\s*\(impl-trait\s+([^\s\)]+)\)')
    for match in pattern.finditer(content):
        trait_sym = match.group(1).strip()
        # Skip commented impl-trait statements
        if match.group(0).strip().startswith(';;'):
            continue
        if trait_sym:
            impl_traits.append(trait_sym)
    return impl_traits

def validate_trait_implementations():
    """Validate all impl-trait statements reference valid modular trait files"""
    script_dir = os.path.dirname(__file__)
    contracts_dir = os.path.abspath(os.path.join(script_dir, '..', 'contracts'))
    
    # Load contract mappings from Clarinet.toml
    contract_map = load_clarinet_contracts()
    
    clar_files = read_all_clar_files(contracts_dir)
    failures = []

    for file_path in clar_files:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        impls = parse_impl_trait(content)

        for sym in impls:
            # Parse .contract-name.trait-name pattern
            parts = sym.lstrip('.').split('.')
            if len(parts) < 2:
                failures.append({
                    'file': file_path,
                    'message': f'(impl-trait {sym}) has invalid format, expected .contract-name.trait-name'
                })
                continue
            
            contract_name = parts[0]
            
            # Check if contract exists in Clarinet.toml
            if contract_name in contract_map:
                contract_path = contract_map[contract_name]
                # Handle both relative and absolute paths in Clarinet.toml
                if contract_path.startswith('contracts/'):
                    trait_file_path = os.path.join(script_dir, '..', contract_path)
                else:
                    trait_file_path = os.path.join(contracts_dir, contract_path)
                if not os.path.exists(trait_file_path):
                    failures.append({
                        'file': file_path,
                        'message': f'(impl-trait {sym}) references contract "{contract_name}" which maps to non-existent file: {trait_file_path}'
                    })
            else:
                # Fallback: check traits directory
                trait_file_path = os.path.join(contracts_dir, 'traits', f'{contract_name}.clar')
                if not os.path.exists(trait_file_path):
                    failures.append({
                        'file': file_path,
                        'message': f'(impl-trait {sym}) references unknown contract "{contract_name}" not in Clarinet.toml or traits/'
                    })
    
    if failures:
        error_lines = [f"{f['file']}: {f['message']}" for f in failures]
        print("Trait implementation policy violations:")
        for line in error_lines:
            print(line)
        sys.exit(1)
    else:
        print("All trait implementations adhere to modular trait policy (Clarinet.toml-based)")
        sys.exit(0)

if __name__ == '__main__':
    validate_trait_implementations()
