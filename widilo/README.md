# Widilo build of the Adjust MAUI SDK

Internal package `Adjust.Maui.Sdk <upstream version>-widilo.<n>`: the official 5.5.0 wrapper with newer native SDKs and an iOS
fix (see `CHANGELOG.md`). .NET 10 Android and iOS only. Native libraries are never committed: they are downloaded at
build time from the official GitHub releases.

| File | Role |
|---|---|
| `versions.env` | Native iOS SDK, native Android SDK and Signature library versions |
| `fetch-natives.sh android\|ios` | Downloads those versions (iOS: Mac only) |
| `build-ios.sh` | Mac: builds the iOS part from a clean state |
| `pack.ps1` | Windows: builds the Android part, fetches the iOS part from the Mac, packs into `widilo/out/` |

## Build

Prerequisites: a Mac with Xcode, the .NET 10 SDK and the `ios` workload; a Windows machine with the .NET 10 SDK, the
`android` workload, Git for Windows and SSH access to the Mac. On Windows, clone into a short path (`C:\dev\...`): the
Android resource compiler fails on long paths.

1. Update `versions.env`, set a new `-widilo.N` in `AdjustSdk.nuspec` (never reuse a number), add a `CHANGELOG.md` entry,
   commit and push.
2. Mac, on a clone of the same commit:

   ```bash
   git pull && widilo/build-ios.sh
   ```

3. Windows, on the same commit:

   ```powershell
   .\widilo\pack.ps1 -MacHost <ssh host of the Mac> -MacRepoPath <clone path on the Mac, relative to its home>
   ```

   `pack.ps1` stops if the Mac built another commit, or if the version was already built from another commit. It tags
   the commit `widilo/<version>`: push the tag with `git push origin main widilo/<version>`.
4. Test the package in the app on iOS and Android before using it.

If the Android binding fails to compile on a class of a new native SDK, remove that class in
`android/AdjustSdk.AndroidBinding/Transforms/Metadata.xml` (5.8.1: `ObjectInputFilterStream`).
