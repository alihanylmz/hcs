$ErrorActionPreference = 'Stop'

$testFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot '..\test') -Filter 'quote_editor_*_test.dart' |
  Sort-Object Name

if ($testFiles.Count -eq 0) {
  throw 'quote_editor_*_test.dart bulunamadi.'
}

foreach ($testFile in $testFiles) {
  Write-Host "Calistiriliyor: $($testFile.Name)"
  flutter test $testFile.FullName --reporter compact
  if ($LASTEXITCODE -ne 0) {
    throw "Test basarisiz: $($testFile.Name)"
  }
}

Write-Host "Teklif editörü testleri basariyla tamamlandi."
