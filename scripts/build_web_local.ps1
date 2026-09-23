$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$EnvFile = Join-Path $Root ".env.local"

. (Join-Path $PSScriptRoot "flutter-public-env.ps1")

$Values = Read-PublicFlutterEnv -Path $EnvFile
$DefineArgs = ConvertTo-DartDefineArgs -Values $Values

Write-Host "Building Flutter web release with public defines from .env.local:"
foreach ($Key in $Values.Keys) {
  Write-Host " - $Key"
}

Set-Location $Root
flutter build web --release @DefineArgs

