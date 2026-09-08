param(
  [string]$OutputDirectory = 'backups\supabase',
  [string]$DatabaseUrl = $env:SUPABASE_DB_URL
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw 'SUPABASE_DB_URL gerekli. Degeri repoya yazmayin; komut oturumunda ortam degiskeni olarak verin.'
}

$pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if ($null -eq $pgDump) {
  throw 'pg_dump bulunamadi. PostgreSQL client/ Supabase CLI kurup PATH''e ekleyin.'
}

$root = Split-Path -Parent $PSScriptRoot
$resolvedOutputDirectory = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
  $OutputDirectory
} else {
  Join-Path $root $OutputDirectory
}

New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputPath = Join-Path $resolvedOutputDirectory "supabase-$stamp.dump"

Write-Host "Supabase yedegi aliniyor: $outputPath" -ForegroundColor Cyan
& $pgDump.Source '--format=custom' '--no-owner' '--no-privileges' '--file' $outputPath $DatabaseUrl
if ($LASTEXITCODE -ne 0) {
  throw "pg_dump basarisiz oldu (exit code $LASTEXITCODE)."
}

$file = Get-Item -LiteralPath $outputPath
if ($file.Length -le 0) {
  throw "Yedek dosyasi bos olusturuldu: $outputPath"
}

$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
Write-Host "Yedek tamamlandi. Boyut: $($file.Length) byte; SHA-256: $hash" -ForegroundColor Green
