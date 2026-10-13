$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$mainPath = Join-Path $projectRoot 'lib\main.dart'
$gitDirectory = Join-Path $projectRoot '.git'

if (-not (Test-Path $mainPath)) {
  throw "Could not find lib\main.dart. Extract this bundle into the root of your KhataFlow project and run the script again."
}

$source = [System.IO.File]::ReadAllText($mainPath)
$importLine = "import 'features/business/business_home_screen.dart';"
$authImport = "import 'package:firebase_auth/firebase_auth.dart';"

if ($source -notmatch [regex]::Escape($importLine)) {
  $firebaseOptionsImport = "import 'firebase_options.dart';"
  $importIndex = $source.IndexOf($firebaseOptionsImport)
  if ($importIndex -lt 0) {
    throw "Could not find the firebase_options.dart import. No files were changed."
  }
  $insertAt = $importIndex + $firebaseOptionsImport.Length
  $source = $source.Insert($insertAt, "`r`n$importLine")
}

if ($source -notmatch [regex]::Escape($authImport)) {
  $materialImport = "import 'package:flutter/material.dart';"
  $importIndex = $source.IndexOf($materialImport)
  if ($importIndex -lt 0) {
    throw "Could not find the Flutter material import. No files were changed."
  }
  $insertAt = $importIndex + $materialImport.Length
  $source = $source.Insert($insertAt, "`r`n$authImport")
}

# Keep all authentication and AuthGate code. Replace only the old placeholder home screen.
$marker = '// Temporary authenticated landing screen.'
$markerIndex = $source.IndexOf($marker)
if ($markerIndex -ge 0) {
  $source = $source.Substring(0, $markerIndex)
} else {
  # Supports re-running the script if the first run already installed the wrapper.
  $classMarker = 'class HomeScreen extends StatelessWidget'
  $classIndex = $source.LastIndexOf($classMarker)
  if ($classIndex -lt 0) {
    throw "Could not locate the old HomeScreen placeholder. No files were changed."
  }
  $source = $source.Substring(0, $classIndex)
}

$wrapper = @'
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return BusinessHomeScreen(user: user);
  }
}
'@
$source = $source.TrimEnd() + "`r`n`r`n" + $wrapper.Trim() + "`r`n"

if (Test-Path $gitDirectory) {
  $backupPath = Join-Path $gitDirectory 'khataflow-main.dart.before-modules.bak'
  if (-not (Test-Path $backupPath)) {
    [System.IO.File]::Copy($mainPath, $backupPath)
  }
}

[System.IO.File]::WriteAllText($mainPath, $source, [System.Text.UTF8Encoding]::new($false))
Write-Host 'KhataFlow workspace integration complete.' -ForegroundColor Green
Write-Host 'Your existing AuthGate and AuthScreen were preserved.'
Write-Host 'The old placeholder HomeScreen now opens BusinessHomeScreen.'
if (Test-Path $gitDirectory) {
  Write-Host 'A one-time backup of main.dart is stored inside .git.'
}
