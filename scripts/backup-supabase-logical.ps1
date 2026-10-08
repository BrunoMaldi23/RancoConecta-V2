param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string] $ProjectRef,
  [string] $OutputRoot = (Join-Path $env:LOCALAPPDATA 'RancoConecta\production-backups')
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$resolvedRoot = [IO.Path]::GetFullPath($OutputRoot)
if ($resolvedRoot.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Backup OutputRoot must be outside the repository.'
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$backupDir = Join-Path $resolvedRoot "$ProjectRef-$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# Restrict access to the current Windows identity; children inherit this ACL.
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetOwner($sid)
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object Security.AccessControl.FileSystemAccessRule(
  $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -LiteralPath $backupDir -AclObject $acl
trap {
  if (Test-Path -LiteralPath $backupDir -PathType Container) {
    Get-ChildItem -LiteralPath $backupDir -File -ErrorAction SilentlyContinue |
      Remove-Item -Force -ErrorAction SilentlyContinue
  }
  break
}

$dumps = @(
  @{ Name = 'schema-public.sql'; Args = @('db','dump','--linked','--project-ref',$ProjectRef,'--schema','public','--file',(Join-Path $backupDir 'schema-public.sql')) },
  @{ Name = 'schema-auth.sql'; Args = @('db','dump','--linked','--project-ref',$ProjectRef,'--schema','auth','--file',(Join-Path $backupDir 'schema-auth.sql')) },
  @{ Name = 'schema-storage.sql'; Args = @('db','dump','--linked','--project-ref',$ProjectRef,'--schema','storage','--file',(Join-Path $backupDir 'schema-storage.sql')) },
  @{ Name = 'data-public.sql'; Args = @('db','dump','--linked','--project-ref',$ProjectRef,'--data-only','--use-copy','--schema','public','--file',(Join-Path $backupDir 'data-public.sql')) },
  @{ Name = 'data-auth.sql'; Args = @('db','dump','--linked','--project-ref',$ProjectRef,'--data-only','--use-copy','--schema','auth','--file',(Join-Path $backupDir 'data-auth.sql')) },
  @{ Name = 'data-storage.sql'; Args = @('db','dump','--linked','--project-ref',$ProjectRef,'--data-only','--use-copy','--schema','storage','--file',(Join-Path $backupDir 'data-storage.sql')) },
  @{ Name = 'cluster-roles.sql'; Args = @('db','dump','--linked','--project-ref',$ProjectRef,'--role-only','--file',(Join-Path $backupDir 'cluster-roles.sql')) }
)
foreach ($dump in $dumps) {
  $targetFile = Join-Path $backupDir $dump.Name
  $dumpExit = 1
  for ($attempt = 1; $attempt -le 3 -and $dumpExit -ne 0; $attempt++) {
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    switch ($dump.Name) {
    'schema-public.sql' { npx supabase db dump --linked --project-ref $ProjectRef --schema public --file $targetFile 2>$null }
    'schema-auth.sql' { npx supabase db dump --linked --project-ref $ProjectRef --schema auth --file $targetFile 2>$null }
    'schema-storage.sql' { npx supabase db dump --linked --project-ref $ProjectRef --schema storage --file $targetFile 2>$null }
    'data-public.sql' { npx supabase db dump --linked --project-ref $ProjectRef --data-only --use-copy --schema public --file $targetFile 2>$null }
    'data-auth.sql' { npx supabase db dump --linked --project-ref $ProjectRef --data-only --use-copy --schema auth --file $targetFile 2>$null }
    'data-storage.sql' { npx supabase db dump --linked --project-ref $ProjectRef --data-only --use-copy --schema storage --file $targetFile 2>$null }
    'cluster-roles.sql' { npx supabase db dump --linked --project-ref $ProjectRef --role-only --file $targetFile 2>$null }
      default { throw "Unrecognized dump artifact $($dump.Name)" }
    }
    $dumpExit = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($dumpExit -ne 0 -and $attempt -lt 3) {
      Write-Warning "Dump failed for $($dump.Name); retrying attempt $($attempt + 1) of 3."
      Start-Sleep -Seconds 5
    }
  }
  if ($dumpExit -ne 0) { throw "Supabase dump failed for $($dump.Name) after three attempts." }
  if (-not (Test-Path -LiteralPath (Join-Path $backupDir $dump.Name)) -or
      (Get-Item -LiteralPath (Join-Path $backupDir $dump.Name)).Length -eq 0) {
    throw "Expected dump is missing or empty: $($dump.Name)"
  }
}

$historyPath = Join-Path $backupDir 'migration-history.json'
$savedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$historyOutput = npx supabase migration list --linked --project-ref $ProjectRef --output-format json 2>$null
$historyExit = $LASTEXITCODE
$ErrorActionPreference = $savedErrorActionPreference
if ($historyExit -ne 0) { throw 'Could not capture remote migration history.' }
$history = ($historyOutput -join [Environment]::NewLine) | ConvertFrom-Json
if (-not $history.migrations -or @($history.migrations).Count -lt 1) { throw 'Remote migration history is empty.' }
$history | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $historyPath -Encoding utf8
$backupFiles = @($dumps | ForEach-Object {
  $path = Join-Path $backupDir $_.Name
  [ordered]@{ name = $_.Name; bytes = (Get-Item -LiteralPath $path).Length; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
})
$backupFiles += [ordered]@{ name = 'migration-history.json'; bytes = (Get-Item -LiteralPath $historyPath).Length; sha256 = (Get-FileHash -LiteralPath $historyPath -Algorithm SHA256).Hash }

$manifest = [ordered]@{
  project_ref = $ProjectRef
  captured_at_utc = $timestamp
  files = $backupFiles
}
$manifestPath = Join-Path $backupDir 'manifest.json'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8

# Build the zip in memory so no additional plaintext archive is written to disk.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.Security
function Get-ByteSha256([byte[]] $Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-', '') }
  finally { $sha.Dispose() }
}
$memory = New-Object IO.MemoryStream
$zip = New-Object IO.Compression.ZipArchive($memory, [IO.Compression.ZipArchiveMode]::Create, $true)
foreach ($file in Get-ChildItem -LiteralPath $backupDir -File) {
  $entry = $zip.CreateEntry($file.Name, [IO.Compression.CompressionLevel]::Optimal)
  $entryStream = $entry.Open()
  $input = [IO.File]::OpenRead($file.FullName)
  try { $input.CopyTo($entryStream) } finally { $input.Dispose(); $entryStream.Dispose() }
}
$zip.Dispose()
$archiveBytes = $memory.ToArray()
$plainHash = Get-ByteSha256 $archiveBytes
$encrypted = [Security.Cryptography.ProtectedData]::Protect(
  $archiveBytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
$encryptedPath = Join-Path $backupDir 'snapshot.zip.dpapi'
[IO.File]::WriteAllBytes($encryptedPath, $encrypted)

$roundTrip = [Security.Cryptography.ProtectedData]::Unprotect(
  [IO.File]::ReadAllBytes($encryptedPath), $null,
  [Security.Cryptography.DataProtectionScope]::CurrentUser)
$roundTripHash = Get-ByteSha256 $roundTrip
if ($roundTripHash -ne $plainHash) { throw 'DPAPI round-trip integrity check failed.' }

# Keep only the DPAPI-protected archive after validating its round-trip.
foreach ($file in Get-ChildItem -LiteralPath $backupDir -File | Where-Object { $_.FullName -ne $encryptedPath }) {
  [IO.File]::Delete($file.FullName)
}
if (@(Get-ChildItem -LiteralPath $backupDir -File | Where-Object { $_.FullName -ne $encryptedPath }).Count -ne 0) {
  throw 'Plaintext backup artifacts remain after encryption.'
}

$result = [ordered]@{
  project_ref = $ProjectRef
  captured_at_utc = $timestamp
  encrypted_file = $encryptedPath
  encrypted_sha256 = (Get-FileHash -LiteralPath $encryptedPath -Algorithm SHA256).Hash
  decrypted_archive_sha256 = $roundTripHash
  plaintext_dumps_retained_for_restore = $false
}
$result | ConvertTo-Json | Write-Output
