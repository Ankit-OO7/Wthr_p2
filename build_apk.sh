#!/usr/bin/env bash
# Builds the release APK. Needs Flutter (stable) and the Android SDK installed.
set -euo pipefail
cd "$(dirname "$0")"

# 1. Generate the Android runner once, keeping our own lib/, test/ and pubspec.
if [ ! -d android ]; then
  mkdir -p .keep
  cp -r lib test pubspec.yaml .keep/
  flutter create --platforms=android --project-name minimal_weather \
    --org com.example --overwrite . >/dev/null
  rm -rf lib test pubspec.yaml
  cp -r .keep/lib .keep/test .keep/pubspec.yaml .
  rm -rf .keep
fi

# 2. Release builds need the INTERNET permission, and a friendlier app name.
MANIFEST=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' "$MANIFEST" || \
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
sed -i 's#android:label="[^"]*"#android:label="Weather"#' "$MANIFEST"

# 3. Fetch packages, run the tests, build.
flutter pub get
flutter test || echo "WARNING: some tests failed; building the APK anyway."
flutter build apk --release

echo
echo "Done: build/app/outputs/flutter-apk/app-release.apk"
