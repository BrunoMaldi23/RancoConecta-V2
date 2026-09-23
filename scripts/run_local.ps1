param(
  [string]$Device = "chrome"
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$EnvFile = Join-Path $Root ".env.local"

. (Join-Path $PSScriptRoot "flutter-public-env.ps1")

$Values = Read-PublicFlutterEnv -Path $EnvFile
$DefineArgs = ConvertTo-DartDefineArgs -Values $Values

Write-Host "Starting Flutter web with public defines from .env.local:"
foreach ($Key in $Values.Keys) {
  Write-Host " - $Key"
}

Set-Location $Root

$SelectedDevice = $Device
$DevicesOutput = flutter devices
if ($LASTEXITCODE -ne 0) {
  throw "Unable to list Flutter devices."
}

$DevicePattern = "\b$([regex]::Escape($Device))\b"
if ($DevicesOutput -notmatch $DevicePattern) {
  if ($Device -eq "chrome" -and $DevicesOutput -match "\bedge\b") {
    Write-Host "Chrome device was not found by Flutter; falling back to Edge."
    $SelectedDevice = "edge"
  } else {
    throw "Flutter device '$Device' was not found. Run 'flutter devices' to inspect available devices."
  }
}

flutter run -d $SelectedDevice @DefineArgs
