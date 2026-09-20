#!/bin/sh
# Builds both platforms into bin/.
set -eu

cd "$(dirname "$0")/.."

sh scripts/build-ios.sh
sh scripts/build-android.sh
