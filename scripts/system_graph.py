#!/usr/bin/env python3
"""
System Graph Builder for Conxian Protocol

Builds a graph of:
- Trait definitions from contracts/traits/all-traits.clar
- Contracts (contracts/**/*.clar) and Tests (tests/**/*.clar)
- Edges for use-trait, impl-trait, and static contract-call? (dot-qualified targets)

Outputs:
- artifacts/system-graph.json (nodes, edges, stats, cycles)
- artifacts/system-graph.dot (Graphviz)
"""
import os
import re
import json
from pathlib import Path
from typing import Dict, List, Tuple, Set

ROOT_DIR = Path(__file__).parent.parent
CONTRACTS_DIR = ROOT_DIR / "contracts"
TESTS_DIR = ROOT_DIR / "tests"
TRAITS_FILE = CONTRACTS_DIR / "traits" / "all-traits.clar"
ARTIFACTS = ROOT_DIR / "artifacts"
ARTIFACTS.mkdir(exist_ok=True)

USE_TRAIT_RE = re.compile(r"\(use-trait\s+([^\s]+)\s+([^\s\)]+)\)")
IMPL_TRAIT_RE = re.compile(r"\(impl-trait\s+([^\s\)]+)\)")
DEFINE_TRAIT_RE = re.compile(r"\(define-trait\s+([^\s\)]+)")
CALL_RE = re.compile(r"\(contract-call\?\s+([^\s\)]+)\s+([^\s\)]+)")


def strip_comments(s: str) -> str:
    return re.sub(r";.*$", "", s, flags=re.MULTILINE)


def index_contracts() -> Dict[str, Path]:
    """Map contract name (stem) to path for all contracts under contracts/ and tests/."""
    mapping: Dict[str, Path] = {}
    for base in (CONTRACTS_DIR, TESTS_DIR):
        if not base.exists():
            continue
        for p in base.rglob("*.clar"):
            mapping[p.stem] = p
    return mapping


def load_traits() -> Set[str]:
    traits: Set[str] = set()
    if TRAITS_FILE.exists():
        content = strip_comments(TRAITS_FILE.read_text(encoding="utf-8"))
        for m in DEFINE_TRAIT_RE.finditer(content):
            traits.add(m.group(1))
    return traits


def node_id_for_path(p: Path) -> str:
    rel = p.relative_to(ROOT_DIR).as_posix()
    return f"file:{rel}"


def build_system_graph(root_dir: Path = ROOT_DIR) -> Dict:
    contract_index = index_contracts()
    trait_names = load_traits()

    nodes: Dict[str, Dict] = {}
    edges: List[Dict] = []

    # Trait nodes
    for t in sorted(trait_names):
        nid = f"trait:{t}"
        nodes[nid] = {"id": nid, "type": "trait", "name": t}

    # Contract/Test nodes + edges
    for stem, path in contract_index.items():
        content = strip_comments(path.read_text(encoding="utf-8"))
        ntype = "test" if TESTS_DIR in path.parents else "contract"
        nid = node_id_for_path(path)
        nodes[nid] = {"id": nid, "type": ntype, "name": stem}

        # use-trait
        for m in USE_TRAIT_RE.finditer(content):
            trait_ref = m.group(2)
            if trait_ref.startswith('.all-traits.'):
                base = trait_ref.split('.')[-1]
            else:
                base = trait_ref
            tid = f"trait:{base}"
            edges.append({"from": nid, "to": tid, "type": "use-trait"})

        # impl-trait
        for m in IMPL_TRAIT_RE.finditer(content):
            trait_ref = m.group(1)
            if trait_ref.startswith('.all-traits.'):
                base = trait_ref.split('.')[-1]
            else:
                base = trait_ref
            tid = f"trait:{base}"
            edges.append({"from": nid, "to": tid, "type": "impl-trait"})

        # contract-call? static targets (.contract)
        for m in CALL_RE.finditer(content):
            target = m.group(1)
            if target.startswith('.'):
                tgt_name = target[1:]
                target_path = contract_index.get(tgt_name)
                if target_path:
                    tid = node_id_for_path(target_path)
                    edges.append({"from": nid, "to": tid, "type": "calls", "resolved": True})
                else:
                    tid = f"contract-ref:.{tgt_name}"
                    edges.append({"from": nid, "to": tid, "type": "calls", "resolved": False})
            else:
                # dynamic contract ref (variable or trait-typed)
                edges.append({"from": nid, "to": str(target), "type": "dynamic-call"})

    # Build adjacency for cycle detection (only resolved contract->contract calls)
    adj: Dict[str, List[str]] = {}
    for e in edges:
        if e["type"] == "calls" and e.get("resolved"):
            adj.setdefault(e["from"], []).append(e["to"])

    visited: Set[str] = set()
    stack: Set[str] = set()
    cycles: List[List[str]] = []

    def dfs(u: str, path: List[str]):
        visited.add(u)
        stack.add(u)
        for v in adj.get(u, []):
            if v not in visited:
                dfs(v, path + [v])
            elif v in stack:
                # found a cycle; extract from path
                try:
                    i = path.index(v)
                    cycles.append(path[i:] + [v])
                except ValueError:
                    cycles.append([v])
        stack.remove(u)

    for n in nodes.keys():
        if n not in visited:
            dfs(n, [n])

    graph = {
        "nodes": list(nodes.values()),
        "edges": edges,
        "stats": {
            "nodes": len(nodes),
            "edges": len(edges),
            "traits": len(trait_names),
        },
        "cycles": cycles,
    }

    # Persist artifacts
    (ARTIFACTS / "system-graph.json").write_text(json.dumps(graph, indent=2), encoding="utf-8")

    # DOT file
    dot_lines: List[str] = ["digraph conxian {", "  rankdir=LR;"]
    for nid, meta in nodes.items():
        label = f"{meta['name']}\n({meta['type']})"
        shape = "box" if meta['type'] == 'contract' else ("ellipse" if meta['type'] == 'trait' else "note")
        dot_lines.append(f"  \"{nid}\" [label=\"{label}\", shape={shape}];")
    for e in edges:
        color = {
            "use-trait": "#8888ff",
            "impl-trait": "#3333ff",
            "calls": "#44aa44",
            "dynamic-call": "#ffaa00",
        }.get(e["type"], "#999999")
        dot_lines.append(f"  \"{e['from']}\" -> \"{e['to']}\" [color=\"{color}\", label=\"{e['type']}\"];")
    dot_lines.append("}")
    (ARTIFACTS / "system-graph.dot").write_text("\n".join(dot_lines) + "\n", encoding="utf-8")

    return graph


if __name__ == "__main__":
    g = build_system_graph(ROOT_DIR)
    print(f"System graph built: {g['stats']['nodes']} nodes, {g['stats']['edges']} edges, cycles: {len(g['cycles'])}")
