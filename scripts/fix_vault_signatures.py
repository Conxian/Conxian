
import re

file_path = r"c:\Users\bmokoka\anyachainlabs\Conxian\contracts\dex\vault.clar"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update deposit signature and body
# Pattern: (define-public (deposit (asset principal) (amount uint))
# We want to change it to (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
# And inside let, add (asset (contract-of asset-trait))
# And change contract-call? asset to contract-call? asset-trait

# Helper to inject asset definition
def inject_asset_def(match):
    full_match = match.group(0)
    # Check if we already did it (idempotency)
    if "asset-trait" in full_match:
        return full_match
    
    # Change signature
    new_sig = full_match.replace("(asset principal)", "(asset-trait <sip-010-ft-trait>)")
    
    # Inject let binding.
    # The let block starts after signature.
    # (let ((user tx-sender)
    # We want (let ((user tx-sender) (asset (contract-of asset-trait))
    new_sig = new_sig.replace("(let ((user tx-sender)", "(let ((user tx-sender)\n        (asset (contract-of asset-trait))")
    
    return new_sig

# Helper to replace contract call
def replace_contract_call(content):
    # (try! (contract-call? asset transfer
    return content.replace("(contract-call? asset transfer", "(contract-call? asset-trait transfer")

# Update deposit
content = re.sub(r"\(define-public \(deposit \(asset principal\) \(amount uint\)\)\s+\(let \(\(user tx-sender\)", inject_asset_def, content)

# Update withdraw
content = re.sub(r"\(define-public \(withdraw \(asset principal\) \(shares uint\)\)\s+\(let \(\(user tx-sender\)", inject_asset_def, content)

# Replace contract calls in the whole file? No, only in functions where we have asset-trait.
# But 'asset' is shadowed by 'asset' variable which is principal.
# So 'contract-call? asset' is definitely wrong if asset is principal.
# So replacing ALL 'contract-call? asset' with 'contract-call? asset-trait' is correct IF we assume the variable name in scope is asset-trait.
# But we only renamed it in deposit/withdraw.
# We should be careful.

# Update emergency-withdraw
# Signature: (define-public (emergency-withdraw (asset principal) (amount uint) (recipient principal))
# Body: (try! (contract-call? asset transfer ...))
def fix_emergency(match):
    return match.group(0).replace("(asset principal)", "(asset-trait <sip-010-ft-trait>)") \
                         .replace("(begin", "(begin\n    (let ((asset (contract-of asset-trait)))") \
                         .replace("(contract-call? asset", "(contract-call? asset-trait")
    # Wait, let block? emergency-withdraw has (begin (asserts! ...)). No let.
    # We need to wrap in let or define asset.
    # It uses 'asset' in asserts and map-set.
    # So we need 'asset' variable.
    # (let ((asset (contract-of asset-trait))) (begin ...))
    # But it starts with (begin ...).
    # We can replace (begin with (let ((asset (contract-of asset-trait))) (begin
    # And add closing ) at end? No, that's hard with regex.
    # Better: (define-public (emergency-withdraw (asset-trait <sip-010-ft-trait>) ...)
    # (let ((asset (contract-of asset-trait)))
    #   (begin ... ))
    
# Manual replace for emergency-withdraw
old_ew = """(define-public (emergency-withdraw (asset principal) (amount uint) (recipient principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Emergency withdrawal - transfer assets directly
    (try! (contract-call? asset transfer amount (as-contract tx-sender) recipient none))"""

new_ew = """(define-public (emergency-withdraw (asset-trait <sip-010-ft-trait>) (amount uint) (recipient principal))
  (let ((asset (contract-of asset-trait)))
    (begin
      (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Emergency withdrawal - transfer assets directly
      (try! (contract-call? asset-trait transfer amount (as-contract tx-sender) recipient none))"""

# We need to close the let. The function ends with (ok amount))).
# So we need to add ) at the end of function.
# This is risky with regex.
# However, pay-service also needs fix.

# Let's apply global replacement for 'contract-call? asset' -> 'contract-call? asset-trait'
# And assume we update signatures.
content = replace_contract_call(content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
