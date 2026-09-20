#!/bin/sh
# Builds the iOS static libraries into src/ios/bin/. Can be run from any directory.
set -eu

cd "$(dirname "$0")/.."

ARCH="arm64"
TARGET="godot_billing"

# Engine headers that only exist after generation. These are all the plugin sources include; if a
# future Godot version needs more, the compile below fails with "file not found" naming the header.
GODOT_GENERATED_HEADERS="core/disabled_classes.gen.h core/extension/gdextension_interface.gen.h"

if [ ! -f godot/SConstruct ]; then
	echo "error: src/ios/godot is empty. Run: git submodule update --init --depth 1 src/ios/godot" >&2
	exit 1
fi

command -v scons >/dev/null || { echo "error: scons not found (pip3 install scons)" >&2; exit 1; }

# Naming the headers as targets makes SCons generate just those files (seconds, no engine build).
# shellcheck disable=SC2086
(cd godot && scons platform=ios target=template_release arch="$ARCH" $GODOT_GENERATED_HEADERS)

mkdir -p bin
rm -f bin/*.a

# Release build
scons target=release arch="$ARCH" target_name="$TARGET" version=4.0
mv bin/lib"$TARGET"."$ARCH"-iphone.release.a bin/"$TARGET".release.a
cp bin/"$TARGET".release.a bin/"$TARGET".a

# Debug build
scons target=release_debug arch="$ARCH" target_name="$TARGET" version=4.0
mv bin/lib"$TARGET"."$ARCH"-iphone.release_debug.a bin/"$TARGET".debug.a

GODOT_VERSION=$(python3 -B -c 'import sys; sys.path.insert(0, "godot"); import version as v; print("%d.%d.%d-%s" % (v.major, v.minor, v.patch, v.status))')
echo "Built against Godot $GODOT_VERSION ($(git -C godot rev-parse HEAD)):"
shasum -a 256 bin/"$TARGET".debug.a bin/"$TARGET".release.a godot_billing.gdip
