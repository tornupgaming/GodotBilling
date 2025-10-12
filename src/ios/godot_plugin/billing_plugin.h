//
//  billing_plugin.h
//  godot_plugin
//
//  iOS In-App Purchase plugin for Godot
//

#ifndef billing_plugin_h
#define billing_plugin_h

#include "core/object/class_db.h"

class GodotIOSBilling : public Object {
    GDCLASS(GodotIOSBilling, Object);

    static GodotIOSBilling *instance;
    static void _bind_methods();

public:
    // Connection methods
    void startConnection();

    // Purchase methods
    void purchase(String sku);
    void queryPurchases(String type);

    // Product details
    void querySkuDetails(Array skus, String type);

    // Acknowledgement and consumption
    void acknowledgePurchase(String purchase_token);
    void consumePurchase(String purchase_token);

    static GodotIOSBilling *get_singleton();

    GodotIOSBilling();
    ~GodotIOSBilling();
};

#endif /* billing_plugin_h */
