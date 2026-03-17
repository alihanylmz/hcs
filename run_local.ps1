param(
  [ValidateSet('run', 'test', 'build-web', 'build-windows', 'build-apk', 'build-appbundle')]
  [string]$Action = 'run',

  [string]$Device = 'chrome'
)

$ErrorActionPreference = 'Stop'

function Read-EnvFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $values = @{}

  foreach ($line in Get-Content -Path $Path) {
    $trimmed = $line.Trim()

    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
      continue
    }

    $separatorIndex = $trimmed.IndexOf('=')
    if ($separatorIndex -lt 1) {
      continue
    }

    $key = $trimmed.Substring(0, $separatorIndex).Trim()
    $value = $trimmed.Substring($separatorIndex + 1).Trim()

    if (
      ($value.StartsWith('"') -and $value.EndsWith('"')) -or
      ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    $values[$key] = $value
  }

  return $values
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $projectRoot 'env.txt'

if (-not (Test-Path $envFile)) {
  throw "env.txt bulunamadi. Proje kokune env.txt dosyasi eklemelisin."
}

$envValues = Read-EnvFile -Path $envFile
$supabaseUrl = $envValues['SUPABASE_URL']
$supabaseAnonKey = $envValues['SUPABASE_ANON_KEY']

if ([string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  $supabaseAnonKey = $envValues['SUPABASE_KEY']
}

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw 'env.txt icinde SUPABASE_URL ve SUPABASE_ANON_KEY (veya SUPABASE_KEY) bulunmali.'
}

$flutterArgs = @()

switch ($Action) {
  'run' {
    $flutterArgs += @('run', '-d', $Device)
  }
  'test' {
    $flutterArgs += @('test', 'test/widget_test.dart')
  }
  'build-web' {
    $flutterArgs += @('build', 'web')
  }
  'build-windows' {
    $flutterArgs += @('build', 'windows')
  }
  'build-apk' {
    $flutterArgs += @('build', 'apk')
  }
  'build-appbundle' {
    $flutterArgs += @('build', 'appbundle')
  }
}

if ($Action -ne 'test') {
  $flutterArgs += "--dart-define=SUPABASE_URL=$supabaseUrl"
  $flutterArgs += "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"

  if ($envValues.ContainsKey('ONESIGNAL_APP_ID') -and -not [string]::IsNullOrWhiteSpace($envValues['ONESIGNAL_APP_ID'])) {
    $flutterArgs += "--dart-define=ONESIGNAL_APP_ID=$($envValues['ONESIGNAL_APP_ID'])"
  }
}

Push-Location $projectRoot
try {
  Write-Host "Action: $Action"
  if ($Action -eq 'run') {
    Write-Host "Device: $Device"
  }
  & 'C:\flutter\bin\flutter.bat' @flutterArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
