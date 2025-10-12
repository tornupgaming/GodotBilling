//
//  haptics_implementation_h.h
//  haptics_plugin
//

#ifndef haptics_implementation_h
#define haptics_implementation_h

#include "core/object/class_db.h"

#ifdef __OBJC__
@class HapticsEngineWrapper;
#else
typedef struct objc_object HapticsEngineWrapper;
#endif

class HapticsPlugin : public Object {
  GDCLASS(HapticsPlugin, Object);

  static void _bind_methods();

  HapticsEngineWrapper *engine_wrapper;

 public:
  bool supports_haptics();
  Error light();
  Error medium();
  Error heavy();

  HapticsPlugin();
  ~HapticsPlugin();
};

#endif /* haptics_implementation_h */
