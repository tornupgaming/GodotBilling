# Third-party notices

First-party code (the StoreKit implementation in `src/ios/godot_plugin/godot_iap.*`, the haptics
code, the GDScript mock and types, the build scripts and the changes to the Android plugin) is
MIT licensed, Copyright (c) Torn Up Gaming; see [LICENSE](LICENSE). The parts below come from other
projects and keep their own terms.

## Godot iOS plugin template (`src/ios`)

`src/ios/SConstruct`, `src/ios/godot_plugin.xcodeproj`, `src/ios/.gitignore` and the plugin entry
point skeleton (`godot_plugin.h`, `godot_plugin.mm`, and the class skeleton that
`haptics_plugin.*` started from) derive from the Godot iOS plugin template by Sergey Minakov:

- Source: <https://github.com/naithar/godot_ios_plugin>, imported with its history (the commits by
  Sergey Minakov, 2020-2021). File headers read "Created by Sergey Minakov on 14.08.2020.
  Copyright © 2020 Godot."
- **Licence status: the upstream repository publishes no licence file** (checked 2026-09-20), so
  no licence text can be reproduced here for it. The same author contributed the same template
  (SConstruct and plugin skeleton) to the official
  [godotengine/godot-ios-plugins](https://github.com/godotengine/godot-ios-plugins) repository,
  where it is published under the MIT licence reproduced below. Our MIT licence cannot grant
  rights to these files. The template exists to be copied, so the practical risk is low, but to
  close the gap either ask the author to add a licence upstream or re-base these files on the
  godot-ios-plugins versions.
- `SConstruct` credits <https://github.com/BastiaanOlij/gdnative_cpp_example> for most of its
  settings.

```
MIT License

Copyright (c) 2021 Godot Engine

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Godot Google Play Billing (`src/android`)

`src/android` is a modified copy of
[godotengine/godot-google-play-billing](https://github.com/godotengine/godot-google-play-billing),
MIT licence, Copyright (c) 2020 Godot Engine. The full text is kept in
[src/android/LICENSE](src/android/LICENSE).

## Godot Engine (`src/ios/godot` submodule)

Not part of this repository's contents; it is referenced as a git submodule and only its headers
are used at build time. Godot Engine is MIT licensed, Copyright (c) 2014-present Godot Engine
contributors and Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Games that ship these
binaries already ship Godot and must carry its notice; see `src/ios/godot/LICENSE.txt` and
`COPYRIGHT.txt`.

## Google Play Billing Library

The Android plugin declares `com.android.billingclient:billing` as a remote dependency. It is not
bundled here; it is fetched by Gradle and is subject to the Android Software Development Kit
License Agreement.
