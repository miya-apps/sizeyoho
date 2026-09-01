param(
  [string]$ConfigPath = "config/ios.firebase.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedConfig = Join-Path $projectRoot $ConfigPath

if (-not (Test-Path -LiteralPath $resolvedConfig -PathType Leaf)) {
  Write-Error "iOS Firebase設定が見つかりません: $ConfigPath"
}

try {
  $config = Get-Content -LiteralPath $resolvedConfig -Raw | ConvertFrom-Json
} catch {
  Write-Error "iOS Firebase設定が有効なJSONではありません。"
}

$requiredKeys = @(
  "FIREBASE_IOS_API_KEY",
  "FIREBASE_IOS_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_PROJECT_ID",
  "FIREBASE_STORAGE_BUCKET",
  "FIREBASE_IOS_BUNDLE_ID"
)

$missingKeys = @()
foreach ($key in $requiredKeys) {
  $property = $config.PSObject.Properties[$key]
  if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
    $missingKeys += $key
  }
}
if ($missingKeys.Count -gt 0) {
  Write-Error ("iOS Firebase設定の必須項目が空です: " + ($missingKeys -join ", "))
}

if ($config.FIREBASE_IOS_BUNDLE_ID -ne "com.miyaapps.sizeyoho") {
  Write-Error "FirebaseのBundle IDがcom.miyaapps.sizeyohoと一致しません。"
}
if ($config.FIREBASE_PROJECT_ID -ne "sizeyoho") {
  Write-Error "Firebase Project IDがsizeyohoと一致しません。"
}
if ($config.FIREBASE_MESSAGING_SENDER_ID -ne "643895439317") {
  Write-Error "Firebase Sender IDがサイズ予報projectと一致しません。"
}
if ($config.FIREBASE_STORAGE_BUCKET -ne "sizeyoho.firebasestorage.app") {
  Write-Error "Firebase Storage Bucketがサイズ予報projectと一致しません。"
}
if ($config.FIREBASE_IOS_APP_ID -notmatch '^1:643895439317:ios:[0-9A-Fa-f]+$') {
  Write-Error "Firebase iOS App IDのproject prefixまたは形式が一致しません。"
}

Push-Location $projectRoot
try {
  & git check-ignore --quiet -- $ConfigPath
  if ($LASTEXITCODE -ne 0) {
    Write-Error "$ConfigPath が.gitignoreで保護されていません。"
  }
} finally {
  Pop-Location
}

Write-Host "OK: iOS Firebase設定の必須項目・project・Bundle ID・Git除外を確認しました。"
