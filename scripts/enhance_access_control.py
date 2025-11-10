#!/usr/bin/env python3
"""
Script to enhance access control in Conxian smart contracts.
"""
import re
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple

class AccessControlEnhancer:
    """Enhances access control in smart contracts by adding role-based checks."""
    
    ROLES = {
        'ADMIN': 'Administrator with full access',
        'PAUSER': 'Can pause/unpause the contract',
        'MINTER': 'Can mint new tokens',
        'BURNER': 'Can burn tokens',
        'UPGRADER': 'Can upgrade contract logic',
        'FEE_SETTER': 'Can set protocol fees',
        'GUARDIAN': 'Emergency intervention role',
        'OPERATOR': 'Day-to-day operations',
    }
    
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.contracts_dir = repo_root / 'contracts'
        self.roles_contract = self.contracts_dir / 'access' / 'roles.clar'
        self.ownable_contract = self.contracts_dir / 'base' / 'ownable.clar'
        self.contracts: Dict[str, Dict] = {}
        
    def _has_contract(self, contract_name: str) -> bool:
        """Check if a contract exists."""
        return (self.contracts_dir / f"{contract_name}.clar").exists()
        
    def _get_contract_content(self, contract_name: str) -> str:
        """Get the content of a contract."""
        path = self.contracts_dir / f"{contract_name}.clar"
        if path.exists():
            return path.read_text()
        return ""
        
    def _write_contract(self, contract_name: str, content: str):
        """Write content to a contract file."""
        path = self.contracts_dir / f"{contract_name}.clar"
        path.write_text(content)
        
    def ensure_roles_contract(self):
        """Ensure the roles contract exists and has all required roles."""
        if not self.roles_contract.exists():
            # Create a basic roles contract
            roles_content = """;; Access Control Roles
;; This contract defines the roles used across the Conxian protocol.

(use-trait ownable-trait .all-traits.ownable-trait)
(use-trait roles-trait .all-traits.roles-trait)

(define-constant CONTRACT_OWNER tx-sender)

;; Role definitions
(define-constant ROLE_ADMIN (string-utf8 "ADMIN"))
(define-constant ROLE_PAUSER (string-utf8 "PAUSER"))
(define-constant ROLE_MINTER (string-utf8 "MINTER"))
(define-constant ROLE_BURNER (string-utf8 "BURNER"))
(define-constant ROLE_UPGRADER (string-utf8 "UPGRADER"))
(define-constant ROLE_FEE_SETTER (string-utf8 "FEE_SETTER"))
(define-constant ROLE_GUARDIAN (string-utf8 "GUARDIAN"))
(define-constant ROLE_OPERATOR (string-utf8 "OPERATOR"))

;; Role data
(define-data-var roles (map principal (list 10 (string-utf8))) (list))

;; ===== Role Management =====

;; Grant a role to a principal
(define-public (grant-role (role (string-utf8 32)) (grantee principal))
    (let (
        (current-roles (default-to (list) (map-get? roles grantee)))
        (new-roles (append current-roles (list role)))
    )
        (asserts! (contains? (var-get roles) grantee) (err u1001))  ;; Already has role
        (map-set roles grantee new-roles)
        (ok true)
    )
)

;; Revoke a role from a principal
(define-public (revoke-role (role (string-utf8 32)) (revokee principal))
    (let (
        (current-roles (default-to (list) (map-get? roles revokee)))
        (new-roles (filter (lambda (r) (not (is-eq r role))) current-roles))
    )
        (asserts! (contains? (var-get roles) revokee) (err u1002))  ;; Doesn't have role
        (map-set roles revokee new-roles)
        (ok true)
    )
)

;; Check if a principal has a role
(define-read-only (has-role (role (string-utf8 32)) (principal principal))
    (let ((roles (default-to (list) (map-get? roles principal))))
        (some (lambda (r) (is-eq r role)) roles)
    )
)

;; ===== Initialization =====

;; Initialize the contract (only callable once)
(define-public (initialize (owner principal))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u1000))  ;; Not authorized
    (map-set roles owner (list ROLE_ADMIN))
    (ok true)
)

;; ===== Trait Implementation =====

(impl-trait .all-traits.roles-trait)

(define-read-only (get-role-admin (role (string-utf8 32)))
    (ok (some ROLE_ADMIN))  ;; Only ADMIN can manage roles
)

(define-read-only (get-role-members (role (string-utf8 32)))
    (ok (filter 
        (lambda ((p (tuple (principal principal) (roles (list 10 (string-utf8))))))
            (some (lambda (r) (is-eq r role)) (get roles p))
        )
        (map (var-get roles))
    ))
)
"""
            self.roles_contract.parent.mkdir(parents=True, exist_ok=True)
            self.roles_contract.write_text(roles_content)
            print(f"Created roles contract at {self.roles_contract.relative_to(self.repo_root)}")
            return True
        return False
    
    def ensure_ownable_contract(self):
        """Ensure the ownable contract exists."""
        if not self.ownable_contract.exists():
            ownable_content = """;; Ownable
;; This contract provides basic authorization control functions.

(use-trait ownable-trait .all-traits.ownable-trait)

(define-data-var owner principal tx-sender)

;; ===== Modifiers =====

(define-private (only-owner)
    (asserts! (is-eq tx-sender (var-get owner)) (err u1000))  ;; Caller is not the owner
    true
)

;; ===== Public Functions =====

;; Transfer ownership to a new address
(define-public (transfer-ownership (new-owner principal))
    (let ((sender tx-sender))
        (asserts! (is-eq sender (var-get owner)) (err u1000))  ;; Caller is not the owner
        (var-set owner new-owner)
        (ok true)
    )
)

;; Renounce ownership of the contract
(define-public (renounce-ownership)
    (let ((sender tx-sender))
        (asserts! (is-eq sender (var-get owner)) (err u1000))  ;; Caller is not the owner
        (var-set owner tx-sender)  ;; Set to zero address or similar
        (ok true)
    )
)

;; ===== View Functions =====

;; Get the current owner
(define-read-only (get-owner)
    (ok (var-get owner))
)

;; Check if the caller is the owner
(define-read-only (is-owner (caller principal))
    (ok (is-eq caller (var-get owner)))
)

;; ===== Trait Implementation =====

(impl-trait .all-traits.ownable-trait)
"""
            self.ownable_contract.parent.mkdir(parents=True, exist_ok=True)
            self.ownable_contract.write_text(ownable_content)
            print(f"Created ownable contract at {self.ownable_contract.relative_to(self.repo_root)}")
            return True
        return False
    
    def analyze_contract(self, contract_path: Path) -> Dict:
        """Analyze a contract for access control patterns."""
        content = contract_path.read_text()
        
        # Check for existing access control
        has_ownable = "(use-trait ownable-trait" in content
        has_roles = "(use-trait roles-trait" in content
        
        # Find public functions
        func_pattern = r'\(define-public\s+\(([^\s(]+)(?:\s+([^)]*))?\)[^{}]*'
        functions = []
        
        for match in re.finditer(func_pattern, content, re.DOTALL):
            func_name = match.group(1)
            functions.append({
                'name': func_name,
                'params': match.group(2) or '',
                'needs_auth': self._function_needs_auth(func_name, content)
            })
        
        return {
            'path': str(contract_path.relative_to(self.repo_root)),
            'has_ownable': has_ownable,
            'has_roles': has_roles,
            'functions': functions
        }
    
    def _function_needs_auth(self, func_name: str, content: str) -> bool:
        """Determine if a function needs access control."""
        # Functions that typically need access control
        protected_patterns = [
            'set', 'update', 'add', 'remove', 'create', 'delete',
            'mint', 'burn', 'transfer', 'approve', 'pause', 'unpause',
            'upgrade', 'migrate', 'withdraw', 'deposit', 'claim', 'stake', 'unstake'
        ]
        
        # Functions that typically don't need access control
        public_patterns = [
            'get', 'is', 'has', 'can', 'total', 'balance', 'price', 'ratio',
            'calculate', 'compute', 'estimate', 'view', 'read', 'query'
        ]
        
        # Check if function name matches any protected pattern
        if any(pattern in func_name.lower() for pattern in protected_patterns):
            return True
            
        # Check if function is a getter or view function
        if any(func_name.lower().startswith(pattern) for pattern in public_patterns):
            return False
            
        # Default to requiring auth for modification functions
        return 'set' in func_name.lower() or 'update' in func_name.lower()
    
    def enhance_contract(self, contract_path: Path, analysis: Dict):
        """Enhance a contract with access control."""
        content = contract_path.read_text()
        modified = False
        
        # Add use-trait statements if missing
        if not analysis['has_ownable']:
            content = self._add_use_trait(content, 'ownable-trait')
            modified = True
            
        if not analysis['has_roles'] and any(f['needs_auth'] for f in analysis['functions']):
            content = self._add_use_trait(content, 'roles-trait')
            modified = True
        
        # Add role checks to functions that need them
        for func in analysis['functions']:
            if func['needs_auth'] and not self._has_auth_check(func['name'], content):
                content = self._add_role_check(content, func['name'], 'ADMIN')
                modified = True
        
        if modified:
            contract_path.write_text(content)
            print(f"Enhanced access control in {contract_path.relative_to(self.repo_root)}")
    
    def _add_use_trait(self, content: str, trait_name: str) -> str:
        """Add a use-trait statement to the contract."""
        use_trait = f'(use-trait {trait_name} .all-traits.{trait_name})'
        
        # Find the first non-comment, non-whitespace line
        lines = content.split('\n')
        insert_pos = 0
        
        for i, line in enumerate(lines):
            line = line.strip()
            if line and not line.startswith(';') and not line.startswith('('):
                insert_pos = i
                break
        
        # Insert the use-trait statement
        lines.insert(insert_pos, use_trait)
        return '\n'.join(lines)
    
    def _has_auth_check(self, func_name: str, content: str) -> bool:
        """Check if a function already has an authorization check."""
        # Look for common auth patterns
        patterns = [
            f'\(define-public \s*\(\s*{func_name}[^{{}}]*\{{[^{}]*\(asserts! \s*\(is-eq tx-sender',
            f'\(define-public \s*\(\s*{func_name}[^{{}}]*\{{[^{}]*\(asserts! \s*\(has-role',
            f'\(define-public \s*\(\s*{func_name}[^{{}}]*\{{[^{}]*\(only-owner',
            f'\(define-public \s*\(\s*{func_name}[^{{}}]*\{{[^{}]*\(require-owner',
        ]
        
        for pattern in patterns:
            if re.search(pattern, content, re.DOTALL | re.IGNORECASE):
                return True
                
        return False
    
    def _add_role_check(self, content: str, func_name: str, role: str) -> str:
        """Add a role check to a function."""
        pattern = f'(define-public\\s+\\(\\s*{func_name}(?:\\s+([^)]*))?\\)\\s*\\{{)'
        
        def add_check(match):
            params = match.group(1) or ''
            return f'''(define-public ({func_name} {params})
    (let ((sender tx-sender))
        (asserts! (contract-call? .roles has-role (string-utf8 "{role}") sender) (err u1003))  ;; Missing required role: {role}
        {match.group(2)}'''
        
        return re.sub(pattern, add_check, content, flags=re.DOTALL)
    
    def run(self):
        """Run the access control enhancement process."""
        # Ensure required contracts exist
        self.ensure_ownable_contract()
        self.ensure_roles_contract()
        
        # Process all contract files
        for file_path in self.contracts_dir.rglob('*.clar'):
            # Skip test and mock contracts
            if 'test' in str(file_path).lower() or 'mock' in str(file_path).lower():
                continue
                
            # Skip the roles and ownable contracts
            if file_path.name in ['roles.clar', 'ownable.clar']:
                continue
                
            # Analyze the contract
            analysis = self.analyze_contract(file_path)
            
            # Enhance the contract with access control
            self.enhance_contract(file_path, analysis)

def main():
    repo_root = Path(__file__).parent.parent
    enhancer = AccessControlEnhancer(repo_root)
    enhancer.run()
    print("Access control enhancement complete.")

if __name__ == "__main__":
    main()
