# MotoLog — dev machine history and reinstall guide

Everything installed on the owner's Windows PC to build MotoLog (2026-09-23 →
2026-09-26), with exact versions, so a future session can set the machine up
again to update the app. After v1.0.1 the owner asked for all of it to be
removed; this file is the record. **Claude: to update MotoLog later, follow
"Reinstall" top to bottom, then `docs/STATUS.md`.**

## What was installed (versions used for v1.0.1)

| Item | Version / details | Where it lived | Size |
|---|---|---|---|
| Flutter SDK (stable) | **3.47.5** (Dart 3.13.4, DevTools 2.60.0, framework rev 6a19cca564) | `C:\dev\flutter`, user PATH `C:\dev\flutter\bin` | 1.5 GB |
| Android Studio | 2026.1.4 (winget `Google.AndroidStudio`) — provides the JDK (bundled JBR) and the SDK wizard | `C:\Program Files\Android\Android Studio`, settings in `%APPDATA%` / `%LOCALAPPDATA%\Google\AndroidStudio2026.1.4` | — |
| Android SDK | cmdline-tools 23.0 (`latest`), platform-tools 37.0.1, emulator 37.1.11, build-tools 36.0.0, platforms android-35 / 36 / 37.0, NDK 28.2.13676358 (Gradle auto-download), CMake 3.22.1 | `%LOCALAPPDATA%\Android\Sdk` | 11.6 GB |
| Emulator images | `system-images;android-36;google_apis;x86_64`, `system-images;android-24;google_apis;x86_64` | in the SDK | (incl.) |
| Emulators (AVDs) | `motolog_api36` (Android 16, 1080×2340, main QA device), `motolog_api24` (Android 7, minSdk check) | `%USERPROFILE%\.android\avd` | — |
| Debug signing key | `%USERPROFILE%\.android\debug.keystore` — **signed the released APKs 1.0.0 and 1.0.1** | `%USERPROFILE%\.android` | — |
| Gradle caches | Android builds (Gradle wrapper + deps + Kotlin) | `%USERPROFILE%\.gradle` | 4.7 GB |
| Dart/Flutter packages cache | `flutter pub get` downloads | `%LOCALAPPDATA%\Pub\Cache` | 0.5 GB |
| GitHub CLI | 2.101.0 (winget `GitHub.cli`), logged in as Abdullah8873 | Program Files | — |
| VS Code extensions | `Dart-Code.dart-code`, `Dart-Code.flutter` | `%USERPROFILE%\.vscode\extensions` | — |
| Windows Developer Mode | turned on by the owner (Flutter plugins need symlinks) | Settings → System → For developers | — |

Already on the PC before the project (not ours to remove): Git, Node.js,
ffmpeg, Google Chrome (+ Claude in Chrome), Docker, VS Code, BlueStacks 5
with Drivvo (reference app — view only).

Hosted, nothing local: Supabase project `motolog` (ref
`ibizgqnhurgvhyclfqza`, region ap-northeast-2), GitHub repo
`Abdullah8873/Drivvo` (private; releases v1.0.0, v1.0.1 with
`MotoLog-1.0.1-arm64.apk`), Google Cloud OAuth clients (if created).

## Signing key — read before the next release

The debug key that signed 1.0.0/1.0.1 was deleted with `.android` on
2026-09-26 (after the 1.0.1 release). A new machine creates a **new** debug
key, so the next APK has a different signature and Android refuses to
install it over 1.0.1 ("App not installed" / signature conflict). Each phone
must uninstall MotoLog once and install the new build — **sign in and sync
first** (data comes back from Supabase after signing in again; offline-only
data would be lost, so export a backup: Settings → Backup & restore).

Do this once, at the next update, and never again:
1. Create a real upload key and keep it **outside the repo, backed up**
   (password manager / cloud drive):
   `keytool -genkeypair -v -keystore %USERPROFILE%\motolog-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. `android/key.properties` (git-ignored) with `storePassword`,
   `keyPassword`, `keyAlias=upload`, `storeFile=<path>`; wire a `release`
   `signingConfig` in `android/app/build.gradle.kts` that reads it (falls
   back to debug when the file is missing).
3. Add the same values as GitHub secrets (`ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`) so `release.yml` builds
   and publishes signed APKs on each `v*` tag. The same key is needed for the
   Play Store later.

## Reinstall (Windows, ~30–60 min + downloads)

1. **Flutter 3.47.5**
   ```
   git clone https://github.com/flutter/flutter.git -b stable C:\dev\flutter
   git -C C:\dev\flutter checkout 3.47.5
   ```
   Add `C:\dev\flutter\bin` to the user PATH (System → Environment
   variables), open a new terminal, `flutter --version`. (A newer stable
   usually works too; if analyze/tests break, go back to 3.47.5.)
2. **Android Studio** — `winget install Google.AndroidStudio`, launch it
   once and finish the setup wizard (installs SDK, platform-tools,
   emulator). Then SDK Manager → SDK Tools → "Android SDK Command-line
   Tools (latest)". Accept licences: `flutter doctor --android-licenses`.
   Extra packages (Gradle fetches NDK/CMake itself on the first build):
   ```
   sdkmanager "platforms;android-36" "platforms;android-35" "build-tools;36.0.0" "system-images;android-36;google_apis;x86_64" "system-images;android-24;google_apis;x86_64"
   ```
3. **Emulators**
   ```
   avdmanager create avd -n motolog_api36 -k "system-images;android-36;google_apis;x86_64" -d pixel_5
   avdmanager create avd -n motolog_api24 -k "system-images;android-24;google_apis;x86_64" -d pixel_5
   ```
   Start: `%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe -avd motolog_api36`.
4. **Windows Developer Mode** on (Settings → System → For developers).
5. **GitHub CLI** — `winget install GitHub.cli`, `gh auth login`.
6. **VS Code** (optional) — extension "Flutter" (`Dart-Code.flutter`).
7. **Project**
   ```
   git clone https://github.com/Abdullah8873/Drivvo.git   (or keep Desktop\Projects\APP)
   git config user.email 213306697+Abdullah8873@users.noreply.github.com
   ```
   Recreate `env/cloud.json` (git-ignored) if it's gone:
   ```json
   {
     "SUPABASE_URL": "https://ibizgqnhurgvhyclfqza.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "<Supabase → Project Settings → API keys → publishable>",
     "GOOGLE_WEB_CLIENT_ID": "<Google Cloud → Credentials, or empty>",
     "GOOGLE_ANDROID_CLIENT_ID": "<Google Cloud → Credentials, or empty>"
   }
   ```
   Then:
   ```
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   flutter analyze
   flutter test --timeout 45s
   flutter run -d chrome
   ```
8. `flutter doctor` must show Flutter, Android toolchain, Chrome ✓.
9. Release build: see `docs/STATUS.md` and the release checklist
   (`flutter build apk --release --split-per-abi --dart-define-from-file=env/cloud.json`).

Cloud (Linux) sessions don't need any of this: `docs/CLOUD-SESSION.md` +
`bash tool/cloud_setup.sh`.

## Removal log

- 2026-09-26 evening: Android Studio, the AVDs, `%USERPROFILE%\.android`
  (incl. debug.keystore) and the VS Code Dart/Flutter extensions were
  already gone when the cleanup session started (removed outside Claude).
- 2026-09-26 ~22:00, cleanup session (owner confirmed): deleted `C:\dev`
  (Flutter) and its user PATH entry, `%LOCALAPPDATA%\Android\Sdk`
  (11.6 GB), `%USERPROFILE%\.gradle` (4.7 GB), `%LOCALAPPDATA%\Pub`
  (0.5 GB), the Android Studio settings folder in `%APPDATA%\Google`, and
  the repo's regenerable `build/` + `.dart_tool/` (3 GB). ~22 GB freed.
- Kept on purpose: GitHub CLI (owner's choice), the repo with
  `env/cloud.json`, BlueStacks + Drivvo.
- Left behind (need admin / a reboot): the empty `C:\Program Files\Android`
  (admin to delete) and `%LOCALAPPDATA%\Google\AndroidStudio2026.1.4`
  holding one stale Android Studio socket file `.port` (Windows error 1920
  — deletable after a reboot). Both are a few bytes.
- Owner to do: turn Windows Developer Mode off if not needed (Settings → System → For developers).
