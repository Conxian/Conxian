import pathlib
import re

ERRORS_FILE = pathlib.Path(__file__).resolve().parents[1] / "contracts" / "errors" / "protocol-errors.clar"
ACCESSOR_HEADER = """;; =============================================================================\n;; ACCESSORS (auto-generated)\n;; =============================================================================\n\n"""

def main() -> None:
    text = ERRORS_FILE.read_text(encoding="utf-8")
    if "ACCESSORS" in text:
        print("Accessors already present; skipping")
        return

    constants = re.findall(r"\(define-constant\s+((?:ERR|err)[A-Za-z0-9_-]+)\s", text)
    if not constants:
        raise SystemExit("No ERR_* constants found")

    blocks = []
    for name in constants:
        fn_name = name.lower().replace("_", "-")
        block = f"(define-read-only ({fn_name})\n  {name}\n)\n"
        blocks.append(block)

    appendix = ACCESSOR_HEADER + "\n".join(blocks)
    ERRORS_FILE.write_text(text.rstrip() + "\n\n" + appendix, encoding="utf-8")
    print(f"Generated {len(blocks)} accessors")


if __name__ == "__main__":
    main()
