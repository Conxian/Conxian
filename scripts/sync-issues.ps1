# Sync ISSUES.md with GitHub issues
# Requires GitHub CLI

# Authenticate
gh auth status || gh auth login

# Fetch issues
gh issue list --state all --json number,title,state > issues.json

# Parse ISSUES.md and sync
$issues = Get-Content -Raw -Path issues.json | ConvertFrom-Json
$issuesMd = Get-Content -Raw -Path .github\ISSUES.md

# Group by title to detect duplicates
$duplicates = $issues | Group-Object title | Where-Object { $_.Count -gt 1 }

foreach ($group in $duplicates) {
  $primary = $group.Group[0]
  $others = $group.Group | Select-Object -Skip 1
  
  # Merge duplicates into primary issue
  foreach ($other in $others) {
    # Add comments from duplicate to primary
    gh issue comment $other.number --body "Merged into #$($primary.number)"
    
    # Close duplicate
    gh issue close $other.number
    
    # Update ISSUES.md references
    $issuesMd = $issuesMd -replace "#$($other.number)", "#$($primary.number)"
  }
}

foreach ($issue in $issues) {
  $issueNumber = $issue.number
  $issueTitle = $issue.title
  $issueState = $issue.state

  # Update ISSUES.md with current issue state
  $issuesMd = $issuesMd -replace "(?m)^#$issueNumber\s+.*$", "#$issueNumber $issueTitle ($issueState)"
}

$issuesMd | Set-Content -Path .github\ISSUES.md
