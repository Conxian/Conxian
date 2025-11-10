#!/usr/bin/env python3
"""
Script to consolidate duplicate TOML configuration files in the Conxian repository.
"""
import os
import toml
from pathlib import Path
from typing import Dict, Any

def load_toml(file_path: Path) -> Dict[str, Any]:
    """Load a TOML file and return its contents as a dictionary."""
    with open(file_path, 'r') as f:
        return toml.load(f)

def save_toml(data: Dict[str, Any], file_path: Path):
    """Save a dictionary as a TOML file."""
    with open(file_path, 'w') as f:
        toml.dump(data, f)

def merge_toml_files(main_file: Path, *other_files: Path) -> Dict[str, Any]:
    """Merge multiple TOML files, with later files taking precedence."""
    result = {}
    for file in (main_file, *other_files):
        if file.exists():
            file_data = load_toml(file)
            # Merge dictionaries recursively
            for key, value in file_data.items():
                if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                    result[key].update(value)
                else:
                    result[key] = value
    return result

def main():
    repo_root = Path(__file__).parent.parent
    
    # Define main configuration files
    main_clarinet = repo_root / 'Clarinet.toml'
    test_clarinet = repo_root / 'stacks' / 'Clarinet.test.toml'
    
    # Consolidate testnet plans
    testnet_plans = [
        repo_root / 'deployments' / 'testnet-plan.toml',
        repo_root / 'deployments' / 'simplified-testnet-plan.toml',
        repo_root / 'stacks' / 'deployments' / 'simplified-testnet-plan.toml'
    ]
    
    # Consolidate settings
    settings_files = [
        repo_root / 'settings' / 'Devnet.toml',
        repo_root / 'settings' / 'Testnet.toml',
        repo_root / 'settings' / 'Mainnet.toml',
        repo_root / 'stacks' / 'settings' / 'Devnet.toml',
        repo_root / 'stacks' / 'settings' / 'Testnet.toml'
    ]
    
    print("Consolidating configuration files...")
    
    # Create backups
    backup_dir = repo_root / '.backup'
    backup_dir.mkdir(exist_ok=True)
    
    # Backup original files
    for file in [main_clarinet, test_clarinet, *testnet_plans, *settings_files]:
        if file.exists():
            backup_path = backup_dir / file.relative_to(repo_root).with_suffix(f'.bak{file.suffix}')
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            backup_path.write_text(file.read_text())
    
    # Consolidate testnet plans
    if any(f.exists() for f in testnet_plans):
        consolidated_plan = merge_toml_files(*[f for f in testnet_plans if f.exists()])
        target_plan = repo_root / 'deployments' / 'testnet-plan.toml'
        save_toml(consolidated_plan, target_plan)
        print(f"Consolidated testnet plans to {target_plan}")
        
        # Remove duplicate files
        for plan in testnet_plans[1:]:
            if plan.exists():
                plan.unlink()
                print(f"Removed duplicate testnet plan: {plan}")
    
    # Consolidate settings
    if any(f.exists() for f in settings_files):
        consolidated_settings = merge_toml_files(*[f for f in settings_files if f.exists()])
        (repo_root / 'settings').mkdir(exist_ok=True)
        
        # Save per-environment settings
        for env in ['Devnet', 'Testnet', 'Mainnet']:
            env_settings = {
                k: v for k, v in consolidated_settings.items()
                if k.lower() == env.lower() or not any(k.lower() == e.lower() for e in ['Devnet', 'Testnet', 'Mainnet'])
            }
            if env_settings:
                target_file = repo_root / 'settings' / f'{env}.toml'
                save_toml(env_settings, target_file)
                print(f"Saved {env} settings to {target_file}")
        
        # Remove duplicate settings
        for settings_file in settings_files[3:]:  # Skip the ones we just saved
            if settings_file.exists():
                settings_file.unlink()
                print(f"Removed duplicate settings file: {settings_file}")
    
    print("\nConsolidation complete. Original files have been backed up to the .backup directory.")

if __name__ == "__main__":
    main()
