#!/usr/bin/env python3
"""
Tests for the trait linter.
"""
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add the parent directory to the path so we can import the linter
sys.path.append(str(Path(__file__).parent.parent))

from scripts.trait_linter import TraitLinter

class TestTraitLinter(unittest.TestCase):
    def setUp(self):
        """Set up test environment."""
        self.repo_root = Path(__file__).parent.parent
        self.linter = TraitLinter(self.repo_root)
        
        # Create a temporary test directory
        self.test_dir = self.repo_root / 'test_temp'
        self.test_dir.mkdir(exist_ok=True)
        
        # Create a test traits file
        self.traits_file = self.test_dir / 'all-traits.clar'
        self.traits_file.write_text("""
        (define-trait test-trait
            ((test-func (uint) (response bool uint)))
        )
        """)
        
        # Create a test contract file
        self.contract_file = self.test_dir / 'test-contract.clar'
        self.contract_file.write_text("""
        (impl-trait .all-traits.test-trait)
        
        (define-public (test-func (amount uint))
            (ok true)
        )
        """)
    
    def tearDown(self):
        """Clean up test environment."""
        # Remove test files
        if self.test_dir.exists():
            for file in self.test_dir.glob('*'):
                file.unlink()
            self.test_dir.rmdir()
    
    def test_load_traits(self):
        """Test loading trait definitions."""
        with patch('pathlib.Path.read_text') as mock_read:
            mock_read.return_value = """
            (define-trait test-trait
                ((test-func (uint) (response bool uint)))
            )
            """
            self.linter.load_traits()
            
            self.assertIn('test-trait', self.linter.traits)
            self.assertIn('test-func', self.linter.traits['test-trait']['functions'])
    
    def test_process_contract(self):
        """Test processing a contract file."""
        self.linter.traits = {
            'test-trait': {
                'file': 'test.clar',
                'functions': {
                    'test-func': {
                        'params': 'uint',
                        'return_type': '(response bool uint)',
                        'found': False
                    }
                }
            }
        }
        
        with patch('pathlib.Path.read_text') as mock_read:
            mock_read.return_value = """
            (impl-trait .all-traits.test-trait)
            
            (define-public (test-func (amount uint))
                (ok true)
            )
            """
            self.linter._process_contract(Path('test.clar'))
            
            self.assertIn('test-func', self.linter.contracts['test']['functions'])
            self.assertEqual(
                self.linter.contracts['test']['functions']['test-func']['params'],
                '(amount uint)'
            )
    
    def test_verify_implementations(self):
        """Test verifying trait implementations."""
        self.linter.traits = {
            'test-trait': {
                'file': 'test.clar',
                'functions': {
                    'test-func': {
                        'params': 'uint',
                        'return_type': '(response bool uint)',
                        'found': False
                    }
                }
            }
        }
        
        self.linter.contracts = {
            'test': {
                'path': 'test.clar',
                'traits': ['test-trait'],
                'functions': {
                    'test-func': {
                        'params': '(amount uint)',
                        'return_type': '(response bool uint)'
                    }
                },
                'errors': []
            }
        }
        
        self.linter.verify_implementations()
        self.assertTrue(self.linter.traits['test-trait']['functions']['test-func']['found'])
        self.assertEqual(len(self.linter.contracts['test']['errors']), 0)

if __name__ == '__main__':
    unittest.main()
