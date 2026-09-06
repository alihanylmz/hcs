param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Flutter {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  Write-Host ("`n> flutter " + ($Arguments -join ' ')) -ForegroundColor Cyan
  & flutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter komutu basarisiz oldu (exit code $LASTEXITCODE): flutter $($Arguments -join ' ')"
  }
}

Push-Location $projectRoot
try {
  if (-not $SkipPubGet) {
    Invoke-Flutter @('pub', 'get')
  }

  # Uyari ve analiz hatalari CI'da sessizce yutulmaz. Testler de paketin
  # tamamini calistirir; tek bir widget testiyle sinirli degildir.
  Invoke-Flutter @('analyze')
  Invoke-Flutter @('test')

  Write-Host "`nTeklif uygulamasi kalite kontrolu basarili." -ForegroundColor Green
} finally {
  Pop-Location
}
