$AllowedPublicFlutterKeys = @(
  "APP_ENVIRONMENT",
  "SUPABASE_URL",
  "SUPABASE_PUBLISHABLE_KEY",
  "SUPABASE_ANON_KEY",
  "CHAT_ENABLED",
  "PAYMENTS_ENABLED",
  "QUOTES_ENABLED",
  "LODGING_ENABLED"
)

function Read-PublicFlutterEnv {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing env file: $Path"
  }

  $Values = [ordered]@{}

  foreach ($RawLine in Get-Content -LiteralPath $Path) {
    $Line = $RawLine.Trim()

    if ($Line.Length -eq 0 -or $Line.StartsWith("#")) {
      continue
    }

    $Parts = $Line.Split("=", 2)
    if ($Parts.Count -ne 2) {
      throw "Invalid env line in $Path. Expected KEY=value."
    }

    $Key = $Parts[0].Trim()
    $Value = $Parts[1].Trim().Trim('"').Trim("'")

    if ($AllowedPublicFlutterKeys -notcontains $Key) {
      throw "Refusing to load non-public key from ${Path}: $Key"
    }

    $Values[$Key] = $Value
  }

  if (-not $Values.Contains("APP_ENVIRONMENT")) {
    $Values["APP_ENVIRONMENT"] = "development"
  }

  if (-not $Values.Contains("CHAT_ENABLED")) {
    $Values["CHAT_ENABLED"] = "false"
  }

  if (-not $Values.Contains("PAYMENTS_ENABLED")) {
    $Values["PAYMENTS_ENABLED"] = "false"
  }

  if (-not $Values.Contains("QUOTES_ENABLED")) {
    $Values["QUOTES_ENABLED"] = "false"
  }

  if (-not $Values.Contains("LODGING_ENABLED")) {
    $Values["LODGING_ENABLED"] = "true"
  }

  if (-not $Values.Contains("SUPABASE_URL") -or
      [string]::IsNullOrWhiteSpace($Values["SUPABASE_URL"])) {
    throw "Missing required key in ${Path}: SUPABASE_URL"
  }

  $HasPublishableKey =
    $Values.Contains("SUPABASE_PUBLISHABLE_KEY") -and
    -not [string]::IsNullOrWhiteSpace($Values["SUPABASE_PUBLISHABLE_KEY"])
  $HasAnonKey =
    $Values.Contains("SUPABASE_ANON_KEY") -and
    -not [string]::IsNullOrWhiteSpace($Values["SUPABASE_ANON_KEY"])

  if (-not $HasPublishableKey -and -not $HasAnonKey) {
    throw "Missing required key in ${Path}: SUPABASE_ANON_KEY or SUPABASE_PUBLISHABLE_KEY"
  }

  return $Values
}

function ConvertTo-DartDefineArgs {
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.IDictionary]$Values
  )

  $Args = @()

  foreach ($Key in $AllowedPublicFlutterKeys) {
    if ($Values.Contains($Key)) {
      $Args += "--dart-define=$Key=$($Values[$Key])"
    }
  }

  return $Args
}
