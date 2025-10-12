//
//  billing_plugin.mm
//  godot_plugin
//
//  iOS In-App Purchase plugin for Godot
//

#import <Foundation/Foundation.h>

#include "core/config/project_settings.h"
#include "core/object/class_db.h"

#import "billing_plugin.h"

GodotIOSBilling *GodotIOSBilling::instance = NULL;

GodotIOSBilling::GodotIOSBilling() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;
    NSLog(@"GodotIOSBilling plugin initialized");
}

GodotIOSBilling::~GodotIOSBilling() {
    if (instance == this) {
        instance = NULL;
    }
    NSLog(@"GodotIOSBilling plugin destroyed");
}

GodotIOSBilling *GodotIOSBilling::get_singleton() {
    return instance;
}

void GodotIOSBilling::_bind_methods() {
    // Bind methods
    ClassDB::bind_method(D_METHOD("startConnection"), &GodotIOSBilling::startConnection);
    ClassDB::bind_method(D_METHOD("purchase"), &GodotIOSBilling::purchase);
    ClassDB::bind_method(D_METHOD("queryPurchases"), &GodotIOSBilling::queryPurchases);
    ClassDB::bind_method(D_METHOD("querySkuDetails"), &GodotIOSBilling::querySkuDetails);
    ClassDB::bind_method(D_METHOD("acknowledgePurchase"), &GodotIOSBilling::acknowledgePurchase);
    ClassDB::bind_method(D_METHOD("consumePurchase"), &GodotIOSBilling::consumePurchase);

    // Bind signals
    ADD_SIGNAL(MethodInfo("connected"));
    ADD_SIGNAL(MethodInfo("disconnected"));
    ADD_SIGNAL(MethodInfo("connect_error",
        PropertyInfo(Variant::INT, "response_id"),
        PropertyInfo(Variant::STRING, "debug_message")));

    ADD_SIGNAL(MethodInfo("purchases_updated",
        PropertyInfo(Variant::ARRAY, "purchases")));
    ADD_SIGNAL(MethodInfo("purchase_error",
        PropertyInfo(Variant::INT, "response_id"),
        PropertyInfo(Variant::STRING, "debug_message")));

    ADD_SIGNAL(MethodInfo("sku_details_query_completed",
        PropertyInfo(Variant::ARRAY, "products")));
    ADD_SIGNAL(MethodInfo("sku_details_query_error",
        PropertyInfo(Variant::INT, "response_id"),
        PropertyInfo(Variant::STRING, "debug_message"),
        PropertyInfo(Variant::ARRAY, "queried_skus")));

    ADD_SIGNAL(MethodInfo("purchase_acknowledged",
        PropertyInfo(Variant::STRING, "purchase_token")));
    ADD_SIGNAL(MethodInfo("purchase_acknowledgement_error",
        PropertyInfo(Variant::INT, "response_id"),
        PropertyInfo(Variant::STRING, "debug_message"),
        PropertyInfo(Variant::STRING, "purchase_token")));

    ADD_SIGNAL(MethodInfo("purchase_consumed",
        PropertyInfo(Variant::STRING, "purchase_token")));
    ADD_SIGNAL(MethodInfo("purchase_consumption_error",
        PropertyInfo(Variant::INT, "response_id"),
        PropertyInfo(Variant::STRING, "debug_message"),
        PropertyInfo(Variant::STRING, "purchase_token")));

    ADD_SIGNAL(MethodInfo("query_purchases_response",
        PropertyInfo(Variant::DICTIONARY, "purchases")));
}

// ===== Method Implementations with Dummy Data =====

void GodotIOSBilling::startConnection() {
    NSLog(@"GodotIOSBilling::startConnection called");

    // Simulate successful connection after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"GodotIOSBilling: Emitting 'connected' signal");
        emit_signal("connected");
    });
}

void GodotIOSBilling::purchase(String sku) {
    NSLog(@"GodotIOSBilling::purchase called with SKU: %s", sku.utf8().get_data());

    // Simulate a successful purchase after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Array purchases;
        Dictionary purchase_data;

        purchase_data["sku"] = sku;
        purchase_data["purchase_token"] = "dummy_token_" + sku;
        purchase_data["purchase_state"] = 1; // PURCHASED
        purchase_data["purchase_time"] = (int64_t)[[NSDate date] timeIntervalSince1970] * 1000;
        purchase_data["original_json"] = "{\"sku\":\"" + sku + "\"}";
        purchase_data["signature"] = "dummy_signature";
        purchase_data["is_acknowledged"] = false;

        purchases.push_back(purchase_data);

        NSLog(@"GodotIOSBilling: Emitting 'purchases_updated' signal");
        emit_signal("purchases_updated", purchases);
    });
}

void GodotIOSBilling::queryPurchases(String type) {
    NSLog(@"GodotIOSBilling::queryPurchases called with type: %s", type.utf8().get_data());

    // Simulate returning empty purchases (no previous purchases)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Dictionary response;
        Array purchases;
        response["purchases"] = purchases;
        response["status"] = 0; // OK

        NSLog(@"GodotIOSBilling: Emitting 'query_purchases_response' signal");
        emit_signal("query_purchases_response", response);
    });
}

void GodotIOSBilling::querySkuDetails(Array skus, String type) {
    NSLog(@"GodotIOSBilling::querySkuDetails called with %d SKUs", (int)skus.size());

    // Simulate returning product details for each SKU
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Array products;

        for (int i = 0; i < skus.size(); i++) {
            String sku = skus[i];
            Dictionary product;

            product["sku"] = sku;
            product["title"] = "Dummy Product - " + sku;
            product["description"] = "This is a dummy product for testing: " + sku;
            product["price"] = "$0.99";
            product["price_amount_micros"] = 990000; // $0.99 in micros
            product["price_currency_code"] = "USD";
            product["type"] = type;

            products.push_back(product);
        }

        NSLog(@"GodotIOSBilling: Emitting 'sku_details_query_completed' signal with %d products", (int)products.size());
        emit_signal("sku_details_query_completed", products);
    });
}

void GodotIOSBilling::acknowledgePurchase(String purchase_token) {
    NSLog(@"GodotIOSBilling::acknowledgePurchase called with token: %s", purchase_token.utf8().get_data());

    // Simulate successful acknowledgement
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"GodotIOSBilling: Emitting 'purchase_acknowledged' signal");
        emit_signal("purchase_acknowledged", purchase_token);
    });
}

void GodotIOSBilling::consumePurchase(String purchase_token) {
    NSLog(@"GodotIOSBilling::consumePurchase called with token: %s", purchase_token.utf8().get_data());

    // Simulate successful consumption
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"GodotIOSBilling: Emitting 'purchase_consumed' signal");
        emit_signal("purchase_consumed", purchase_token);
    });
}
