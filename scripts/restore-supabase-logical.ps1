param(
  [Parameter(Mandatory = $true)]
  [string] $EncryptedArchive,
  [Parameter(Mandatory = $true)]
  [string] $DestinationRoot
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$resolvedRoot = [IO.Path]::GetFullPath($DestinationRoot)
if ($resolvedRoot.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Restore staging must be outside the repository.'
}
if (-not (Test-Path -LiteralPath $EncryptedArchive -PathType Leaf)) {
  throw 'Encrypted snapshot file not found.'
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.Security
$encrypted = [IO.File]::ReadAllBytes((Resolve-Path $EncryptedArchive))
$archiveBytes = [Security.Cryptography.ProtectedData]::Unprotect(
  $encrypted, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
$memory = New-Object IO.MemoryStream(,$archiveBytes)
$zip = New-Object IO.Compression.ZipArchive($memory, [IO.Compression.ZipArchiveMode]::Read, $false)
$allowed = @('schema-public.sql','schema-auth.sql','schema-storage.sql',
  'data-public.sql','data-auth.sql','data-storage.sql','cluster-roles.sql',
  'migration-history.json','manifest.json')
$entries = @($zip.Entries)
if ($entries.Count -ne $allowed.Count -or
    @($entries | Where-Object { $_.FullName -notin $allowed }).Count -ne 0) {
  throw 'Unexpected archive contents; extraction aborted.'
}

New-Item -ItemType Directory -Path $resolvedRoot -Force | Out-Null
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetOwner($sid)
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object Security.AccessControl.FileSystemAccessRule(
  $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -LiteralPath $resolvedRoot -AclObject $acl

foreach ($entry in $entries) {
  $destination = Join-Path $resolvedRoot $entry.FullName
  $stream = $entry.Open()
  $output = [IO.File]::Create($destination)
  try { $stream.CopyTo($output) } finally { $stream.Dispose(); $output.Dispose() }
}
$zip.Dispose()
$memory.Dispose()

$manifest = Get-Content -LiteralPath (Join-Path $resolvedRoot 'manifest.json') -Raw | ConvertFrom-Json
foreach ($item in $manifest.files) {
  $path = Join-Path $resolvedRoot $item.name
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing archive file: $($item.name)" }
  if ((Get-Item -LiteralPath $path).Length -ne [long]$item.bytes -or
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.sha256) {
    throw "Snapshot integrity check failed for $($item.name)."
  }
}
if ($manifest.files.Count -ne 8) { throw 'Unexpected manifest file count.' }

# The Auth dump has three auth.users triggers whose functions live in public.
# Defer just those CREATE TRIGGER statements until public has been restored.
$authSchemaPath = Join-Path $resolvedRoot 'schema-auth.sql'
$authSchema = [IO.File]::ReadAllText($authSchemaPath)
$triggerPattern = '(?m)^CREATE OR REPLACE TRIGGER .+ ON "auth"\."users" .+EXECUTE FUNCTION "public"\."[A-Za-z0-9_]+"\(\);\r?$'
$deferred = [regex]::Matches($authSchema, $triggerPattern)
if ($deferred.Count -ne 3) {
  throw "Expected exactly three auth.users triggers depending on public; found $($deferred.Count). Restore must be reviewed before continuing."
}
$authBase = [regex]::Replace($authSchema, $triggerPattern, '')
[IO.File]::WriteAllText((Join-Path $resolvedRoot 'schema-auth-base.sql'), $authBase, [Text.UTF8Encoding]::new($false))
$deferredText = (($deferred | ForEach-Object Value) -join "`r`n") + "`r`n"
[IO.File]::WriteAllText((Join-Path $resolvedRoot 'auth-deferred-triggers.sql'), $deferredText, [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
  project_ref = $manifest.project_ref
  captured_at_utc = $manifest.captured_at_utc
  extracted_to = $resolvedRoot
  verified_dump_count = $manifest.files.Count
  deferred_auth_trigger_count = $deferred.Count
  integrity = 'PASS'
} | ConvertTo-Json | Write-Output
