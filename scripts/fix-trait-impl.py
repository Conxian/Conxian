import os
import re

def fix_contract(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find all impl-trait statements that use .all-traits directly
    pattern = r'\(impl-trait (\.all-traits\.[\w-]+)'
    matches = re.findall(pattern, content)
    
    if not matches:
        return
    
    # For each match, we need to add a use-trait and change the impl-trait to use the alias
    new_content = content
    for trait_path in set(matches):
        trait_name = trait_path.split('.')[-1]
        # Create an alias (use snake_case)
        alias = trait_name.replace('-', '_')
        # Add the use-trait at the top (after any existing use-trait)
        use_stmt = f'(use-trait {alias} {trait_path})'
        if use_stmt not in new_content:
            # Insert after the last use-trait or at the top
            new_content = re.sub(r'(.*?)(\(define|\(impl-trait)', r'\1' + use_stmt + '\n\2', new_content, 1)
        # Replace the impl-trait with the alias
        new_content = new_content.replace(f'(impl-trait {trait_path})', f'(impl-trait {alias})')
    
    with open(file_path, 'w') as f:
        f.write(new_content)

def main():
    for root, _, files in os.walk('contracts'):
        for file in files:
            if file.endswith('.clar'):
                fix_contract(os.path.join(root, file))

if __name__ == '__main__':
    main()
