# Windows: builds the Android part, fetches the iOS build outputs from the Mac (widilo/build-ios.sh) and packs the
# .NET 10 Android + iOS package into widilo/out/. The version is the one in AdjustSdk.nuspec.
param(
    [Parameter(Mandatory)][string]$MacHost,
    # Path of the fork clone on the Mac, relative to the home directory
    [Parameter(Mandatory)][string]$MacRepoPath
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
Set-Location $repository

git diff --quiet HEAD
if ($LASTEXITCODE -ne 0) { throw 'Commit or discard the local changes first: the package must come from a single commit' }

$commit = git rev-parse HEAD

# A version number is tied to one commit: NuGet caches would silently keep the first content published under it
$version = ([xml](Get-Content AdjustSdk.nuspec -Raw)).package.metadata.version
$versionTag = "widilo/$version"
$taggedCommit = git rev-parse -q --verify "refs/tags/$versionTag^{commit}"
if ($taggedCommit -and $taggedCommit -ne $commit) { throw "Version $version was already built from commit ${taggedCommit}: set a new -widilo.N in AdjustSdk.nuspec" }

$iosCommit = ssh $MacHost "cat '$MacRepoPath/.artifacts/widilo-ios-commit'"
if ($LASTEXITCODE -ne 0) { throw 'No iOS build on the Mac: run widilo/build-ios.sh there first' }
if ($iosCommit -ne $commit) { throw "The Mac built commit ${iosCommit}, Windows is on ${commit}: update the Mac clone and run widilo/build-ios.sh again" }

Remove-Item -Recurse -Force .artifacts -ErrorAction SilentlyContinue

& "$env:ProgramFiles\Git\bin\bash.exe" widilo/fetch-natives.sh android
if ($LASTEXITCODE -ne 0) { throw 'fetch-natives.sh android failed' }

dotnet build AdjustSdk/AdjustSdk.csproj -f net10.0-android36.0 -c Release -m:4
if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }

$iosOutputs = @{
    'AdjustSdk/bin/Release/net10.0-ios26.2'            = @('AdjustSdk.dll')
    'AdjustSdk.iOSBinding/bin/Release/net10.0-ios26.2' = @('AdjustSdk.iOSBinding.dll', 'AdjustSdk.iOSBinding.resources.zip')
}

foreach ($folder in $iosOutputs.Keys) {
    New-Item -ItemType Directory -Force ".artifacts/$folder" | Out-Null

    foreach ($file in $iosOutputs[$folder]) {
        scp -q "${MacHost}:$MacRepoPath/.artifacts/$folder/$file" ".artifacts/$folder/$file"
        if ($LASTEXITCODE -ne 0) { throw "Missing iOS output ${folder}/${file}: run widilo/build-ios.sh on the Mac first" }
    }
}

# Shope only targets .NET 10: the .NET 8 entries of the official nuspec are left out
$work = Join-Path ([IO.Path]::GetTempPath()) "adjust-widilo-pack"
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
New-Item -ItemType Directory $work | Out-Null

Get-Content AdjustSdk.nuspec | Where-Object { $_ -notmatch 'net8\.0' -and $_ -notmatch '\.NET 8' } | Set-Content "$work/AdjustSdk.nuspec" -Encoding utf8

@"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <IncludeBuildOutput>false</IncludeBuildOutput>
    <NuspecFile>$work/AdjustSdk.nuspec</NuspecFile>
    <NuspecBasePath>$repository</NuspecBasePath>
    <NoWarn>NU5100;NU5128</NoWarn>
  </PropertyGroup>
</Project>
"@ | Set-Content "$work/pack.csproj" -Encoding utf8

dotnet pack "$work/pack.csproj" -c Release -o "$repository/widilo/out" -m:4
if ($LASTEXITCODE -ne 0) { throw 'Pack failed' }

Remove-Item -Recurse -Force $work

if (-not $taggedCommit) {
    git tag $versionTag
    Write-Host "Tag $versionTag created: push it with the commit (git push origin main $versionTag)"
}

Get-ChildItem "$repository/widilo/out/*.nupkg" | Select-Object Name, Length
