$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$scaffold = Join-Path $env:TEMP "hyper_dammam3_android_scaffold"
$androidDir = Join-Path $projectRoot "android"
$wrapperDir = Join-Path $androidDir "gradle\wrapper"

if (Test-Path $scaffold) {
    Remove-Item $scaffold -Recurse -Force
}

flutter create --platforms=android --project-name hyper_dammam3 --org com.example $scaffold
New-Item -ItemType Directory -Force -Path $wrapperDir | Out-Null
Copy-Item (Join-Path $scaffold "android\gradlew") (Join-Path $androidDir "gradlew") -Force
Copy-Item (Join-Path $scaffold "android\gradlew.bat") (Join-Path $androidDir "gradlew.bat") -Force
Copy-Item (Join-Path $scaffold "android\gradle\wrapper\gradle-wrapper.jar") (Join-Path $wrapperDir "gradle-wrapper.jar") -Force

@'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
'@ | Set-Content -Encoding ASCII (Join-Path $wrapperDir "gradle-wrapper.properties")

Write-Host "Gradle Wrapper files prepared. You can now run: flutter pub get; flutter analyze; flutter test; flutter build apk --release" -ForegroundColor Green
