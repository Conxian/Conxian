import re
from pathlib import Path

MANIFEST = Path('stacks/Clarinet.test.toml')

header_re = re.compile(r'^\s*\[(contracts\.[^\]]+)\]\s*$')
depends_re = re.compile(r'^\s*depends_on\s*=')
address_re = re.compile(r'^\s*address\s*=')
list_re = re.compile(r'\[(.*)\]')

content = MANIFEST.read_text(encoding='utf-8').splitlines()

out = []
section = None
has_depends = False
modified = 0

for i, line in enumerate(content):
    m = header_re.match(line)
    if m:
        section = m.group(1)
        has_depends = False
        out.append(line)
        continue

    if section:
        if depends_re.match(line):
            has_depends = True
            if '"all-traits"' not in line:
                lm = list_re.search(line)
                if lm:
                    inner = lm.group(1).strip()
                    new_inner = '"all-traits"' if not inner else f'"all-traits", {inner}'
                    new_line = list_re.sub(f'[{new_inner}]', line)
                    line = new_line
                    modified += 1
            out.append(line)
            continue

        out.append(line)

        if address_re.match(line):
            # if no depends_on for this section and not the all-traits section, insert one after address
            if not has_depends and section != 'contracts.all-traits':
                out.append('depends_on = ["all-traits"]')
                has_depends = True
                modified += 1
            continue
    else:
        out.append(line)

MANIFEST.write_text('\n'.join(out) + '\n', encoding='utf-8')
print(f'Applied depends_on to manifest: {modified} modifications')
