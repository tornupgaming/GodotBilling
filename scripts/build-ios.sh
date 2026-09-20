#!/bin/sh
# Builds the iOS libraries and collects them in bin/ios/plugins/. Requires macOS, Xcode and SCons.
set -eu

cd "$(dirname "$0")/.."

sh src/ios/scripts/build.sh

rm -rf bin/ios/plugins
mkdir -p bin/ios/plugins
cp src/ios/bin/*.a bin/ios/plugins/
cp src/ios/godot_billing.gdip bin/ios/plugins/
