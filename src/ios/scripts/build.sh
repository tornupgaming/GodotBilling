
ARCH="arm64"
TARGET="godot_billing"

rm -rf ./bin/*.a

# Release build
scons target=release arch="$ARCH" target_name="$TARGET" version=4.0
mv ./bin/lib"$TARGET"."$ARCH"-iphone.release.a ./bin/"$TARGET".release.a
cp ./bin/"$TARGET".release.a ./bin/"$TARGET".a

# Debug build
scons target=release_debug arch="$ARCH" target_name="$TARGET" version=4.0
mv ./bin/lib"$TARGET"."$ARCH"-iphone.release_debug.a ./bin/"$TARGET".debug.a