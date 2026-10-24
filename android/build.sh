#!/usr/bin/env bash
# Construit l'APK TestBot sans Gradle, avec les outils du SDK Android du runner GitHub.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"
JAR="$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)/android.jar"
VER="${VERSION_CODE:-1}"
echo "build-tools: $BT"; echo "platform: $JAR"
W="$ROOT/build"; rm -rf "$W"; mkdir -p "$W/classes" "$ROOT/out"
"$BT/aapt2" compile --dir "$ROOT/android/res" -o "$W/res.zip"
"$BT/aapt2" link -o "$W/base.apk" -I "$JAR" --manifest "$ROOT/android/AndroidManifest.xml" \
  --min-sdk-version 26 --target-sdk-version 34 --version-code "$VER" --version-name "1.$VER" \
  "$W/res.zip"
javac -source 11 -target 11 -encoding UTF-8 -Xlint:-options -classpath "$JAR" -d "$W/classes" $(find "$ROOT/android/src" -name '*.java')
"$BT/d8" --release --min-api 26 --lib "$JAR" --output "$W" $(find "$W/classes" -name '*.class')
cd "$W" && zip -q -j base.apk classes.dex && cd "$ROOT"
"$BT/zipalign" -f -p 4 "$W/base.apk" "$W/aligned.apk"
"$BT/apksigner" sign --ks "$ROOT/android/testbot.keystore" --ks-pass pass:testbotpass --key-pass pass:testbotpass \
  --out "$ROOT/out/TestBot.apk" "$W/aligned.apk"
"$BT/apksigner" verify --print-certs "$ROOT/out/TestBot.apk" | head -3
ls -la "$ROOT/out"
