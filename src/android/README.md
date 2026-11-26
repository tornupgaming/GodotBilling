# godot-google-play-billing
Godot Android plugin for the Google Play Billing library


## Usage & Docs

You can find the docs for this first-party plugin in the [official Godot docs](https://docs.godotengine.org/en/stable/tutorials/platform/android_in_app_purchases.html).


## Compiling

Prerequisites:

- JDK 17 (Gradle 8.13 does not run on newer JDKs; point `JAVA_HOME` at it)
- Android SDK platform 36

Run `./gradlew assemble` here. Gradle downloads the Godot library and Play Billing from Maven.
The `.aar` files land in `./godot-google-play-billing/build/outputs/aar/`. Copy the release
`.aar` and `godot_billing.gdap` into the game's `android/plugins/` folder.
