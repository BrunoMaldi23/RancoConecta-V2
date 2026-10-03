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
$Allowed = @("APP_ENVIRONMENT", "SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY", "PUBLIC_SITE_URL", "CONTACT_EMAIL", "CONTACT_WHATSAPP", "CONTACT_INSTAGRAM", "SENTRY_DSN", "SENTRY_RELEASE", "POSTHOG_PROJECT_TOKEN", "POSTHOG_KEY", "POSTHOG_HOST", "PAYMENTS_ENABLED", "CHAT_ENABLED", "QUOTES_ENABLED", "LODGING_ENABLED")
$DefaultDefines = @{
  "PAYMENTS_ENABLED" = "false"
  "CHAT_ENABLED" = "false"
  "QUOTES_ENABLED" = "false"
  "LODGING_ENABLED" = "true"
}
$Lines = Get-Content -LiteralPath $EnvFile | Where-Object {
  $Line = $_
  $Allowed | Where-Object { $Line -match "^\s*$_=" }
}

foreach ($Key in $Allowed) {
  if ($Key -in @("APP_ENVIRONMENT", "SUPABASE_URL") -and
      -not ($Lines | Where-Object { $_ -match "^\s*$Key=" })) {
    throw "Missing required key in .env.production.local: $Key"
  }
}

if (-not ($Lines | Where-Object { $_ -match '^\s*PUBLIC_SITE_URL=' })) {
  $Lines += 'PUBLIC_SITE_URL=https://www.rancoconecta.cl'
}

$PublicValues = @{}
foreach ($Line in $Lines) {
  $Parts = $Line.Trim().Split("=", 2)
  $PublicValues[$Parts[0]] = $Parts[1].Trim().Trim('"').Trim("'")
}

if ($PublicValues["APP_ENVIRONMENT"] -ne "production") {
  throw "APP_ENVIRONMENT must be production for a production deploy."
}

$SupabaseUri = $null
if (-not [Uri]::TryCreate($PublicValues["SUPABASE_URL"], [UriKind]::Absolute, [ref]$SupabaseUri) -or
    $SupabaseUri.Scheme -ne "https" -or
    $SupabaseUri.IsLoopback) {
  throw "SUPABASE_URL must be a valid HTTPS production URL."
}

if ([string]::IsNullOrWhiteSpace($PublicValues["SUPABASE_PUBLISHABLE_KEY"])) {
  if ([string]::IsNullOrWhiteSpace($PublicValues["SUPABASE_ANON_KEY"])) {
    throw "SUPABASE_PUBLISHABLE_KEY or SUPABASE_ANON_KEY must be configured."
  }
}

$SiteUri = $null
if (-not [Uri]::TryCreate($PublicValues["PUBLIC_SITE_URL"], [UriKind]::Absolute, [ref]$SiteUri) -or
    $SiteUri.Scheme -ne "https" -or
    $SiteUri.AbsoluteUri.TrimEnd('/') -ne "https://www.rancoconecta.cl") {
  throw "PUBLIC_SITE_URL must be https://www.rancoconecta.cl for production."
}

New-Item -ItemType Directory -Force -Path (Split-Path $DefinesFile) | Out-Null
if (-not $PublicValues.ContainsKey("SENTRY_RELEASE") -and
    -not [string]::IsNullOrWhiteSpace($PublicValues["SENTRY_DSN"])) {
  $Commit = (git rev-parse --short HEAD).Trim()
  $Stamp = Get-Date -Format "yyyyMMddHHmmss"
  $Lines += "SENTRY_RELEASE=ranco-conecta@$Commit+$Stamp"
}
foreach ($Key in $DefaultDefines.Keys) {
  if (-not $PublicValues.ContainsKey($Key)) {
    $Lines += "$Key=$($DefaultDefines[$Key])"
  }
}
Set-Content -LiteralPath $DefinesFile -Value $Lines -Encoding UTF8

Write-Step "Running Flutter checks"
.\scripts\check_text_encoding.ps1
if ($LASTEXITCODE -ne 0) { throw "Text encoding check failed." }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Flutter pub get failed." }
dart format --output=none --set-exit-if-changed lib test
if ($LASTEXITCODE -ne 0) { throw "Dart format check failed." }
flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { throw "Flutter analyze failed." }
flutter test
if ($LASTEXITCODE -ne 0) { throw "Flutter tests failed." }
git diff --check
if ($LASTEXITCODE -ne 0) { throw "Git diff check failed." }

Write-Step "Building Flutter web production bundle"
flutter build web --release --dart-define-from-file=$DefinesFile
if ($LASTEXITCODE -ne 0) { throw "Flutter web build failed." }

Write-Step "Syncing build/web to vercel_output"
if (-not (Test-Path -LiteralPath $BuildDir)) {
  throw "Flutter build did not create build\web."
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$ResolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$ResolvedOutput = (Resolve-Path -LiteralPath $OutputDir).Path
$RootPrefix = $ResolvedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $ResolvedOutput.StartsWith($RootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe output directory: $ResolvedOutput"
}

Get-ChildItem -LiteralPath $ResolvedOutput -Force | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $BuildDir "*") -Destination $ResolvedOutput -Recurse -Force

# Flutter's generated license notice can contain trailing spaces. Normalize it
# after copying so the tracked deploy output passes the final Git whitespace gate.
$NoticesPath = Join-Path $ResolvedOutput "assets\NOTICES"
if (Test-Path -LiteralPath $NoticesPath) {
  $NoticeText = [IO.File]::ReadAllText($NoticesPath)
  $NoticeText = [regex]::Replace($NoticeText, '(?m)[ \t]+$', '')
  [IO.File]::WriteAllText($NoticesPath, $NoticeText, [Text.UTF8Encoding]::new($false))
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw "Git diff check failed after build sync." }

Write-Step "Git checkpoint is separate from deploy; review the complete working tree before commit or push"

if (-not $SkipVercel) {
  Write-Step "Deploying to Vercel production"
  npx vercel --prod --yes
  if ($LASTEXITCODE -ne 0) { throw "Vercel production deploy failed." }
}

Write-Step "Done"
