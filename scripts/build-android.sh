#!/bin/sh
# Builds the Android aars and collects them in bin/android/plugins/. Requires JDK 17 and the
# Android SDK (ANDROID_HOME, or sdk.dir in src/android/local.properties).
set -eu

cd "$(dirname "$0")/.."

if [ -z "${ANDROID_HOME:-}" ] && [ ! -f src/android/local.properties ]; then
	echo "error: set ANDROID_HOME or create src/android/local.properties with sdk.dir=<path>" >&2
	exit 1
fi

(cd src/android && ./gradlew build)

rm -rf bin/android/plugins
mkdir -p bin/android/plugins
cp src/android/godot-google-play-billing/build/outputs/aar/*.aar bin/android/plugins/
cp src/android/godot_billing.gdap bin/android/plugins/
