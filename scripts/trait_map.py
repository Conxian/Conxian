#!/usr/bin/env python3
"""
Generate a comprehensive overview of trait definitions and usages across the
Conxian Clarity codebase. The script scans every `.clar` file under
`contracts/`, records `(define-trait ...)`, `(use-trait ...)`, and
`(impl-trait ...)` statements, and produces three artefacts under
`scripts/reports/`:

1. `trait-map.json`  – machine-readable summary of traits, contracts, and edges
2. `trait-map.dot`   – Graphviz digraph describing contract-to-trait relations
3. `trait-map.mmd`   – Mermaid mind-map highlighting trait consumers/implementers

The JSON output also surfaces traits referenced via `.all-traits.*` that are
missing from `contracts/traits/all-traits.clar`, duplicate trait definitions,
and unresolved `impl-trait` aliases.
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Set, Tuple

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONTRACTS_DIR = PROJECT_ROOT / "contracts"
ALL_TRAITS_FILE = CONTRACTS_DIR / "traits" / "all-traits.clar"
REPORT_DIR = PROJECT_ROOT / "scripts" / "reports"

DEFINE_TRAIT_RE = re.compile(r"\(define-trait\s+([^\s\(\)]+)", re.MULTILINE)
USE_TRAIT_RE = re.compile(r"\(use-trait\s+([^\s\)]+)\s+([^\)]+)\)", re.MULTILINE)
IMPL_TRAIT_RE = re.compile(r"\(impl-trait\s+([^\s\)]+)\)", re.MULTILINE)


def normalize_trait_ref(ref: str) -> str:
    """Return a normalized trait identifier (strip `.all-traits.` prefix etc.)."""
    token = ref.strip().split()[0]
    if token.startswith(".all-traits."):
        return token.split(".all-traits.", 1)[1]
    if token.startswith('.'):
        return token.lstrip('.')
    return token


def load_aggregator_traits() -> List[str]:
    if not ALL_TRAITS_FILE.exists():
        return []
    content = ALL_TRAITS_FILE.read_text(encoding="utf-8")
    return DEFINE_TRAIT_RE.findall(content)


def scan_contracts():
    aggregator_traits = load_aggregator_traits()
    aggregator_set = set(aggregator_traits)

    trait_definitions: Dict[str, List[str]] = defaultdict(list)
    contract_nodes: Set[str] = set()
    trait_nodes: Set[str] = set(aggregator_traits)
    edges: List[Dict[str, str]] = []
    centralized_refs: Set[str] = set()
    unresolved_impls: Dict[str, List[str]] = defaultdict(list)

    for path in CONTRACTS_DIR.rglob("*.clar"):
        rel_path = path.relative_to(PROJECT_ROOT).as_posix()
        content = path.read_text(encoding="utf-8")

        if path.resolve() == ALL_TRAITS_FILE.resolve():
            # Skip aggregator file for trait_definitions (already recorded)
            continue

        defined_traits = DEFINE_TRAIT_RE.findall(content)
        for trait_name in defined_traits:
            trait_definitions[trait_name].append(rel_path)
            trait_nodes.add(trait_name)

        uses = USE_TRAIT_RE.findall(content)
        impls = IMPL_TRAIT_RE.findall(content)

        if not uses and not impls:
            continue

        contract_nodes.add(rel_path)
        alias_map: Dict[str, Dict[str, object]] = {}

        for alias, ref in uses:
            alias_clean = alias.strip()
            normalized = normalize_trait_ref(ref)
            raw_ref = ref.strip()
            is_centralized = raw_ref.startswith(".all-traits.")
            alias_map[alias_clean] = {
                "normalized": normalized,
                "raw": raw_ref,
                "centralized": is_centralized,
            }
            trait_nodes.add(normalized)
            edges.append({
                "source": rel_path,
                "target": normalized,
                "type": "use",
            })
            if is_centralized:
                centralized_refs.add(normalized)

        for impl_symbol in impls:
            symbol = impl_symbol.strip()
            trait_name = None
            is_central = False

            if symbol.startswith(".all-traits."):
                trait_name = normalize_trait_ref(symbol)
                is_central = True
            elif "." in symbol:
                trait_name = normalize_trait_ref(symbol)
            else:
                alias_info = alias_map.get(symbol)
                if alias_info:
                    trait_name = alias_info["normalized"]
                    is_central = bool(alias_info["centralized"])

            if trait_name:
                trait_nodes.add(trait_name)
                edges.append({
                    "source": rel_path,
                    "target": trait_name,
                    "type": "impl",
                })
                if is_central:
                    centralized_refs.add(trait_name)
            else:
                unresolved_impls[rel_path].append(symbol)

    duplicates = {
        trait: sorted(paths)
        for trait, paths in trait_definitions.items()
        if len(paths) > 1
    }

    missing_in_aggregator = sorted(centralized_refs - set(aggregator_set))

    graph = {
        "contracts": sorted(contract_nodes),
        "traits": sorted(trait_nodes),
        "edges": sorted(edges, key=lambda e: (e["source"], e["target"], e["type"])),
    }

    return {
        "aggregator_traits": aggregator_traits,
        "trait_definitions": {trait: sorted(paths) for trait, paths in trait_definitions.items()},
        "duplicates": duplicates,
        "centralized_refs": sorted(centralized_refs),
        "missing_in_aggregator": missing_in_aggregator,
        "unresolved_impls": {contract: sorted(symbols) for contract, symbols in unresolved_impls.items()},
        "graph": graph,
    }


def generate_dot(graph: Dict[str, object]) -> str:
    lines: List[str] = [
        "digraph TraitMap {",
        "  graph [rankdir=LR];",
        "  node [fontname=\"Inter\", fontsize=10];",
    ]

    if graph["traits"]:
        lines.append("  subgraph cluster_traits {")
        lines.append("    label=\"Traits\";")
        lines.append("    color=\"#CCCCCC\";")
        for trait in graph["traits"]:
            lines.append(f'    "{trait}" [shape=box, style=filled, fillcolor="#f8f9ff"];')
        lines.append("  }")

    if graph["contracts"]:
        lines.append("  subgraph cluster_contracts {")
        lines.append("    label=\"Contracts\";")
        lines.append("    color=\"#CCCCCC\";")
        for contract in graph["contracts"]:
            lines.append(f'    "{contract}" [shape=ellipse, style=filled, fillcolor="#eefaf3"];')
        lines.append("  }")

    for edge in graph["edges"]:
        color = "#1f77b4" if edge["type"] == "use" else "#d62728"
        label = edge["type"]
        lines.append(
            f'  "{edge["source"]}" -> "{edge["target"]}" '
            f'[color="{color}", label="{label}"];'
        )

    lines.append("}")
    return "\n".join(lines)


def generate_mindmap(graph: Dict[str, object]) -> str:
    trait_usage: Dict[str, Dict[str, Set[str]]] = defaultdict(lambda: {"use": set(), "impl": set()})
    for edge in graph["edges"]:
        trait_usage[edge["target"]][edge["type"]].add(edge["source"])

    lines = ["mindmap", "  root((Conxian Trait Map))"]

    for trait in graph["traits"]:
        safe_trait = trait.replace(" ", "-")
        lines.append(f"    {safe_trait}(({trait}))")
        uses = sorted(trait_usage[trait]["use"])
        impls = sorted(trait_usage[trait]["impl"])

        lines.append("      Uses")
        if uses:
            for contract in uses:
                lines.append(f"        {contract}")
        else:
            lines.append("        (none)")

        lines.append("      Implements")
        if impls:
            for contract in impls:
                lines.append(f"        {contract}")
        else:
            lines.append("        (none)")

    return "\n".join(lines)


def main() -> None:
    data = scan_contracts()
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    json_report_path = REPORT_DIR / "trait-map.json"
    dot_graph_path = REPORT_DIR / "trait-map.dot"
    mindmap_path = REPORT_DIR / "trait-map.mmd"

    json_report_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    dot_graph_path.write_text(generate_dot(data["graph"]), encoding="utf-8")
    mindmap_path.write_text(generate_mindmap(data["graph"]), encoding="utf-8")

    print(f"Trait report written to: {json_report_path.relative_to(PROJECT_ROOT)}")
    print(f"Graphviz DOT written to: {dot_graph_path.relative_to(PROJECT_ROOT)}")
    print(f"Mermaid mind map written to: {mindmap_path.relative_to(PROJECT_ROOT)}")

    if data["missing_in_aggregator"]:
        print("\nTraits referenced via .all-traits.* but missing from all-traits.clar:")
        for trait in data["missing_in_aggregator"]:
            print(f"  - {trait}")
    else:
        print("\nNo missing centralized trait definitions detected.")

    if data["unresolved_impls"]:
        print("\nUnresolved impl-trait aliases (no matching use-trait detected):")
        for contract, symbols in data["unresolved_impls"].items():
            print(f"  - {contract}: {', '.join(symbols)}")


if __name__ == "__main__":
    main()
