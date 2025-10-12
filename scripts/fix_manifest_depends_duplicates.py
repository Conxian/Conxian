#!/usr/bin/env python3
"""
Fix duplicate depends_on keys within sections in stacks/Clarinet.test.toml by
- merging multiple depends_on arrays into a single unique array (with "all-traits" first)
- inserting the merged depends_on after the address line if present, else after the header

Usage:
  python scripts/fix_manifest_depends_duplicates.py
"""
from pathlib import Path
import re

MANIFEST = Path('stacks/Clarinet.test.toml')

header_re = re.compile(r'^\s*\[(contracts\.[^\]]+)\]\s*$')
depends_re = re.compile(r'^\s*depends_on\s*=')
address_re = re.compile(r'^\s*address\s*=')
array_re = re.compile(r'\[(.*)\]')


def parse_array(line: str):
    m = array_re.search(line)
    if not m:
        return []
    inner = m.group(1)
    items = []
    for part in inner.split(','):
        v = part.strip().strip('"').strip("'")
        if v:
            items.append(v)
    return items


def render_depends(items):
    seen = set()
    ordered = []
    # ensure all-traits appears first if present or enforce
    if 'all-traits' in items:
        ordered.append('all-traits')
        seen.add('all-traits')
    else:
        ordered.append('all-traits')
        seen.add('all-traits')
    for it in items:
        if it not in seen:
            ordered.append(it)
            seen.add(it)
    return 'depends_on = [ ' + ', '.join(f'"{x}"' for x in ordered) + ' ]'


def process_section(lines):
    # Gather depends lines and their values
    dep_idxs = []
    dep_vals = []
    addr_idx = None
    for idx, line in enumerate(lines):
        if depends_re.match(line):
            dep_idxs.append(idx)
            dep_vals.extend(parse_array(line))
        if addr_idx is None and address_re.match(line):
            addr_idx = idx

    if len(dep_idxs) <= 1:
        # normalize single depends to include all-traits
        if dep_idxs:
            idx = dep_idxs[0]
            merged = render_depends(parse_array(lines[idx]))
            lines[idx] = merged
        return lines

    # Merge
    merged = render_depends(dep_vals)

    # Remove all existing depends lines
    keep = [line for i, line in enumerate(lines) if i not in dep_idxs]

    # Insert merged depends line
    insert_at = 1  # after header line
    if addr_idx is not None:
        # address index may have shifted due to removed lines; recompute
        # naive approach: find first occurrence of 'address =' in keep
        for i, l in enumerate(keep):
            if address_re.match(l):
                insert_at = i + 1
                break
    keep = keep[:insert_at] + [merged] + keep[insert_at:]
    return keep


def main():
    txt = MANIFEST.read_text(encoding='utf-8').splitlines()
    out = []
    i = 0
    while i < len(txt):
        line = txt[i]
        m = header_re.match(line)
        if not m:
            out.append(line)
            i += 1
            continue
        # start of a section
        section_lines = [line]
        i += 1
        while i < len(txt):
            if header_re.match(txt[i]):
                break
            section_lines.append(txt[i])
            i += 1
        # process only contracts.* sections
        out.extend(process_section(section_lines))
    MANIFEST.write_text('\n'.join(out) + '\n', encoding='utf-8')
    print('Fixed duplicate depends_on in stacks/Clarinet.test.toml')


if __name__ == '__main__':
    main()
