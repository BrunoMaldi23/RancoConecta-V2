param(
  [switch]$SkipGit,
  [switch]$SkipVercel,
  [string]$Message = "deploy: publish Flutter web production build"
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
  Write-Host ""
  Write-Host "==> $Message"
}

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

$EnvFile = Join-Path $Root ".env.production.local"
$DefinesFile = Join-Path $Root ".dart_tool\production_public_defines.env"
$BuildDir = Join-Path $Root "build\web"
$OutputDir = Join-Path $Root "vercel_output"

if (-not (Test-Path -LiteralPath $EnvFile)) {
  throw "Missing .env.production.local. Create it locally with APP_ENVIRONMENT, SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY."
}

Write-Step "Preparing sanitized public dart defines"
$Allowed = @("APP_ENVIRONMENT", "SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY")
$Lines = Get-Content -LiteralPath $EnvFile | Where-Object {
  $Line = $_
  $Allowed | Where-Object { $Line -match "^\s*$_=" }
}

foreach ($Key in $Allowed) {
  if (-not ($Lines | Where-Object { $_ -match "^\s*$Key=" })) {
    throw "Missing required key in .env.production.local: $Key"
  }
}

New-Item -ItemType Directory -Force -Path (Split-Path $DefinesFile) | Out-Null
Set-Content -LiteralPath $DefinesFile -Value $Lines -Encoding UTF8

Write-Step "Running Flutter checks"
flutter pub get
dart format .
flutter analyze
flutter test

Write-Step "Building Flutter web production bundle"
flutter build web --release --dart-define-from-file=$DefinesFile

Write-Step "Syncing build/web to vercel_output"
if (-not (Test-Path -LiteralPath $BuildDir)) {
  throw "Flutter build did not create build\web."
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$ResolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$ResolvedOutput = (Resolve-Path -LiteralPath $OutputDir).Path
if (-not $ResolvedOutput.StartsWith($ResolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe output directory: $ResolvedOutput"
}

Get-ChildItem -LiteralPath $ResolvedOutput -Force | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $BuildDir "*") -Destination $ResolvedOutput -Recurse -Force

if (-not $SkipGit) {
  Write-Step "Committing and pushing production output"
  git add pubspec.yaml pubspec.lock package.json package-lock.json vercel.json scripts/deploy-production.ps1 vercel_output
  git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) {
    Write-Host "No staged changes to commit."
  } else {
    git commit -m $Message
    git push origin main
  }
}

if (-not $SkipVercel) {
  Write-Step "Deploying to Vercel production"
  npx vercel --prod --yes
}

Write-Step "Done"
