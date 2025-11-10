#!/usr/bin/env python3
"""
Linter for verifying trait implementations in Conxian smart contracts.
"""
import os
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional
import toml

class TraitLinter:
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.traits: Dict[str, Dict] = {}
        self.contracts: Dict[str, Dict] = {}
        self.errors: List[str] = []
        
    def load_traits(self):
        """Load trait definitions from all-traits.clar"""
        traits_file = self.repo_root / 'contracts' / 'traits' / 'all-traits.clar'
        if not traits_file.exists():
            self.errors.append(f"Trait definitions not found at {traits_file}")
            return
            
        content = traits_file.read_text()
        trait_pattern = r'\(define-trait\s+([^\s]+)\s*\(([^)]*)\)'
        
        for match in re.finditer(trait_pattern, content, re.DOTALL):
            trait_name = match.group(1)
            self.traits[trait_name] = {
                'file': str(traits_file.relative_to(self.repo_root)),
                'functions': {}
            }
            
            # Extract functions
            func_pattern = r'\(s*([^\s(]+)\s*(?:\(([^)]*)\))?\s*\(([^)]*)\)'
            func_matches = re.finditer(func_pattern, match.group(2))
            
            for func_match in func_matches:
                func_name = func_match.group(1)
                params = func_match.group(2) or ''
                return_type = func_match.group(3).strip()
                
                self.traits[trait_name]['functions'][func_name] = {
                    'params': params,
                    'return_type': return_type,
                    'found': False
                }
    
    def load_contracts(self):
        """Load all contracts and their trait implementations"""
        contracts_dir = self.repo_root / 'contracts'
        for root, _, files in os.walk(contracts_dir):
            for file in files:
                if file.endswith('.clar') and 'traits' not in root:
                    self._process_contract(Path(root) / file)
    
    def _process_contract(self, contract_path: Path):
        """Process a single contract file"""
        content = contract_path.read_text()
        contract_name = contract_path.stem
        
        self.contracts[contract_name] = {
            'path': str(contract_path.relative_to(self.repo_root)),
            'traits': [],
            'functions': {},
            'errors': []
        }
        
        # Find trait implementations
        impl_matches = re.finditer(
            r'\(impl-trait\s+(\.all-traits\.([^\s)]+))',
            content
        )
        
        for match in impl_matches:
            trait_ref = match.group(1)
            trait_name = match.group(2)
            self.contracts[contract_name]['traits'].append(trait_name)
            
            # Verify trait exists
            if trait_name not in self.traits:
                self.contracts[contract_name]['errors'].append(
                    f"Trait {trait_name} not found in all-traits.clar"
                )
        
        # Find all public functions
        func_matches = re.finditer(
            r'\(define-public\s+\(([^\s(]+)(?:\s+([^)]*))?\)',
            content
        )
        
        for match in func_matches:
            func_name = match.group(1)
            params = match.group(2) or ''
            
            # Find return type
            return_type = 'bool'  # Default return type
            func_end = content.find(')', match.end())
            if func_end != -1:
                return_match = re.search(
                    r'\(response\s+([^\s)]+)',
                    content[match.end():func_end]
                )
                if return_match:
                    return_type = f"(response {return_match.group(1)} uint)"
            
            self.contracts[contract_name]['functions'][func_name] = {
                'params': params,
                'return_type': return_type
            }
    
    def verify_implementations(self):
        """Verify that all required trait functions are implemented"""
        for contract_name, contract in self.contracts.items():
            for trait_name in contract['traits']:
                if trait_name not in self.traits:
                    continue
                    
                for func_name, func_sig in self.traits[trait_name]['functions'].items():
                    func_sig['found'] = False
                    
                    if func_name in contract['functions']:
                        # Check if function signature matches
                        impl = contract['functions'][func_name]
                        
                        # Simple parameter count check
                        expected_params = len([p for p in func_sig['params'].split() if p])
                        actual_params = len([p for p in impl['params'].split() if p])
                        
                        if expected_params != actual_params:
                            contract['errors'].append(
                                f"Parameter count mismatch for {func_name}: "
                                f"expected {expected_params}, got {actual_params}"
                            )
                        
                        # Check return type
                        if func_sig['return_type'] != impl['return_type']:
                            contract['errors'].append(
                                f"Return type mismatch for {func_name}: "
                                f"expected {func_sig['return_type']}, got {impl['return_type']}"
                            )
                        
                        func_sig['found'] = True
                    else:
                        contract['errors'].append(
                            f"Missing required function: {func_name} from trait {trait_name}"
                        )
    
    def run_checks(self) -> bool:
        """Run all checks and return True if no errors found"""
        self.load_traits()
        self.load_contracts()
        self.verify_implementations()
        
        # Collect all errors
        has_errors = False
        
        for contract_name, contract in self.contracts.items():
            if contract['errors']:
                has_errors = True
                print(f"\nErrors in {contract_name}:")
                for error in contract['errors']:
                    print(f"  - {error}")
        
        return not has_errors

def main():
    repo_root = Path(__file__).parent.parent
    linter = TraitLinter(repo_root)
    
    print("Running trait implementation checks...")
    success = linter.run_checks()
    
    if success:
        print("\nAll trait implementations are valid!")
        return 0
    else:
        print("\nTrait implementation errors found.")
        return 1

if __name__ == "__main__":
    import sys
    sys.exit(main())
