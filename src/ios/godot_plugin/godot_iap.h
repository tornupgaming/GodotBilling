//
//  godot_iap.h
//  godot_plugin
//
//  Unified In-App Purchase interface for iOS and Android
//

#ifndef GODOT_IAP_H
#define GODOT_IAP_H

#include "core/object/class_db.h"

#ifdef __OBJC__
@class GodotIAPProductsDelegate;
@class GodotIAPTransactionObserver;

typedef GodotIAPProductsDelegate IAPProductDelegate;
typedef GodotIAPTransactionObserver IAPTransactionObserver;
#else
typedef void IAPProductDelegate;
typedef void IAPTransactionObserver;
#endif

// Unified IAP interface that works consistently across iOS and Android
//
// Platform-specific behaviors:
// - startConnection(): Required on Android, no-op on iOS (always connected)
// - restorePurchases(): Native on iOS, simulates via queryPurchases on Android
// - acknowledgePurchase(): Maps to finishTransaction on iOS
// - consumePurchase(): Marks consumable + finishTransaction on iOS
// - Event system: Both platforms emit events through the same signal/callback mechanism

class GodotIAP : public Object {
    GDCLASS(GodotIAP, Object);

    static GodotIAP *instance;
    static void _bind_methods();

    IAPProductDelegate *products_delegate;
    IAPTransactionObserver *transaction_observer;

public:
    // ============================================================================
    // Lifecycle & Connection
    // ============================================================================

    // Initialize the billing system
    // Android: Connects to Google Play Billing
    // iOS: Sets up StoreKit observer (always "connected")
    void startConnection();

    // Check if billing is ready
    // Android: Returns connection status
    // iOS: Always returns true if StoreKit available
    bool isReady();

    // End the billing connection (cleanup)
    void endConnection();

    // ============================================================================
    // Product Information
    // ============================================================================

    // Query product details from the store
    // @param skus: Array of product IDs (e.g., ["coins_100", "premium_sub"])
    // @param type: "inapp" for consumables/non-consumables, "subs" for subscriptions
    //
    // Emits: "sku_details_query_completed" signal with Dictionary result:
    // {
    //     "status": 0 (OK) or error code,
    //     "products": [
    //         {
    //             "sku": "coins_100",
    //             "title": "100 Coins",
    //             "description": "A bag of 100 coins",
    //             "price": "$0.99",
    //             "price_currency_code": "USD",
    //             "price_amount_micros": 990000,
    //             "type": "inapp"
    //         },
    //         ...
    //     ]
    // }
    void querySkuDetails(const Array &skus, const String &type);

    // ============================================================================
    // Purchasing
    // ============================================================================

    // Initiate a purchase
    // @param sku: Product ID to purchase
    // @param type: "inapp" or "subs" (optional, defaults to "inapp")
    //
    // Emits: "purchase_updated" signal with Dictionary:
    // {
    //     "status": 0 (OK), 1 (user cancelled), or error code,
    //     "purchases": [
    //         {
    //             "sku": "coins_100",
    //             "purchase_token": "platform-specific-token",
    //             "order_id": "GPA.1234...", // Android transaction ID or iOS transaction identifier
    //             "purchase_time": 1234567890,
    //             "signature": "...", // Android only
    //             "acknowledged": false,
    //             "purchase_state": 1 // 1=purchased, 0=pending
    //         }
    //     ]
    // }
    void purchase(const String &sku);
    void purchase(const String &sku, const String &type);

    // ============================================================================
    // Purchase Management
    // ============================================================================

    // Query existing purchases (owned items)
    // @param type: "inapp" or "subs"
    //
    // Emits: "purchases_updated" signal with same format as purchase()
    void queryPurchases(const String &type);

    // Restore purchases (primarily for iOS, but works on Android too)
    // Retrieves all purchases associated with the user's account
    // iOS: Triggers StoreKit restoreCompletedTransactions
    // Android: Queries both inapp and subs purchases
    //
    // Emits: "purchases_restored" signal with Dictionary:
    // {
    //     "status": 0 (OK) or error code,
    //     "purchases": [ ... ] // Same format as purchase_updated
    // }
    void restorePurchases();

    // ============================================================================
    // Purchase Acknowledgement & Consumption
    // ============================================================================

    // Acknowledge a purchase (for non-consumables and subscriptions)
    // Must be called within 3 days or Google Play will refund
    // @param purchase_token: Token from purchase result
    //
    // iOS: Calls finishTransaction
    // Android: Calls acknowledgePurchase API
    //
    // Emits: "purchase_acknowledged" signal with Dictionary:
    // {
    //     "status": 0 (OK) or error code,
    //     "purchase_token": "..."
    // }
    void acknowledgePurchase(const String &purchase_token);

    // Consume a purchase (for consumables only)
    // Marks the purchase as consumed so it can be purchased again
    // @param purchase_token: Token from purchase result
    //
    // iOS: Marks as consumed + calls finishTransaction
    // Android: Calls consumePurchase API
    //
    // Emits: "purchase_consumed" signal with Dictionary:
    // {
    //     "status": 0 (OK) or error code,
    //     "purchase_token": "..."
    // }
    void consumePurchase(const String &purchase_token);

    // ============================================================================
    // Configuration
    // ============================================================================

    // Enable/disable automatic purchase finishing (iOS only, no-op on Android)
    // When enabled, transactions are automatically finished after successful purchase
    // Default: false (you must manually acknowledge/consume)
    void setAutoFinishTransactions(bool auto_finish);

    // ============================================================================
    // Utility
    // ============================================================================

    // Get the current platform ("ios" or "android")
    String getPlatform();

    static GodotIAP *get_singleton();

    GodotIAP();
    ~GodotIAP();
};

#endif /* GODOT_IAP_H */
