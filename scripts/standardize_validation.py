#!/usr/bin/env python3
"""
Script to standardize input validation across all contracts.
"""
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set

class ValidationStandardizer:
    """Standardizes input validation across smart contracts."""
    
    # Common validation patterns
    VALIDATION_PATTERNS = {
        'address': r'principal',
        'amount': r'uint|int',
        'string': r'string',
        'bool': r'bool',
        'buffer': r'buff',
    }
    
    # Common validation functions
    VALIDATION_FUNCTIONS = {
        'principal': 'is-valid-principal',
        'uint': 'is-valid-uint',
        'int': 'is-valid-int',
        'string': 'is-valid-string',
        'bool': 'is-valid-bool',
        'buff': 'is-valid-buffer',
    }
    
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.contracts_dir = repo_root / 'contracts'
        self.validation_lib = self.contracts_dir / 'utils' / 'validation.clar'
        self.contracts: Dict[str, Dict] = {}
        self.imports: Set[str] = set()
    
    def ensure_validation_lib(self):
        """Ensure the validation library exists."""
        if not self.validation_lib.exists():
            self.validation_lib.parent.mkdir(parents=True, exist_ok=True)
            
            validation_content = """;; Validation Library
;; Standard validation functions for input parameters.

;; ===== Type Validation =====

;; Check if a principal is valid (not none and not empty)
(define-read-only (is-valid-principal (p principal))
    (is-some p)
)

;; Check if a uint is valid (not none and within bounds)
(define-read-only (is-valid-uint (value uint) (min-val uint) (max-val uint))
    (and
        (>= value min-val)
        (<= value max-val)
    )
)

;; Check if an int is valid (within bounds)
(define-read-only (is-valid-int (value int) (min-val int) (max-val int))
    (and
        (>= value min-val)
        (<= value max-val)
    )
)

;; Check if a string is valid (not empty and within length limits)
(define-read-only (is-valid-string (s string-utf8) (max-len uint))
    (and
        (> (len s) 0)
        (<= (len s) max-len)
    )
)

;; Check if a boolean is valid (not none)
(define-read-only (is-valid-bool (b bool))
    (is-some b)
)

;; Check if a buffer is valid (not empty and within size limits)
(define-read-only (is-valid-buffer (b (buff 1024)) (max-size uint))
    (and
        (> (len b) 0)
        (<= (len b) max-size)
    )
)

;; ===== Common Validations =====

;; Validate an amount (positive uint)
(define-read-only (validate-amount (amount uint))
    (asserts! (is-valid-uint amount u1 u115792089237316195423570985008687907853269984665640564039457584007913129639935) (err u1001))  ;; Invalid amount
    (ok true)
)
;; Validate an address (principal)
(define-read-only (validate-address (addr principal))
    (asserts! (is-valid-principal addr) (err u1002))  ;; Invalid address
    (ok true)
)

;; Validate a string length
(define-read-only (validate-string (s string-utf8) (max-len uint))
    (asserts! (is-valid-string s max-len) (err u1003))  ;; Invalid string
    (ok true)
)

;; Validate a buffer
(define-read-only (validate-buffer (b (buff 1024)) (max-size uint))
    (asserts! (is-valid-buffer b max-size) (err u1004))  ;; Invalid buffer
    (ok true)
)
"""
            self.validation_lib.write_text(validation_content)
            print(f"Created validation library at {self.validation_lib.relative_to(self.repo_root)}")
            return True
        return False
    
    def analyze_contract(self, contract_path: Path) -> Dict:
        """Analyze a contract for validation patterns."""
        content = contract_path.read_text()
        
        # Check for existing validation imports
        has_validation_import = 'validation' in content
        
        # Find public functions and their parameters
        func_pattern = r'\(define-public\s+\(([^\s(]+)(?:\s+([^)]*))?\)\s*\{?[^}]*\}?'
        functions = []
        
        for match in re.finditer(func_pattern, content, re.DOTALL):
            func_name = match.group(1)
            params_str = match.group(2) or ''
            
            # Parse parameters
            params = []
            param_pattern = r'\(([^\s)]+)\s+([^\s)]+)\)'
            for param_match in re.finditer(param_pattern, params_str):
                param_name = param_match.group(1)
                param_type = param_match.group(2)
                params.append({
                    'name': param_name,
                    'type': param_type,
                    'validated': self._is_param_validated(param_name, content)
                })
            
            functions.append({
                'name': func_name,
                'params': params,
                'has_validation': any(p['validated'] for p in params) or 'asserts!' in match.group(0)
            })
        
        return {
            'path': str(contract_path.relative_to(self.repo_root)),
            'has_validation_import': has_validation_import,
            'functions': functions
        }
    
    def _is_param_validated(self, param_name: str, content: str) -> bool:
        """Check if a parameter is validated in the function body."""
        # Look for validation patterns
        patterns = [
            f'asserts!\s*\([^)]*{param_name}[^)]*\)',  # asserts! with param
            f'is-none\s*\(\s*{param_name}\s*\)',      # is-none check
            f'is-some\s*\(\s*{param_name}\s*\)',      # is-some check
            f'is-eq\s+{param_name}',                     # equality check
            f'<=\s+{param_name}',                        # less than or equal
            f'>=\s+{param_name}',                        # greater than or equal
            f'<\s+{param_name}',                         # less than
            f'>\s+{param_name}',                         # greater than
        ]
        
        return any(re.search(pattern, content) for pattern in patterns)
    
    def standardize_contract(self, contract_path: Path, analysis: Dict):
        """Standardize validation in a contract."""
        content = contract_path.read_text()
        modified = False
        
        # Add validation import if missing
        if not analysis['has_validation_import'] and any(f['params'] for f in analysis['functions']):
            content = self._add_validation_import(content)
            modified = True
        
        # Add validation for function parameters
        for func in analysis['functions']:
            for param in func['params']:
                if not param['validated'] and not self._is_safe_parameter(param['name']):
                    content = self._add_parameter_validation(
                        content, 
                        func['name'], 
                        param['name'], 
                        param['type']
                    )
                    modified = True
        
        if modified:
            contract_path.write_text(content)
            print(f"Standardized validation in {contract_path.relative_to(self.repo_root)}")
    
    def _add_validation_import(self, content: str) -> str:
        """Add validation import to the contract."""
        import_statement = '(use-contract-interface validation .validation)'
        
        # Find the first non-comment, non-whitespace line
        lines = content.split('\n')
        insert_pos = 0
        
        for i, line in enumerate(lines):
            line = line.strip()
            if line and not line.startswith(';') and not line.startswith('('):
                insert_pos = i
                break
        
        # Insert the import statement
        lines.insert(insert_pos, import_statement)
        return '\n'.join(lines)
    
    def _is_safe_parameter(self, param_name: str) -> bool:
        """Check if a parameter is safe to not validate."""
        # These parameters are typically safe or have validation elsewhere
        safe_params = ['tx-sender', 'block-height', 'contract-caller']
        return param_name in safe_params or any(p in param_name.lower() for p in ['index', 'id', 'version'])
    
    def _add_parameter_validation(self, content: str, func_name: str, param_name: str, param_type: str) -> str:
        """Add validation for a function parameter."""
        # Determine the appropriate validation based on parameter type
        validation = None
        
        if 'principal' in param_type:
            validation = f'(asserts! (contract-call? .validation is-valid-principal {param_name}) (err u1002))  ;; Invalid {param_name}'
        elif 'uint' in param_type:
            # Extract max value from type if specified (e.g., uint100)
            max_val = '115792089237316195423570985008687907853269984665640564039457584007913129639935'  # 2^256 - 1
            if 'uint' != param_type:
                try:
                    bits = int(param_type.replace('uint', ''))
                    max_val = str(2 ** bits - 1)
                except ValueError:
                    pass
            validation = f'(asserts! (contract-call? .validation is-valid-uint {param_name} u1 u{max_val}) (err u1001))  ;; Invalid {param_name}'
        elif 'int' in param_type:
            # Extract min/max values from type if specified (e.g., int32)
            min_val = '-57896044618658097711785492504343953926634992332820282019728792003956564819968'  # -2^255
            max_val = '57896044618658097711785492504343953926634992332820282019728792003956564819967'   # 2^255 - 1
            if 'int' != param_type:
                try:
                    bits = int(param_type.replace('int', ''))
                    max_val = str(2 ** (bits - 1) - 1)
                    min_val = str(-(2 ** (bits - 1)))
                except ValueError:
                    pass
            validation = f'(asserts! (and (>= {param_name} {min_val}) (<= {param_name} {max_val})) (err u1001))  ;; Invalid {param_name}'
        elif 'string' in param_type:
            # Extract max length from type if specified (e.g., string-utf8-100)
            max_len = '1024'  # Default max length
            if '-' in param_type:
                try:
                    max_len = param_type.split('-')[-1]
                    int(max_len)  # Verify it's a number
                except (IndexError, ValueError):
                    pass
            validation = f'(asserts! (contract-call? .validation is-valid-string {param_name} u{max_len}) (err u1003))  ;; Invalid {param_name}'
        elif 'buff' in param_type:
            # Extract max size from type if specified (e.g., buff-1024)
            max_size = '1024'  # Default max size
            if '-' in param_type:
                try:
                    max_size = param_type.split('-')[-1].rstrip(')')
                    int(max_size)  # Verify it's a number
                except (IndexError, ValueError):
                    pass
            validation = f'(asserts! (contract-call? .validation is-valid-buffer {param_name} u{max_size}) (err u1004))  ;; Invalid {param_name}'
        
        if not validation:
            return content
        
        # Find the function definition
        func_pattern = f'(define-public\s+\(\s*{func_name}(?:\s+([^)]*))?\)\s*\{{)'
        
        def add_validation(match):
            return f'{match.group(0)}\n    {validation}'
        
        return re.sub(func_pattern, add_validation, content, flags=re.DOTALL)
    
    def run(self):
        """Run the validation standardization process."""
        # Ensure validation library exists
        self.ensure_validation_lib()
        
        # Process all contract files
        for file_path in self.contracts_dir.rglob('*.clar'):
            # Skip test and mock contracts
            if 'test' in str(file_path).lower() or 'mock' in str(file_path).lower():
                continue
                
            # Skip the validation library itself
            if file_path.name == 'validation.clar':
                continue
                
            # Analyze the contract
            analysis = self.analyze_contract(file_path)
            
            # Standardize validation in the contract
            self.standardize_contract(file_path, analysis)

def main():
    repo_root = Path(__file__).parent.parent
    standardizer = ValidationStandardizer(repo_root)
    standardizer.run()
    print("Validation standardization complete.")

if __name__ == "__main__":
    main()
