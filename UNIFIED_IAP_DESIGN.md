# Unified IAP Interface Design

## Design Principles

### 1. Signal-Based Event System
Both platforms emit events through Godot signals rather than polling or callbacks:
- Consistent async pattern
- Easy to connect in GDScript
- No platform-specific polling logic needed

### 2. Dictionary-Based Results
All results return Godot Dictionaries with consistent structure:
- Easy to parse in GDScript
- Extensible for future fields
- Platform differences hidden in implementation

### 3. Android API as Base
The method names follow Android's Play Billing pattern because:
- More explicit (acknowledge vs finish)
- Clearer separation of consumables vs non-consumables
- Your Android code already uses this

## Key Signals

```gdscript
# Connection
signal billing_connected(result: Dictionary)  # {status: int}
signal billing_disconnected()

# Products
signal sku_details_query_completed(result: Dictionary)  # {status: int, products: Array}

# Purchases
signal purchase_updated(result: Dictionary)  # {status: int, purchases: Array}
signal purchases_updated(result: Dictionary)  # {status: int, purchases: Array}; Android emits query_purchases_response
signal purchases_restored(result: Dictionary)  # {status: int, purchases: Array}

# Post-purchase
signal purchase_acknowledged(result: Dictionary)  # {status: int, purchase_token: String}
signal purchase_consumed(result: Dictionary)  # {status: int, purchase_token: String}

# Errors (iOS only)
signal billing_error(error: Dictionary)  # {code: int, message: String}
```

## Platform Mapping

### iOS (StoreKit) → Unified API

| Unified API | iOS Implementation |
|-------------|-------------------|
| `startConnection()` | Setup transaction observer (instant) |
| `querySkuDetails()` | `SKProductsRequest` |
| `purchase()` | `SKPaymentQueue.add(payment)` |
| `queryPurchases()` | Return cached transactions |
| `restorePurchases()` | `SKPaymentQueue.restoreCompletedTransactions()` |
| `acknowledgePurchase()` | `SKPaymentQueue.finishTransaction()` |
| `consumePurchase()` | Mark consumed + `finishTransaction()` |

### Android (Play Billing) → Unified API

| Unified API | Android Implementation |
|-------------|----------------------|
| `startConnection()` | `BillingClient.startConnection()` |
| `querySkuDetails()` | `queryProductDetailsAsync()` |
| `purchase()` | `launchBillingFlow()` |
| `queryPurchases()` | `queryPurchasesAsync()` |
| `restorePurchases()` | `queryPurchasesAsync()` for all types |
| `acknowledgePurchase()` | `acknowledgePurchase()` |
| `consumePurchase()` | `consumeAsync()` |

## Purchase Flow Examples

### Consumable (e.g., 100 coins)

```gdscript
# 1. Query product details
iap.querySkuDetails(["coins_100"], "inapp")

# 2. On signal, show price
func _on_sku_details_completed(result):
    if result.status == 0:
        show_price(result.products[0].price)

# 3. User clicks buy
iap.purchase("coins_100", "inapp")

# 4. On purchase success, grant coins and consume
func _on_purchase_updated(result):
    if result.status == 0:
        var purchase = result.purchases[0]
        grant_coins(100)
        iap.consumePurchase(purchase.purchase_token)
```

### Non-Consumable (e.g., premium unlock)

```gdscript
# Purchase flow same as above, but acknowledge instead:
func _on_purchase_updated(result):
    if result.status == 0:
        var purchase = result.purchases[0]
        unlock_premium()
        iap.acknowledgePurchase(purchase.purchase_token)
```

### Subscription

```gdscript
# Same as non-consumable, but use type "subs"
iap.querySkuDetails(["premium_monthly"], "subs")
iap.purchase("premium_monthly", "subs")  # Android: iap.purchase("premium_monthly")
iap.acknowledgePurchase(purchase_token)  # After verification
```

### Restore Purchases (iOS requirement)

```gdscript
# Typically called from "Restore Purchases" button
iap.restorePurchases()

func _on_purchases_restored(result):
    if result.status == 0:
        for purchase in result.purchases:
            if purchase.sku == "premium_unlock":
                unlock_premium()
            # Note: Already finished on iOS, but Android may need acknowledge
```

## Implementation Strategy

### Phase 1: iOS Implementation
1. Keep existing `in_app_store.mm` as reference
2. Create new `godot_iap.mm` implementing unified interface
3. Map StoreKit events to unified signals
4. Test with your iOS app

### Phase 2: Android Verification
1. Update Android plugin to match unified interface
2. Ensure signal names and Dictionary structures match
3. Test existing Android game still works

### Phase 3: Godot Code Update
1. Update game code to use unified signals
2. Remove platform-specific code paths
3. Add restore button for iOS compliance

## Status Codes

Standardized across platforms:

```
0  = OK
1  = User cancelled
2  = Service unavailable
3  = Billing unavailable
4  = Item unavailable
5  = Developer error
6  = Error (generic)
7  = Item already owned
8  = Item not owned
```

## Testing Checklist

- [ ] Connection succeeds on both platforms
- [ ] Product queries return consistent format
- [ ] Purchase flow works for consumables
- [ ] Purchase flow works for non-consumables
- [ ] Restore purchases works (iOS)
- [ ] Acknowledge prevents refund (Android)
- [ ] Consume allows re-purchase
- [ ] User cancellation handled gracefully
- [ ] Network errors handled gracefully
- [ ] Signals fire with correct data structure
