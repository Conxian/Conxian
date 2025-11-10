#!/usr/bin/env python3
"""
Test script to verify all enhancements made to the Conxian repository.
"""
import os
import sys
import unittest
import subprocess
from pathlib import Path
from typing import List, Dict, Any, Optional

class TestConxianEnhancements(unittest.TestCase):    
    @classmethod
    def setUpClass(cls):
        """Set up test environment."""
        cls.repo_root = Path(__file__).parent.parent
        cls.scripts_dir = cls.repo_root / 'scripts'
        cls.contracts_dir = cls.repo_root / 'contracts'
        
        # Add scripts directory to path
        sys.path.append(str(cls.scripts_dir))
        
        # Run all enhancement scripts
        cls.run_enhancement_scripts()
    
    @classmethod
    def run_enhancement_scripts(cls):
        """Run all enhancement scripts."""
        print("\nRunning enhancement scripts...")
        
        # 1. Consolidate configs
        print("\n=== Consolidating configurations ===")
        subprocess.run(['python', str(cls.scripts_dir / 'consolidate_configs.py')], check=True)
        
        # 2. Standardize errors
        print("\n=== Standardizing errors ===")
        subprocess.run(['python', str(cls.scripts_dir / 'standardize_errors.py')], check=True)
        
        # 3. Enhance access control
        print("\n=== Enhancing access control ===")
        subprocess.run(['python', str(cls.scripts_dir / 'enhance_access_control.py')], check=True)
        
        # 4. Standardize validation
        print("\n=== Standardizing validation ===")
        subprocess.run(['python', str(cls.scripts_dir / 'standardize_validation.py')], check=True)
        
        print("\nAll enhancement scripts completed successfully.")
    
    def test_config_files_consolidated(self):
        """Test that configuration files have been consolidated."""
        # Check that duplicate testnet plans have been removed
        self.assertFalse((self.repo_root / 'deployments' / 'simplified-testnet-plan.toml').exists())
        self.assertFalse((self.repo_root / 'stacks' / 'deployments' / 'simplified-testnet-plan.toml').exists())
        
        # Check that settings files are in the correct location
        for env in ['Devnet', 'Testnet', 'Mainnet']:
            self.assertTrue((self.repo_root / 'settings' / f'{env}.toml').exists())
    
    def test_roles_contract_exists(self):
        """Test that the roles contract exists and has the correct structure."""
        roles_contract = self.contracts_dir / 'access' / 'roles.clar'
        self.assertTrue(roles_contract.exists())
        
        content = roles_contract.read_text()
        self.assertIn('(use-trait ownable-trait .all-traits.ownable-trait)', content)
        self.assertIn('(use-trait roles-trait .all-traits.roles-trait)', content)
        self.assertIn('(define-constant ROLE_ADMIN', content)
        self.assertIn('(define-public (grant-role', content)
        self.assertIn('(define-public (revoke-role', content)
    
    def test_ownable_contract_exists(self):
        """Test that the ownable contract exists and has the correct structure."""
        ownable_contract = self.contracts_dir / 'base' / 'ownable.clar'
        self.assertTrue(ownable_contract.exists())
        
        content = ownable_contract.read_text()
        self.assertIn('(use-trait ownable-trait .all-traits.ownable-trait)', content)
        self.assertIn('(define-data-var owner principal', content)
        self.assertIn('(define-public (transfer-ownership', content)
        self.assertIn('(define-read-only (get-owner', content)
    
    def test_validation_library_exists(self):
        """Test that the validation library exists and has the correct structure."""
        validation_lib = self.contracts_dir / 'utils' / 'validation.clar'
        self.assertTrue(validation_lib.exists())
        
        content = validation_lib.read_text()
        self.assertIn('(define-read-only (is-valid-principal', content)
        self.assertIn('(define-read-only (is-valid-uint', content)
        self.assertIn('(define-read-only (is-valid-int', content)
        self.assertIn('(define-read-only (is-valid-string', content)
        self.assertIn('(define-read-only (is-valid-bool', content)
        self.assertIn('(define-read-only (is-valid-buffer', content)
    
    def test_contracts_have_access_control(self):
        """Test that contracts have proper access control."""
        # Skip directories that don't need access control
        skip_dirs = ['traits', 'mocks', 'test', 'tests', 'interfaces', 'libraries', 'lib', 'utils']
        
        for file_path in self.contracts_dir.rglob('*.clar'):
            # Skip test and mock contracts
            if any(skip_dir in str(file_path.parts) for skip_dir in skip_dirs):
                continue
                
            content = file_path.read_text()
            
            # Check for use-trait statements
            self.assertIn('(use-trait', content, f"Missing use-trait in {file_path.relative_to(self.repo_root)}")
            
            # Check for role-based access control in functions that modify state
            if any(f in str(file_path) for f in ['set_', 'update_', 'add_', 'remove_', 'create_', 'delete_']):
                self.assertIn('has-role', content or 'asserts!', 
                            f"Missing role check in {file_path.relative_to(self.repo_root)}")
    
    def test_contracts_have_validation(self):
        """Test that contracts have proper input validation."""
        # Skip directories that don't need validation
        skip_dirs = ['traits', 'mocks', 'test', 'tests', 'interfaces', 'libraries', 'lib']
        
        for file_path in self.contracts_dir.rglob('*.clar'):
            # Skip test and mock contracts
            if any(skip_dir in str(file_path.parts) for skip_dir in skip_dirs):
                continue
                
            content = file_path.read_text()
            
            # Check for validation in public functions with parameters
            func_matches = list(re.finditer(r'\(define-public\s+\(([^\s(]+)(?:\s+([^)]*))?\)', content))
            
            for match in func_matches:
                func_name = match.group(1)
                params = match.group(2) or ''
                
                # Skip functions without parameters
                if not params.strip():
                    continue
                    
                # Check for validation in function body
                func_body = content[match.end():content.find(')', match.end())]
                
                # Look for validation patterns
                has_validation = (
                    'asserts!' in func_body or
                    'is-valid-' in func_body or
                    'contract-call? .validation' in func_body
                )
                
                self.assertTrue(has_validation, 
                              f"Missing validation in {file_path.relative_to(self.repo_root)} function {func_name}")
    
    def test_clarinet_check_passes(self):
        """Test that clarinet check passes with the enhanced codebase."""
        try:
            result = subprocess.run(
                ['clarinet', 'check', '--manifest-path', str(self.repo_root / 'stacks' / 'Clarinet.test.toml')],
                cwd=self.repo_root,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                print("\nClarinet check failed with output:")
                print(result.stdout)
                print(result.stderr)
            
            self.assertEqual(result.returncode, 0, "Clarinet check failed")
        except FileNotFoundError:
            self.skipTest("Clarinet not installed")

if __name__ == '__main__':
    unittest.main(verbosity=2)
