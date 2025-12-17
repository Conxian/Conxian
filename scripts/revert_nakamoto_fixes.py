import os
import re

# We will divide by 120 to revert the previous multiplication.
DIVISOR = 120

def revert_fixes(root_dir):
    print(f"Reverting Nakamoto constant fixes in {root_dir}...\n")

    # Files identified by the analysis script (and modified by the previous script)
    files_to_fix = [
        'contracts/batch-auction.clar',
        'contracts/proposal-engine.clar',
        'contracts/self-launch-coordinator.clar',
        'contracts/audit-registry/audit-registry.clar',
        'contracts/core/economic-policy-engine.clar',
        'contracts/core/funding-rate-calculator.clar',
        'contracts/cross-chain/bridge-nft.clar',
        'contracts/dex/batch-auction.clar',
        'contracts/dex/bond-factory.clar',
        'contracts/dex/cxlp-migration-queue.clar',
        'contracts/dex/cxvg-utility.clar',
        'contracts/dex/enterprise-loan-manager.clar',
        'contracts/dex/nakamoto-compatibility.clar',
        'contracts/dex/real-time-monitoring-dashboard.clar',
        'contracts/dex/sbtc-bond-integration.clar',
        'contracts/dex/sbtc-flash-loan-vault.clar',
        'contracts/dex/sbtc-integration.clar',
        'contracts/dex/sbtc-oracle-adapter.clar',
        'contracts/dex/timelock-controller.clar',
        'contracts/dex/token-emission-controller.clar',
        'contracts/dex/yield-distribution-engine.clar',
        'contracts/dimensional/dim-yield-stake.clar',
        'contracts/dimensional/governance.clar',
        'contracts/governance/emergency-governance.clar',
        'contracts/governance/ico-offering.clar',
        'contracts/governance/lending-protocol-governance.clar',
        'contracts/governance/proposal-engine.clar',
        'contracts/governance/timelock.clar',
        'contracts/governance/upgrade-controller.clar',
        'contracts/insurance/insurance-protection-nft.clar',
        'contracts/lending/interest-rate-model.clar',
        'contracts/marketplace/nft-marketplace.clar',
        'contracts/monitoring/analytics-aggregator.clar',
        'contracts/monitoring/price-stability-monitor.clar',
        'contracts/oracle/oracle-aggregator-v2.clar',
        'contracts/rewards/early-lp-rewards.clar',
        'contracts/risk/funding-calculator.clar',
        'contracts/security/conxian-insurance-fund.clar',
        'contracts/security/mev-protector.clar',
        'contracts/security/proof-of-reserves.clar',
        'contracts/security/rate-limiter.clar',
        'contracts/staking/staking-yield-nft.clar',
        'contracts/traits/trait-errors.clar',
        'contracts/utils/block-utils.clar',
        'contracts/vaults/custody.clar'
    ]

    # Time keywords to target
    time_keywords = ['delay', 'period', 'duration', 'lock', 'expiry', 'window', 'interval', 'timelock', 'blocks']

    for file_rel_path in files_to_fix:
        file_path = os.path.join(root_dir, file_rel_path.replace('/', os.sep))
        if not os.path.exists(file_path):
            print(f"Skipping {file_path} (not found)")
            continue

        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        new_content = content

        # Regex to find constants: (define-constant NAME uVALUE)
        matches = re.finditer(r'\(define-constant\s+([A-Z0-9_-]+)\s+u([0-9]+)\)', content)

        for match in matches:
            name = match.group(1)
            old_value = int(match.group(2))

            # Check if this constant looks like a time constant
            if any(k in name.lower() for k in time_keywords) and old_value > 0:
                # Calculate new value
                new_value = old_value // DIVISOR # Use integer division

                # Replace in content
                old_str = match.group(0)
                new_str = f'(define-constant {name} u{new_value})'

                new_content = new_content.replace(old_str, new_str)
                print(f"Updated {name} in {file_rel_path}: u{old_value} -> u{new_value}")

        # Regex for data-vars: (define-data-var NAME type uVALUE)
        matches_var = re.finditer(r'\(define-data-var\s+([a-z0-9_-]+)\s+uint\s+u([0-9]+)\)', content)
        for match in matches_var:
            name = match.group(1)
            old_value = int(match.group(2))

            if any(k in name.lower() for k in time_keywords) and old_value > 0:
                new_value = old_value // DIVISOR
                old_str = match.group(0)
                new_str = f'(define-data-var {name} uint u{new_value})'
                new_content = new_content.replace(old_str, new_str)
                print(f"Updated {name} in {file_rel_path}: u{old_value} -> u{new_value}")

        if new_content != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Saved changes to {file_rel_path}\n")

if __name__ == "__main__":
    revert_fixes(".")
