import os

def convert_to_lf(file_path):
    with open(file_path, 'rb') as f:
        content = f.read()
    
    content = content.replace(b'\r\n', b'\n')
    
    with open(file_path, 'wb') as f:
        f.write(content)
    print(f"Converted {file_path} to LF")

convert_to_lf('contracts/dex/vault.clar')
