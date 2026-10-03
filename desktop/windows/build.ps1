param([string]$Output = "$PSScriptRoot/build", [switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$Output = [System.IO.Path]::GetFullPath($Output)
function Invoke-Checked { param([string]$Command, [string[]]$Arguments); & $Command @Arguments; if ($LASTEXITCODE -ne 0) { throw "$Command failed ($LASTEXITCODE)" } }
Invoke-Checked cmake @('-S', "$PSScriptRoot/native", '-B', "$Output/native", '-A', 'x64')
Invoke-Checked cmake @('--build', "$Output/native", '--config', 'Release')
$Native = "$Output/native/Release/MosaicGeometry.dll"
if (-not $SkipTests) {
    Invoke-Checked dotnet @('run', '--project', "$PSScriptRoot/Tests/Mosaic.Tests.csproj", '-c', 'Release', "-p:MosaicNativeLibrary=$Native")
}
Invoke-Checked dotnet @('publish', "$PSScriptRoot/Mosaic/Mosaic.csproj", '-c', 'Release', '-r', 'win-x64', '--self-contained', 'true', "-p:MosaicNativeLibrary=$Native", '-o', "$Output/Mosaic")
Write-Output "Portable application: $Output/Mosaic/Mosaic.exe"
