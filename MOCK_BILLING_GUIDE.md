# Mock Billing Plugin - Testing Guide

The `MockGodotBilling` class allows you to test your IAP flows in the Godot editor without deploying to a device. It simulates all billing operations with realistic delays and configurable behavior.

## Quick Setup

### Option 1: Automatic Mock Injection (Recommended)

Add this code to your billing setup:

```gdscript
var billing

func _ready():
    if Engine.is_editor_hint() or OS.has_feature("editor"):
        # Editor mode - use mock
        billing = MockGodotBilling.new()
        add_child(billing)
    else:
        # Device - use real plugin
        if OS.get_name() == "iOS":
            billing = Engine.get_singleton("GodotBilling")
        else:
            billing = Engine.get_singleton("GodotBilling")

    _connect_signals()
    billing.startConnection()
```

### Option 2: Autoload Singleton

1. Add `MockGodotBilling.gd` to Project Settings → Autoload
2. Name it "Billing"
3. Enable only when `EditorSettings` is detected

## Features

### ✅ Complete API Coverage

The mock implements **every method and signal** from the real plugins:

**Methods:**
- `startConnection()`, `endConnection()`, `isReady()`
- `querySkuDetails()`, `queryPurchases()`, `restorePurchases()`
- `purchase()`, `acknowledgePurchase()`, `consumePurchase()`
- `getPlatform()`, `setAutoFinishTransactions()`

**Signals:**
- `billing_connected`, `billing_disconnected`
- `sku_details_query_completed`
- `purchase_updated`, `purchases_updated`, `purchases_restored`
- `purchase_acknowledged`, `purchase_consumed`
- Plus backward compatibility signals

### 🎮 Realistic Simulation

- **Network delays**: Configurable delay for all async operations
- **Random failures**: Simulate intermittent network/API errors
- **User cancellation**: 10% chance of simulated cancellation
- **Purchase tracking**: Maintains state across operations
- **Type checking**: Validates SKU types (inapp vs subs)

### 📦 Pre-Configured Product Catalog

Out of the box, includes:

**In-App Products:**
- `coins_100` - $0.99
- `coins_500` - $4.99
- `coins_1000` - $9.99
- `premium_unlock` - $19.99
- `remove_ads` - $2.99

**Subscriptions:**
- `premium_monthly` - $9.99
- `premium_yearly` - $99.99

### 🛠️ Testing Tools

Special methods for testing different scenarios:

```gdscript
# Add custom products
billing.mock_add_product("test_item", "Test Item", "$99.99", "inapp")

# Grant purchases without flow (for testing restore)
var token = billing.mock_grant_purchase("premium_unlock")

# Simulate failures
billing.mock_fail_next_operation()  # Next operation will fail

# Clear all state
billing.mock_clear_purchases()

# View internal state
var history = billing.mock_get_purchase_history()
print(history.owned_products)
```

## Configuration

### Basic Configuration

```gdscript
var billing = MockGodotBilling.new()

# Enable/disable debug logs
billing.debug_enabled = true

# Set network delay (in seconds)
billing.network_delay = 0.5  # 500ms

# Set failure rate (0.0 - 1.0)
billing.failure_rate = 0.1  # 10% of operations fail

# Set platform to simulate
billing.mock_platform = "android"  # or "ios"
```

### Advanced Configuration

```gdscript
# Test iOS auto-finish behavior
billing.mock_platform = "ios"
billing.setAutoFinishTransactions(true)

# Aggressive failure testing
billing.failure_rate = 0.5  # 50% failure rate
billing.network_delay = 2.0  # Slow network

# Fast testing (no delays)
billing.network_delay = 0.0
billing.debug_enabled = false
```

## Testing Scenarios

### Test 1: Basic Purchase Flow

```gdscript
# 1. Connect
billing.startConnection()
await billing.billing_connected

# 2. Query products
billing.querySkuDetails(["coins_100"], "inapp")
await billing.sku_details_query_completed

# 3. Purchase
billing.purchase("coins_100")
await billing.purchase_updated

# 4. Consume
billing.consumePurchase(purchase_token)
await billing.purchase_consumed
```

### Test 2: User Cancellation

The mock automatically simulates user cancellation 10% of the time:

```gdscript
billing.purchase("coins_100")
# Wait for signal...
# Status will be 1 (USER_CANCELLED) randomly
```

### Test 3: Network Errors

```gdscript
# Test intermittent failures
billing.failure_rate = 0.3  # 30% fail rate

for i in range(10):
    billing.purchase("coins_100")
    await billing.purchase_updated
    # Some will succeed, some will fail
```

### Test 4: One-Time Failure

```gdscript
# Force next operation to fail
billing.mock_fail_next_operation()
billing.querySkuDetails(["coins_100"], "inapp")
# Will fail with status 6
```

### Test 5: Restore Purchases

```gdscript
# Grant some purchases manually
billing.mock_grant_purchase("premium_unlock")
billing.mock_grant_purchase("remove_ads")

# Then test restore
billing.restorePurchases()
await billing.purchases_restored
# Should return both purchases
```

### Test 6: Invalid SKUs

```gdscript
billing.querySkuDetails(["invalid_sku", "coins_100"], "inapp")
# Result will include "invalid_skus" array
```

### Test 7: Type Mismatches

```gdscript
# Try to query subscription as inapp
billing.querySkuDetails(["premium_monthly"], "inapp")
# Will return empty products array
```

## Debugging

### View Purchase State

```gdscript
var history = billing.mock_get_purchase_history()

print("Purchased Items:")
for token in history.purchased_items:
    var purchase = history.purchased_items[token]
    print("  %s: %s (consumed: %s)" % [
        purchase.sku,
        token,
        purchase.get("consumed", false)
    ])

print("Owned Products: ", history.owned_products)
print("Active Subscriptions: ", history.active_subscriptions)
```

### Debug Menu Example

```gdscript
# Add to your debug/dev menu
func _on_debug_menu_opened():
    if billing is MockGodotBilling:
        var menu = DebugMenu.new()
        menu.add_button("Force Next Failure", func():
            billing.mock_fail_next_operation()
        )
        menu.add_button("Clear Purchases", func():
            billing.mock_clear_purchases()
        )
        menu.add_button("View Purchase History", func():
            print(billing.mock_get_purchase_history())
        )
        menu.add_slider("Failure Rate", billing.failure_rate, 0.0, 1.0, func(val):
            billing.failure_rate = val
        )
```

## Console Output

The mock prints detailed logs when `debug_enabled = true`:

```
[MockGodotBilling] MockGodotBilling initialized
[MockGodotBilling] Platform: android
[MockGodotBilling] Network delay: 0.5s
[MockGodotBilling] startConnection() called
[MockGodotBilling] Connection SUCCESS
[MockGodotBilling] querySkuDetails(skus: ["coins_100", "premium_unlock"], type: inapp)
[MockGodotBilling] SKU query SUCCESS: 2 products found
[MockGodotBilling] purchase(sku: coins_100, type: inapp)
[MockGodotBilling] Purchase SUCCESS: coins_100
[MockGodotBilling]   Token: mock_token_1
[MockGodotBilling]   Order: GPA.1000-4523-1234567890
[MockGodotBilling] consumePurchase(token: mock_token_1)
[MockGodotBilling] Consume SUCCESS: coins_100 can be purchased again
```

## Common Patterns

### Pattern 1: Test Each Purchase Type

```gdscript
func test_consumable():
    billing.purchase("coins_100")
    await billing.purchase_updated
    billing.consumePurchase(purchase_token)

func test_non_consumable():
    billing.purchase("premium_unlock")
    await billing.purchase_updated
    billing.acknowledgePurchase(purchase_token)

func test_subscription():
    billing.purchase("premium_monthly", "subs")
    await billing.purchase_updated
    billing.acknowledgePurchase(purchase_token)
```

### Pattern 2: Test Retry Logic

```gdscript
func purchase_with_retry(sku: String, max_retries: int = 3):
    for i in range(max_retries):
        var result = billing.purchase(sku)
        await billing.purchase_updated

        if result.status == 0:
            return true  # Success

        print("Retry %d/%d" % [i + 1, max_retries])
        await get_tree().create_timer(1.0).timeout

    return false  # Failed after retries
```

### Pattern 3: Test Offline Mode

```gdscript
func test_offline():
    # Simulate completely offline
    billing.failure_rate = 1.0  # 100% failure

    billing.startConnection()
    # Should fail with error

    # Restore online
    billing.failure_rate = 0.0
    billing.startConnection()
    # Should succeed
```

## Differences from Real Plugins

The mock behaves **99% identically** to real plugins, but with these intentional differences:

1. **No real money** - Obviously!
2. **No platform validation** - Doesn't check App Store Connect / Google Play Console
3. **Instant server responses** - Real stores have variable latency
4. **Predictable tokens** - Tokens are `mock_token_1`, `mock_token_2`, etc.
5. **No receipt validation** - Signatures are fake
6. **State resets on restart** - Purchases don't persist

## Best Practices

### ✅ DO

- Use the mock for **rapid iteration** during development
- Test **error handling** with failure rates
- Test **all purchase types** (consumable, non-consumable, subscription)
- Test **restore flow** before App Store submission
- Use **custom products** for special test cases
- Keep `debug_enabled = true` during development

### ❌ DON'T

- Don't **rely on mock for final testing** - Always test on real devices
- Don't **commit hardcoded mock products** - Use external config files
- Don't **ship with mock enabled** - Always check `Engine.is_editor_hint()`
- Don't **skip server verification** - Even in mock mode, test your server flow

## Integration with Testing Framework

If using a testing framework like GUT:

```gdscript
extends GutTest

var billing: MockGodotBilling

func before_each():
    billing = MockGodotBilling.new()
    billing.debug_enabled = false  # Quiet in tests
    billing.network_delay = 0.0     # Fast tests
    add_child_autofree(billing)
    await billing.startConnection()

func test_purchase_flow():
    billing.purchase("coins_100")
    var result = await billing.purchase_updated
    assert_eq(result.status, 0)
    assert_eq(result.purchases[0].sku, "coins_100")

func test_consume_unowned_item():
    billing.consumePurchase("invalid_token")
    var result = await billing.purchase_consumed
    assert_eq(result.status, 8)  # ITEM_NOT_OWNED
```

## Platform-Specific Testing

### Test iOS Behavior

```gdscript
billing.mock_platform = "ios"
billing.setAutoFinishTransactions(true)

# Purchases auto-acknowledge
billing.purchase("premium_unlock")
await billing.purchase_updated
# No need to call acknowledgePurchase()
```

### Test Android Behavior

```gdscript
billing.mock_platform = "android"

# Must explicitly acknowledge
billing.purchase("premium_unlock")
await billing.purchase_updated
billing.acknowledgePurchase(purchase_token)
# Required or refund after 3 days!
```

## Troubleshooting

### Signals Not Firing

**Problem:** Signals emit but handlers don't run.

**Solution:** Make sure mock is added as a child:
```gdscript
billing = MockGodotBilling.new()
add_child(billing)  # Required for signals!
```

### Purchases Lost on Restart

**Problem:** Purchase state resets.

**Solution:** This is expected! Mock doesn't persist. For testing persistence:
```gdscript
# Save tokens before restart
var tokens = billing.mock_get_purchase_history().purchased_items.keys()
save_to_file(tokens)

# After restart
for token in load_from_file():
    billing.mock_grant_purchase(extract_sku(token))
```

### Wrong Platform Detected

**Problem:** `Engine.is_editor_hint()` returns false in editor.

**Solution:** Use combined check:
```gdscript
if Engine.is_editor_hint() or OS.has_feature("editor"):
    # Use mock
```

## See Also

- [README.md](README.md) - Main plugin documentation
- [example_usage_with_mock.gd](example_usage_with_mock.gd) - Complete integration example
- [UNIFIED_IAP_DESIGN.md](UNIFIED_IAP_DESIGN.md) - Design philosophy

---

**Happy Testing! 🎮**
