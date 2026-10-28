#!/bin/bash
# Downloads the native Adjust SDKs and Signature library named in versions.env from the official GitHub releases.
# Usage: widilo/fetch-natives.sh android|ios
set -euo pipefail
cd "$(dirname "$0")/.."
source widilo/versions.env

platform="${1:?android or ios}"
download() { curl -fsSL --retry 3 -o "$1" "$2"; }

case "$platform" in
android)
  libs=android/AdjustSdk.AndroidBinding/libs
  mkdir -p "$libs"
  download "$libs/adjust-android.aar" "https://github.com/adjust/android_sdk/releases/download/v$ANDROID_SDK_VERSION/adjust-android-$ANDROID_SDK_VERSION.aar"
  download "$libs/adjust-android-signature.aar" "https://github.com/adjust/adjust_signature_sdk/releases/download/v$SIGNATURE_VERSION/adjust-android-signature-$SIGNATURE_VERSION.aar"
  ;;
ios)
  # ditto keeps the framework symlinks, which unzip on Windows would not
  binding=ios/AdjustSdk.iOSBinding
  work=$(mktemp -d)
  download "$work/sdk.zip" "https://github.com/adjust/ios_sdk/releases/download/v$IOS_SDK_VERSION/AdjustSdk-iOS-tvOS-Dynamic-$IOS_SDK_VERSION.xcframework.zip"
  download "$work/signature.zip" "https://github.com/adjust/adjust_signature_sdk/releases/download/v$SIGNATURE_VERSION/AdjustSigSdk-iOS-tvOS-Dynamic-$SIGNATURE_VERSION.xcframework.zip"
  rm -rf "$binding/AdjustSdk.xcframework" "$binding/AdjustSigSdk.xcframework"
  ditto -x -k "$work/sdk.zip" "$work/sdk"
  mv "$work/sdk/AdjustSdk-iOS-tvOS-Dynamic-xcframework/AdjustSdk.xcframework" "$binding/"
  ditto -x -k "$work/signature.zip" "$binding/"
  rm -rf "$work"
  plutil -p "$binding/AdjustSdk.xcframework/ios-arm64/AdjustSdk.framework/Info.plist" | grep -q "\"$IOS_SDK_VERSION\"" || { echo "AdjustSdk.xcframework is not $IOS_SDK_VERSION" >&2; exit 1; }
  ;;
*)
  echo "Unknown platform: $platform" >&2; exit 1
  ;;
esac

echo "Native libraries for $platform downloaded (iOS $IOS_SDK_VERSION, Android $ANDROID_SDK_VERSION, Signature $SIGNATURE_VERSION)"
