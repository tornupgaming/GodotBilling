//
//  godot_plugin.m
//  godot_plugin
//
//  Created by Sergey Minakov on 14.08.2020.
//  Copyright © 2020 Godot. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "godot_plugin.h"
#import "haptics_plugin.h"
#import "billing_plugin.h"
#import "godot_iap.h"

#import "core/config/engine.h"

HapticsPlugin *hapticsPlugin;
GodotIOSBilling *billingPlugin;
GodotIAP *iapPlugin;

void godot_plugin_init() {
	NSLog(@"init plugin");

	hapticsPlugin = memnew(HapticsPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Haptics", hapticsPlugin));

	iapPlugin = memnew(GodotIAP);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GodotBilling", iapPlugin));
}

void godot_plugin_deinit() {
	NSLog(@"deinit plugin");
	if (hapticsPlugin) {
		memdelete(hapticsPlugin);
	}
	if (iapPlugin) {
		memdelete(iapPlugin);
	}
}
