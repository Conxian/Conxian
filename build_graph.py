import json
import os
from pathlib import Path
import re
from typing import Dict, List, Set, Tuple, Optional, Any

ROOT_DIR = Path(__file__).parent
CONTRACTS_DIR = ROOT_DIR / "contracts"
TESTS_DIR = ROOT_DIR / "tests"
TRAITS_FILE = CONTRACTS_DIR / "traits" / "all-traits.clar"

USE_TRAIT_RE = re.compile(r"\(use-trait\s+([^\s]+)\s+([^\s\)]+)\)")
IMPL_TRAIT_RE = re.compile(r"\(impl-trait\s+([^\s\)]+)\)")
DEFINE_TRAIT_RE = re.compile(r"\(define-trait\s+([^\s\)]+)")
CALL_RE = re.compile(r"\(contract-call\?\s+([^\s\)]+)\s+([^\s\)]+)")


def strip_comments(s: str) -> str:
    return re.sub(r";.*$", "", s, flags=re.MULTILINE)


class SystemGraph:
    def __init__(self, root_dir: Path):
        self.root_dir = root_dir
        self.contracts_dir = root_dir / "contracts"
        self.tests_dir = root_dir / "tests"
        self.traits_file = self.contracts_dir / "traits" / "all-traits.clar"
        self._graph: Optional[Dict[str, Any]] = None

    def _index_contracts(self) -> Dict[str, Path]:
        mapping: Dict[str, Path] = {}
        for base in (self.contracts_dir, self.tests_dir):
            if not base.exists():
                continue
            for p in base.rglob("*.clar"):
                mapping[p.stem] = p
        return mapping

    def _load_traits(self) -> Set[str]:
        traits: Set[str] = set()
        if self.traits_file.exists():
            content = strip_comments(self.traits_file.read_text(encoding="utf-8"))
            for m in DEFINE_TRAIT_RE.finditer(content):
                traits.add(m.group(1))
        return traits

    def _node_id_for_path(self, p: Path) -> str:
        rel = p.relative_to(self.root_dir).as_posix()
        return f"file:{rel}"

    def build_system_graph(self, root_dir: Optional[Path] = None) -> Dict[str, Any]:
        root_dir = root_dir or self.root_dir
        contract_index = self._index_contracts()
        trait_names = self._load_traits()

        nodes: Dict[str, Dict[str, Any]] = {}
        edges: List[Dict[str, Any]] = []

        # Trait nodes
        for t in sorted(trait_names):
            nid = f"trait:{t}"
            nodes[nid] = {"id": nid, "type": "trait", "name": t}

        # Contract/Test nodes + edges
        for stem, path in contract_index.items():
            content = strip_comments(path.read_text(encoding="utf-8"))
            ntype = "test" if self.tests_dir in path.parents else "contract"
            nid = self._node_id_for_path(path)
            nodes[nid] = {"id": nid, "type": ntype, "name": stem}

            # use-trait
            for m in USE_TRAIT_RE.finditer(content):
                trait_ref = m.group(2)
                base = trait_ref.split(".")[-1] if trait_ref.startswith('.all-traits.') else trait_ref
                tid = f"trait:{base}"
                edges.append({"from": nid, "to": tid, "type": "use-trait"})

            # impl-trait
            for m in IMPL_TRAIT_RE.finditer(content):
                trait_ref = m.group(1)
                base = trait_ref.split(".")[-1] if trait_ref.startswith('.all-traits.') else trait_ref
                tid = f"trait:{base}"
                edges.append({"from": nid, "to": tid, "type": "impl-trait"})

            # contract-call? static targets (.contract)
            for m in CALL_RE.finditer(content):
                target = m.group(1)
                if target.startswith('.'):
                    tgt_name = target[1:]
                    target_path = contract_index.get(tgt_name)
                    if target_path:
                        tid = self._node_id_for_path(target_path)
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

        self._graph = graph
        return graph

    def get_graph(self) -> Dict[str, Any]:
        if self._graph is None:
            self._graph = self.build_system_graph(self.root_dir)
        return self._graph


if __name__ == "__main__":
    ROOT = Path(__file__).parent
    sg = SystemGraph(ROOT)
    graph = sg.get_graph()
    print(json.dumps(graph, indent=2))
