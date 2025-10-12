//
//  godot_plugin_implementation.m
//  godot_plugin
//
//  Created by Sergey Minakov on 14.08.2020.
//  Copyright © 2020 Godot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreHaptics/CoreHaptics.h>

#include "core/config/project_settings.h"
#include "core/object/class_db.h"

#import "haptics_plugin.h"

// Objective-C wrapper to hold the CHHapticEngine
@interface HapticsEngineWrapper : NSObject
@property (nonatomic, strong) CHHapticEngine *engine;
@property (nonatomic, assign) BOOL supportsHaptics;

- (instancetype)init;
- (void)playHapticWithIntensity:(float)intensity sharpness:(float)sharpness;
@end

@implementation HapticsEngineWrapper

- (instancetype)init {
    self = [super init];
    if (self) {
        // Check if the device supports haptics
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware.supportsHaptics;

        if (self.supportsHaptics) {
            NSError *error = nil;
            self.engine = [[CHHapticEngine alloc] initAndReturnError:&error];

            if (error) {
                NSLog(@"Error creating haptic engine: %@", error.localizedDescription);
                self.supportsHaptics = NO;
                return self;
            }

            // Start the engine
            [self.engine startAndReturnError:&error];
            if (error) {
                NSLog(@"Error starting haptic engine: %@", error.localizedDescription);
            }
        } else {
            NSLog(@"Haptics not supported on this device");
        }
    }
    return self;
}

- (void)playHapticWithIntensity:(float)intensity sharpness:(float)sharpness {
    if (!self.supportsHaptics || !self.engine) {
        return;
    }

    // Create haptic pattern
    CHHapticEventParameter *intensityParam = [[CHHapticEventParameter alloc]
        initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity];
    CHHapticEventParameter *sharpnessParam = [[CHHapticEventParameter alloc]
        initWithParameterID:CHHapticEventParameterIDHapticSharpness value:sharpness];

    CHHapticEvent *event = [[CHHapticEvent alloc]
        initWithEventType:CHHapticEventTypeHapticTransient
        parameters:@[intensityParam, sharpnessParam]
        relativeTime:0];

    NSError *error = nil;
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event]
        parameters:@[] error:&error];

    if (error) {
        NSLog(@"Error creating haptic pattern: %@", error.localizedDescription);
        return;
    }

    id<CHHapticPatternPlayer> player = [self.engine createPlayerWithPattern:pattern error:&error];
    if (error) {
        NSLog(@"Error creating haptic player: %@", error.localizedDescription);
        return;
    }

    [player startAtTime:0 error:&error];
    if (error) {
        NSLog(@"Error playing haptic: %@", error.localizedDescription);
    }
}

- (void)dealloc {
    if (self.engine) {
        [self.engine stopWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error stopping haptic engine: %@", error.localizedDescription);
            }
        }];
    }
}

@end

// C++ implementation
void HapticsPlugin::_bind_methods() {
    ClassDB::bind_method(D_METHOD("supports_haptics"), &HapticsPlugin::supports_haptics);
    ClassDB::bind_method(D_METHOD("light"), &HapticsPlugin::light);
    ClassDB::bind_method(D_METHOD("medium"), &HapticsPlugin::medium);
    ClassDB::bind_method(D_METHOD("heavy"), &HapticsPlugin::heavy);
}

bool HapticsPlugin::supports_haptics() {
    if (engine_wrapper) {
        return [engine_wrapper supportsHaptics];
    }
    return false;
}

Error HapticsPlugin::light() {
    if (engine_wrapper && [engine_wrapper supportsHaptics]) {
        [engine_wrapper playHapticWithIntensity:0.5f sharpness:0.3f];
        return OK;
    }
    return FAILED;
}

Error HapticsPlugin::medium() {
    if (engine_wrapper && [engine_wrapper supportsHaptics]) {
        [engine_wrapper playHapticWithIntensity:0.7f sharpness:0.5f];
        return OK;
    }
    return FAILED;
}

Error HapticsPlugin::heavy() {
    if (engine_wrapper && [engine_wrapper supportsHaptics]) {
        [engine_wrapper playHapticWithIntensity:1.0f sharpness:0.8f];
        return OK;
    }
    return FAILED;
}

HapticsPlugin::HapticsPlugin() {
    NSLog(@"Haptics plugin initialising");
    engine_wrapper = [[HapticsEngineWrapper alloc] init];
}

HapticsPlugin::~HapticsPlugin() {
    NSLog(@"Haptics plugin destructor");
    engine_wrapper = nil;
}
