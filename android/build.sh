#!/usr/bin/env bash
# Construit l'APK sans Gradle, avec les outils du SDK Android du runner GitHub.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"
JAR="$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)/android.jar"
VER="${VERSION_CODE:-1}"
echo "build-tools: $BT"; echo "platform: $JAR"
W="$ROOT/build"; rm -rf "$W"; mkdir -p "$W/classes" "$W/apk/assets" "$ROOT/out"
cp -r "$ROOT/www" "$W/apk/assets/www"
"$BT/aapt2" compile --dir "$ROOT/android/res" -o "$W/res.zip"
"$BT/aapt2" link -o "$W/base.apk" -I "$JAR" --manifest "$ROOT/android/AndroidManifest.xml" \
  --min-sdk-version 24 --target-sdk-version 34 --version-code "$VER" --version-name "1.0.$VER" \
  -A "$W/apk/assets" "$W/res.zip"
javac -source 11 -target 11 -encoding UTF-8 -classpath "$JAR" -d "$W/classes" $(find "$ROOT/android/src" -name '*.java')
"$BT/d8" --release --min-api 24 --lib "$JAR" --output "$W" $(find "$W/classes" -name '*.class')
cd "$W" && zip -q -j base.apk classes.dex && cd "$ROOT"
"$BT/zipalign" -f -p 4 "$W/base.apk" "$W/aligned.apk"
"$BT/apksigner" sign --ks "$ROOT/android/bug404.keystore" --ks-pass pass:brecheecarlate --key-pass pass:brecheecarlate \
  --out "$ROOT/out/FRACTURE.apk" "$W/aligned.apk"
"$BT/apksigner" verify --print-certs "$ROOT/out/FRACTURE.apk" | head -3
ls -la "$ROOT/out"
