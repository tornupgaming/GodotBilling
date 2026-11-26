# Godot Billing - Unified Cross-Platform IAP Plugin

A unified in-app purchase (IAP) plugin for Godot Engine that provides a consistent API across iOS and Android platforms. Write your billing code once and it works on both platforms!

## Features

- ✅ **Unified API** - Same interface for iOS (StoreKit) and Android (Google Play Billing)
- ✅ **Signal-Based** - Async operations using Godot signals
- ✅ **Type-Safe** - Dictionary-based responses with consistent structure
- ✅ **Well-Documented** - Comprehensive docs and examples
- ✅ **Production Ready** - Used in live games on both platforms

## Platform Support

| Platform | Implementation | API Version |
|----------|---------------|-------------|
| **iOS** | StoreKit | iOS 11.2+ |
| **Android** | Google Play Billing Library | Billing 9.1, Android 6.0+ (API 23) |

---

## Quick Start

### 1. Installation

Build the binaries first (see [Building](#building)), then copy them into the Godot project.

#### iOS
```bash
# <project> is the folder containing project.godot
cp bin/ios/plugins/godot_billing.debug.a bin/ios/plugins/godot_billing.release.a \
   bin/ios/plugins/godot_billing.gdip <project>/ios/plugins/
```
Enable `GodotBilling` under Plugins in the iOS export preset. The library also registers a
`Haptics` singleton. It is an arm64 device build; there is no simulator slice.

#### Android
```bash
cp bin/android/plugins/*.aar bin/android/plugins/godot_billing.gdap <project>/android/plugins/
```
Enable `GodotGooglePlayBilling` under Plugins in the Android export preset (Gradle build required).

### 2. Basic Setup

```gdscript
extends Node

var billing  # GodotBilling singleton

func _ready():
	# The singleton is called "GodotBilling" on both platforms
	billing = Engine.get_singleton("GodotBilling")

	# Connect to signals
	billing.billing_connected.connect(_on_billing_connected)
	billing.sku_details_query_completed.connect(_on_sku_details_completed)
	billing.purchase_updated.connect(_on_purchase_updated)
	billing.purchase_acknowledged.connect(_on_purchase_acknowledged)
	billing.purchase_consumed.connect(_on_purchase_consumed)

	# Start the billing service
	billing.startConnection()

func _on_billing_connected(result: Dictionary):
	if result.status == 0:
		print("Billing connected!")
		# Now you can query products
		billing.querySkuDetails(["coins_100", "premium_unlock"], "inapp")
	else:
		print("Billing connection failed: ", result.get("error_message", "Unknown error"))
```

### 3. Query Products

```gdscript
func query_products():
	# Query in-app products
	billing.querySkuDetails(["coins_100", "coins_500", "coins_1000"], "inapp")

	# Query subscriptions
	billing.querySkuDetails(["premium_monthly", "premium_yearly"], "subs")

func _on_sku_details_completed(result: Dictionary):
	if result.status != 0:
		print("Product query failed: ", result.get("error_message", "Unknown error"))
		return

	print("Found ", result.products.size(), " products:")
	for product in result.products:
		print("  - ", product.sku)
		print("    Title: ", product.title)
		print("    Price: ", product.price)
		print("    Type: ", product.type)

		# Store product info for display
		product_catalog[product.sku] = product
```

---

## Purchase Flows

### Consumable Products (Coins, Gems, etc.)

```gdscript
func buy_coins():
	var result = billing.purchase("coins_100")
	if result.status != 0:
		show_error("Purchase failed to start: " + str(result.get("error_message", "")))

func _on_purchase_updated(result: Dictionary):
	if result.status == 1:
		print("User cancelled purchase")
		return

	if result.status != 0:
		show_error("Purchase failed: " + str(result.get("error_message", "Unknown error")))
		return

	# Purchase successful!
	for purchase in result.purchases:
		print("Purchased: ", purchase.sku)
		print("Purchase token: ", purchase.purchase_token)

		# IMPORTANT: Verify purchase with your server before granting items
		verify_purchase_with_server(purchase.purchase_token, purchase.signature)

func _on_purchase_verified_by_server(purchase_token: String, sku: String):
	# Grant the coins/gems to the player
	match sku:
		"coins_100":
			player_coins += 100
		"coins_500":
			player_coins += 500
		"coins_1000":
			player_coins += 1000

	save_player_data()

	# Consume the purchase so it can be bought again
	billing.consumePurchase(purchase_token)

func _on_purchase_consumed(result: Dictionary):
	if result.status == 0:
		print("Purchase consumed: ", result.purchase_token)
	else:
		print("Consume failed: ", result.get("error_message", "Unknown error"))
		# Retry later or log for manual resolution
```

### Non-Consumable Products (Premium Unlock, Remove Ads)

```gdscript
func buy_premium():
	var result = billing.purchase("premium_unlock")
	if result.status != 0:
		show_error("Purchase failed to start")

func _on_purchase_updated(result: Dictionary):
	if result.status != 0:
		return

	for purchase in result.purchases:
		if purchase.sku == "premium_unlock":
			# IMPORTANT: Verify purchase with your server
			verify_purchase_with_server(purchase.purchase_token, purchase.signature)

func _on_purchase_verified_by_server(purchase_token: String, sku: String):
	if sku == "premium_unlock":
		# Unlock premium features
		player_data.is_premium = true
		save_player_data()
		update_ui()

		# Acknowledge the purchase (required on Android, prevents refund)
		billing.acknowledgePurchase(purchase_token)

func _on_purchase_acknowledged(result: Dictionary):
	if result.status == 0:
		print("Purchase acknowledged: ", result.purchase_token)
	else:
		print("Acknowledge failed: ", result.get("error_message", "Unknown error"))
		# Retry later
```

### Subscriptions

```gdscript
func subscribe_monthly():
	if billing.getPlatform() == "ios":
		billing.purchase("premium_monthly", "subs")
		return
	var result = billing.purchaseWithType("premium_monthly", "subs")
	if result.status != 0:
		show_error("Subscription failed to start")

func _on_purchase_updated(result: Dictionary):
	if result.status != 0:
		return

	for purchase in result.purchases:
		if purchase.sku == "premium_monthly":
			# Verify with your server (CRITICAL for subscriptions!)
			verify_subscription_with_server(purchase.purchase_token, purchase.signature)

func _on_subscription_verified(purchase_token: String):
	player_data.subscription_active = true
	player_data.subscription_expires = get_expiry_from_server()
	save_player_data()

	billing.acknowledgePurchase(purchase_token)
```

### Restore Purchases (Required for iOS App Review)

```gdscript
# Add a "Restore Purchases" button for iOS compliance
func _on_restore_button_pressed():
	billing.restorePurchases()

func _on_purchases_restored(result: Dictionary):
	if result.status != 0:
		show_error("Restore failed: " + str(result.get("error_message", "Unknown error")))
		return

	if result.purchases.is_empty():
		show_message("No purchases to restore")
		return

	print("Restoring ", result.purchases.size(), " purchases")
	for purchase in result.purchases:
		# Restore non-consumables and active subscriptions
		match purchase.sku:
			"premium_unlock":
				player_data.is_premium = true
			"remove_ads":
				player_data.ads_removed = true
			"premium_monthly", "premium_yearly":
				# Verify subscription is still active with your server
				verify_subscription_with_server(purchase.purchase_token, purchase.signature)

	save_player_data()
	update_ui()
	show_message("Purchases restored!")
```

---

## API Reference

### Methods

#### Connection Management

##### `startConnection() -> void`
Initialize billing service and connect to the platform store.

**Emits:** `billing_connected`

```gdscript
billing.startConnection()
```

---

##### `endConnection() -> void`
Disconnect from billing service and cleanup resources.

```gdscript
func _exit_tree():
	billing.endConnection()
```

---

##### `isReady() -> bool`
Check if billing service is connected and ready.

**Returns:** `true` if ready, `false` otherwise

```gdscript
if billing.isReady():
	billing.querySkuDetails(["coins_100"], "inapp")
```

---

##### `getPlatform() -> String`
Get the current platform name.

**Returns:** `"android"` or `"ios"`

```gdscript
var platform = billing.getPlatform()
if platform == "ios":
	show_restore_purchases_button()
```

---

#### Product Queries

##### `querySkuDetails(skus: Array, type: String) -> void`
Query product details from the store.

**Parameters:**
- `skus`: Array of product IDs (e.g., `["coins_100", "premium_unlock"]`)
- `type`: `"inapp"` for one-time purchases, `"subs"` for subscriptions

**Emits:** `sku_details_query_completed`

```gdscript
billing.querySkuDetails(["coins_100", "coins_500"], "inapp")
billing.querySkuDetails(["premium_monthly"], "subs")
```

---

#### Purchasing

##### Android: `purchase(sku: String) -> Dictionary`
##### Android: `purchaseWithType(sku: String, type: String) -> Dictionary`
##### iOS: `purchase(sku: String, type: String) -> void`
Initiate a purchase flow. The signatures differ per platform: Godot's Android plugin bridge cannot
expose two Java overloads under one name, and the iOS binding has no default for `type`.

**Parameters:**
- `sku`: Product ID to purchase
- `type`: `"inapp"` or `"subs"`. Required on iOS. Android ignores it (the type comes from
  `querySkuDetails`), so `purchaseWithType` exists only for call-site symmetry.

**Returns:** Android returns the immediate result `{status: int, error_message: String}`. iOS
returns nothing; failures arrive through `purchase_updated`.

**Emits:** `purchase_updated` when purchase completes

```gdscript
if billing.getPlatform() == "ios":
	billing.purchase("coins_100", "inapp")
else:
	var result = billing.purchase("coins_100")
	if result.status != 0:
		print("Failed to start purchase: ", result.error_message)
```

---

##### `queryPurchases(type: String) -> void`
Query existing purchases (owned items).

**Parameters:**
- `type`: `"inapp"` or `"subs"`

**Emits:** `purchases_updated` on iOS, `query_purchases_response` on Android (same Dictionary)

```gdscript
billing.queryPurchases("inapp")
billing.queryPurchases("subs")
```

---

##### `restorePurchases() -> void`
Restore all purchases (queries both inapp and subs on Android).

**Emits:** `purchases_restored`

```gdscript
billing.restorePurchases()
```

---

#### Purchase Completion

##### `acknowledgePurchase(purchase_token: String) -> void`
Acknowledge a non-consumable purchase or subscription.

**Required:** Must be called within 3 days on Android or purchase will be refunded!

**Parameters:**
- `purchase_token`: Token from purchase result

**Emits:** `purchase_acknowledged`

```gdscript
billing.acknowledgePurchase(purchase.purchase_token)
```

---

##### `consumePurchase(purchase_token: String) -> void`
Consume a consumable purchase, allowing it to be purchased again.

**Parameters:**
- `purchase_token`: Token from purchase result

**Emits:** `purchase_consumed`

```gdscript
billing.consumePurchase(purchase.purchase_token)
```

---

#### Configuration (iOS Only)

##### `setAutoFinishTransactions(auto_finish: bool) -> void`
Enable/disable automatic transaction finishing on iOS.

**Default:** `false` (manual finish required)

**Note:** No-op on Android

```gdscript
# iOS: Auto-finish transactions (not recommended for production)
if billing.getPlatform() == "ios":
	billing.setAutoFinishTransactions(true)
```

---

### Signals

#### `billing_connected(result: Dictionary)`
Emitted when billing service connects.

**Result:**
```gdscript
{
	"status": 0,  # 0 = success, other = error code
	"error_message": "..."  # Only present on error
}
```

---

#### `billing_disconnected()`
Emitted when billing service disconnects.

---

#### `sku_details_query_completed(result: Dictionary)`
Emitted when product details query completes.

**Result:**
```gdscript
{
	"status": 0,  # 0 = success, other = error code
	"products": [
		{
			"sku": "coins_100",
			"title": "100 Coins",
			"description": "A bag of 100 coins",
			"price": "$0.99",
			"price_currency_code": "USD",
			"price_amount_micros": 990000,
			"type": "inapp"
		}
	],
	"invalid_skus": ["invalid_product"],  # iOS only
	"error_message": "..."  # Only present on error
}
```

---

#### `purchase_updated(result: Dictionary)`
Emitted when a purchase is completed or updated.

**Result:**
```gdscript
{
	"status": 0,  # 0 = success, 1 = user cancelled, other = error
	"purchases": [
		{
			"sku": "coins_100",
			"purchase_token": "platform-specific-token",
			"order_id": "GPA.1234-5678...",
			"purchase_time": 1234567890,
			"signature": "...",  # Android only
			"acknowledged": false,
			"purchase_state": 1  # 1 = purchased, 0 = pending
		}
	],
	"error_message": "..."  # Only present on error
}
```

---

#### `purchases_updated(result: Dictionary)`
Emitted when queryPurchases() completes. Same format as `purchase_updated`.

---

#### `purchases_restored(result: Dictionary)`
Emitted when restorePurchases() completes. Same format as `purchase_updated`.

---

#### `purchase_acknowledged(result: Dictionary)`
Emitted when acknowledgePurchase() completes.

**Result:**
```gdscript
{
	"status": 0,  # 0 = success, other = error code
	"purchase_token": "...",
	"error_message": "..."  # Only present on error
}
```

---

#### `purchase_consumed(result: Dictionary)`
Emitted when consumePurchase() completes. Same format as `purchase_acknowledged`.

---

### Status Codes

All operations return status codes in the result Dictionary:

| Code | Name | Description |
|------|------|-------------|
| `0` | OK | Operation succeeded |
| `1` | USER_CANCELLED | User cancelled the purchase |
| `3` | BILLING_UNAVAILABLE | Billing service unavailable |
| `5` | DEVELOPER_ERROR | Invalid parameters or setup error |
| `6` | ERROR | Generic error |
| `8` | ITEM_NOT_OWNED | Trying to consume/acknowledge unowned item |

---

## Best Practices

### 1. Always Verify Purchases Server-Side

**Never trust client-side purchase verification!** Always verify purchases with your backend server:

```gdscript
func _on_purchase_updated(result: Dictionary):
	for purchase in result.purchases:
		# Send to your server for verification
		var verification = await verify_with_server(
			purchase.purchase_token,
			purchase.signature,  # Android only
			purchase.order_id
		)

		if verification.valid:
			grant_items(purchase.sku)
			billing.consumePurchase(purchase.purchase_token)
```

### 2. Handle Errors Gracefully

```gdscript
func _on_purchase_updated(result: Dictionary):
	match result.status:
		0:  # Success
			process_purchase(result.purchases)
		1:  # User cancelled
			show_message("Purchase cancelled")
		3:  # Billing unavailable
			show_error("Store is currently unavailable. Please try again later.")
		_:  # Other errors
			show_error("Purchase failed: " + result.get("error_message", "Unknown error"))
			log_error_to_analytics(result)
```

### 3. Always Acknowledge/Consume Purchases

On Android, unacknowledged purchases are automatically refunded after 3 days:

```gdscript
# For non-consumables and subscriptions
billing.acknowledgePurchase(purchase_token)

# For consumables
billing.consumePurchase(purchase_token)
```

### 4. Query Products Before Purchasing

```gdscript
# BAD: Purchasing without querying first
billing.purchase("coins_100")  # May fail!

# GOOD: Query first, then purchase
billing.querySkuDetails(["coins_100"], "inapp")
# Wait for sku_details_query_completed...
billing.purchase("coins_100")
```

### 5. Implement Restore Purchases for iOS

Apple requires a "Restore Purchases" button for non-consumables:

```gdscript
func _ready():
	if billing.getPlatform() == "ios":
		show_restore_purchases_button()

func _on_restore_button_pressed():
	billing.restorePurchases()
```

### 6. Save Purchase State Immediately

```gdscript
func _on_purchase_consumed(result: Dictionary):
	if result.status == 0:
		# Save immediately to prevent loss
		player_data.save()
```

---

## Troubleshooting

### Purchase not completing on Android

**Problem:** Purchase dialog shows but signal never fires.

**Solution:** Make sure you called `querySkuDetails()` first and cached the product:
```gdscript
# Must query first!
billing.querySkuDetails(["coins_100"], "inapp")
# Wait for signal...
billing.purchase("coins_100")
```

---

### "Item not owned" error when consuming

**Problem:** Getting error 8 when trying to consume.

**Solution:** The purchase may have already been consumed, or the purchase_token is invalid:
```gdscript
func _on_purchase_consumed(result: Dictionary):
	if result.status == 8:
		print("Already consumed or invalid token")
		# This is usually fine, ignore it
```

---

### Restore not finding purchases on Android

**Problem:** `restorePurchases()` returns empty on Android.

**Solution:** On Android, only *active* purchases are returned. Consumed purchases don't show up. This is expected behavior.

---

### Products not found in sandbox/testing

**Problem:** Products return empty or invalid in test environment.

**iOS Solution:**
- Make sure you're signed in with a sandbox test account
- Products must be submitted in App Store Connect (doesn't need approval)
- Wait up to 24 hours for products to propagate

**Android Solution:**
- Products must be published (draft products work too)
- Make sure app is configured correctly in Google Play Console
- Use a test account configured in Google Play Console

---

## Migration from Old API

If you're using the old signal names, here's the mapping:

| Old Signal | New Signal |
|-----------|------------|
| `connected` | `billing_connected` |
| `disconnected` | `billing_disconnected` |
| `purchases_updated` (array param) | `purchase_updated` (Dictionary) |
| `sku_details_query_completed` (array param) | `sku_details_query_completed` (Dictionary) |
| `purchase_acknowledged` (string param) | `purchase_acknowledged` (Dictionary) |
| `purchase_consumed` (string param) | `purchase_consumed` (Dictionary) |

The Android plugin removed the old signals in 2.0.0. It still emits `purchase_error`,
`sku_details_query_error` and `query_purchases_response` alongside the unified signals.

---

## Testing

### Android Testing

1. **Use test cards:**
   ```
   Add test account in Google Play Console → Setup → License testing
   ```

2. **Test purchases:**
   - Sign in with test account on device
   - Purchases complete instantly
   - No actual charges

### iOS Testing

1. **Create sandbox tester:**
   - App Store Connect → Users and Access → Sandbox Testers

2. **Test on device:**
   - Sign out of production App Store
   - Run app from Xcode
   - Sign in with sandbox account when prompted

---

## Platform-Specific Notes

### Android

- **Requires Android 5.0+** (API level 21)
- Products must be published in Google Play Console
- Acknowledgement required within 3 days
- Subscriptions require server-side verification

### iOS

- **Requires iOS 11.2+** for subscription period detection
- Must implement "Restore Purchases" button
- Sandbox testing requires test account
- Production testing uses real purchases (can refund later)

---

## Strongly-Typed Data Classes

For better type safety and autocomplete support, use the provided `BillingTypes` classes:

### Using Typed Results

```gdscript
# Instead of raw Dictionary:
func _on_purchase_updated(result_dict: Dictionary) -> void:
	if result_dict.status == 0:
		for purchase_dict in result_dict.purchases:
			print(purchase_dict.sku)  # No autocomplete!

# Use typed classes:
func _on_purchase_updated(result_dict: Dictionary) -> void:
	var result := BillingTypes.PurchaseResult.from_dict(result_dict)

	if result.is_success():
		for purchase in result.purchases:
			print(purchase.sku)        # Full autocomplete!
			print(purchase.order_id)   # Type-safe!
			print(purchase.needs_acknowledgement())
```

### Available Types

#### `BillingTypes.Status` (Enum)
```gdscript
enum Status {
	OK = 0,
	USER_CANCELLED = 1,
	BILLING_UNAVAILABLE = 3,
	DEVELOPER_ERROR = 5,
	ERROR = 6,
	ITEM_NOT_OWNED = 8,
}
```

#### `BillingTypes.Product`
```gdscript
var product := BillingTypes.Product.from_dict(product_dict)
print(product.title)              # String
print(product.price)              # String: "$0.99"
print(product.get_price_value())  # float: 0.99
print(product.is_subscription())  # bool
print(product.is_inapp())         # bool
```

#### `BillingTypes.Purchase`
```gdscript
var purchase := BillingTypes.Purchase.from_dict(purchase_dict)
print(purchase.sku)                      # String
print(purchase.purchase_token)           # String
print(purchase.get_purchase_datetime())  # Dictionary
print(purchase.is_completed())           # bool
print(purchase.needs_acknowledgement())  # bool
```

#### Result Types
- `ConnectionResult` - from `billing_connected`
- `ProductQueryResult` - from `sku_details_query_completed`
- `PurchaseResult` - from `purchase_updated`, `purchases_updated`, `purchases_restored`
- `AcknowledgementResult` - from `purchase_acknowledged`
- `ConsumptionResult` - from `purchase_consumed`

### Type-Safe Example

```gdscript
func _on_sku_details_completed(result_dict: Dictionary) -> void:
	var result := BillingTypes.ProductQueryResult.from_dict(result_dict)

	if not result.is_success():
		print("Query failed: ", result.get_error())
		return

	# Type-safe product access
	for product in result.products:
		# Full autocomplete on all properties!
		print("%s - %s (%.2f)" % [
			product.title,
			product.price,
			product.get_price_value()
		])

	# Get specific product
	var coins_product := result.get_product("coins_100")
	if coins_product:
		print("Found coins product: ", coins_product.title)

	# Check invalid SKUs
	if result.invalid_skus.size() > 0:
		print("Invalid: ", result.invalid_skus)
```

### Advanced Typed Usage

```gdscript
# Store products in catalog
var product_catalog: Dictionary = {}  # String -> BillingTypes.Product

func _on_sku_details_completed(result_dict: Dictionary) -> void:
	var result := BillingTypes.ProductQueryResult.from_dict(result_dict)

	for product in result.products:
		product_catalog[product.sku] = product

# Type-safe product lookup
func get_product(sku: String) -> BillingTypes.Product:
	return product_catalog.get(sku) as BillingTypes.Product

# Type-safe purchase handling
func handle_purchase(purchase: BillingTypes.Purchase) -> void:
	var product := get_product(purchase.sku)
	if not product:
		return

	if product.is_subscription():
		activate_subscription()
	elif product.sku.begins_with("coins_"):
		grant_coins()
	else:
		unlock_feature()
```

See [example_typed_usage.gd](example_typed_usage.gd) for a complete typed implementation example.

---

## Examples

- [billing_types.gd](billing_types.gd) - Strongly-typed data classes
- [example_typed_usage.gd](example_typed_usage.gd) - Complete typed implementation example
- [example_usage_with_mock.gd](example_usage_with_mock.gd) - Integration with MockGodotBilling
- [UNIFIED_IAP_DESIGN.md](UNIFIED_IAP_DESIGN.md) - Design philosophy and additional examples
- [MOCK_BILLING_GUIDE.md](MOCK_BILLING_GUIDE.md) - Testing guide for MockGodotBilling

---

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/GodotBilling/issues)
- **Documentation:** This README and inline code documentation
- **Platform Docs:**
  - [Google Play Billing](https://developer.android.com/google/play/billing)
  - [Apple StoreKit](https://developer.apple.com/storekit/)

---

## Building

Releases are tagged; build from a tag so the binaries can be traced to source.

```bash
git clone --branch <tag> git@github.com:tornupgaming/GodotBilling.git && cd GodotBilling
git submodule update --init --depth 1 src/ios/godot   # about 130 MB; without --depth it is 1.6 GB
sh scripts/build-ios.sh                     # -> bin/ios/plugins/
sh scripts/build-android.sh                 # -> bin/android/plugins/
```

`sh scripts/build.sh` runs both.

| | Requirements |
|---|---|
| iOS | macOS, Xcode with the iOS SDK, SCons (`pip3 install scons`) |
| Android | JDK 17 and the Android SDK (platform 34). Set `ANDROID_HOME`, or put `sdk.dir=<path>` in `src/android/local.properties` |

Notes:

- **The iOS libraries must match the game's Godot version.** Godot's C++ ABI changes between minor
  versions, so a library built against other headers fails to link. The headers come from the
  `src/ios/godot` submodule, currently `4.7.2-stable`. To target another version, check that tag out
  in the submodule, rebuild, and commit the new submodule pointer.
- The iOS build generates the two engine headers it needs and compiles only the plugin; the engine
  itself is not built. It stops on the first error.
- Builds are reproducible. The iOS archives are byte-for-byte identical for the same source, Godot
  tag and Xcode version, and `src/ios/scripts/build.sh` prints their SHA-256 so a consuming project
  can record and verify them.
- The Android library compiles against `org.godotengine:godot:4.3.0.stable` from Maven Central. The
  v2 Android plugin API is stable across Godot 4.x, so it does not track the engine version.

---

## License

MIT; see [LICENSE](LICENSE). Parts of the repository derive from other projects and keep their own
terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
