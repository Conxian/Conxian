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
    $traitDefsMatches = [regex]::Matches($allTraitsContent, $defineTraitRegex)
    foreach ($m in $traitDefsMatches) { $AllTraits[$m.Groups[1].Value] = $true }
    Write-Host "Loaded $($AllTraits.Keys.Count) centralized trait definitions from all-traits.clar" -ForegroundColor DarkCyan
} else {
    Write-Host "Warning: $allTraitsPath not found; trait validation skipped" -ForegroundColor Yellow
}

# Collect issues for final reporting
$Issues = @()
# Track referenced contracts discovered from dotted references like .trait-registry
$ReferencedContracts = New-Object System.Collections.Generic.HashSet[string]
# Track globally used trait aliases from code for all-traits coverage verification
$GlobalUsedTraits = New-Object System.Collections.Generic.HashSet[string]
# Ignore set to avoid false positives from file extensions or common tokens
$IgnoredRefNames = New-Object System.Collections.Generic.HashSet[string]
[void]$IgnoredRefNames.Add('clar')
[void]$IgnoredRefNames.Add('self')
[void]$IgnoredRefNames.Add('io')
[void]$IgnoredRefNames.Add('utils')
[void]$IgnoredRefNames.Add('math')
[void]$IgnoredRefNames.Add('SBTC-MAINNET')

# Special mapping for known test mocks or aliases
$SpecialRefMap = @{
    'token-a' = 'tests/mocks/test-token-a.clar'
    'token-b' = 'tests/mocks/test-token-b.clar'
}

# Optional external alias map (JSON object: { "alias": "relative/path.clar", ... })
$ExternalRefMapPath = "scripts/ref-alias-map.json"
$ExternalRefPathMap = @{}
if (Test-Path $ExternalRefMapPath) {
    try {
        $json = Get-Content -Path $ExternalRefMapPath -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($null -ne $json) {
            foreach ($prop in $json.PSObject.Properties) {
                if ($prop.Value -and ([string]$prop.Value).Trim().Length -gt 0) {
                    $ExternalRefPathMap[$prop.Name] = [string]$prop.Value
                }
            }
        }
    } catch {
        Write-Host ("Warning: Failed to parse {0}: {1}" -f $ExternalRefMapPath, $_) -ForegroundColor Yellow
    }
}

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
    foreach ($alias in $detectedAliases) { [void]$GlobalUsedTraits.Add($alias) }

    # Discover dotted contract references: .contract-name (exclude .all-traits.* and known trait aliases)
    # Avoid dots inside strings/paths: negative lookbehind for ., ", ', /, \
    $dotRefRegex = '(?<![\.''"/\\])\.([a-zA-Z][a-zA-Z0-9\-]+)\b'
    $dotMatches = [regex]::Matches($content, $dotRefRegex)
    foreach ($d in $dotMatches) {
        $ref = $d.Groups[1].Value
        if ($ref -ne 'all-traits' -and -not $AllTraits.ContainsKey($ref) -and -not $IgnoredRefNames.Contains($ref)) {
            [void]$ReferencedContracts.Add($ref)
        }

    # Also scan test clarity files for dotted references
    $testFiles = @()
    if (Test-Path "tests") { $testFiles = Get-ChildItem -Path "tests" -Filter "*.clar" -Recurse -ErrorAction SilentlyContinue }
    foreach ($tfile in $testFiles) {
        $tcontent = Get-Content $tfile.FullName -Raw
        # strip line comments '; ...' to reduce false positives
        $tcontent = ($tcontent -replace '(?m);.*$','')
        $dotRefRegexTests = '(?<![\.''"/\\])\.([a-zA-Z][a-zA-Z0-9\-]+)\b'
        $tdots = [regex]::Matches($tcontent, $dotRefRegexTests)
        foreach ($d in $tdots) {
            $ref = $d.Groups[1].Value
            if ($ref -ne 'all-traits' -and -not $AllTraits.ContainsKey($ref) -and -not $IgnoredRefNames.Contains($ref)) {
                [void]$ReferencedContracts.Add($ref)
            }
        }
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
        $allTraitsPrincipal = "STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ"
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
    
    if ($content -match "'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.\S+") {
        $pattern = @'
'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.([^\.\s]+)\.([^\.\s]+)
'@
        $replacement = '.all-traits.$2'
        $content = $content -replace $pattern, $replacement
        $fileFixCount++
        Write-Host "  OK Removed hardcoded principal quotes" -ForegroundColor Green
    }
    
    # =========================================================================
    # FIX 6: Fix contract references to use relative paths
    # =========================================================================
    
    # Dotted contract references are collected earlier into $ReferencedContracts; manifest verification occurs later.

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
        try {
            # Fallback to .NET relative path computation
            $rel2 = [IO.Path]::GetRelativePath((Resolve-Path -LiteralPath $fromDir), (Resolve-Path -LiteralPath $toPath))
            return ($rel2 -replace '\\','/')
        } catch {
            return ($toPath -replace '\\','/')
        }
    }
}

function Align-Manifest {
    param(
        [string]$ManifestPath,
        [string]$CanonicalPrincipal,
        [switch]$EnforceAddresses
    )

    $result = [ordered]@{ ManifestPath = $ManifestPath; AddressFixes = 0; PathFixes = 0; AddedAllTraits = $false }
    $removedNames = New-Object System.Collections.Generic.HashSet[string]
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

    # Deduplicate duplicate [contracts.*] tables: keep the last occurrence per contract name
    $contractsBlockRegex = New-Object System.Text.RegularExpressions.Regex("(?ms)^(\[contracts\.(?<name>[^\]]+)\])\s*(?<body>.*?)(?=^\[contracts\.|\Z)")
    $matches = $contractsBlockRegex.Matches($manifestContent)
    if ($matches.Count -gt 0) {
        $lastBlockByName = @{}
        foreach ($m in $matches) {
            $n = $m.Groups['name'].Value
            $cur = $m.Value
            $curPathMatch = [regex]::Match($cur, '(?m)^\s*path\s*=\s*"([^"]+)"')
            $curPath = if ($curPathMatch.Success) { $curPathMatch.Groups[1].Value } else { '' }
            if ($lastBlockByName.ContainsKey($n)) {
                $prev = $lastBlockByName[$n]
                $prevPathMatch = [regex]::Match($prev, '(?m)^\s*path\s*=\s*"([^"]+)"')
                $prevPath = if ($prevPathMatch.Success) { $prevPathMatch.Groups[1].Value } else { '' }
                $isTopCur = ($curPath -eq ("contracts/$n.clar"))
                $isTopPrev = ($prevPath -eq ("contracts/$n.clar"))
                $isContractsCur = ($curPath -like 'contracts/*')
                $isContractsPrev = ($prevPath -like 'contracts/*')
                if ($isTopCur -and -not $isTopPrev) {
                    $lastBlockByName[$n] = $cur
                } elseif (-not $isContractsPrev -and $isContractsCur) {
                    $lastBlockByName[$n] = $cur
                } else {
                    # keep existing (prefer previous canonical or last if equal)
                    $lastBlockByName[$n] = $prev
                }
            } else {
                $lastBlockByName[$n] = $cur
            }
        }
        $sbDedup = New-Object System.Text.StringBuilder
        $used = New-Object System.Collections.Generic.HashSet[string]
        $lastIndexD = 0
        foreach ($m in $matches) {
            $sbDedup.Append($manifestContent.Substring($lastIndexD, $m.Index - $lastIndexD)) | Out-Null
            $n = $m.Groups['name'].Value
            if (-not $used.Contains($n)) {
                $sbDedup.Append($lastBlockByName[$n]) | Out-Null
                [void]$used.Add($n)
            }
            $lastIndexD = $m.Index + $m.Length
        }
        $sbDedup.Append($manifestContent.Substring($lastIndexD)) | Out-Null
        $manifestContent = $sbDedup.ToString()
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
                    return ($block + ("address = `"$CanonicalPrincipal`"`n"))
                } else {
                    # Normalize any address (with or without suffix) to principal-only
                    $block = [regex]::Replace($block, '(?mi)^\s*address\s*=\s*"ST[0-9A-Z]+(?:\.[A-Za-z0-9\-]+)?"', ("address = `"$CanonicalPrincipal`""))
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
                $addrLine = "address = `"$CanonicalPrincipal`""
                $newBody = ($body.TrimEnd() + "`n" + $addrLine + "`n")
                $block = "[contracts.$name]`n" + $newBody
                $result.AddressFixes++
            } else {
                # Sanitize to canonical principal (remove any .contract suffix or wrong principal)
                $body = [regex]::Replace($body, '(?mi)^\s*address\s*=\s*"ST[0-9A-Z]+(?:\.[A-Za-z0-9\-]+)?"', ("address = `"$CanonicalPrincipal`""))
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
                    # File not found anywhere. If it looks like a trait placeholder (e.g., sip-010-trait), prune the block and rewrite depends_on later
                    if (($name -ne 'all-traits') -and ($name -match '(^sip-010-trait$)|(^.+-trait$)')) {
                        Write-Host "Manifest: Pruning missing trait block contracts.$name (path '$origPath')" -ForegroundColor Yellow
                        [void]$removedNames.Add($name)
                        $block = ''
                    } else {
                        Write-Host "Manifest: Missing file for $name at '$origPath' not found in repo" -ForegroundColor Yellow
                    }
                }
            } else {
                # Normalize to relative forward-slash path if currently absolute/backslash
                if ($origPath -match '^[A-Za-z]:\\' -or $origPath -match '\\') {
                    $resolved = (Resolve-Path -LiteralPath $absOrig).Path
                    $rel = Get-RelativePath -fromDir $manifestDir -toPath $resolved
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
    # Rewrite depends_on entries: replace any pruned names with all-traits and dedupe items
    if ($removedNames.Count -gt 0) {
        foreach ($rn in $removedNames) {
            $newManifest = $newManifest -replace ('"' + [regex]::Escape($rn) + '"'), '"all-traits"'
        }
        $newManifest = [regex]::Replace($newManifest, '(?ms)^\s*depends_on\s*=\s*\[(?<items>[^\]]*)\]', {
            param($me)
            $items = $me.Groups['items'].Value
            $parts = @()
            if ($items.Trim().Length -gt 0) { $parts = $items -split ',' }
            $seen = @{}
            $out = @()
            foreach ($p in $parts) {
                $n = ($p.Trim() -replace '^"', '' -replace '"$', '')
                if ([string]::IsNullOrWhiteSpace($n)) { continue }
                if (-not $seen.ContainsKey($n)) { $seen[$n] = $true; $out += $n }
            }
            $joined = ($out | ForEach-Object { '"' + $_ + '"' }) -join ', '
            return "depends_on = [${joined}]"
        })
    }
    # Strip accidental repo folder prefix (e.g., 'Conxian/contracts/...') to canonical 'contracts/...'
    $repoLeafEsc = [regex]::Escape((Split-Path $repoRoot -Leaf))
    $newManifest = [regex]::Replace($newManifest, '(?m)^\s*path\s*=\s*"' + $repoLeafEsc + '/(contracts/[^"\r\n]+)"', 'path = "$1"')
    # Sanitize all path lines: convert backslashes to forward slashes, and collapse any leading prefix before contracts/ or tests/
    $newManifest = [regex]::Replace($newManifest, '(?m)^\s*path\s*=\s*"([^"]+)"', {
        param($me)
        $p = $me.Groups[1].Value
        $canon = ($p -replace '\\','/')
        # reduce to repo-relative when possible
        $canon = [regex]::Replace($canon, '.*?((?:contracts|tests)/[^"\r\n]+)$', '$1')
        return 'path = "' + $canon + '"'
    })

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

$CanonicalPrincipal = "STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ"
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
        $nameEsc = [regex]::Escape($name)
        $hdrPat = '(?m)^\[contracts\.' + $nameEsc + '\]'
        if ($content -match $hdrPat) { continue }
        # Skip if any block already references a path ending with /<name>.clar
        $pathPat = '(?m)^\s*path\s*=\s*"[^"]*[/\\]' + $nameEsc + '\.clar"'
        if ($content -match $pathPat) { continue }
        # Prefer special mapping when available
        if ($SpecialRefMap.ContainsKey($name)) {
            $mapped = $SpecialRefMap[$name]
            if (Test-Path -LiteralPath $mapped) {
                $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $mapped)
                $block = "`n[contracts.$name]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal`"`n"
                $content += $block
                $added += @{ name = $name; path = $rel }
                continue
            }
        }
        # Prefer external alias mapping when available
        if ($ExternalRefPathMap.ContainsKey($name)) {
            $mappedRel = $ExternalRefPathMap[$name]
            $mappedAbs = if ([IO.Path]::IsPathRooted($mappedRel)) { $mappedRel } else { Join-Path (Get-Location) $mappedRel }
            if (Test-Path -LiteralPath $mappedAbs) {
                $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $mappedAbs)
                $block = "`n[contracts.$name]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal`"`n"
                $content += $block
                $added += @{ name = $name; path = $rel }
                continue
            }
        }
        # Find best file for <name> across repo (contracts and tests)
        $cands = Get-ChildItem -Path "contracts" -Filter "$name.clar" -Recurse -ErrorAction SilentlyContinue
        if ($cands.Count -eq 1) {
            $full = $cands[0].FullName
            $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $full)
            $block = "`n[contracts.$name]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal`"`n"
            $content += $block
            $added += @{ name = $name; path = $rel }
        } else {
            # Try additional flexible patterns and include tests
            $extra = @()
            $extra += Get-ChildItem -Path "contracts" -Filter "*-$name.clar" -Recurse -ErrorAction SilentlyContinue
            $extra += Get-ChildItem -Path "contracts" -Filter "*$name*.clar" -Recurse -ErrorAction SilentlyContinue
            if (Test-Path "tests") {
                $extra += Get-ChildItem -Path "tests" -Filter "$name.clar" -Recurse -ErrorAction SilentlyContinue
                $extra += Get-ChildItem -Path "tests" -Filter "test-$name.clar" -Recurse -ErrorAction SilentlyContinue
                $extra += Get-ChildItem -Path "tests" -Filter "*$name*.clar" -Recurse -ErrorAction SilentlyContinue
            }
            if ($extra.Count -gt 0) {
                # Prefer contracts/** exact, else tests/mocks, else shortest
                $pick = $extra | Where-Object { $_.FullName -like "*\contracts\*\$name.clar" } | Select-Object -First 1
                if (-not $pick) { $pick = $extra | Where-Object { $_.FullName -like "*\tests\mocks\*" } | Sort-Object { $_.FullName.Length } | Select-Object -First 1 }
                if (-not $pick) { $pick = ($extra | Sort-Object { $_.FullName.Length } | Select-Object -First 1) }
                if ($pick) {
                    $full = $pick.FullName
                    $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $full)
                    $block = "`n[contracts.$name]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal`"`n"
                    $content += $block
                    $added += @{ name = $name; path = $rel }
                } else {
                    $missing += $name
                }
            } else {
                $missing += $name
            }
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
        $bnEsc = [regex]::Escape($basename)
        $sectionRegex = '(?ms)^(\[contracts\.' + $bnEsc + '\])\s*(?<body>.*?)(?=^\[contracts\.|\Z)'
        if ($content -match $sectionRegex) {
            $body = $Matches['body']
            $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $cf.FullName)
            # path
            $pathCapture = [regex]::Match($body, '(?m)^\s*path\s*=\s*"([^"]+)"')
            if (-not $pathCapture.Success -or ($pathCapture.Groups[1].Value -ne $rel)) {
                if ($pathCapture.Success) {
                    $newBody = [regex]::Replace($body, '(?m)^\s*path\s*=\s*"[^"]+"', ("path = `"$rel`""))
                } else {
                    $newBody = ("path = `"$rel`"`n" + $body)
                }
                if ($newBody -ne $body) { $body = $newBody; $result.UpdatedPaths++ }
            }
            # address
            $addrLine = "address = `"$CanonicalPrincipal`""
            if ($body -notmatch '(?m)^\s*address\s*=\s*"') {
                $body = ($body.TrimEnd() + "`n" + $addrLine + "`n")
            } else {
                $body = [regex]::Replace($body, '(?mi)^\s*address\s*=\s*"ST[0-9A-Z]+(?:\.[A-Za-z0-9\-]+)?"', ("address = `"$CanonicalPrincipal`""))
            }
            $content = [regex]::Replace($content, $sectionRegex, "[contracts.$basename]`n" + $body)
        } else {
            # Add a new section
            $rel = Get-RelativePath -fromDir $manifestDir -toPath (Resolve-Path -LiteralPath $cf.FullName)
            $block = "`n[contracts.$basename]`npath = `"$rel`"`nclarity_version = 3`nepoch = `"3.0`"`naddress = `"$CanonicalPrincipal`"`n"
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
                    # fix address to principal-only
                    $block = [regex]::Replace($block, '(?mi)^\s*address\s*=\s*"ST[0-9A-Z]+(?:\.[A-Za-z0-9\-]+)?"', ("address = `"$CanonicalPrincipal`""))
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

# Extract a complete (define-trait <alias> ...) block from a file by balancing parentheses
function Extract-DefineTraitBlock {
    param(
        [string]$FilePath,
        [string]$Alias
    )
    if (-not (Test-Path $FilePath)) { return $null }
    $text = Get-Content $FilePath -Raw
    $pat = "(?m)^\s*\(define-trait\s+" + [regex]::Escape($Alias) + "\b"
    $m = [regex]::Match($text, $pat)
    if (-not $m.Success) { return $null }
    $start = $m.Index
    $src = $text.Substring($start)
    $depth = 0
    $foundStart = $false
    for ($i = 0; $i -lt $src.Length; $i++) {
        $ch = $src[$i]
        if ($ch -eq '(') { $depth++; $foundStart = $true }
        elseif ($ch -eq ')') { $depth-- }
        if ($foundStart -and $depth -le 0 -and $i -gt 0) {
            return $src.Substring(0, $i+1)
        }
    }
    return $null
}

# Verify that all used traits exist in all-traits.clar; auto-append missing define-trait blocks when found
function Verify-And-Fix-AllTraits {
    param(
        [string]$AllTraitsPath,
        [System.Collections.Generic.HashSet[string]]$UsedTraits
    )
    $result = [ordered]@{ Used=$UsedTraits.Count; MissingBefore=@(); AddedFromRepo=@(); MissingUnresolved=@() }
    if (-not (Test-Path $AllTraitsPath)) {
        $dir = Split-Path -Parent $AllTraitsPath
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        Set-Content -Path $AllTraitsPath -Value "; Centralized trait definitions" -NoNewline
    }
    $allText = Get-Content $AllTraitsPath -Raw
    foreach ($alias in $UsedTraits) {
        if ($AllTraits.ContainsKey($alias)) { continue }
        $result.MissingBefore += $alias
        # Search likely trait definition files first under contracts/traits
        $cands = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse -ErrorAction SilentlyContinue | Where-Object { Select-String -Path $_.FullName -Pattern ("(?m)^\s*\(define-trait\s+" + [regex]::Escape($alias) + "\b") -Quiet }
        if ($cands.Count -gt 0) {
            # Prefer files under contracts/traits/
            $pref = $cands | Where-Object { $_.FullName -like "*\contracts\traits\*" }
            $file = if ($pref.Count -gt 0) { $pref[0].FullName } else { $cands[0].FullName }
            $block = Extract-DefineTraitBlock -FilePath $file -Alias $alias
            if ($null -ne $block -and $block.Trim().Length -gt 0) {
                Add-Content -Path $AllTraitsPath -Value ("`n" + $block + "`n")
                $result.AddedFromRepo += @{ alias=$alias; from=$file }
                $AllTraits[$alias] = $true
            } else {
                $result.MissingUnresolved += $alias
            }
        } else {
            $result.MissingUnresolved += $alias
        }
    }
    return $result
}

$refResults = Ensure-Referenced-Contracts-In-Manifest -ManifestPath "Clarinet.toml" -Refs $ReferencedContracts -CanonicalPrincipal $CanonicalPrincipal

# Ensure referenced contracts in test manifest too
$refResultsTests = Ensure-Referenced-Contracts-In-Manifest -ManifestPath "stacks/Clarinet.test.toml" -Refs $ReferencedContracts -CanonicalPrincipal $CanonicalPrincipal

# Optionally, sync all contract files into Clarinet.toml
$syncResults = $null
if ($SyncContracts) {
    $syncResults = Sync-Manifest-With-Contracts -ManifestPath "Clarinet.toml" -CanonicalPrincipal $CanonicalPrincipal -RenameBlocks:$RenameBlocks
}

# Verify centralized traits coverage and auto-fix when possible
$traitsCoverage = Verify-And-Fix-AllTraits -AllTraitsPath $allTraitsPath -UsedTraits $GlobalUsedTraits

# Re-normalize manifests after any additions so paths are canonical
$manifestResults += Align-Manifest -ManifestPath "Clarinet.toml" -CanonicalPrincipal $CanonicalPrincipal -EnforceAddresses
if (Test-Path "stacks/Clarinet.test.toml") {
    $manifestResults += Align-Manifest -ManifestPath "stacks/Clarinet.test.toml" -CanonicalPrincipal $CanonicalPrincipal -EnforceAddresses
}

# Referenced contract verification summary (root + test manifests)
if ($ReferencedContracts.Count -gt 0) {
    $allRefs = New-Object System.Collections.Generic.HashSet[string]
    foreach ($r in $ReferencedContracts) { [void]$allRefs.Add($r) }
    $addedRoot = @($refResults.Added | ForEach-Object { $_.name })
    $addedTest = @($refResultsTests.Added | ForEach-Object { $_.name })
    $missingRoot = @($refResults.Missing)
    $missingTest = @($refResultsTests.Missing)
    # Remove added in either manifest from the outstanding set
    foreach ($n in $addedRoot) { [void]$allRefs.Remove($n) }
    foreach ($n in $addedTest) { [void]$allRefs.Remove($n) }
    # Remove missing (we will print them explicitly)
    foreach ($n in $missingRoot) { [void]$allRefs.Remove($n) }
    foreach ($n in $missingTest) { [void]$allRefs.Remove($n) }
    $verified = @(); foreach ($x in $allRefs) { $verified += $x }
    if ($addedRoot.Count -gt 0) { Write-Host ("Added referenced contracts (root): " + ($addedRoot -join ', ')) -ForegroundColor Green }
    if ($addedTest.Count -gt 0) { Write-Host ("Added referenced contracts (tests): " + ($addedTest -join ', ')) -ForegroundColor Green }
    if ($verified.Count -gt 0) { Write-Host ("Verified referenced contracts already present: " + ($verified -join ', ')) -ForegroundColor Green }
    $unresolved = @()
    # Consider unresolved only if missing in both
    $missingBoth = New-Object System.Collections.Generic.HashSet[string]
    foreach ($n in $missingRoot) { if (-not $addedTest.Contains($n)) { [void]$missingBoth.Add($n) } }
    foreach ($n in $missingTest) { if (-not $addedRoot.Contains($n)) { [void]$missingBoth.Add($n) } }
    foreach ($n in $missingBoth) { $unresolved += $n }
    if ($unresolved.Count -gt 0) { Write-Host ("Unresolved referenced contracts (manual review): " + ($unresolved -join ', ')) -ForegroundColor Yellow }
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
        TraitsCoverage = $traitsCoverage
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
