param(
  [ValidateSet('release', 'debug', 'profile')]
  [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'

Push-Location $PSScriptRoot
try {
  flutter build apk --$Mode --split-per-abi

  $apkDir = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk'
  if (-not (Test-Path $apkDir)) {
    throw "APK output directory tidak ditemukan: $apkDir"
  }

  Get-ChildItem $apkDir -Filter "app-*-$Mode.apk" | ForEach-Object {
    $newName = $_.Name -replace '^app-', 'quiz-qta-'
    Rename-Item -LiteralPath $_.FullName -NewName $newName -Force
  }

  Write-Host "APK siap di: $apkDir"
  Get-ChildItem $apkDir -Filter "quiz-qta-*-$Mode.apk" |
    Select-Object Name, Length |
    Format-Table -AutoSize
}
finally {
  Pop-Location
}
