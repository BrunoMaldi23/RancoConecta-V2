$ErrorActionPreference = "Stop"

$checker = Join-Path `
    $PSScriptRoot `
    "check_text_encoding.py"

if (-not (Test-Path $checker)) {
    Write-Host "No existe check_text_encoding.py"
    exit 1
}

python $checker

exit $LASTEXITCODE
