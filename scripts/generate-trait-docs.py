import os
import re

TRAITS_DIR = 'contracts/traits'
DOCS_DIR = 'docs/traits'

def extract_trait_docs(trait_content):
    """Extract trait name and function signatures."""
    trait_name_match = re.search(r'\(define-trait (\w+)', trait_content)
    if not trait_name_match:
        return None
    trait_name = trait_name_match.group(1)
    functions = re.findall(r'\((\w+)\s*(\([^)]*\))\s*(response[^)]*)\)', trait_content)
    return trait_name, functions

def main():
    os.makedirs(DOCS_DIR, exist_ok=True)
    with open(os.path.join(TRAITS_DIR, 'all-traits.clar'), 'r') as f:
        content = f.read()
        traits = re.split(r'\(define-trait', content)[1:]
        for trait in traits:
            trait = '(define-trait' + trait
            doc = extract_trait_docs(trait)
            if not doc:
                continue
            trait_name, functions = doc
            with open(os.path.join(DOCS_DIR, f"{trait_name}.md"), 'w') as doc_file:
                doc_file.write(f"# {trait_name} Trait\n\n")
                doc_file.write("## Functions\n\n")
                for func in functions:
                    doc_file.write(f"- `{func[0]}{func[1]} -> {func[2]}`\n")
    print("Trait documentation generated.")

if __name__ == '__main__':
    main()
