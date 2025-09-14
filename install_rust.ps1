$rustInstaller = "rustup-init.exe"
$rustUrl = "https://win.rustup.rs/x86_64"

# Ensure no existing installer is running
Get-Process | Where-Object { $_.Path -like "*rustup*" } | Stop-Process -Force

# Download and run installer
Invoke-WebRequest -Uri $rustUrl -OutFile $rustInstaller
Start-Process -Wait -FilePath $rustInstaller -ArgumentList "-y"

# Verify installation
rustc --version
cargo --version
