$ErrorActionPreference = 'Stop'
$projectRoot = (Get-Location).Path
$sourceRoot = Join-Path $projectRoot 'modular_refactor'

if (-not (Test-Path (Join-Path $projectRoot 'pubspec.yaml'))) {
  throw 'Run this script from the KhataFlow project root (the folder containing pubspec.yaml).'
}
if (-not (Test-Path $sourceRoot)) {
  throw 'Could not find .\modular_refactor. Extract the refactor ZIP into the project root first.'
}

$required = @(
  'lib\main.dart',
  'lib\app\khata_flow_app.dart',
  'lib\core\theme\app_theme.dart',
  'lib\features\auth\auth_gate.dart',
  'lib\features\auth\screens\login_screen.dart',
  'lib\features\auth\screens\signup_screen.dart',
  'lib\features\auth\screens\forgot_password_screen.dart',
  'lib\features\business\business_home_screen.dart',
  'lib\features\business\parts\dashboard_page.dart',
  'lib\features\business\parts\parties_page.dart',
  'lib\features\business\parts\transactions_page.dart',
  'lib\features\business\parts\expenses_page.dart',
  'lib\features\business\parts\more_page.dart'
)
foreach ($relative in $required) {
  if (-not (Test-Path (Join-Path $sourceRoot $relative))) {
    throw "Missing expected source file: $relative. No files have been copied."
  }
}

$gitDir = Join-Path $projectRoot '.git'
if (Test-Path $gitDir) {
  $backupRoot = Join-Path $gitDir 'khataflow-pre-modular-refactor'
} else {
  $backupRoot = Join-Path $projectRoot '.khataflow_backup'
}
New-Item -ItemType Directory -Force $backupRoot | Out-Null

$toBackup = @(
  'lib\main.dart',
  'lib\features\business\business_home_screen.dart'
)
foreach ($relative in $toBackup) {
  $original = Join-Path $projectRoot $relative
  if (Test-Path $original) {
    $backup = Join-Path $backupRoot $relative
    New-Item -ItemType Directory -Force (Split-Path -Parent $backup) | Out-Null
    Copy-Item -LiteralPath $original -Destination $backup -Force
  }
}

Get-ChildItem $sourceRoot -Recurse -File | ForEach-Object {
  $relativePath = $_.FullName.Substring($sourceRoot.Length).TrimStart('\','/')
  $destination = Join-Path $projectRoot $relativePath
  New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
}

Write-Host 'KhataFlow modular refactor copied successfully.' -ForegroundColor Green
Write-Host 'Backups of replaced files are stored at:' $backupRoot
Write-Host 'No Flutter build or Firebase operation was run.'
