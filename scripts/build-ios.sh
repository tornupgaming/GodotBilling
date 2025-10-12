
mkdir -p ./bin/ios/plugins

cd src/ios
sh ./scripts/build.sh

cp -r ./bin/**.a ../../bin/ios/plugins
cp ./godot_billing.gdip ../../bin/ios/plugins/godot_billing.gdip