# Build & release a new self-contained version of Quran AlKareem
# (publishes single-file self-contained exe + zip + VersionInfo.xml)
# Usage:  powershell -ExecutionPolicy Bypass -File build-release.ps1 -Version 1.0.1
param(
    [Parameter(Mandatory = $true)] [string]$Version
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$app  = Join-Path $root "QuranAlKareem.App\QuranAlKareem.App.csproj"
$name = "QuranAlKareem_v$Version"
$pub  = Join-Path $root "publish\$name"
$rel  = Join-Path $root "release"
$zip  = Join-Path $rel "$name.zip"
$xmlPath = Join-Path $root "deploy\VersionInfo.xml"

Write-Host ">> Setting version to $Version ..." -ForegroundColor Cyan
$csproj = Get-Content $app -Raw
$csproj = $csproj -replace '<Version>.*?</Version>', "<Version>$Version</Version>"
$csproj = $csproj -replace '<AssemblyVersion>.*?</AssemblyVersion>', "<AssemblyVersion>$Version.0</AssemblyVersion>"
$csproj = $csproj -replace '<FileVersion>.*?</FileVersion>', "<FileVersion>$Version.0</FileVersion>"
Set-Content $app $csproj -Encoding UTF8

Write-Host ">> Publishing (self-contained, single-file) ..." -ForegroundColor Cyan
dotnet publish $app -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o $pub --nologo
if ($LASTEXITCODE -ne 0) { throw "publish failed" }

Write-Host ">> Bundling database and Data files ..." -ForegroundColor Cyan
$db = Join-Path $root "QuranAlKareem.App\bin\Debug\net9.0-windows\quran.db"
if (Test-Path $db) { Copy-Item $db (Join-Path $pub "quran.db") -Force }
$data = Join-Path $root "QuranAlKareem.App\bin\Release\net9.0-windows\win-x64\Data"
if (Test-Path $data) { Copy-Item $data (Join-Path $pub "Data") -Recurse -Force }
Remove-Item (Join-Path $pub "*.pdb") -Force -ErrorAction SilentlyContinue

Write-Host ">> Zipping ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force $rel | Out-Null
Remove-Item $zip -ErrorAction SilentlyContinue
Compress-Archive -Path "$pub\*" -DestinationPath $zip -CompressionLevel Optimal

Write-Host ">> Writing VersionInfo.xml ..." -ForegroundColor Cyan
$xml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`r`n"
$xml += "<item>`r`n"
$xml += "  <version>$Version.0</version>`r`n"
$xml += "  <url>https://update.alraed-iq.com/quran_alihasan/$name.zip</url>`r`n"
$xml += "  <changelog>https://update.alraed-iq.com/quran_alihasan/changelog.html</changelog>`r`n"
$xml += "  <mandatory mode=`"2`">false</mandatory>`r`n"
$xml += "</item>`r`n"
Set-Content $xmlPath $xml -Encoding UTF8

$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host "DONE. Upload these two files to update.alraed-iq.com/quran_alihasan/ :" -ForegroundColor Green
Write-Host "   1) $zip  ($mb MB)"
Write-Host "   2) $xmlPath"
