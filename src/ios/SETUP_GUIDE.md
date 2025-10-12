# GodotIAP Plugin Setup Guide

## Overview

The GodotIAP plugin provides a unified In-App Purchase interface for both iOS and Android. This means you write your IAP code once and it works on both platforms.

## Building the Plugin

### Prerequisites

- Xcode 14+ (for iOS)
- Python 3
- SCons (`pip install scons`)
- Godot 4.x source code

### Build Commands

```bash
# Build for iOS device (arm64)
scons arch=arm64 target=release version=4.0 target_name=godot_plugin simulator=no

# Build for iOS simulator (arm64 for Apple Silicon Macs)
scons arch=arm64 target=release version=4.0 target_name=godot_plugin simulator=yes

# Build for iOS simulator (x86_64 for Intel Macs)
scons arch=x86_64 target=release version=4.0 target_name=godot_plugin simulator=yes
```

This will create static libraries in the `bin/` directory.

## Godot Project Setup

### 1. Copy Plugin Files

Copy the generated `.a` files and the plugin configuration to your Godot project:

```
your_godot_project/
└── ios/
    └── plugins/
        └── godot_plugin/
            ├── godot_plugin.gdip
            ├── libgodot_plugin.arm64-iphone.release.a
            └── libgodot_plugin.arm64-simulator.release.a
```

### 2. Enable the Plugin

In your Godot project, go to:
- **Project → Export → iOS**
- Under "Plugins", check the box for "godot_plugin"

### 3. Add Required Frameworks

In the iOS export settings, ensure these frameworks are enabled:
- **StoreKit.framework** (required for IAP)
- **Foundation.framework** (usually enabled by default)

### 4. Configure Products

#### iOS (App Store Connect)

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to "Features" → "In-App Purchases"
4. Create your products:
   - **Consumable**: Items that can be purchased multiple times (coins, power-ups)
   - **Non-Consumable**: One-time purchases (premium unlock, ad removal)
   - **Auto-Renewable Subscription**: Recurring subscriptions

5. Note the **Product ID** for each item (e.g., "coins_100", "premium_unlock")

#### Android (Google Play Console)

1. Set up your products in the Google Play Console
2. Ensure the product IDs match between iOS and Android

### 5. Add IAP Code to Your Game

See `EXAMPLE_USAGE.gd` for a complete example. Basic usage:

```gdscript
extends Node

var iap

func _ready():
    if Engine.has_singleton("GodotIAP"):
        iap = Engine.get_singleton("GodotIAP")
        iap.connect("billing_connected", self, "_on_billing_connected")
        iap.connect("purchase_updated", self, "_on_purchase_updated")
        iap.startConnection()

func _on_billing_connected(result):
    if result.status == 0:
        # Query your products
        iap.querySkuDetails(["coins_100", "premium_unlock"], "inapp")

func _on_purchase_updated(result):
    if result.status == 0:
        for purchase in result.purchases:
            # Grant the item to the player
            grant_item(purchase.sku)
            # Then consume or acknowledge
            if is_consumable(purchase.sku):
                iap.consumePurchase(purchase.purchase_token)
            else:
                iap.acknowledgePurchase(purchase.purchase_token)
```

## Testing

### iOS Sandbox Testing

1. **Create Sandbox Testers**:
   - Go to App Store Connect
   - Users and Access → Sandbox Testers
   - Add a test account

2. **Sign Out of App Store**:
   - On your test device, go to Settings → App Store
   - Sign out of your regular Apple ID
   - DO NOT sign in to the sandbox account yet

3. **Test in Your App**:
   - Build and run your app from Xcode
   - When you try to make a purchase, iOS will prompt you to sign in
   - Sign in with your sandbox tester account
   - Complete the test purchase (it's free)

4. **Important**: Sandbox purchases will prompt "Environment: Sandbox" in the purchase dialog

### Android Testing

1. **Add Test Accounts**:
   - Google Play Console → Setup → License testing
   - Add Gmail accounts for testers

2. **Upload to Internal Testing Track**:
   - You must upload an AAB/APK to test real billing
   - You can't test billing on a local debug build

3. **Test in Your App**:
   - Install from the internal testing track
   - Make test purchases (they're free for test accounts)

## Common Issues

### iOS

**"Cannot connect to iTunes Store"**
- Make sure you're signed out of the App Store in Settings
- Sign in with your sandbox tester when prompted by your app
- Don't sign in to the sandbox account in Settings → App Store

**"Product IDs not found"**
- Wait 2-4 hours after creating products in App Store Connect
- Ensure your app's bundle ID matches exactly
- Products must be in "Ready to Submit" status
- Your app must have at least one build uploaded to App Store Connect

**"Transaction observer not receiving updates"**
- Make sure you call `startConnection()` early (in `_ready()`)
- Don't create multiple instances of GodotIAP

### Android

**"Billing service unavailable"**
- You must install from Google Play (internal testing track at minimum)
- Debug builds from Android Studio won't connect to billing

**"Item already owned"**
- Consume the previous purchase first
- Or clear Google Play cache

### Both Platforms

**"Purchase not being acknowledged"**
- Always check for pending purchases on app start with `queryPurchases()`
- Implement all signal handlers, especially `purchase_updated`
- Save the purchase token and retry acknowledging if it fails

**"Users not getting items after purchase"**
- Always save the granted item BEFORE acknowledging/consuming
- Implement proper error handling and retry logic
- Consider server-side receipt validation for high-value items

## App Store Review Requirements

### iOS

1. **Restore Purchases Button**: Required for non-consumables and subscriptions
   ```gdscript
   func _on_restore_button_pressed():
       iap.restorePurchases()
   ```

2. **Terms of Use**: Required for subscriptions
3. **Privacy Policy**: Required for subscriptions

### Android

- Similar requirements for subscriptions
- Ensure you handle subscription lifecycle properly

## Advanced Topics

### Receipt Validation

For production apps, especially with subscriptions, you should validate receipts server-side:

**iOS**: Use the [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)

**Android**: Use the [Google Play Developer API](https://developers.google.com/android-publisher)

The purchase data includes:
- iOS: `order_id` is the transaction ID
- Android: `signature` field contains the purchase signature

### Subscription Management

For subscriptions, you'll need to:
1. Validate receipts server-side
2. Check subscription status regularly
3. Handle grace periods and billing retries
4. Provide subscription management UI

### Handling Refunds

- iOS: Monitor the App Store Server Notifications
- Android: Monitor the Real-time Developer Notifications
- Revoke items if a refund is issued

## Support

For issues with the plugin itself, check the implementation in:
- `godot_plugin/godot_iap.h` - Interface definition
- `godot_plugin/godot_iap.mm` - iOS implementation
- `godot_plugin/UNIFIED_IAP_DESIGN.md` - Design documentation

For issues with App Store Connect or Google Play Console, refer to their official documentation:
- [Apple IAP Documentation](https://developer.apple.com/in-app-purchase/)
- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
