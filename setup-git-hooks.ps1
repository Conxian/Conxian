# Setup Git Hooks for Windows
# Run this script to configure Git to use the hooks in .githooks

# Ensure .git/hooks directory exists
$hooksDir = ".git/hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force
}

# Create a pre-commit hook that runs our script
$preCommitHook = @"
#!/bin/sh
# Run the pre-commit hook from .githooks
. .githooks/pre-commit
"@

# Save the hook
$preCommitHook | Out-File -FilePath "$hooksDir/pre-commit" -Encoding ascii

# Make the hook executable (for WSL/Git Bash)
if (Get-Command "bash" -ErrorAction SilentlyContinue) {
    bash -c "chmod +x .git/hooks/pre-commit"
}

Write-Host "Git hooks have been configured successfully." -ForegroundColor Green
Write-Host "The pre-commit hook will now check for sensitive information before each commit." -ForegroundColor Cyan
