# Runs clarinet check for each .clar file individually and writes failures to scripts/clarinet_check_summary.txt
$root = Get-Location
$files = Get-ChildItem -Path $root -Recurse -Filter *.clar | Select-Object -ExpandProperty FullName
$results = @()
foreach ($f in $files) {
  $rel = [System.IO.Path]::GetRelativePath($root, $f)
  $proc = Start-Process -FilePath 'clarinet' -ArgumentList @('check', $rel) -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\clarinet_stdout.txt" -RedirectStandardError "$env:TEMP\clarinet_stderr.txt"
  $stdout = Get-Content -Raw "$env:TEMP\clarinet_stdout.txt" -ErrorAction SilentlyContinue
  if ($proc.ExitCode -ne 0) {
    $results += [pscustomobject]@{ File=$rel; ExitCode=$proc.ExitCode; Output=$stdout }
  }
}
$summaryPath = Join-Path $root 'scripts' 'clarinet_check_summary.txt'
"Failures (file, exit, snippet):" | Set-Content -Path $summaryPath -Encoding utf8
foreach ($r in $results) {
  Add-Content -Path $summaryPath -Value ("`nFile: {0}`nExit: {1}`nOutput:`n{2}`n" -f $r.File, $r.ExitCode, $r.Output)
}