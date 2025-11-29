import sys

if len(sys.argv) != 2:
    print("usage: paren_check_insurance.py <file>")
    sys.exit(1)

path = sys.argv[1]
text = open(path, "r", encoding="utf-8").read()

stack = []
line = 1
col = 0

for ch in text:
    if ch == "\n":
        line += 1
        col = 0
        continue
    col += 1
    if ch == "(":
        stack.append((line, col))
    elif ch == ")":
        if stack:
            stack.pop()
        else:
            print("extra ')' at line", line, "col", col)

if stack:
    print("unclosed '(' at line", stack[-1][0], "col", stack[-1][1])
else:
    print("parens balanced")
