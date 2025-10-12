//
//  godot_iap.mm
//  godot_plugin
//
//  Unified In-App Purchase implementation for iOS
//

#include "godot_iap.h"

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#include "core/config/engine.h"

// ============================================================================
// Product Request Delegate
// ============================================================================

@interface GodotIAPProductsDelegate : NSObject <SKProductsRequestDelegate>

@property(strong, nonatomic) NSMutableArray *products;
@property(strong, nonatomic) NSMutableDictionary *productCache;

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response;
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error;
- (void)requestDidFinish:(SKRequest *)request;

@end

@implementation GodotIAPProductsDelegate

- (id)init {
    self = [super init];
    if (self) {
        self.products = [[NSMutableArray alloc] init];
        self.productCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"[GodotIAP] Received product response: %lu products", (unsigned long)[response.products count]);

    GodotIAP *iap = GodotIAP::get_singleton();
    if (!iap) {
        return;
    }

    Dictionary result;
    result["status"] = 0; // OK

    Array products_array;

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];

    for (SKProduct *product in response.products) {
        // Cache the product for later purchase
        [self.productCache setObject:product forKey:product.productIdentifier];

        Dictionary product_dict;

        product_dict["sku"] = String([product.productIdentifier UTF8String]);
        product_dict["title"] = String([product.localizedTitle UTF8String]);
        product_dict["description"] = String([product.localizedDescription UTF8String]);

        [formatter setLocale:product.priceLocale];
        product_dict["price"] = String([[formatter stringFromNumber:product.price] UTF8String]);
        product_dict["price_currency_code"] = String([[product.priceLocale objectForKey:NSLocaleCurrencyCode] UTF8String]);

        // Convert price to micros (price * 1,000,000)
        double price_value = [product.price doubleValue];
        product_dict["price_amount_micros"] = (int64_t)(price_value * 1000000);

        // Determine type based on subscription period (iOS 11.2+)
        String product_type = "inapp";
        if (@available(iOS 11.2, *)) {
            if (product.subscriptionPeriod && product.subscriptionPeriod.numberOfUnits > 0) {
                product_type = "subs";
            }
        }
        product_dict["type"] = product_type;

        products_array.push_back(product_dict);
    }

    result["products"] = products_array;

    // Log invalid product IDs
    if ([response.invalidProductIdentifiers count] > 0) {
        NSLog(@"[GodotIAP] Invalid product IDs: %@", response.invalidProductIdentifiers);
        Array invalid_skus;
        for (NSString *invalid_sku in response.invalidProductIdentifiers) {
            invalid_skus.push_back(String([invalid_sku UTF8String]));
        }
        result["invalid_skus"] = invalid_skus;
    }

    iap->emit_signal("sku_details_query_completed", result);
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"[GodotIAP] Product request failed: %@", error.localizedDescription);

    GodotIAP *iap = GodotIAP::get_singleton();
    if (!iap) {
        return;
    }

    Dictionary result;
    result["status"] = 6; // Generic error
    result["error_message"] = String([error.localizedDescription UTF8String]);
    result["products"] = Array();

    iap->emit_signal("sku_details_query_completed", result);
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"[GodotIAP] Product request finished");
}

@end

// ============================================================================
// Transaction Observer
// ============================================================================

@interface GodotIAPTransactionObserver : NSObject <SKPaymentTransactionObserver>

@property(nonatomic, assign) bool autoFinishTransactions;
@property(strong, nonatomic) NSMutableDictionary *pendingTransactions;
@property(strong, nonatomic) NSMutableSet *consumedProducts;

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;

@end

@implementation GodotIAPTransactionObserver

- (id)init {
    self = [super init];
    if (self) {
        self.autoFinishTransactions = false;
        self.pendingTransactions = [[NSMutableDictionary alloc] init];
        self.consumedProducts = [[NSMutableSet alloc] init];
    }
    return self;
}

- (Dictionary)transactionToDictionary:(SKPaymentTransaction *)transaction {
    Dictionary purchase;

    purchase["sku"] = String([transaction.payment.productIdentifier UTF8String]);
    purchase["purchase_token"] = String([transaction.transactionIdentifier UTF8String] ?: "");
    purchase["order_id"] = String([transaction.transactionIdentifier UTF8String] ?: "");

    if (transaction.transactionDate) {
        purchase["purchase_time"] = (int64_t)[transaction.transactionDate timeIntervalSince1970];
    } else {
        purchase["purchase_time"] = 0;
    }

    purchase["signature"] = ""; // iOS doesn't have signatures like Android
    purchase["acknowledged"] = false; // We'll track this separately

    // Map transaction state to purchase state
    // 1 = purchased, 0 = pending, 2 = failed
    switch (transaction.transactionState) {
        case SKPaymentTransactionStatePurchased:
        case SKPaymentTransactionStateRestored:
            purchase["purchase_state"] = 1;
            break;
        case SKPaymentTransactionStatePurchasing:
            purchase["purchase_state"] = 0;
            break;
        default:
            purchase["purchase_state"] = 2;
            break;
    }

    return purchase;
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    GodotIAP *iap = GodotIAP::get_singleton();
    if (!iap) {
        return;
    }

    for (SKPaymentTransaction *transaction in transactions) {
        NSLog(@"[GodotIAP] Transaction updated: %@ state: %ld",
              transaction.payment.productIdentifier, (long)transaction.transactionState);

        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased: {
                // Store transaction for later acknowledgement/consumption
                if (transaction.transactionIdentifier) {
                    [self.pendingTransactions setObject:transaction
                                                 forKey:transaction.transactionIdentifier];
                }

                Dictionary result;
                result["status"] = 0; // OK
                Array purchases;
                purchases.push_back([self transactionToDictionary:transaction]);
                result["purchases"] = purchases;

                iap->emit_signal("purchase_updated", result);

                // Auto-finish if enabled
                if (self.autoFinishTransactions) {
                    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                }
                break;
            }

            case SKPaymentTransactionStateFailed: {
                Dictionary result;

                // Map error code
                if (transaction.error.code == SKErrorPaymentCancelled) {
                    result["status"] = 1; // User cancelled
                } else {
                    result["status"] = 6; // Generic error
                    result["error_message"] = String([transaction.error.localizedDescription UTF8String]);
                }

                result["purchases"] = Array();

                iap->emit_signal("purchase_updated", result);

                // Always finish failed transactions
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            }

            case SKPaymentTransactionStateRestored: {
                // Store for restore completion
                if (transaction.transactionIdentifier) {
                    [self.pendingTransactions setObject:transaction
                                                 forKey:transaction.transactionIdentifier];
                }

                // Will be sent in batch when restore completes
                break;
            }

            case SKPaymentTransactionStatePurchasing:
                // Transaction is being processed
                NSLog(@"[GodotIAP] Transaction purchasing...");
                break;

            case SKPaymentTransactionStateDeferred:
                // Transaction is deferred (waiting for approval)
                NSLog(@"[GodotIAP] Transaction deferred");
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        NSLog(@"[GodotIAP] Transaction removed: %@", transaction.payment.productIdentifier);

        // Clean up our tracking
        if (transaction.transactionIdentifier) {
            [self.pendingTransactions removeObjectForKey:transaction.transactionIdentifier];
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"[GodotIAP] Restore completed");

    GodotIAP *iap = GodotIAP::get_singleton();
    if (!iap) {
        return;
    }

    Dictionary result;
    result["status"] = 0; // OK

    Array purchases;
    for (NSString *token in self.pendingTransactions) {
        SKPaymentTransaction *transaction = [self.pendingTransactions objectForKey:token];
        if (transaction.transactionState == SKPaymentTransactionStateRestored) {
            purchases.push_back([self transactionToDictionary:transaction]);

            // Auto-finish restored transactions if enabled
            if (self.autoFinishTransactions) {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
        }
    }

    result["purchases"] = purchases;

    iap->emit_signal("purchases_restored", result);
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"[GodotIAP] Restore failed: %@", error.localizedDescription);

    GodotIAP *iap = GodotIAP::get_singleton();
    if (!iap) {
        return;
    }

    Dictionary result;

    if (error.code == SKErrorPaymentCancelled) {
        result["status"] = 1; // User cancelled
    } else {
        result["status"] = 6; // Generic error
        result["error_message"] = String([error.localizedDescription UTF8String]);
    }

    result["purchases"] = Array();

    iap->emit_signal("purchases_restored", result);
}

@end

// ============================================================================
// GodotIAP Implementation
// ============================================================================

GodotIAP *GodotIAP::instance = NULL;

GodotIAP *GodotIAP::get_singleton() {
    return instance;
}

void GodotIAP::_bind_methods() {
    ClassDB::bind_method(D_METHOD("startConnection"), &GodotIAP::startConnection);
    ClassDB::bind_method(D_METHOD("isReady"), &GodotIAP::isReady);
    ClassDB::bind_method(D_METHOD("endConnection"), &GodotIAP::endConnection);

    ClassDB::bind_method(D_METHOD("querySkuDetails", "skus", "type"), &GodotIAP::querySkuDetails);

    // Bind both purchase overloads separately
    ClassDB::bind_method(D_METHOD("purchase", "sku", "type"), (void (GodotIAP::*)(const String &, const String &))&GodotIAP::purchase);
    ClassDB::bind_method(D_METHOD("queryPurchases", "type"), &GodotIAP::queryPurchases);
    ClassDB::bind_method(D_METHOD("restorePurchases"), &GodotIAP::restorePurchases);

    ClassDB::bind_method(D_METHOD("acknowledgePurchase", "purchase_token"), &GodotIAP::acknowledgePurchase);
    ClassDB::bind_method(D_METHOD("consumePurchase", "purchase_token"), &GodotIAP::consumePurchase);

    ClassDB::bind_method(D_METHOD("setAutoFinishTransactions", "auto_finish"), &GodotIAP::setAutoFinishTransactions);
    ClassDB::bind_method(D_METHOD("getPlatform"), &GodotIAP::getPlatform);

    // Signals
    ADD_SIGNAL(MethodInfo("billing_connected", PropertyInfo(Variant::DICTIONARY, "result")));
    ADD_SIGNAL(MethodInfo("billing_disconnected"));
    ADD_SIGNAL(MethodInfo("sku_details_query_completed", PropertyInfo(Variant::DICTIONARY, "result")));
    ADD_SIGNAL(MethodInfo("purchase_updated", PropertyInfo(Variant::DICTIONARY, "result")));
    ADD_SIGNAL(MethodInfo("purchases_updated", PropertyInfo(Variant::DICTIONARY, "result")));
    ADD_SIGNAL(MethodInfo("purchases_restored", PropertyInfo(Variant::DICTIONARY, "result")));
    ADD_SIGNAL(MethodInfo("purchase_acknowledged", PropertyInfo(Variant::DICTIONARY, "result")));
    ADD_SIGNAL(MethodInfo("purchase_consumed", PropertyInfo(Variant::DICTIONARY, "result")));
    ADD_SIGNAL(MethodInfo("billing_error", PropertyInfo(Variant::DICTIONARY, "error")));
}

GodotIAP::GodotIAP() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;

    products_delegate = [[GodotIAPProductsDelegate alloc] init];
    transaction_observer = [[GodotIAPTransactionObserver alloc] init];

    NSLog(@"[GodotIAP] Initialized");
}

GodotIAP::~GodotIAP() {
    if (transaction_observer != nil) {
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:(GodotIAPTransactionObserver *)transaction_observer];
        transaction_observer = nil;
    }

    products_delegate = nil;

    instance = NULL;

    NSLog(@"[GodotIAP] Destroyed");
}

void GodotIAP::startConnection() {
    NSLog(@"[GodotIAP] Starting connection");

    // Add transaction observer
    if (transaction_observer != nil) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:(GodotIAPTransactionObserver *)transaction_observer];
    }

    // iOS is always "connected" if StoreKit is available
    Dictionary result;
    result["status"] = 0; // OK

    emit_signal("billing_connected", result);
}

bool GodotIAP::isReady() {
    // Check if payments are allowed
    return [SKPaymentQueue canMakePayments];
}

void GodotIAP::endConnection() {
    NSLog(@"[GodotIAP] Ending connection");

    if (transaction_observer != nil) {
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:(GodotIAPTransactionObserver *)transaction_observer];
    }

    emit_signal("billing_disconnected");
}

void GodotIAP::querySkuDetails(const Array &skus, const String &type) {
    NSLog(@"[GodotIAP] Querying SKU details for %d products", skus.size());

    if (skus.size() == 0) {
        Dictionary result;
        result["status"] = 5; // Developer error
        result["error_message"] = "No SKUs provided";
        result["products"] = Array();
        emit_signal("sku_details_query_completed", result);
        return;
    }

    NSMutableSet *product_identifiers = [[NSMutableSet alloc] init];

    for (int i = 0; i < skus.size(); i++) {
        String sku = skus[i];
        [product_identifiers addObject:[NSString stringWithUTF8String:sku.utf8().get_data()]];
    }

    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:product_identifiers];
    request.delegate = (GodotIAPProductsDelegate *)products_delegate;
    [request start];
}

void GodotIAP::purchase(const String &sku) {
    purchase(sku, "inapp");
}

void GodotIAP::purchase(const String &sku, const String &type) {
    NSLog(@"[GodotIAP] Initiating purchase for: %s", sku.utf8().get_data());

    if (![SKPaymentQueue canMakePayments]) {
        Dictionary result;
        result["status"] = 3; // Billing unavailable
        result["error_message"] = "Payments are not allowed on this device";
        result["purchases"] = Array();
        emit_signal("purchase_updated", result);
        return;
    }

    NSString *product_id = [NSString stringWithUTF8String:sku.utf8().get_data()];
    GodotIAPProductsDelegate *delegate = (GodotIAPProductsDelegate *)products_delegate;

    // Try to use cached product (modern API)
    SKProduct *product = [delegate.productCache objectForKey:product_id];

    SKPayment *payment;
    if (product) {
        // Modern API: create payment from product
        payment = [SKPayment paymentWithProduct:product];
    } else {
        // Fallback: Use the old API if product wasn't queried first
        // This will trigger a warning but allows purchase without querying first
        NSLog(@"[GodotIAP] Warning: Product %@ not in cache, using deprecated API", product_id);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        payment = [SKPayment paymentWithProductIdentifier:product_id];
        #pragma clang diagnostic pop
    }

    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

void GodotIAP::queryPurchases(const String &type) {
    NSLog(@"[GodotIAP] Querying purchases for type: %s", type.utf8().get_data());

    GodotIAPTransactionObserver *observer = (GodotIAPTransactionObserver *)transaction_observer;

    Dictionary result;
    result["status"] = 0; // OK

    Array purchases;

    // Return all pending transactions that haven't been finished
    for (NSString *token in observer.pendingTransactions) {
        SKPaymentTransaction *transaction = [observer.pendingTransactions objectForKey:token];
        if (transaction.transactionState == SKPaymentTransactionStatePurchased ||
            transaction.transactionState == SKPaymentTransactionStateRestored) {
            purchases.push_back([observer transactionToDictionary:transaction]);
        }
    }

    result["purchases"] = purchases;

    emit_signal("purchases_updated", result);
}

void GodotIAP::restorePurchases() {
    NSLog(@"[GodotIAP] Restoring purchases");

    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

void GodotIAP::acknowledgePurchase(const String &purchase_token) {
    NSLog(@"[GodotIAP] Acknowledging purchase: %s", purchase_token.utf8().get_data());

    GodotIAPTransactionObserver *observer = (GodotIAPTransactionObserver *)transaction_observer;

    NSString *token = [NSString stringWithUTF8String:purchase_token.utf8().get_data()];
    SKPaymentTransaction *transaction = [observer.pendingTransactions objectForKey:token];

    Dictionary result;
    result["purchase_token"] = purchase_token;

    if (transaction) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        [observer.pendingTransactions removeObjectForKey:token];
        result["status"] = 0; // OK
    } else {
        result["status"] = 8; // Item not owned
        result["error_message"] = "Transaction not found";
    }

    emit_signal("purchase_acknowledged", result);
}

void GodotIAP::consumePurchase(const String &purchase_token) {
    NSLog(@"[GodotIAP] Consuming purchase: %s", purchase_token.utf8().get_data());

    GodotIAPTransactionObserver *observer = (GodotIAPTransactionObserver *)transaction_observer;

    NSString *token = [NSString stringWithUTF8String:purchase_token.utf8().get_data()];
    SKPaymentTransaction *transaction = [observer.pendingTransactions objectForKey:token];

    Dictionary result;
    result["purchase_token"] = purchase_token;

    if (transaction) {
        // Mark as consumed (so we know it can be purchased again)
        NSString *product_id = transaction.payment.productIdentifier;
        [observer.consumedProducts addObject:product_id];

        // Finish the transaction
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        [observer.pendingTransactions removeObjectForKey:token];
        result["status"] = 0; // OK
    } else {
        result["status"] = 8; // Item not owned
        result["error_message"] = "Transaction not found";
    }

    emit_signal("purchase_consumed", result);
}

void GodotIAP::setAutoFinishTransactions(bool auto_finish) {
    NSLog(@"[GodotIAP] Setting auto-finish transactions: %d", auto_finish);

    GodotIAPTransactionObserver *observer = (GodotIAPTransactionObserver *)transaction_observer;
    observer.autoFinishTransactions = auto_finish;
}

String GodotIAP::getPlatform() {
    return "ios";
}
