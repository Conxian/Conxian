#!/usr/bin/env python3
"""
Script to standardize error handling across all contracts.
"""
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

class ErrorStandardizer:
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.error_codes: Dict[str, int] = {}
        self.next_code = 1000  # Starting error code
        
    def load_error_codes(self, file_path: Path) -> bool:
        """Load error codes from a file."""
        if not file_path.exists():
            return False
            
        content = file_path.read_text()
        pattern = r';;\s*ERR_([A-Z0-9_]+)\s*=\s*(\d+)'
        
        for match in re.finditer(pattern, content):
            name = match.group(1)
            code = int(match.group(2))
            self.error_codes[name] = code
            if code >= self.next_code:
                self.next_code = code + 1
                
        return True
    
    def process_contract(self, file_path: Path) -> bool:
        """Process a single contract file to standardize error handling."""
        if not file_path.exists() or file_path.name == 'errors.clar':
            return False
            
        content = file_path.read_text()
        modified = False
        
        # Find all error messages
        error_pattern = r'\(err\s+\(?:(?:u(\d+)|(\w+))\)\s+([^)]+)\)'
        
        def replace_error(match):
            nonlocal modified
            
            code = match.group(1) or match.group(2)
            message = match.group(3).strip('"')
            
            # If it's already a named error code, update its message
            if match.group(2):
                error_name = match.group(2)
                if error_name in self.error_codes:
                    return match.group(0)  # No change needed
                
                # Add new error code
                self.error_codes[error_name] = self.next_code
                self.next_code += 1
                modified = True
                return f'(err u{self.error_codes[error_name]})  ;; {error_name}'
            
            # If it's a numeric code, try to find a matching error name
            elif match.group(1):
                code_num = int(match.group(1))
                for name, num in self.error_codes.items():
                    if num == code_num:
                        return f'(err u{num})  ;; {name}'
                
                # No matching name found, create one
                error_name = 'ERR_' + message.upper().replace(' ', '_').replace('"', '').replace('-', '_')
                error_name = re.sub(r'[^A-Z0-9_]', '', error_name)
                
                # Make sure the name is unique
                base_name = error_name
                counter = 1
                while error_name in self.error_codes:
                    error_name = f"{base_name}_{counter}"
                    counter += 1
                
                self.error_codes[error_name] = code_num
                modified = True
                return f'(err u{code_num})  ;; {error_name}'
            
            return match.group(0)
        
        # Replace all error codes
        new_content = re.sub(error_pattern, replace_error, content)
        
        # Update the file if changes were made
        if new_content != content:
            file_path.write_text(new_content)
            return True
            
        return modified
    
    def update_errors_file(self, file_path: Path):
        """Update the errors.clar file with all error codes."""
        if not file_path.exists():
            return False
            
        # Read existing content
        content = file_path.read_text()
        
        # Find the start and end of the error codes section
        start_marker = ';; ===== ERROR CODES ====='
        end_marker = ';; ========================'
        
        start_idx = content.find(start_marker)
        end_idx = content.find(end_marker, start_idx)
        
        if start_idx == -1 or end_idx == -1:
            return False
            
        # Sort error codes by value
        sorted_errors = sorted(self.error_codes.items(), key=lambda x: x[1])
        
        # Generate new error codes section
        error_section = [start_marker]
        for name, code in sorted_errors:
            error_section.append(f';; {name.ljust(30)} = {code}')
        error_section.append(end_marker + '\n')
        
        # Replace the old section
        new_content = (
            content[:start_idx] + 
            '\n'.join(error_section) + 
            content[end_idx + len(end_marker) + 1:]
        )
        
        if new_content != content:
            file_path.write_text(new_content)
            return True
            
        return False
    
    def run(self):
        """Run the error standardization process."""
        # Load existing error codes
        errors_file = self.repo_root / 'contracts' / 'errors' / 'errors.clar'
        self.load_error_codes(errors_file)
        
        # Process all contract files
        contracts_dir = self.repo_root / 'contracts'
        for file_path in contracts_dir.rglob('*.clar'):
            if 'traits' in str(file_path) or 'errors' in str(file_path):
                continue
                
            if self.process_contract(file_path):
                print(f'Updated error handling in {file_path.relative_to(self.repo_root)}')
        
        # Update the errors file
        if self.update_errors_file(errors_file):
            print(f'Updated {errors_file.relative_to(self.repo_root)}')
        
        print(f'Processed {len(self.error_codes)} error codes')

def main():
    repo_root = Path(__file__).parent.parent
    standardizer = ErrorStandardizer(repo_root)
    standardizer.run()

if __name__ == "__main__":
    main()
