import os

def fix_file(filepath):
    try:
        with open(filepath, 'rb') as f:
            content = f.read()
        
        # Decode as utf-8 (ignoring errors if any) to get string
        text = content.decode('utf-8', errors='ignore')
        
        # Replace CRLF with LF
        text = text.replace('\r\n', '\n')
        
        # Encode back to utf-8 (no BOM)
        new_content = text.encode('utf-8')
        
        # Write back
        with open(filepath, 'wb') as f:
            f.write(new_content)
        print(f"Fixed: {filepath}")
    except Exception as e:
        print(f"Error fixing {filepath}: {e}")

def main():
    root_dir = os.getcwd()
    for subdir, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.clar') or file.endswith('.toml') or file.endswith('.yaml'):
                fix_file(os.path.join(subdir, file))

if __name__ == "__main__":
    main()
