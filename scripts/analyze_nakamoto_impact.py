import os
import re

def scan_constants(root_dir):
    time_keywords = ['delay', 'period', 'duration', 'lock', 'expiry', 'window', 'interval', 'timelock', 'blocks']
    
    print(f"Scanning for block-time sensitive constants in {root_dir}...\n")
    print(f"{'File':<60} | {'Constant':<30} | {'Value':<10} | {'Potential Issue?'}")
    print("-" * 120)

    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".clar"):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    for i, line in enumerate(lines):
                        # Look for (define-constant NAME VALUE) or (define-data-var NAME type VALUE)
                        # Simplified regex for constants
                        match = re.search(r'\(define-constant\s+([A-Z0-9_-]+)\s+u([0-9]+)\)', line)
                        if match:
                            name = match.group(1)
                            value = int(match.group(2))
                            check_name(path, name, value, time_keywords)
                            continue

                        # Simplified regex for data-vars
                        match_var = re.search(r'\(define-data-var\s+([a-z0-9_-]+)\s+uint\s+u([0-9]+)\)', line)
                        if match_var:
                            name = match_var.group(1)
                            value = int(match_var.group(2))
                            check_name(path, name, value, time_keywords)

def check_name(path, name, value, keywords):
    # Heuristic: if value > 10 and name contains time keywords
    if any(k in name.lower() for k in keywords) and value > 0:
         rel_path = path.split("Conxian\\")[-1]
         print(f"{rel_path:<60} | {name:<30} | u{value:<9} | YES")

if __name__ == "__main__":
    scan_constants("contracts")
