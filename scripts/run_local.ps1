param(
  [string]$Device = "chrome",
  [switch]$Web,
  [switch]$Windows
)

$ErrorActionPreference = "Stop"

if ($Web -and $Windows) {
  throw "Elige solo uno de los parametros -Web o -Windows."
}

if (($Web -or $Windows) -and $PSBoundParameters.ContainsKey('Device')) {
  throw "Usa -Device o uno de los parametros -Web y -Windows."
}

# RANCO_UTF8_CHECK
$encodingCheck = Join-Path $PSScriptRoot "check_text_encoding.ps1"

if (Test-Path $encodingCheck) {
  & $encodingCheck

  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Inicio cancelado por problemas de texto/UTF-8."
    exit $LASTEXITCODE
  }
}
# /RANCO_UTF8_CHECK

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$EnvFile = Join-Path $Root ".env.local"

. (Join-Path $PSScriptRoot "flutter-public-env.ps1")

$Values = Read-PublicFlutterEnv -Path $EnvFile
$DefineArgs = ConvertTo-DartDefineArgs -Values $Values

Write-Host "Starting Flutter with public defines from .env.local:"
foreach ($Key in $Values.Keys) {
  Write-Host " - $Key"
}

Set-Location $Root

$RequestedDevice = if ($Web) {
  "edge"
} elseif ($Windows) {
  "windows"
} else {
  $Device
}

$SelectedDevice = $RequestedDevice
$DevicesOutput = flutter devices
if ($LASTEXITCODE -ne 0) {
  throw "Unable to list Flutter devices."
}

$DevicesText = $DevicesOutput -join [Environment]::NewLine
$DevicePattern = "\b$([regex]::Escape($RequestedDevice))\b"
if ($DevicesText -notmatch $DevicePattern) {
  if ($RequestedDevice -eq "chrome" -and $DevicesText -match "\bedge\b") {
    Write-Host "Chrome device was not found by Flutter; falling back to Edge."
    $SelectedDevice = "edge"
  } else {
    throw "Flutter device '$RequestedDevice' was not found. Run 'flutter devices' to inspect available devices."
  }
}

flutter run -d $SelectedDevice @DefineArgs
exit $LASTEXITCODE
