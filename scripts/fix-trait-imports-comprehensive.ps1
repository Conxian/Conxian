# Fix Trait Imports - Comprehensive System Repair
# This script systematically fixes trait imports to use centralized all-traits.clar

param(
    [switch]$ReportOnly = $false,
    [string]$ReportJsonPath = "trait_fixer_report.json",
    # Sync all contracts found in contracts/ (excluding traits) into Clarinet.toml
    [switch]$SyncContracts = $true,
    # If set, rename manifest [contracts.*] block names to match the file basename
    [switch]$RenameBlocks = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Conxian Trait Import Fix Script v2.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$FixCount = 0
$FileCount = 0

# Load centralized trait definitions from contracts/traits/all-traits.clar
$AllTraits = @{}
$allTraitsPath = "contracts/traits/all-traits.clar"
if (Test-Path $allTraitsPath) {
    $allTraitsContent = Get-Content $allTraitsPath -Raw
    $defineTraitRegex = "(?m)^\s*\(define-trait\s+([a-zA-Z0-9\-]+)"
    $matches = [regex]::Matches($allTraitsContent, $defineTraitRegex)
    foreach ($m in $matches) { $AllTraits[$m.Groups[1].Value] = $true }
    Write-Host "Loaded $($AllTraits.Keys.Count) centralized trait definitions from all-traits.clar" -ForegroundColor DarkCyan
} else {
    Write-Host "Warning: $allTraitsPath not found; trait validation skipped" -ForegroundColor Yellow
}

# Collect issues for final reporting
$Issues = @()
# Track referenced contracts discovered from dotted references like .trait-registry
$ReferencedContracts = New-Object System.Collections.Generic.HashSet[string]

# Get all Clarity contract files
$contractFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse -Exclude "all-traits.clar"

Write-Host "Found $($contractFiles.Count) contract files to process" -ForegroundColor Yellow
Write-Host ""

foreach ($file in $contractFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Gray
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    $fileFixCount = 0
    $fileIssues = @()

    # =========================================================================
    # ANALYZE: detect required trait aliases from type usage and impl-trait
    # =========================================================================
    $detectedAliases = New-Object System.Collections.Generic.HashSet[string]
    # Type usage: <alias>
    $typeRegex = "<([a-zA-Z0-9\-]+)>"
    $typeMatches = [regex]::Matches($content, $typeRegex)
    foreach ($m in $typeMatches) { [void]$detectedAliases.Add($m.Groups[1].Value) }
    # impl-trait .all-traits.alias
    $implAllRegex = "\(impl-trait\s+\.all-traits\.([a-zA-Z0-9\-]+)\)"
    $implAllMatches = [regex]::Matches($content, $implAllRegex)
    foreach ($m in $implAllMatches) { [void]$detectedAliases.Add($m.Groups[1].Value) }
    # impl-trait alias
    $implAliasRegex = "\(impl-trait\s+([a-zA-Z0-9\-]+)\s*\)"
    $implAliasMatches = [regex]::Matches($content, $implAliasRegex)
    foreach ($m in $implAliasMatches) { [void]$detectedAliases.Add($m.Groups[1].Value) }

    # Discover dotted contract references: .contract-name (exclude .all-traits.* and known trait aliases)
    $dotRefRegex = "(?<!\.)\.([a-zA-Z][a-zA-Z0-9\-]+)\b"
    $dotMatches = [regex]::Matches($content, $dotRefRegex)
    foreach ($d in $dotMatches) {
        $ref = $d.Groups[1].Value
        if ($ref -ne 'all-traits' -and -not $AllTraits.ContainsKey($ref)) {
            [void]$ReferencedContracts.Add($ref)
        }
    }
    # Existing use-trait aliases
    $existingUseAliases = New-Object System.Collections.Generic.HashSet[string]
    $useTraitAliasRegex = "(?m)^\s*\(use-trait\s+([a-zA-Z0-9\-]+)\s+"
    $useMatches = [regex]::Matches($content, $useTraitAliasRegex)
    foreach ($m in $useMatches) { [void]$existingUseAliases.Add($m.Groups[1].Value) }
    # Required but missing use-trait aliases
    $missingUse = @()
    foreach ($alias in $detectedAliases) {
        if (-not $existingUseAliases.Contains($alias)) { $missingUse += $alias }
    }
    if ($missingUse.Count -gt 0) {
        foreach ($alias in $missingUse) {
            $known = $AllTraits.ContainsKey($alias)
            if ($known) {
                $newLine = "(use-trait $alias .all-traits.$alias)"
                if (-not $ReportOnly) {
                    $content = "$newLine`n" + $content
                }
                $fileFixCount++
                $fileIssues += "Inserted missing use-trait for $alias"
            } else {
                $ErrorCount++
                $fileIssues += "Unknown trait alias detected: $alias (not found in all-traits.clar)"
            }
        }
    }
    
    # =========================================================================
    # FIX 1: Replace incorrect use-trait patterns
    # =========================================================================
    
    # Pattern: (use-trait trait-name .trait-name.trait-name)
    # Fix to: (use-trait trait-name .all-traits.trait-name)
    
    $traitPatterns = @(
        @{Name="sip-010-ft-trait"; Old="\.sip-010-ft-trait\.sip-010-ft-trait"; New=".all-traits.sip-010-ft-trait"},
        @{Name="sip-009-nft-trait"; Old="\.sip-009-nft-trait\.sip-009-nft-trait"; New=".all-traits.sip-009-nft-trait"},
        @{Name="ownable-trait"; Old="\.ownable-trait\.ownable-trait"; New=".all-traits.ownable-trait"},
        @{Name="access-control-trait"; Old="\.access-control-trait\.access-control-trait"; New=".all-traits.access-control-trait"},
        @{Name="vault-trait"; Old="\.vault-trait\.vault-trait"; New=".all-traits.vault-trait"},
        @{Name="pool-trait"; Old="\.pool-trait\.pool-trait"; New=".all-traits.pool-trait"},
        @{Name="factory-trait"; Old="\.factory-trait\.factory-trait"; New=".all-traits.factory-trait"},
        @{Name="staking-trait"; Old="\.staking-trait\.staking-trait"; New=".all-traits.staking-trait"},
        @{Name="strategy-trait"; Old="\.strategy-trait\.strategy-trait"; New=".all-traits.strategy-trait"},
        @{Name="lending-system-trait"; Old="\.lending-system-trait\.lending-system-trait"; New=".all-traits.lending-system-trait"},
        @{Name="math-trait"; Old="\.math-trait\.math-trait"; New=".all-traits.math-trait"},
        @{Name="bond-trait"; Old="\.bond-trait\.bond-trait"; New=".all-traits.bond-trait"},
        @{Name="router-trait"; Old="\.router-trait\.router-trait"; New=".all-traits.router-trait"},
        @{Name="error-codes-trait"; Old="\.error-codes-trait\.error-codes-trait"; New=".all-traits.error-codes-trait"},
        @{Name="standard-constants-trait"; Old="\.standard-constants-trait\.standard-constants-trait"; New=".all-traits.standard-constants-trait"},
        @{Name="vault-admin-trait"; Old="\.vault-admin-trait\.vault-admin-trait"; New=".all-traits.vault-admin-trait"},
        @{Name="pool-creation-trait"; Old="\.pool-creation-trait\.pool-creation-trait"; New=".all-traits.pool-creation-trait"},
        @{Name="fee-manager-trait"; Old="\.fee-manager-trait\.fee-manager-trait"; New=".all-traits.fee-manager-trait"},
        @{Name="circuit-breaker-trait"; Old="\.circuit-breaker-trait\.circuit-breaker-trait"; New=".all-traits.circuit-breaker-trait"},
        @{Name="monitoring-trait"; Old="\.monitoring-trait\.monitoring-trait"; New=".all-traits.monitoring-trait"},
        @{Name="pausable-trait"; Old="\.pausable-trait\.pausable-trait"; New=".all-traits.pausable-trait"},
        @{Name="compliance-hooks-trait"; Old="\.compliance-hooks-trait\.compliance-hooks-trait"; New=".all-traits.compliance-hooks-trait"},
        @{Name="mev-protector-trait"; Old="\.mev-protector-trait\.mev-protector-trait"; New=".all-traits.mev-protector-trait"},
        @{Name="sip-010-ft-mintable-trait"; Old="\.sip-010-ft-mintable-trait\.sip-010-ft-mintable-trait"; New=".all-traits.sip-010-ft-mintable-trait"},
        @{Name="position-nft-trait"; Old="\.position-nft-trait\.position-nft-trait"; New=".all-traits.position-nft-trait"}
    )
    
    foreach ($pattern in $traitPatterns) {
        $regex = "\(use-trait\s+$($pattern.Name)\s+$($pattern.Old)\)"
        if ($content -match $regex) {
            $content = $content -replace $regex, "(use-trait $($pattern.Name) $($pattern.New))"
            $fileFixCount++
            Write-Host "  OK Fixed use-trait for $($pattern.Name)" -ForegroundColor Green
        }
    }

    # Generic catch-all: (use-trait alias .alias.alias) -> (use-trait alias .all-traits.alias)
    # Only apply if alias exists in AllTraits to avoid mis-mapping (e.g. ft-trait)
    $genericUseTrait = "\(use-trait\s+([a-zA-Z0-9\-]+)\s+\.\1\.\1\)"
    if ($content -match $genericUseTrait) {
        $content = [regex]::Replace($content, $genericUseTrait, {
            param($m)
            $alias = $m.Groups[1].Value
            if ($AllTraits.ContainsKey($alias)) { "(use-trait $alias .all-traits.$alias)" } else { $m.Value }
        })
        $fileFixCount++
        Write-Host "  OK Generic rewrite of use-trait alias .alias.alias -> .all-traits.alias (known only)" -ForegroundColor Green
    }

    # Extended catch-all: (use-trait local-alias .path-alias.path-alias) -> (use-trait local-alias .all-traits.path-alias)
    $diffAliasUseTrait = "\(use-trait\s+([a-zA-Z0-9\-]+)\s+\.([a-zA-Z0-9\-]+)\.\2\)"
    if ($content -match $diffAliasUseTrait) {
        $content = [regex]::Replace($content, $diffAliasUseTrait, {
            param($m)
            $local = $m.Groups[1].Value
            $pathAlias = $m.Groups[2].Value
            if ($AllTraits.ContainsKey($pathAlias)) { "(use-trait $local .all-traits.$pathAlias)" } else { $m.Value }
        })
        $fileFixCount++
        Write-Host "  OK Rewrote use-trait local alias to point to .all-traits.<path-alias>" -ForegroundColor Green
    }

    # Special case: legacy alias 'nft-trait' -> centralized sip-009-nft-trait
    $legacyNftRegex = "\(use-trait\s+nft-trait\s+\.nft-trait\.nft-trait\)"
    if ($content -match $legacyNftRegex) {
        $content = $content -replace $legacyNftRegex, "(use-trait sip-009-nft-trait .all-traits.sip-009-nft-trait)"
        $fileFixCount++
        Write-Host "  OK Rewrote legacy nft-trait alias to sip-009-nft-trait" -ForegroundColor Green
    }

    # DISABLED: explicit-principal rewrites (breaks Clarinet parsing and SDK rules)
    # Keeping block for reference but not executing.
    if ($false) {
        $allTraitsPrincipal = "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"
        if ($File.FullName -notmatch "all-traits\.clar$") {
            $useTraitRelRegex = "\(use-trait\s+([a-zA-Z0-9\-]+)\s+\.all-traits\.([a-zA-Z0-9\-]+)\)"
            $implTraitRelRegex = "\(impl-trait\s+\.all-traits\.([a-zA-Z0-9\-]+)\)"
            if ($content -match $useTraitRelRegex) {
                $content = [regex]::Replace($content, $useTraitRelRegex, "(use-trait $1 '$allTraitsPrincipal .all-traits.$2)")
                $fileFixCount++
            }
            if ($content -match $implTraitRelRegex) {
                $content = [regex]::Replace($content, $implTraitRelRegex, "(impl-trait '$allTraitsPrincipal .all-traits.$1)")
                $fileFixCount++
            }
        }
    }

    # CLEANUP: remove any corrupted explicit-principal trait lines produced earlier
    $linesArr = $content -split "`n"
    $beforeCount = $linesArr.Length
    $linesArr = $linesArr | Where-Object { $_ -notmatch '^\s*\(use-trait\s+ST[A-Z0-9]+' -and $_ -notmatch '^\s*\(impl-trait\s+ST[A-Z0-9]+' }
    $afterCount = $linesArr.Length
    if ($afterCount -lt $beforeCount) {
        $content = ($linesArr -join "`n")
        $fileFixCount += ($beforeCount - $afterCount)
        Write-Host "  OK Removed corrupted explicit-principal lines" -ForegroundColor Green
    }
    
    # REMOVE alias-less use-trait lines: (use-trait  .all-traits.)
    $useTraitAliasless = "(?m)^\s*\(use-trait\s+\.all-traits\.\s*\)\s*$"
    if ($content -match $useTraitAliasless) {
        $content = [regex]::Replace($content, $useTraitAliasless, "")
        $fileFixCount++
        Write-Host "  OK Removed alias-less use-trait line" -ForegroundColor Green
    }
    
    # REPAIR: lines like "(use-trait alias .all-traits.)" (missing trait identifier)
    $useTraitMissingTrait = "(?m)^\s*\(use-trait\s+([a-zA-Z0-9\-]+)\s+\.all-traits\.\s*\)\s*$"
    if ($content -match $useTraitMissingTrait) {
        $content = [regex]::Replace($content, $useTraitMissingTrait, "(use-trait $1 .all-traits.$1)")
        $fileFixCount++
        Write-Host "  OK Repaired missing trait identifier in use-trait" -ForegroundColor Green
    }
    
    # CLEAN: remove malformed impl-trait with missing identifier "(impl-trait .all-traits.)"
    $implMissingTrait = "(?m)^\s*\(impl-trait\s+\.all-traits\.\s*\)\s*$"
    if ($content -match $implMissingTrait) {
        $content = [regex]::Replace($content, $implMissingTrait, "")
        $fileFixCount++
        Write-Host "  OK Removed malformed impl-trait missing identifier" -ForegroundColor Green
    }
    
    # =========================================================================
    # FIX 2: Remove duplicate use-trait declarations
    # =========================================================================
    
    # Find and remove duplicate use-trait lines
    $lines = $content -split "`n"
    $seenTraits = @{}
    $newLines = @()
    $removedDuplicates = 0
    
    foreach ($line in $lines) {
        if ($line -match '^\s*\(use-trait\s+(\S+)\s+') {
            $traitName = $Matches[1]
            if ($seenTraits.ContainsKey($traitName)) {
                $removedDuplicates++
                Write-Host "  OK Removed duplicate use-trait for $traitName" -ForegroundColor Green
                continue
            }
            $seenTraits[$traitName] = $true
        }
        $newLines += $line
    }
    
    if ($removedDuplicates -gt 0) {
        $content = $newLines -join "`n"
        $fileFixCount += $removedDuplicates
    }
    
    # =========================================================================
    # FIX 3: Fix impl-trait statements
    # =========================================================================
    
    # Pattern: (impl-trait trait-name)
    # Fix to: (impl-trait .all-traits.trait-name)
    
    foreach ($pattern in $traitPatterns) {
        # Only fix if it's just the trait name without a path
        $regex = "\(impl-trait\s+$($pattern.Name)\s*\)"
        if ($content -match $regex) {
            $content = $content -replace $regex, "(impl-trait $($pattern.New))"
            $fileFixCount++
            Write-Host "  OK Fixed impl-trait for $($pattern.Name)" -ForegroundColor Green
        }
    }

    # Generic impl-trait fallback: (impl-trait alias) -> (impl-trait .all-traits.alias)
    # Only replace when corresponding use-trait exists to avoid false positives
    $implGeneric = "\(impl-trait\s+([a-zA-Z0-9\-]+)\s*\)"
    if ($content -match $implGeneric) {
        $content = [regex]::Replace($content, $implGeneric, {
            param($m)
            $alias = $m.Groups[1].Value
            $hasUse = [regex]::IsMatch($content, "\(use-trait\s+$alias\s+\.all\-traits\.$alias\)")
            if ($hasUse) { return "(impl-trait .all-traits.$alias)" } else { return $m.Value }
        })
        # We can't accurately count per-replacement here; conservative increment
        $fileFixCount++
        Write-Host "  OK Applied generic impl-trait fallback where matching use-trait exists" -ForegroundColor Green
    }

    # =========================================================================
    # FIX 4b: Ensure missing use-trait lines exist when trait types or impls are used
    # =========================================================================
    foreach ($pattern in $traitPatterns) {
        $typeUsageRegex = "<" + [regex]::Escape($pattern.Name) + ">"
        $implUsageRegex = "\(impl-trait\s+" + [regex]::Escape($pattern.New) + "\)"
        $useTraitExistsRegex = "\(use-trait\s+" + [regex]::Escape($pattern.Name) + "\s+" + [regex]::Escape($pattern.New) + "\)"

        $usesTrait = ($content -match $typeUsageRegex) -or ($content -match $implUsageRegex)
        $hasUseTrait = ($content -match $useTraitExistsRegex)

        if ($usesTrait -and -not $hasUseTrait) {
            # Prepend canonical use-trait line
            $content = "(use-trait $($pattern.Name) $($pattern.New))`n" + $content
            $fileFixCount++
            Write-Host "  OK Inserted missing use-trait for $($pattern.Name)" -ForegroundColor Green
        }
    }
    
    # =========================================================================
    # FIX 5: Remove any remaining quote syntax in trait references
    # =========================================================================
    
    if ($content -match "'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.\S+") {
        $pattern = @'
'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.([^\.\s]+)\.([^\.\s]+)
'@
        $replacement = '.all-traits.$2'
        $content = $content -replace $pattern, $replacement
        $fileFixCount++
        Write-Host "  OK Removed hardcoded principal quotes" -ForegroundColor Green
    }
    
    # =========================================================================
    # FIX 6: Fix contract references to use relative paths
    # =========================================================================
    
    # Fix references like .trait-registry to contracts that exist
    $contractRefs = @(
        @{Name="trait-registry"; Path=".trait-registry"},
        @{Name="circuit-breaker"; Path=".circuit-breaker"},
        @{Name="fee-manager"; Path=".fee-manager"}
    )
    
    # This is informational only - these need to be reviewed manually
    foreach ($ref in $contractRefs) {
        if ($content -match "\.$($ref.Name)\b") {
            Write-Host "  Info: Found reference to $($ref.Name) - verify this contract exists" -ForegroundColor DarkYellow
        }
    }

    # =========================================================================
    # FIX 7: Special-case alias normalization - ft-trait -> sip-010-ft-trait
    # =========================================================================
    # (use-trait ft-trait .sip-010-ft-trait.sip-010-ft-trait) => (use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
    $ftAliasUse = "\(use-trait\s+ft-trait\s+\.sip-010-ft-trait\.sip-010-ft-trait\)"
    if ($content -match $ftAliasUse) {
        $content = $content -replace $ftAliasUse, "(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)"
        $fileFixCount++
        Write-Host "  OK Normalized ft-trait alias to sip-010-ft-trait" -ForegroundColor Green
    }
    # Replace type usages <ft-trait> -> <sip-010-ft-trait>
    $ftType = "<ft-trait>"
    if ($content -match [regex]::Escape($ftType)) {
        $content = $content -replace [regex]::Escape($ftType), "<sip-010-ft-trait>"
        $fileFixCount++
        Write-Host "  OK Normalized type <ft-trait> to <sip-010-ft-trait>" -ForegroundColor Green
    }
    
    # =========================================================================
    # Save changes if any fixes were made
    # =========================================================================
    
    if ($content -ne $originalContent) {
        if (-not $ReportOnly) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
        }
        $FileCount++
        $FixCount += $fileFixCount
        Write-Host "  Saved $fileFixCount fixes to $($file.Name)" -ForegroundColor Cyan
    } else {
        Write-Host "  No changes needed" -ForegroundColor DarkGray
    }

    # Accumulate per-file issues for the final report
    if ($fileIssues.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            File = $file.FullName
            Issues = $fileIssues
        }
    }
    
    Write-Host ""
}

# =========================================================================
# Summary Report
# =========================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Files Processed: $($contractFiles.Count)" -ForegroundColor White
Write-Host "Files Modified: $FileCount" -ForegroundColor Green
Write-Host "Total Fixes Applied: $FixCount" -ForegroundColor Green
Write-Host "Unknown Trait Aliases Detected: $ErrorCount" -ForegroundColor Yellow
Write-Host ""

# =========================================================================
# MANIFEST ALIGNMENT (multi-file): Ensure .all-traits presence, principal alignment (ST3), and repair bad paths
# =========================================================================

function Get-RelativePath([string]$fromDir, [string]$toPath) {
    try {
        $fromUri = New-Object System.Uri((Resolve-Path -LiteralPath $fromDir))
        $toUri = New-Object System.Uri((Resolve-Path -LiteralPath $toPath))
        $rel = $fromUri.MakeRelativeUri($toUri).ToString() -replace '%20',' '
        # Clarinet TOML paths prefer forward slashes
        return ($rel -replace '\\','/')
    } catch {
        return $toPath
    }
}

function Align-Manifest {
    param(
        [string]$ManifestPath,
        [string]$CanonicalPrincipal,
        [switch]$EnforceAddresses
    )

    $result = [ordered]@{ ManifestPath = $ManifestPath; AddressFixes = 0; PathFixes = 0; AddedAllTraits = $false }
    if (-not (Test-Path $ManifestPath)) { return $result }

    try {
        $manifestDir = Split-Path -Parent (Resolve-Path -LiteralPath $ManifestPath)
    } catch {
        $manifestDir = (Get-Location).Path
    }
    $manifestContent = Get-Content $ManifestPath -Raw
    $originalManifest = $manifestContent

    # Ensure [contracts.all-traits] block exists; if missing, insert with correct relative path
    if ($manifestContent -notmatch '(?m)^\[contracts\.all-traits\]') {
        $traitsAbs = Join-Path (Get-Location) "contracts/traits/all-traits.clar"
        $relPath = Get-RelativePath -fromDir $manifestDir -toPath $traitsAbs
        $insert = "`n[contracts.all-traits]`npath = `"$relPath`"`nclarity_version = 3`nepoch = `"3.0`"`n"
        $manifestContent = $insert + $manifestContent
        $result.AddedAllTraits = $true
    }

    # If enforcing addresses, ensure [contracts.all-traits] uses ST3 principal and add ST3 address to any missing
    if ($EnforceAddresses) {
        $manifestContent = [regex]::Replace($manifestContent,
            '(?ms)^(\[contracts\.all-traits\]\s*(?:.*?\r?\n)*)',
            {
                param($m)
                $block = $m.Groups[1].Value
                if ($block -notmatch '(?m)^\s*address\s*=\s*"') {
                    $result.AddressFixes++
                    return ($block + ("address = `"$CanonicalPrincipal.all-traits`"`n"))
                } else {
                    if ($block -match '(?m)^\s*address\s*=\s*"(ST[0-9A-Z]+)\.all-traits"') {
                        $addr = $Matches[1]
                        if ($addr -ne $CanonicalPrincipal) {
                            $result.AddressFixes++
                            $block = [regex]::Replace($block, '(?m)^\s*address\s*=\s*".*?"', ("address = `"$CanonicalPrincipal.all-traits`""))
                        }
                    }
                    return $block
                }
            },
            1)

        # Add ST3 address to any [contracts.*] blocks missing it to prevent ST1 defaults
        $contractsRegex = New-Object System.Text.RegularExpressions.Regex("(?ms)^(\[contracts\.(?<name>[^\]]+)\])\s*(?<body>.*?)(?=^\[contracts\.|\Z)")
        $sb = New-Object System.Text.StringBuilder
        $lastIndex = 0
        foreach ($m in $contractsRegex.Matches($manifestContent)) {
            $sb.Append($manifestContent.Substring($lastIndex, $m.Index - $lastIndex)) | Out-Null
            $name = $m.Groups['name'].Value
            $body = $m.Groups['body'].Value
            $block = $m.Value
            if ($body -notmatch '(?m)^\s*address\s*=\s*"') {
                $addrLine = "address = `"$CanonicalPrincipal.$name`""
                $newBody = ($body.TrimEnd() + "`n" + $addrLine + "`n")
                $block = "[contracts.$name]`n" + $newBody
                $result.AddressFixes++
            } else {
                # Sanitize to canonical principal (remove any .contract suffix or wrong principal)
                $body = [regex]::Replace($body, '(?mi)^\s*address\s*=\s*"ST[0-9A-Z]+(?:\.[A-Za-z0-9\-]+)?"', ("address = `"$CanonicalPrincipal.$name`""))
                $block = "[contracts.$name]`n" + $body
            }
            $sb.Append($block) | Out-Null
            $lastIndex = $m.Index + $m.Length
        }
        $sb.Append($manifestContent.Substring($lastIndex)) | Out-Null
        $manifestContent = $sb.ToString()
    }

    # Repair any missing paths by searching repository
    $repoRoot = (Get-Location).Path
    $contractsBlockRegex = New-Object System.Text.RegularExpressions.Regex("(?ms)^(\[contracts\.(?<name>[^\]]+)\])\s*(?<body>.*?)(?=^\[contracts\.|\Z)")
    $pathRegex = New-Object System.Text.RegularExpressions.Regex('(?m)^\s*path\s*=\s*"(?<path>[^"]+)"')
    $sb2 = New-Object System.Text.StringBuilder
    $lastIndex2 = 0
    foreach ($m in $contractsBlockRegex.Matches($manifestContent)) {
        $sb2.Append($manifestContent.Substring($lastIndex2, $m.Index - $lastIndex2)) | Out-Null
        $name = $m.Groups['name'].Value
        $body = $m.Groups['body'].Value
        $block = $m.Value
        $pathMatch = $pathRegex.Match($body)
        if ($pathMatch.Success) {
            $origPath = $pathMatch.Groups['path'].Value
            if ([string]::IsNullOrWhiteSpace($origPath)) {
                Write-Host "Manifest: Empty path for contracts.$name" -ForegroundColor Yellow
                $sb2.Append($block) | Out-Null
                $lastIndex2 = $m.Index + $m.Length
                continue
            }
            $absOrig = if ([IO.Path]::IsPathRooted($origPath)) { $origPath } else { Join-Path $manifestDir $origPath }
            $exists = Test-Path -LiteralPath $absOrig
            if (-not $exists) {
                $leaf = Split-Path -Path $origPath -Leaf
                $candidates = Get-ChildItem -Path (Join-Path $repoRoot '.') -Filter $leaf -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.clar' }
                if ($candidates.Count -eq 1) {
                    $full = $candidates[0].FullName
                    $rel = Get-RelativePath -fromDir $manifestDir -toPath $full
                    $newBody = [regex]::Replace($body, '(?m)^\s*path\s*=\s*"[^"]+"', ("path = `"$rel`""))
                    $block = "[contracts.$name]`n" + $newBody
                    $result.PathFixes++
                } elseif ($candidates.Count -gt 1) {
                    $pref = $candidates | Where-Object { $_.FullName -like "*$([IO.Path]::DirectorySeparatorChar)contracts$([IO.Path]::DirectorySeparatorChar)*" }
                    if ($pref.Count -ge 1) {
                        $full = $pref[0].FullName
                        $rel = Get-RelativePath -fromDir $manifestDir -toPath $full
                        $newBody = [regex]::Replace($body, '(?m)^\s*path\s*=\s*"[^"]+"', ("path = `"$rel`""))
                        $block = "[contracts.$name]`n" + $newBody
                        $result.PathFixes++
                    } else {
                        Write-Host "Manifest: Multiple candidates for $name ($leaf), manual review needed" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Manifest: Missing file for $name at '$origPath' not found in repo" -ForegroundColor Yellow
                }
            } else {
                # Normalize to relative forward-slash path if currently absolute/backslash
                if ($origPath -match '^[A-Za-z]:\\' -or $origPath -match '\\') {
                    $resolved = (Resolve-Path -LiteralPath $absOrig).Path
                    if ($resolved.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $rel = $resolved.Substring($repoRoot.Length + 1) -replace '\\','/'
                    } else {
                        $rel = Get-RelativePath -fromDir $manifestDir -toPath $resolved
                    }
                    $newBody = [regex]::Replace($body, '(?m)^\s*path\s*=\s*"[^"]+"', ("path = `"$rel`""))
                    $block = "[contracts.$name]`n" + $newBody
                    $result.PathFixes++
                }
            }
        } else {
            Write-Host "Manifest: No path entry for contracts.$name" -ForegroundColor Yellow
        }
        $sb2.Append($block) | Out-Null
        $lastIndex2 = $m.Index + $m.Length
    }
    $sb2.Append($manifestContent.Substring($lastIndex2)) | Out-Null
    $newManifest = $sb2.ToString()

    if ($newManifest -ne $originalManifest) {
        if (-not $ReportOnly) {
            Set-Content -Path $ManifestPath -Value $newManifest -NoNewline
        }
        Write-Host "Manifest fixes applied to ${ManifestPath}: $($result.AddressFixes) address, $($result.PathFixes) paths, AddedAllTraits=$($result.AddedAllTraits)" -ForegroundColor Cyan
    } else {
        Write-Host "Manifest alignment: no changes needed for ${ManifestPath}" -ForegroundColor DarkGray
    }

    return $result
}

$CanonicalPrincipal = "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"
$manifestResults = @()
$manifestResults += Align-Manifest -ManifestPath "Clarinet.toml" -CanonicalPrincipal $CanonicalPrincipal -EnforceAddresses
$manifestResults += Align-Manifest -ManifestPath "stacks/Clarinet.test.toml" -CanonicalPrincipal $CanonicalPrincipal -EnforceAddresses # enforce addresses in tests too
$manifestResults += Align-Manifest -ManifestPath "stacks/Clarinet.toml" -CanonicalPrincipal $CanonicalPrincipal      # deprecated, but repair paths

# Ensure referenced contracts discovered in code are present in root Clarinet.toml
function Ensure-Referenced-Contracts-In-Manifest {
    param(
        [string]$ManifestPath,
        [System.Collections.Generic.HashSet[string]]$Refs,
        [string]$CanonicalPrincipal
    )
    if (-not (Test-Path $ManifestPath)) { return @{ Added = @(); Missing = @() } }
    $manifestDir = Split-Path -Parent $ManifestPath
    $content = Get-Content $ManifestPath -Raw
    $added = @()
    $missing = @()
    foreach ($name in $Refs) {
        if ($name -eq 'all-traits') { continue }
        if ($content -match "(?m)^\[contracts\.$([regex]::Escape($name))\]") { continue }
        # Skip if any block already references a path ending with /<name>.clar
        if ($content -match "(?m)^\s*path\s*=\s*\"[^\"]*[/\\]$([regex]::Escape($name))\.clar\"") { continue }
        # Find file named <name>.clar under contracts/
        $cands = Get-ChildItem -Path "contracts" -Filter "$name.clar" -Recurse -ErrorAction SilentlyContinue
        if ($cands.Count -eq 1) {
            $full = $cands[0].FullName
            $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $full)
            $block = "`n[contracts.$name]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal.$name`"`n"
            $content += $block
            $added += @{ name = $name; path = $rel }
        } elseif ($cands.Count -gt 1) {
            # Prefer path under contracts/<name>.clar exact match if exists
            $pref = $cands | Where-Object { $_.FullName -like "*\contracts\$name.clar" }
            if ($pref.Count -eq 1) {
                $full = $pref[0].FullName
                $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $full)
                $block = "`n[contracts.$name]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal.$name`"`n"
                $content += $block
                $added += @{ name = $name; path = $rel }
            } else {
                $missing += $name
            }
        } else {
            $missing += $name
        }
    }
    if ($added.Count -gt 0) { Set-Content -Path $ManifestPath -Value $content -NoNewline }
    return @{ Added = $added; Missing = $missing }
}

# Ensure every contract file under contracts/ (excluding traits/) exists in the manifest with correct path and address
function Sync-Manifest-With-Contracts {
    param(
        [string]$ManifestPath,
        [string]$CanonicalPrincipal,
        [switch]$RenameBlocks
    )
    $result = [ordered]@{ Added=0; Renamed=0; UpdatedPaths=0 }
    if (-not (Test-Path $ManifestPath)) { return $result }
    $manifestDir = Split-Path -Parent (Resolve-Path -LiteralPath $ManifestPath)
    $content = Get-Content $ManifestPath -Raw
    $contracts = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "\\traits\\" }
    foreach ($cf in $contracts) {
        $basename = [IO.Path]::GetFileNameWithoutExtension($cf.Name)
        # If a block exists by name, ensure path and address
        $sectionRegex = "(?ms)^(\[contracts\.$([regex]::Escape($basename))\])\s*(?<body>.*?)(?=^\[contracts\.|\Z)"
        if ($content -match $sectionRegex) {
            $body = $Matches['body']
            $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $cf.FullName)
            # path
            if ($body -notmatch "(?m)^\s*path\s*=\s*\"[^"]*\Q$rel\E\"") {
                $newBody = [regex]::Replace($body, '(?m)^\s*path\s*=\s*"[^"]+"', ("path = `"$rel`""))
                if ($newBody -ne $body) { $body = $newBody; $result.UpdatedPaths++ }
            }
            # address
            $addrLine = "address = `"$CanonicalPrincipal.$basename`""
            if ($body -notmatch '(?m)^\s*address\s*=\s*"') {
                $body = ($body.TrimEnd() + "`n" + $addrLine + "`n")
            } else {
                $body = [regex]::Replace($body, '(?mi)^\s*address\s*=\s*"ST[0-9A-Z]+(?:\.[A-Za-z0-9\-]+)?"', ("address = `"$CanonicalPrincipal.$basename`""))
            }
            $content = [regex]::Replace($content, $sectionRegex, "[contracts.$basename]`n" + $body)
        } else {
            # Add a new section
            $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $cf.FullName)
            $block = "`n[contracts.$basename]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal.$basename`"`n"
            $content += $block
            $result.Added++
        }
    }
    if ($RenameBlocks) {
        # Rename blocks where header name != basename for their path target
        $contractsBlockRegex = New-Object System.Text.RegularExpressions.Regex("(?ms)^(\[contracts\.(?<name>[^\]]+)\])\s*(?<body>.*?)(?=^\[contracts\.|\Z)")
        $sb = New-Object System.Text.StringBuilder
        $lastIndex = 0
        foreach ($m in $contractsBlockRegex.Matches($content)) {
            $sb.Append($content.Substring($lastIndex, $m.Index - $lastIndex)) | Out-Null
            $name = $m.Groups['name'].Value
            $body = $m.Groups['body'].Value
            $pathMatch = [regex]::Match($body, '(?m)^\s*path\s*=\s*"([^"]+)"')
            $block = $m.Value
            if ($pathMatch.Success) {
                $p = $pathMatch.Groups[1].Value
                $bn = [IO.Path]::GetFileNameWithoutExtension($p)
                if ($bn -and ($bn -ne $name)) {
                    $block = "[contracts.$bn]`n" + $body
                    # fix address suffix as well
                    $block = [regex]::Replace($block, '(?mi)^\s*address\s*=\s*"ST[0-9A-Z]+(?:\.[A-Za-z0-9\-]+)?"', ("address = `"$CanonicalPrincipal.$bn`""))
                    $result.Renamed++
                }
            }
            $sb.Append($block) | Out-Null
            $lastIndex = $m.Index + $m.Length
        }
        $sb.Append($content.Substring($lastIndex)) | Out-Null
        $content = $sb.ToString()
    }
    Set-Content -Path $ManifestPath -Value $content -NoNewline
    return $result
}

$refResults = Ensure-Referenced-Contracts-In-Manifest -ManifestPath "Clarinet.toml" -Refs $ReferencedContracts -CanonicalPrincipal $CanonicalPrincipal

# Optionally, sync all contract files into Clarinet.toml
$syncResults = $null
if ($SyncContracts) {
    $syncResults = Sync-Manifest-With-Contracts -ManifestPath "Clarinet.toml" -CanonicalPrincipal $CanonicalPrincipal -RenameBlocks:$RenameBlocks
}

if ($FileCount -gt 0) {
    Write-Host "Trait import fixes complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Run: clarinet check" -ForegroundColor White
    Write-Host "2. Review error count reduction" -ForegroundColor White
} else {
    Write-Host "Info: No changes were needed" -ForegroundColor Yellow
}

# Write JSON report if requested
try {
    $report = [PSCustomObject]@{
        FilesProcessed = $contractFiles.Count
        FilesModified  = $FileCount
        TotalFixes     = $FixCount
        UnknownTraitAliases = $ErrorCount
        Issues = $Issues
        ManifestResults = $manifestResults
        ReferencedContracts = @{
            Collected = $ReferencedContracts
            Added = $refResults.Added
            Missing = $refResults.Missing
        }
        SyncResults = $syncResults
    }
    if ($ReportJsonPath) {
        $report | ConvertTo-Json -Depth 6 | Set-Content -Path $ReportJsonPath -Encoding UTF8
        Write-Host "Report written to $ReportJsonPath" -ForegroundColor DarkCyan
    }
} catch {
    Write-Host "Warning: Failed to write report JSON: $_" -ForegroundColor Yellow
}

Write-Host ""
