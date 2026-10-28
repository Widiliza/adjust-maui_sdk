#!/bin/bash
# Mac only: downloads the iOS native libraries and builds the iOS part of the package from a clean state.
set -euo pipefail
cd "$(dirname "$0")/.."

git diff --quiet HEAD || { echo "Commit or discard the local changes first: pack.ps1 checks that Mac and Windows build the same commit" >&2; exit 1; }

rm -rf .artifacts
widilo/fetch-natives.sh ios
dotnet build AdjustSdk/AdjustSdk.csproj -f net10.0-ios26.2 -c Release -m:4

# Read by pack.ps1, which refuses iOS outputs built from another commit
git rev-parse HEAD > .artifacts/widilo-ios-commit

ls -la .artifacts/AdjustSdk/bin/Release/net10.0-ios26.2/AdjustSdk.dll \
  .artifacts/AdjustSdk.iOSBinding/bin/Release/net10.0-ios26.2/AdjustSdk.iOSBinding.dll \
  .artifacts/AdjustSdk.iOSBinding/bin/Release/net10.0-ios26.2/AdjustSdk.iOSBinding.resources.zip
