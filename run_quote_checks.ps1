param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'
$projectRoot = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'uzalteklif'
$qualityScript = Join-Path $projectRoot 'tool\verify_quality.ps1'

if (-not (Test-Path -LiteralPath $qualityScript)) {
  throw "Teklif kalite scripti bulunamadi: $qualityScript"
}

$args = @()
if ($SkipPubGet) {
  $args += '-SkipPubGet'
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $qualityScript @args
exit $LASTEXITCODE
