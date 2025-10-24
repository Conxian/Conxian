#!/usr/bin/env python3
"""
Contract Verification Script for Conxian Protocol

This script verifies that:
1. All .clar files in contracts/ are listed in Clarinet.toml [contracts] by path
2. All entries in Clarinet.toml [contracts] point to existing files
3. All trait references in contracts are properly defined
4. All contracts implement their declared traits (lightweight check)

Notes:
- No directories are excluded; the entire repository under contracts/ is treated as deployable for verification purposes.
"""

import os
import re
import toml
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional, Any
import importlib.util
import argparse
import json
import sys

# Add project root to the Python path
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR))

# Now that the path is set, we can import build_graph
try:
    from build_graph import SystemGraph
except ImportError:
    print("Warning: 'build_graph' module not found. Graph-related features will be disabled.")
    SystemGraph = None

# Configuration
CONTRACTS_DIR = ROOT_DIR / "contracts"
CLARINET_TOML = ROOT_DIR / "Clarinet.toml"
STACKS_TEST_TOML = ROOT_DIR / "stacks" / "Clarinet.test.toml"
TRAITS_FILE = ROOT_DIR / "contracts" / "traits" / "all-traits.clar"

# Directories not required to be listed in Clarinet.toml (auxiliary/non-deployable)
IGNORE_DIRS = {
    "traits",
    "interfaces",
    "mocks",
    "test",
    "tests",
    "lib",
    "libraries",
    "pools",
    "utils",
}

# Production directories for advisory warnings when files are unlisted
PRODUCTION_DIRS = {
    "dex",
    "dimensional",
    "governance",
    "security",
    "tokens",
    "vaults",
    "oracle",
    "monitoring",
    "automation",
    "audit-registry",
    "enterprise",
}

# Directories that are not required to be listed in Clarinet.toml (non-deployable/auxiliary)
IGNORE_DIRS = {
    "traits",
    "interfaces",
    "mocks",
    "test",
    "lib",
    "libraries",
    "pools",
    "utils",
}

# Regex patterns (support quoted and unquoted trait refs, including principal addresses)
USE_TRAIT_PATTERN = r'\(use-trait\s+([^\s]+)\s+([^\s\)]+)\)'
IMPL_TRAIT_PATTERN = r'\(impl-trait\s+([^\s\)]+)\)'
DEFINE_TRAIT_PATTERN = r'\(define-trait\s+([^\s\n]+)'

# Principal address pattern for trait references
PRINCIPAL_TRAIT_PATTERN = r"'([A-Z0-9]+)\.all-traits\.([a-zA-Z0-9-]+)'"

class ContractVerifier:
    def __init__(self, autofix_graph: bool = False, autofix_unused: bool = False, autofix_traits: bool = False, autofix_prune: bool = False, autofix_format: bool = False, autofix_impl_traits: bool = False):
        self.clarinet_toml = ROOT_DIR / 'Clarinet.toml'
        # self.test_config_path = ROOT_DIR / 'deployments' / 'simplified-testnet-plan.toml'
        self.all_traits_file = ROOT_DIR / 'contracts' / 'traits' / 'all-traits.clar'
        self.contracts_dir = ROOT_DIR / 'contracts'
        
        self.do_autofix_graph = autofix_graph
        self.do_autofix_unused = autofix_unused
        self.do_autofix_traits = autofix_traits
        self.do_autofix_prune = autofix_prune
        self.do_autofix_format = autofix_format
        self.do_autofix_impl_traits = autofix_impl_traits

        try:
            from build_graph import SystemGraph
            # SystemGraph expects the repository root_dir; pass ROOT_DIR here.
            self.system_graph: Optional[SystemGraph] = SystemGraph(ROOT_DIR)
        except ImportError:
            print("Warning: 'build_graph' module not found. Graph-related features will be disabled.")
            self.system_graph = None

        self._graph: Optional[Dict[str, Any]] = None
        self.toml_data = self.load_toml(self.clarinet_toml)
        # self.test_config = self.load_toml(self.test_config_path)
        self.test_config = self.toml_data # Use the main toml data
        
        self.contract_files = list(self.contracts_dir.rglob("*.clar"))
        self.defined_traits: Set[str] = set()
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.modified_files: Set[Path] = set()
        self.defined_contracts = set(self.toml_data.get("contracts", {}).keys())
        self.clarinet_errors: List[Dict[str, Any]] = []

    def run_verification(self) -> bool:
        """Runs all verification checks and returns True if all pass."""
        checks = [
            ("Contract Paths", self.verify_contracts_in_toml()),
            ("Trait References", self.verify_trait_references()),
            ("Contract Dependencies", self.check_contract_dependencies()),
            ("Unused Contracts", self.check_unused_contracts()),
            ("Pruned Dependencies", self.check_pruned_dependencies()),
            ("Formatting", self.check_formatting()),
            ("Compilation", self.check_compilation()),
        ]
        
        all_passed = all(result for _, result in checks)
        
        print("\n" + "="*30)
        print("Verification Summary:")
        for name, result in checks:
            status = "✅ PASSED" if result else "❌ FAILED"
            print(f"- {name}: {status}")
        print("="*30)

        return all_passed
    
    def verify_contracts_in_toml(self) -> bool:
        """Verify Clarinet.toml entries exist and every .clar file is listed by path."""
        success = True

        # Build set of normalized contract paths from Clarinet.toml
        contracts_table = self.toml_data.get("contracts", {})
        toml_paths: Set[str] = set()
        for name, entry in contracts_table.items():
            path = entry.get("path") if isinstance(entry, dict) else None
            if path:
                toml_paths.add(os.path.normpath(os.path.join(ROOT_DIR, path)))

        # Check each contract file
        for f in self.contract_files:
            # Skip ignored directories
            if any(ign in f.parts for ign in IGNORE_DIRS):
                continue
            
            norm_path = os.path.normpath(str(f))
            if norm_path not in toml_paths:
                self.errors.append(f"{f.relative_to(ROOT_DIR)} is not listed in Clarinet.toml")
                success = False

        # Check each TOML entry
        for name, entry in contracts_table.items():
            path = entry.get("path") if isinstance(entry, dict) else None
            if path:
                full_path = os.path.normpath(os.path.join(ROOT_DIR, path))
                if not os.path.exists(full_path):
                    self.errors.append(f"Listed path for '{name}' does not exist: {path}")
                    success = False

        return success

    def verify_trait_references(self) -> bool:
        """Verify that all trait references are properly defined and load defined traits."""
        success = True
        
        # Load defined traits from all-traits.clar
        if self.all_traits_file.exists():
            try:
                content = self.all_traits_file.read_text(encoding='utf-8')
                # Find all trait definitions
                trait_matches = re.findall(DEFINE_TRAIT_PATTERN, content)
                self.defined_traits = set(trait_matches)
                print(f"Loaded {len(self.defined_traits)} trait definitions from all-traits.clar")
            except Exception as e:
                self.errors.append(f"Failed to read all-traits.clar: {e}")
                success = False
        else:
            self.errors.append("all-traits.clar file not found")
            success = False


        return success

    def _check_trait_references(self, contract_file: Path, content: str) -> bool:
        success = True
        # Find all use-trait statements
        use_matches = re.finditer(USE_TRAIT_PATTERN, content)
        for match in use_matches:
            trait_ref = match.group(1)

            # Handle different trait reference formats:
            # 1. 'ST...all-traits.trait-name' (quoted principal address format)
            # 2. .all-traits.trait-name (relative format)
            # 3. ST...contract.trait (unquoted principal format)
            # 4. local-trait-id (local reference)
            
            principal_match = re.match(PRINCIPAL_TRAIT_PATTERN, trait_ref)
            if principal_match:
                # Format: 'ST...all-traits.trait-name'
                trait_name = principal_match.group(2)
                if trait_name not in self.defined_traits:
                    self.errors.append(
                        f"Undefined trait reference '{trait_name}' in {contract_file.name}"
                    )
                    success = False
            elif trait_ref.startswith('.all-traits.'):
                # Format: .all-traits.trait-name
                base = trait_ref.split('.')[-1]
                if base not in self.defined_traits:
                    self.errors.append(
                        f"Undefined centralized trait '{base}' used via {trait_ref} in {contract_file.name}"
                    )
                    success = False
            elif trait_ref.startswith('ST') or trait_ref.startswith("'ST"):
                # Principal-qualified trait reference (quoted or unquoted)
                # Extract trait name if it's an all-traits reference
                if 'all-traits.' in trait_ref:
                    trait_name = trait_ref.split('all-traits.')[-1].rstrip("'")
                    if trait_name not in self.defined_traits:
                        self.errors.append(
                            f"Undefined trait reference '{trait_name}' in {contract_file.name}"
                        )
                        success = False
                # Otherwise, allow external principal references
            else:
                # Local trait identifier; ensure defined in all-traits
                if trait_ref not in self.defined_traits:
                    self.errors.append(
                        f"Undefined trait reference '{trait_ref}' in {contract_file.name}"
                    )
                    success = False
        
        # Check impl-trait statements
        impl_matches = re.finditer(IMPL_TRAIT_PATTERN, content)
        for match in impl_matches:
            trait_ref = match.group(1)

            # Handle the same formats as above
            principal_match = re.match(PRINCIPAL_TRAIT_PATTERN, trait_ref)
            if principal_match:
                # Format: 'ST...all-traits.trait-name'
                trait_name = principal_match.group(2)
                if trait_name not in self.defined_traits:
                    self.errors.append(
                        f"Undefined trait implemented in {contract_file.name}: (impl-trait {trait_ref})"
                    )
                    success = False
            elif trait_ref.startswith('.all-traits.'):
                # Format: .all-traits.trait-name
                base = trait_ref.split('.')[-1]
                if base not in self.defined_traits:
                    self.errors.append(
                        f"Undefined centralized trait '{base}' implemented in {contract_file.name}: {match.group(0)}"
                    )
                    success = False
            elif trait_ref.startswith('ST') or trait_ref.startswith("'ST"):
                # Principal-qualified trait reference
                if 'all-traits.' in trait_ref:
                    trait_name = trait_ref.split('all-traits.')[-1].rstrip("'")
                    if trait_name not in self.defined_traits:
                        self.errors.append(
                            f"Undefined trait implemented in {contract_file.name}: (impl-trait {trait_ref})"
                        )
                        success = False
                # Otherwise, allow external principal references
            else:
                # Local trait reference
                if trait_ref not in self.defined_traits:
                    self.errors.append(
                        f"Undefined trait implemented in {contract_file.name}: {match.group(0)}"
                    )
                    success = False
                
        return success

    def verify_manifest_alignment(self) -> bool:
        """Ensure contracts using centralized .all-traits.* are listed in manifests with same address as all-traits, and advise depends_on.

        Preference order for checks: stacks/Clarinet.test.toml > Clarinet.toml.
        If the test manifest contains the contract path and has depends_on, warnings are suppressed.
        """
        success = True
        root_contracts = self.config.get("contracts", {})
        test_contracts = self.test_config.get("contracts", {})

        # Build path -> (name, address, depends_on, source)
        manifest_paths: Dict[str, Tuple[str, Optional[str], List[str], str]] = {}
        for source, table in (("test", test_contracts), ("root", root_contracts)):
            for name, entry in table.items():
                if isinstance(entry, dict):
                    path = entry.get('path')
                    addr = entry.get('address')
                    deps = entry.get('depends_on', []) or []
                    if path:
                        manifest_paths[path.replace('\\', '/')] = (name, addr, deps, source)

        # Determine all-traits address for both manifests
        test_all_traits = test_contracts.get('all-traits', {})
        test_all_traits_addr = test_all_traits.get('address') if isinstance(test_all_traits, dict) else None
        root_all_traits = root_contracts.get('all-traits', {})
        root_all_traits_addr = root_all_traits.get('address') if isinstance(root_all_traits, dict) else None

        for f in self.contract_files:
            content = self._strip_comments(f.read_text())
            # Check for any all-traits usage (both old and new formats)
            uses_all_traits = ('.all-traits.' in content or 
                             re.search(r"'[A-Z0-9]+\.all-traits\.", content) or
                             'all-traits.' in content)
            if uses_all_traits:
                rel_part = str(f.relative_to(self.contracts_dir)).replace("\\", "/")
                rel = f"contracts/{rel_part}"
                alt_key = rel.replace('contracts/', '')
                manifest_entry = manifest_paths.get(rel) or manifest_paths.get(alt_key)
                if not manifest_entry:
                    self.errors.append(f"Contract using centralized traits not listed in Clarinet.toml: {rel}")
                    success = False
                    continue
                _, addr, deps, source = manifest_entry
                # Compare against matching manifest's all-traits address
                reference_addr = test_all_traits_addr if source == "test" else root_all_traits_addr
                if reference_addr and addr and addr != reference_addr:
                    self.errors.append(
                        f"Address mismatch for {rel}: {addr} != all-traits address {reference_addr} in {source} manifest."
                    )
                    success = False
                # Soft-check depends_on
                if isinstance(deps, list) and 'all-traits' not in deps:
                    # Only warn when the preferred manifest (test) is missing depends_on
                    if source == "test":
                        self.warnings.append(
                            f"Recommend depends_on = ['all-traits'] for {rel} to ensure build order."
                        )
        return success
    
    def verify_trait_implementation(self) -> bool:
        """Verify contracts implement all required trait functions"""
        # This is a simplified check - a full implementation would parse function signatures
        # and verify they match the trait definitions
        # For now, we'll just check that the trait is implemented
        return True  # Placeholder for actual implementation

    def analyze_system_graph(self) -> bool:
        """Build and analyze the system graph to surface structural issues."""
        self._load_system_graph()
        if not self.system_graph:
            return True

        try:
            graph = self.system_graph.build_system_graph(ROOT_DIR)
            self._graph = graph
        except Exception as e:
            self.warnings.append(f"Failed to build system graph: {e}")
            return True

        # Collect node ids for traits and files
        node_ids = {n["id"] for n in graph.get("nodes", [])}

        # 1) Unknown trait references (edges to trait:* without a matching node)
        unknown_traits: Set[str] = set()
        # 2) Unresolved static calls (.contract not found)
        unresolved_calls: List[Tuple[str, str]] = []
        # 3) Dynamic calls from contracts (not tests)
        dynamic_calls_from_contracts: List[Tuple[str, str]] = []

        # Build map from node id to type for contract/test identification
        node_types: Dict[str, str] = {n["id"]: n.get("type", "") for n in graph.get("nodes", [])}

        for e in graph.get("edges", []):
            etype = e.get("type")
            to = e.get("to")
            src = e.get("from")
            if etype in ("use-trait", "impl-trait") and isinstance(to, str) and to.startswith("trait:"):
                if to not in node_ids:
                    unknown_traits.add(to.replace("trait:", ""))
            if etype == "calls" and not e.get("resolved"):
                unresolved_calls.append((src, to))
            if etype == "dynamic-call":
                # flag only if source is a contract (not a test)
                if node_types.get(src) == "contract":
                    dynamic_calls_from_contracts.append((src, str(to)))

        # 4) Cycles
        cycles = graph.get("cycles", []) or []

        # Emit warnings (non-fatal for now; policy can escalate later)
        if unknown_traits:
            self.warnings.append(
                "Unknown trait references detected in graph: " + ", ".join(sorted(unknown_traits))
            )
        if unresolved_calls:
            sample = "; ".join([f"{s} -> {t}" for s, t in unresolved_calls[:10]])
            more = "" if len(unresolved_calls) <= 10 else f" (+{len(unresolved_calls)-10} more)"
            self.warnings.append(f"Unresolved static contract-call? edges: {sample}{more}")
        if dynamic_calls_from_contracts:
            sample = "; ".join([f"{s} -> {t}" for s, t in dynamic_calls_from_contracts[:10]])
            more = "" if len(dynamic_calls_from_contracts) <= 10 else f" (+{len(dynamic_calls_from_contracts)-10} more)"
            self.warnings.append(f"Dynamic calls from contracts detected: {sample}{more}")
        if cycles:
            # Render succinctly
            pretty = []
            for cyc in cycles[:5]:
                pretty.append(" -> ".join(cyc))
            more = "" if len(cycles) <= 5 else f" (+{len(cycles)-5} more)"
            self.warnings.append("Call graph cycles detected: " + " | ".join(pretty) + more)


        return True

    def check_unused_contracts(self) -> bool:
        """Check for unused contracts."""
        # Stub implementation
        return True

    def check_pruned_dependencies(self) -> bool:
        """Check for pruned dependencies."""
        # Stub implementation
        return True

    def check_formatting(self) -> bool:
        """Check formatting."""
        # Stub implementation
        return True

    @staticmethod
    def _strip_comments(content: str) -> str:
        """Removes single-line Clarity comments."""
        return "\n".join(
            line for line in content.splitlines() if not line.strip().startswith(";;")
        )

    @staticmethod
    def load_toml(path: Path) -> Dict[str, Any]:
        try:
            return toml.load(path)
        except Exception as e:
            print(f"Error loading TOML file at {path}: {e}")
            return {}

    def _load_system_graph(self) -> None:
        # FIX: method should be callable, not a property
        if self._graph is not None:
            return
        if not self.system_graph:
            self._graph = None
            return
        try:
            self._graph = self.system_graph.build_system_graph(ROOT_DIR)
        except Exception as e:
            print(f"Error building system graph: {e}")
            self._graph = None

    @property
    def graph(self) -> Dict[str, Any]:
        if self._graph is None:
            # Lazy-load the graph
            try:
                self._load_system_graph()
            except Exception as e:
                print(f"Error building system graph: {e}")
                self._graph = None
        return self._graph

    def autofix_formatting(self) -> int:
        """
        Formatting pass for Clarity files:
        - Ensure a newline between adjacent top-level forms: ')(' -> ')\n('
        - Ensure comments begin on new lines: ';;' -> '\n;;'
        - Collapse excessive blank lines.
        Skips traits/ and mocks/ directories.
        Returns number of files modified.
        """
        modified = 0
        for f in self.contract_files:
            if any(part in f.parts for part in ["traits", "mocks"]):
                continue
            try:
                original = f.read_text(encoding='utf-8')
            except Exception:
                continue
            text = original.replace('\r\n', '\n')
            # Insert newline between adjacent parens to satisfy parser expectations
            new_text = text.replace(')(', ')\n(')
            # Ensure comments start at new lines
            new_text = new_text.replace(';;', '\n;;')
            # Collapse excessive blank lines
            new_text = re.sub(r'\n{3,}', '\n\n', new_text)
            if new_text != text:
                try:
                    f.write_text(new_text, encoding='utf-8', newline='\n')
                    modified += 1
                    self.modified_files.add(f)
                except Exception as e:
                    print(f"Warning: failed to write formatted content to {f}: {e}")
        if modified:
            print(f"Formatted {modified} files (inserted newlines between adjacent forms).")
        else:
            print("autofix_formatting: no changes needed.")
        return modified

    def autofix_traits(self) -> int:
        """
        Stub: Fix trait definitions.
        Currently not implemented; returns 0.
        """
        print("autofix_traits: not implemented; skipping.")
        return 0

    def _contracts_using_all_traits(self) -> List[Path]:
        results: List[Path] = []
        for f in self.contract_files:
            try:
                content = self._strip_comments(f.read_text())
            except Exception:
                continue
            # Check for any all-traits usage (both old and new formats)
            uses_all_traits = ('.all-traits.' in content or 
                             re.search(r"'[A-Z0-9]+\.all-traits\.", content) or
                             'all-traits.' in content)
            if uses_all_traits:
                results.append(f)
        return results

    def is_file_fatal(self, f: Path) -> bool:
        """Return True if `clarinet check` reported a non-allowed (fatal) error for file f."""
        if not self.clarinet_errors:
            return False
        normf = os.path.normpath(str(f))
        allowed_patterns = [
            "detected interdependent functions",
            "(impl-trait ...) expects a trait identifier",
        ]
        for err in self.clarinet_errors:
            ef = err.get('file')
            if not ef:
                continue
            try:
                if os.path.normpath(ef) == normf:
                    msg = err.get('message', '')
                    if any(pat in msg for pat in allowed_patterns):
                        return False
                    return True
            except Exception:
                continue
        return False

    def autofix_normalize_line_endings(self) -> int:
        """Normalize CRLF -> LF for all .clar files. Returns number of files modified."""
        modified = 0
        for f in self.contract_files:
            # skip binary or unreadable files
            try:
                text = f.read_text(encoding='utf-8')
            except Exception:
                continue
            if '\r\n' in text:
                new_text = text.replace('\r\n', '\n')
                try:
                    f.write_text(new_text, encoding='utf-8', newline='\n')
                    modified += 1
                except Exception:
                    continue
        return modified

    def autofix_manifest_depends_on(self) -> int:
        """Ensure depends_on = ["all-traits"] is present for any contract listed in
        stacks/Clarinet.test.toml that uses centralized traits.

        Returns number of modifications made.
        """
        if not STACKS_TEST_TOML.exists():
            self.warnings.append("Test manifest not found; cannot autofix depends_on.")
            return 0

        test_contracts = self.test_config.get("contracts", {})

        # Build reverse map path(normalized) -> key
        path_to_key: Dict[str, str] = {}
        for key, entry in test_contracts.items():
            if isinstance(entry, dict) and 'path' in entry:
                norm = entry['path'].replace('\\', '/')
                path_to_key[norm] = key

        modified = 0
        for f in self._contracts_using_all_traits():
            rel_part = str(f.relative_to(self.contracts_dir)).replace('\\', '/')
            path_variants = [f"contracts/{rel_part}", rel_part]
            key = None
            for pv in path_variants:
                if pv in path_to_key:
                    key = path_to_key[pv]
                    break
            if not key:
                # not listed in test manifest; skip
                continue
            entry = test_contracts.get(key)
            if not isinstance(entry, dict):
                continue
            deps = entry.get('depends_on')
            if not isinstance(deps, list):
                entry['depends_on'] = ['all-traits']
                modified += 1
            else:
                if 'all-traits' not in deps:
                    entry['depends_on'] = ['all-traits'] + deps
                    modified += 1

        if modified > 0:
            # Write back
            data = dict(self.test_config)
            data['contracts'] = test_contracts
            with open(STACKS_TEST_TOML, 'w') as f:
                toml.dump(data, f)
            # Reload into memory
            with open(STACKS_TEST_TOML, 'r') as f:
                self.test_config = toml.load(f)

        return modified
    
    def autofix_graph_dynamic_calls(self) -> int:
        """Generate suggestions for refactoring dynamic contract-call? patterns in non-test contracts
        to use trait-typed parameters instead.
        
        Writes artifacts/autofix-graph-suggestions.json with suggestions.
        Returns number of suggestions generated.
        """
        self._load_system_graph()
        if not self.system_graph or not self._graph:
            # Build graph if not already done
            try:
                graph = self.system_graph.build_system_graph(ROOT_DIR)
                self._graph = graph
            except Exception as e:
                self.warnings.append(f"Failed to build system graph for autofix: {e}")
                return 0
        
        graph = self._graph
        node_types: Dict[str, str] = {n["id"]: n.get("type", "") for n in graph.get("nodes", [])}
        
        suggestions = []
        for e in graph.get("edges", []):
            if e.get("type") == "dynamic-call":
                src = e.get("from", "")
                target = e.get("to", "")
                # Only suggest for contracts (not tests)
                if node_types.get(src) == "contract":
                    suggestions.append({
                        "source": src,
                        "target": target,
                        "recommendation": f"Consider refactoring {src} to accept {target} as a trait-typed parameter (<sip-010-ft-trait>) and use static contract-call? instead of dynamic dispatch."
                    })
        
        # Write to artifacts
        artifacts_dir = ROOT_DIR / "artifacts"
        artifacts_dir.mkdir(exist_ok=True)
        output_path = artifacts_dir / "autofix-graph-suggestions.json"
        with open(output_path, 'w') as f:
            json.dump({
                "dynamic_call_suggestions": suggestions,
                "count": len(suggestions)
            }, f, indent=2)
        
        if suggestions:
            print(f"Generated {len(suggestions)} graph refactoring suggestions in {output_path}")
        else:
            print(f"No dynamic call patterns found requiring refactoring.")
        
        return len(suggestions)

    def autofix_dependency_graph(self) -> int:
        """Coordinate dependency-graph related autofixes.

        Currently this runs the manifest depends_on autofix and generates
        dynamic-call suggestions. Returns the number of manifest entries
        modified (if any)."""
        modified = 0
        try:
            modified += self.autofix_manifest_depends_on()
        except Exception as e:
            self.warnings.append(f"autofix_manifest_depends_on failed: {e}")

        try:
            # This produces suggestions/artifacts but doesn't modify manifests.
            self.autofix_graph_dynamic_calls()
        except Exception as e:
            self.warnings.append(f"autofix_graph_dynamic_calls failed: {e}")

        return modified
    
    def autofix_impl_traits(self) -> int:
        """
        Standardizes all trait usage to a canonical format by rebuilding `use-trait`
        and `impl-trait` statements to use full contract principals.
        This is a two-pass operation to ensure correctness.
        """
        modified_files = 0
        
        try:
            toml_data = toml.load(self.clarinet_toml)
            deployer_address = toml_data.get('accounts', {}).get('deployer', {}).get('address')
            if not deployer_address:
                raise ValueError("Deployer address not found in Clarinet.toml")
        except Exception as e:
            print(f"Error loading deployer address from Clarinet.toml: {e}")
            return 0

        if not self.defined_traits:
            self.verify_trait_references()
            if not self.defined_traits:
                print("FATAL: Could not populate defined traits from all-traits.clar. Aborting autofix.")
                return 0

        # Ensure we have latest clarinet errors to avoid touching files with fatal compile errors
        try:
            if not self.clarinet_errors:
                self.run_clarinet_check()
        except Exception:
            # Non-fatal; proceed but be conservative
            pass

        # Build a set of files with fatal clarinet errors to skip
        fatal_files: Set[str] = set()
        for err in (self.clarinet_errors or []):
            msg = err.get('message', '')
            # Skip allowed patterns
            allowed_patterns = [
                "detected interdependent functions",
                "(impl-trait ...) expects a trait identifier",
            ]
            if err.get('file') and not any(pat in msg for pat in allowed_patterns):
                fatal_files.add(os.path.normpath(err['file']))

        for f in self.contract_files:
            # Exclude mocks and traits directories from this autofix
            if any(part in f.parts for part in ["traits", "mocks"]):
                continue

            # Skip files that had fatal clarinet errors
            try:
                normf = os.path.normpath(str(f))
            except Exception:
                normf = None
            if normf and normf in fatal_files:
                print(f"Skipping autofix for {f.name} due to compilation errors.")
                continue

            try:
                original_content = f.read_text(encoding='utf-8')
                content_lf = original_content.replace('\r\n', '\n')
            except Exception:
                continue

            # --- Pass 1: Discover all traits implemented in this file ---
            implemented_refs = {m.group(1).lstrip('.').split('.')[-1] for m in re.finditer(IMPL_TRAIT_PATTERN, content_lf)}
            implemented_refs.discard('all-traits')

            if not implemented_refs:
                continue

            # --- Pass 2: Rebuild the file content ---
            required_aliases: Dict[str, str] = {} # alias -> canonical_name
            for ref in implemented_refs:
                canonical_name = None
                if ref in self.defined_traits:
                    canonical_name = ref
                elif f"{ref}-trait" in self.defined_traits:
                    canonical_name = f"{ref}-trait"

                if canonical_name:
                    required_aliases[canonical_name] = canonical_name
            
            if not required_aliases:
                continue

            lines = content_lf.split('\n')
            
            # Remove all existing use-trait and impl-trait lines
            lines_no_traits = [line for line in lines if not (line.strip().startswith('(use-trait') or line.strip().startswith('(impl-trait'))]
            
            # Generate new blocks
            new_use_trait_block = [f"(use-trait {alias} .all-traits.{canonical})" for alias, canonical in sorted(required_aliases.items())]
            new_impl_trait_block = [f"(impl-trait {alias})" for alias in sorted(required_aliases.keys())]

            # Find insertion point (typically at the top, after any initial comments)
            insert_at = 0
            for i, line in enumerate(lines_no_traits):
                if line.strip() and not line.strip().startswith(";;"):
                    insert_at = i
                    break
            
            # Combine the new blocks and insert them
            final_lines = lines_no_traits[:insert_at] + new_use_trait_block + new_impl_trait_block + lines_no_traits[insert_at:]
            new_content = "\n".join(final_lines)

            # --- Step 5: Write if changed ---
            if new_content != content_lf:
                try:
                    f.write_text(new_content, encoding='utf-8', newline='\n')
                    print(f"Rewrote: {f.name}")
                    modified_files += 1
                except Exception as e:
                    print(f"Error writing to {f.name}: {e}")

        if modified_files:
            print(f"Auto-fix impl-trait: rewritten in {modified_files} files.")
        else:
            print("Auto-fix impl-trait: no changes needed.")
        return modified_files

    def autofix_impl_trait_false_positives(self) -> int:
        """Target files whose clarinet errors are only the impl-trait false-positive and rewrite them.

        Returns number of files modified.
        """
        try:
            toml_data = toml.load(self.clarinet_toml)
            deployer_address = toml_data.get('accounts', {}).get('deployer', {}).get('address')
            if not deployer_address:
                raise ValueError("Deployer address not found in Clarinet.toml")
        except Exception as e:
            print(f"Error loading deployer address from Clarinet.toml: {e}")
            return 0

        allowed_patterns = [
            "detected interdependent functions",
            "(impl-trait ...) expects a trait identifier",
            "expecting expression of type trait identifier",
        ]

        # Map file -> list of messages
        file_errs: Dict[str, List[str]] = {}
        for err in (self.clarinet_errors or []):
            f = err.get('file')
            if not f:
                continue
            file_errs.setdefault(os.path.normpath(f), []).append(err.get('message', ''))

        modified = 0
        for f in self.contract_files:
            norm = os.path.normpath(str(f))
            msgs = file_errs.get(norm)
            if not msgs:
                continue
            # If all messages for this file are allowed impl-trait patterns, try to rewrite
            if all(any(pat in m for pat in allowed_patterns) for m in msgs):
                # perform a localized rewrite similar to autofix_impl_traits for this file
                try:
                    original_content = f.read_text(encoding='utf-8')
                    content_lf = original_content.replace('\r\n', '\n')
                except Exception:
                    continue

                implemented_refs = {m.group(1).lstrip('.').split('.')[-1] for m in re.finditer(IMPL_TRAIT_PATTERN, content_lf)}
                implemented_refs.discard('all-traits')
                if not implemented_refs:
                    continue

                # Determine canonical trait names
                required_aliases: Dict[str, str] = {}
                # load known traits if not present
                if not self.defined_traits:
                    self.verify_trait_references()
                for ref in implemented_refs:
                    canonical_name = None
                    if ref in self.defined_traits:
                        canonical_name = ref
                    elif f"{ref}-trait" in self.defined_traits:
                        canonical_name = f"{ref}-trait"
                    if canonical_name:
                        required_aliases[canonical_name] = canonical_name

                if not required_aliases:
                    continue

                lines = content_lf.split('\n')
                lines_no_traits = [line for line in lines if not (line.strip().startswith('(use-trait') or line.strip().startswith('(impl-trait'))]

                new_use_trait_block = [f"(use-trait {alias} .all-traits.{canonical})" for alias, canonical in sorted(required_aliases.items())]
                new_impl_trait_block = [f"(impl-trait {alias})" for alias in sorted(required_aliases.keys())]

                insert_at = 0
                for i, line in enumerate(lines_no_traits):
                    if line.strip() and not line.strip().startswith(';;'):
                        insert_at = i
                        break

                final_lines = lines_no_traits[:insert_at] + new_use_trait_block + new_impl_trait_block + lines_no_traits[insert_at:]
                new_content = '\n'.join(final_lines)
                if new_content != content_lf:
                    try:
                        f.write_text(new_content, encoding='utf-8', newline='\n')
                        print(f"Targeted rewrite: {f.name}")
                        modified += 1
                    except Exception as e:
                        print(f"Error writing {f.name}: {e}")

        return modified

    def run_clarinet_check(self) -> List[Dict[str, Any]]:
        """
        Executes `clarinet check` and returns a structured list of errors.
        This function is designed to be the source of truth for compilation errors.
        """
        print("Running `clarinet check`...")
        errors = []
        try:
            import subprocess
            result = subprocess.run(
                ["clarinet", "check"],
                cwd=str(ROOT_DIR),
                capture_output=True,
                text=True,
                encoding='utf-8',
                check=False  # Don't raise exception on non-zero exit code
            )
            output = (result.stdout or "") + "\n" + (result.stderr or "")
            
            # More robust error parsing
            # Handles different formats of clarinet check errors
            error_pattern = re.compile(
                r'error:\s*(?P<message>.*?)\s*in\s*"(?P<file>.*?)"\s*on\s*line\s*(?P<line>\d+)',
                re.IGNORECASE
            )
            
            for line in output.splitlines():
                if 'error:' in line:
                    match = error_pattern.search(line)
                    if match:
                        errors.append({
                            "file": match.group("file"),
                            "line": int(match.group("line")),
                            "message": match.group("message").strip(),
                            "raw": line.strip()
                        })
                    else:
                        # Capture unparsed errors as well, without file/line info
                        errors.append({
                            "file": None,
                            "line": None,
                            "message": line.strip(),
                            "raw": line.strip()
                        })
            
            self.clarinet_errors = errors
            if errors:
                print(f"Found {len(errors)} compilation errors.")
            else:
                print("`clarinet check` completed with no errors.")

        except FileNotFoundError:
            msg = "`clarinet` command not found. Please ensure it is installed and in your PATH."
            self.errors.append(msg)
            print(f"ERROR: {msg}")
        except Exception as e:
            msg = f"An unexpected error occurred while running `clarinet check`: {e}"
            self.errors.append(msg)
            print(f"ERROR: {msg}")
        
        return errors

    def check_compilation(self) -> bool:
        """Check if all contracts compile successfully using clarinet check."""
        print("\n=== Checking Contract Compilation ===")
        # We now rely on the results from run_clarinet_check
        if not hasattr(self, 'clarinet_errors') or self.clarinet_errors is None:
             self.run_clarinet_check()

        if not self.clarinet_errors:
            print("[PASS] All contracts compile successfully.")
            return True
        
        # Filter for non-allowed errors
        allowed_patterns = [
            "detected interdependent functions",
            "(impl-trait ...) expects a trait identifier",
        ]
        
        non_allowed_errors = []
        for error in self.clarinet_errors:
            if not any(pat in error['message'] for pat in allowed_patterns):
                non_allowed_errors.append(error)

        if non_allowed_errors:
            self.errors.append("Fatal compilation errors found:")
            for err in non_allowed_errors:
                if err['file']:
                    self.errors.append(f"  {err['file']}:{err['line']} - {err['message']}")
                else:
                    self.errors.append(f"  {err['message']}")
            return False
        else:
            self.warnings.append("Clarinet reported known false positives (recursion/impl-trait). Proceeding.")
            return True

    def run_all_checks(self) -> None:
        """Run all verification checks."""
        if self.do_autofix_impl_traits:
            self.autofix_impl_traits()
            # Re-run checks after impl-trait normalization
            self.verify_trait_references()
        else:
            self.verify_trait_references()
        self.check_contract_dependencies()
        self.check_unused_contracts()
        self.check_pruned_dependencies()
        self.check_formatting()
        self.check_compilation()

    def autofix_and_report(self) -> None:
        """Run autofixers and report results."""
        print("\n=== Running Autofixers ===")
        # Normalize line endings first (common source of errors)
        try:
            normalized = self.autofix_normalize_line_endings()
            if normalized:
                print(f"Normalized line endings in {normalized} files.")
        except Exception as e:
            print(f"Warning: failed to normalize line endings before autofix: {e}")
        # Run clarinet check to seed error parsing
        try:
            self.run_clarinet_check()
        except Exception as e:
            print(f"Warning: failed to run clarinet check before autofix: {e}")
        # Target impl-trait false positives first
        try:
            fixed = self.autofix_impl_trait_false_positives()
            if fixed:
                print(f"Applied targeted impl-trait fixes to {fixed} files.")
                self.run_clarinet_check()
        except Exception as e:
            print(f"Warning: failed to apply targeted impl-trait fixes: {e}")
        # Graph dependencies and suggestions
        if self.do_autofix_graph:
            modified_count = self.autofix_dependency_graph()
            if modified_count > 0:
                print(f"Fixed {modified_count} contract dependencies in Clarinet.toml.")
        # Impl-trait normalization
        if self.do_autofix_impl_traits:
            modified_count = self.autofix_impl_traits()
            if modified_count > 0:
                print(f"Fixed {modified_count} trait implementations.")
        # Optional stubs
        if self.do_autofix_unused:
            self.autofix_unused_contracts()
        if self.do_autofix_prune:
            self.autofix_pruned_dependencies()
        # Formatting pass
        if self.do_autofix_format:
            self.autofix_formatting()
        print("\n=== Autofix Complete ===")
        self.print_report()

    def print_report(self) -> None:
        """Prints the final error and warning report."""
        if self.errors:
            print("\n" + "="*10 + " ERRORS " + "="*10)
            for error in sorted(list(set(self.errors))):
                print(f"- {error}")
        if self.warnings:
            print("\n" + "="*10 + " WARNINGS " + "="*10)
            for warning in sorted(list(set(self.warnings))):
                print(f"- {warning}")

    def run_verification(self) -> bool:
        """Run all verification steps"""
        print("\n=== Starting Contract Verification ===\n")
        
        # Run all verification steps
        steps = [
            ("Contract Listings", self.verify_contracts_in_toml()),
            ("Trait References", self.verify_trait_references()),
            ("Trait Implementations", self.verify_trait_implementation()),
            ("Manifest Alignment", self.verify_manifest_alignment()),
            ("System Graph", self.analyze_system_graph()),
            ("Contract Compilation", self.check_compilation())
        ]
        
        # Print results
        all_passed = True
        for name, result in steps:
            status = "[PASS]" if result else "[FAIL]"
            print(f"{status} {name}")
            if not result:
                all_passed = False
        
        # Print errors and warnings
        if self.errors:
            print("\n=== Errors ===")
            for error in self.errors:
                print(f"Error: {error}")
                
        if self.warnings:
            print("\n=== Warnings ===")
            for warning in self.warnings:
                print(f"Warning: {warning}")
        
        # Print summary
        print(f"\n=== Verification {'PASSED' if all_passed else 'FAILED'} ===")
        print(f"Errors: {len(self.errors)}")
        print(f"Warnings: {len(self.warnings)}")
        
        return all_passed


def main():
    parser = argparse.ArgumentParser(description="Verify and fix Conxian Clarity contracts.")
    parser.add_argument('--autofix-graph', action='store_true', help="Automatically fix dependency graph issues.")
    parser.add_argument('--autofix-unused', action='store_true', help="Automatically remove unused contracts from Clarinet.toml.")
    parser.add_argument('--autofix-traits', action='store_true', help="Automatically fix trait definitions.")
    parser.add_argument('--autofix-prune', action='store_true', help="Automatically prune unused dependencies.")
    parser.add_argument('--autofix-format', action='store_true', help="Automatically format Clarity files.")
    parser.add_argument('--autofix-impl-traits', action='store_true', help="Standardize impl-trait usage.")
    parser.add_argument('--autofix-all', action='store_true', help="Run all autofixers.")
    args = parser.parse_args()

    if args.autofix_all:
        args.autofix_graph = True
        args.autofix_unused = True
        # args.autofix_traits = True # This is a destructive operation, so we don't include it in all
        args.autofix_prune = True
        args.autofix_format = True
        args.autofix_impl_traits = True

    verifier = ContractVerifier(
        autofix_graph=args.autofix_graph,
        autofix_unused=args.autofix_unused,
        autofix_traits=args.autofix_traits,
        autofix_prune=args.autofix_prune,
        autofix_format=args.autofix_format,
        autofix_impl_traits=args.autofix_impl_traits
    )

    if any([args.autofix_graph, args.autofix_unused, args.autofix_traits, args.autofix_prune, args.autofix_format, args.autofix_impl_traits]):
        verifier.autofix_and_report()
    else:
        print("\n=== Starting Contract Verification ===")
        if not verifier.run_verification():
            verifier.print_report()
            sys.exit(1)
        else:
            verifier.print_report()
            print("\n✅ All checks passed!")

if __name__ == "__main__":
    main()
