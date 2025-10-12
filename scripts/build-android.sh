rm -rf ./bin/android/plugins
mkdir -p ./bin/android/plugins

cd src/android
./gradlew build

cp -r ./godot-google-play-billing/build/outputs/aar/**.aar ../../bin/android/plugins
cp ./godot_billing.gdap ../../bin/android/plugins/godot_billing.gdap