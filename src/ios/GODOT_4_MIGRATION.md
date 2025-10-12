# Godot 4.0 iOS Plugin Migration Changes

This document outlines the changes required to update the iOS plugin template from Godot 3.x to Godot 4.0.

## Summary

The plugin template required updates to header paths, build configuration, and compiler flags to work with Godot 4.0's restructured codebase.

## Changes Made

### 1. Header Path Updates

Godot 4.0 reorganized its core headers into subdirectories. The following headers were updated:

#### `godot_plugin/godot_plugin_implementation.h`
```diff
- #include "core/object.h"
+ #include "core/object/class_db.h"
```
**Reason:** In Godot 4.0, `object.h` moved to `core/object/object.h`, but we need `class_db.h` to provide the ClassDB definition required by the GDCLASS macro.

#### `godot_plugin/godot_plugin.mm`
```diff
- #import "core/engine.h"
+ #import "core/config/engine.h"
```
**Reason:** `engine.h` moved to the `core/config/` directory in Godot 4.0.

#### `godot_plugin/godot_plugin_implementation.mm`
```diff
- #include "core/project_settings.h"
- #include "core/class_db.h"
+ #include "core/config/project_settings.h"
+ #include "core/object/class_db.h"
```
**Reason:** Both headers were relocated to subdirectories in Godot 4.0's restructuring.

### 2. Platform Directory Name Change

#### `SConstruct`
```diff
- 'godot/platform/iphone',
+ 'godot/platform/ios',
```
**Reason:** Godot 4.0 renamed the platform directory from `iphone` to `ios`, causing `platform_config.h` to not be found.

### 3. Include Path Simplification

#### `SConstruct`
```diff
- env.Append(CPPPATH=[
-     '.',
-     'godot',
-     'godot/main',
-     'godot/core',
-     'godot/core/os',
-     'godot/core/platform',
-     'godot/platform/ios',
-     'godot/modules',
-     'godot/scene',
-     'godot/servers',
-     'godot/drivers',
-     'godot/thirdparty',
- ])
+ env.Append(CPPPATH=[
+     '.',
+     'godot',
+     'godot/platform/ios',
+ ])
```
**Reason:** Simplified to match the working configuration pattern used in other Godot 4.0 iOS plugins. Excessive include paths can cause header resolution issues.

### 5. Header Ordering Fix

#### `godot_plugin/godot_plugin.mm`
```diff
+ #include <time.h>
  #import <Foundation/Foundation.h>
```
**Reason:** Including `<time.h>` before Foundation.h ensures that `timespec` and `tm` structures are fully defined before Foundation pulls in conflicting declarations from the C++ standard library. This prevents "incomplete type" and "conflicting declaration" errors.

## Build Command

The build should now work with:
```bash
scons target=release arch=arm64 target_name=godot_plugin version=4.0
```

## Key Differences from Godot 3.x

1. **Header organization**: Core headers are now organized into subdirectories (`object/`, `config/`, etc.)
2. **Platform naming**: `iphone` platform is now `ios`
3. **Module flags**: C++ modules cause conflicts and must be disabled
4. **Header ordering**: More careful ordering required when mixing Foundation and Godot headers

## Reference

The working AdMob plugin project at `../godot-admob-ios` was used as a reference for the correct Godot 4.0 patterns.
