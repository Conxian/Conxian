import os
import re
import sys

def read_all_clar_files(directory, clar_files=None):
    if clar_files is None:
        clar_files = []
    for entry in os.listdir(directory):
        full_path = os.path.join(directory, entry)
        if os.path.isdir(full_path):
            read_all_clar_files(full_path, clar_files)
        elif os.path.isfile(full_path) and full_path.endswith('.clar'):
            clar_files.append(full_path)
    return clar_files

def parse_use_trait(content):
    use_traits = {}
    # Regex to find (use-trait alias trait-ref)
    # Group 1: alias, Group 2: trait-ref
    pattern = re.compile(r'\(use-trait\s+([^\s\)]+)\s+([^\)]+)\)')
    for match in pattern.finditer(content):
        alias = match.group(1).strip()
        trait_ref = match.group(2).strip()
        if alias:
            use_traits[alias] = trait_ref
    return use_traits

def parse_impl_trait(content):
    impl_traits = []
    # Regex to find (impl-trait trait-sym)
    # Group 1: trait-sym
    pattern = re.compile(r'\(impl-trait\s+([^\s\)]+)\)')
    for match in pattern.finditer(content):
        trait_sym = match.group(1).strip()
        if trait_sym:
            impl_traits.append(trait_sym)
    return impl_traits

def validate_trait_implementations():
    script_dir = os.path.dirname(__file__)
    contracts_dir = os.path.abspath(os.path.join(script_dir, '..', 'contracts'))
    
    clar_files = read_all_clar_files(contracts_dir)
    
    failures = []

    for file_path in clar_files:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        uses = parse_use_trait(content)
        impls = parse_impl_trait(content)

        for sym in impls:
            # For individual trait files, the impl-trait symbol should directly correspond to a trait file name.
            # We expect the format to be .trait_name.trait_name or an alias that resolves to it.
            # e.g., .my-trait.my-trait -\u003e my-trait
            expected_trait_file_name = sym.lstrip('.').split('.')[0]
            trait_file_path = os.path.join(contracts_dir, 'traits', f'{expected_trait_file_name}.clar')

            if not os.path.exists(trait_file_path):
                failures.append({
                    'file': file_path,
                    'message': f'(impl-trait {sym}) references a trait that does not have a corresponding file at {trait_file_path}'
                })
                continue
            
            # If an alias is used, ensure it maps to the expected trait file
            ref = uses.get(sym)
            if ref and f'.{expected_trait_file_name}.' not in ref:
                failures.append({
                    'file': file_path,
                    'message': f'(impl-trait {sym}) alias maps to unexpected trait path: {ref}'
                })
    
    if failures:
        error_lines = [f"{f['file']}: {f['message']}" for f in failures]
        print("Trait implementation policy violations (individual traits):")
        for line in error_lines:
            print(line)
        sys.exit(1) # Exit with a non-zero code to indicate failure
    else:
        print("All trait implementations adhere to the individual trait policy.")
        sys.exit(0) # Exit with zero code to indicate success

if __name__ == '__main__':
    validate_trait_implementations()
