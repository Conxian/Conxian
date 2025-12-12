import os

def convert_dir_to_lf(root_dir):
    print(f"Converting files in {root_dir} to LF...\n")
    count = 0
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".clar"):
                path = os.path.join(root, file)
                try:
                    with open(path, 'rb') as f:
                        content = f.read()
                    
                    if b'\r\n' in content:
                        new_content = content.replace(b'\r\n', b'\n')
                        with open(path, 'wb') as f:
                            f.write(new_content)
                        count += 1
                        print(f"Converted {file}")
                except Exception as e:
                    print(f"Error converting {path}: {e}")
    print(f"\nTotal files converted: {count}")

if __name__ == "__main__":
    convert_dir_to_lf("contracts")
