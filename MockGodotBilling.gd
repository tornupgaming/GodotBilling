extends Node
## Mock implementation of GodotBilling for testing in editor
##
## This mock allows you to test IAP flows without deploying to device.
## Add it as an autoload singleton when Engine.is_editor_hint() is true.
##
## Features:
## - Simulates all billing operations with realistic delays
## - Configurable success/failure scenarios
## - Fake product catalog
## - Purchase history tracking
## - Detailed debug logging

class_name MockGodotBilling

# ============================================================================
# Signals (same as real plugin)
# ============================================================================

signal billing_connected(result: Dictionary)
signal billing_disconnected
signal sku_details_query_completed(result: Dictionary)
signal purchase_updated(result: Dictionary)
signal purchases_updated(result: Dictionary)
signal purchases_restored(result: Dictionary)
signal purchase_acknowledged(result: Dictionary)
signal purchase_consumed(result: Dictionary)
signal billing_error(error: Dictionary)

# Backward compatibility signals (deprecated)
signal connected
signal disconnected
signal purchase_error(code: int, message: String)
signal sku_details_query_error(code: int, message: String, skus: Array)
signal query_purchases_response(result: Dictionary)

# ============================================================================
# Configuration
# ============================================================================

## Enable/disable debug logging
var debug_enabled := true

## Simulate network delay (in seconds)
var network_delay := 2.5

## Chance of random failures (0.0 = never, 1.0 = always)
var failure_rate := 0.0

## Platform to simulate
var mock_platform := "android"  # "android" or "ios"

## Auto-finish transactions (iOS behavior)
var auto_finish_transactions := false

# ============================================================================
# Internal State
# ============================================================================

var _is_connected := false
var _is_ready := false

# Mock product catalog
var _product_catalog := {
	"coins_100":
	{
		"sku": "coins_100",
		"title": "100 Coins",
		"description": "A small bag of coins",
		"price": "$0.99",
		"price_currency_code": "USD",
		"price_amount_micros": 990000,
		"type": "inapp"
	},
	"coins_500":
	{
		"sku": "coins_500",
		"title": "500 Coins",
		"description": "A medium bag of coins",
		"price": "$4.99",
		"price_currency_code": "USD",
		"price_amount_micros": 4990000,
		"type": "inapp"
	},
	"coins_1000":
	{
		"sku": "coins_1000",
		"title": "1000 Coins",
		"description": "A large bag of coins",
		"price": "$9.99",
		"price_currency_code": "USD",
		"price_amount_micros": 9990000,
		"type": "inapp"
	},
	"premium_unlock":
	{
		"sku": "premium_unlock",
		"title": "Premium Unlock",
		"description": "Unlock all premium features",
		"price": "$19.99",
		"price_currency_code": "USD",
		"price_amount_micros": 19990000,
		"type": "inapp"
	},
	"remove_ads":
	{
		"sku": "remove_ads",
		"title": "Remove Ads",
		"description": "Remove all advertisements",
		"price": "$2.99",
		"price_currency_code": "USD",
		"price_amount_micros": 2990000,
		"type": "inapp"
	},
	"premium_monthly":
	{
		"sku": "premium_monthly",
		"title": "Premium Monthly",
		"description": "Monthly premium subscription",
		"price": "$9.99",
		"price_currency_code": "USD",
		"price_amount_micros": 9990000,
		"type": "subs"
	},
	"premium_yearly":
	{
		"sku": "premium_yearly",
		"title": "Premium Yearly",
		"description": "Yearly premium subscription (save 20%)",
		"price": "$99.99",
		"price_currency_code": "USD",
		"price_amount_micros": 99990000,
		"type": "subs"
	}
}

# Purchase tracking
var _purchased_items := {}  # purchase_token -> purchase dict
var _owned_products := []  # List of owned non-consumable SKUs
var _active_subscriptions := []  # List of active subscription SKUs
var _next_purchase_token := 1
var _next_order_id := 1000

# ============================================================================
# Lifecycle
# ============================================================================


func _ready():
	_log("MockGodotBilling initialized")
	_log("Platform: %s" % mock_platform)
	_log("Network delay: %.1fs" % network_delay)
	if failure_rate > 0:
		_log("Failure rate: %.0f%%" % (failure_rate * 100))


# ============================================================================
# Connection Management
# ============================================================================


func startConnection() -> void:
	_log("startConnection() called")
	await get_tree().create_timer(network_delay).timeout

	if _should_fail():
		var result := {"status": 6, "error_message": "Mock connection failed (simulated)"}  # ERROR
		_log("Connection FAILED")
		billing_connected.emit(result)
		connected.emit()  # Backward compat
		return

	_is_connected = true
	_is_ready = true

	var result := {"status": 0}
	_log("Connection SUCCESS")
	billing_connected.emit(result)
	connected.emit()  # Backward compat


func endConnection() -> void:
	_log("endConnection() called")
	_is_connected = false
	_is_ready = false
	billing_disconnected.emit()
	disconnected.emit()  # Backward compat


func isReady() -> bool:
	return _is_ready


func getPlatform() -> String:
	return mock_platform


func setAutoFinishTransactions(auto_finish: bool) -> void:
	_log("setAutoFinishTransactions(%s)" % auto_finish)
	auto_finish_transactions = auto_finish


# ============================================================================
# Product Queries
# ============================================================================


func querySkuDetails(skus: Array, type: String) -> void:
	_log("querySkuDetails(skus: %s, type: %s)" % [skus, type])

	if not _is_ready:
		_log_error("Not connected! Call startConnection() first")
		return

	await get_tree().create_timer(network_delay).timeout

	if _should_fail():
		var result := {
			"status": 6, "error_message": "Mock SKU query failed (simulated)", "products": []  # ERROR
		}
		_log("SKU query FAILED")
		sku_details_query_completed.emit(result)
		sku_details_query_error.emit(6, result.error_message, skus)  # Backward compat
		return

	var products := []
	var invalid_skus := []

	for sku in skus:
		if _product_catalog.has(sku):
			var product = _product_catalog[sku].duplicate()
			# Only include products of the requested type
			if product.type == type:
				products.append(product)
			else:
				_log_warn("SKU '%s' is type '%s', not '%s'" % [sku, product.type, type])
				invalid_skus.append(sku)
		else:
			_log_warn("Unknown SKU: %s" % sku)
			invalid_skus.append(sku)

	var result := {"status": 0, "products": products}  # OK

	if invalid_skus.size() > 0:
		result["invalid_skus"] = invalid_skus

	_log("SKU query SUCCESS: %d products found" % products.size())
	sku_details_query_completed.emit(result)


# ============================================================================
# Purchasing
# ============================================================================


func purchase(sku: String, type: String = "inapp") -> Dictionary:
	_log("purchase(sku: %s, type: %s)" % [sku, type])

	if not _is_ready:
		_log_error("Not connected! Call startConnection() first")
		return {"status": 5, "error_message": "Not connected"}

	if not _product_catalog.has(sku):
		_log_error("Unknown SKU: %s" % sku)
		return {"status": 5, "error_message": "Unknown SKU: " + sku}

	# Immediate return (purchase UI is opening)
	var immediate_result := {"status": 0}

	# Simulate async purchase flow
	_simulate_purchase_flow(sku)

	return immediate_result


func _simulate_purchase_flow(sku: String) -> void:
	await get_tree().create_timer(network_delay * 2).timeout  # User interaction takes longer

	# Simulate user cancellation (10% of the time if no failures configured)
	if failure_rate == 0 and randf() < 0.1:
		var result := {"status": 1, "purchases": []}  # USER_CANCELLED
		_log("Purchase CANCELLED by user (simulated)")
		purchase_updated.emit(result)
		return

	if _should_fail():
		var result := {
			"status": 6, "error_message": "Mock purchase failed (simulated)", "purchases": []  # ERROR
		}
		_log("Purchase FAILED")
		purchase_updated.emit(result)
		purchase_error.emit(6, result.error_message)  # Backward compat
		return

	# Create purchase
	var purchase_token := "mock_token_%d" % _next_purchase_token
	_next_purchase_token += 1

	var order_id := (
		"GPA.%d-%d-%d" % [_next_order_id, randi() % 10000, Time.get_unix_time_from_system()]
	)
	_next_order_id += 1

	var purchase := {
		"sku": sku,
		"purchase_token": purchase_token,
		"order_id": order_id,
		"purchase_time": Time.get_unix_time_from_system(),
		"signature": "mock_signature_" + purchase_token,  # Android only
		"acknowledged": false,
		"purchase_state": 1  # 1 = purchased
	}

	_purchased_items[purchase_token] = purchase

	# Track owned items
	var product = _product_catalog[sku]
	if product.type == "inapp":
		if not sku in _owned_products:
			_owned_products.append(sku)
	elif product.type == "subs":
		if not sku in _active_subscriptions:
			_active_subscriptions.append(sku)

	var result := {"status": 0, "purchases": [purchase]}  # OK

	_log("Purchase SUCCESS: %s" % sku)
	_log("  Token: %s" % purchase_token)
	_log("  Order: %s" % order_id)

	purchase_updated.emit(result)

	# Auto-finish if enabled (iOS behavior)
	if auto_finish_transactions:
		_log("Auto-finishing transaction (iOS mode)")
		acknowledgePurchase(purchase_token)


# ============================================================================
# Purchase Queries
# ============================================================================


func queryPurchases(type: String) -> void:
	_log("queryPurchases(type: %s)" % type)

	if not _is_ready:
		_log_error("Not connected!")
		return

	await get_tree().create_timer(network_delay).timeout

	var purchases := []
	for token in _purchased_items:
		var purchase = _purchased_items[token]
		var product = _product_catalog.get(purchase.sku)
		if product and product.type == type and not purchase.get("consumed", false):
			purchases.append(purchase)

	var result := {"status": 0, "purchases": purchases}

	_log("Query purchases: %d found" % purchases.size())
	purchases_updated.emit(result)
	query_purchases_response.emit(result)  # Backward compat


func restorePurchases() -> void:
	_log("restorePurchases() called")

	if not _is_ready:
		_log_error("Not connected!")
		return

	await get_tree().create_timer(network_delay * 1.5).timeout

	if _should_fail():
		var result := {
			"status": 6, "error_message": "Mock restore failed (simulated)", "purchases": []
		}
		_log("Restore FAILED")
		purchases_restored.emit(result)
		return

	# Return all non-consumed purchases
	var purchases := []
	for token in _purchased_items:
		var purchase = _purchased_items[token]
		if not purchase.get("consumed", false):
			purchases.append(purchase)

	var result := {"status": 0, "purchases": purchases}

	_log("Restore SUCCESS: %d purchases" % purchases.size())
	purchases_restored.emit(result)


# ============================================================================
# Purchase Completion
# ============================================================================


func acknowledgePurchase(purchase_token: String) -> void:
	_log("acknowledgePurchase(token: %s)" % purchase_token)

	await get_tree().create_timer(network_delay * 0.5).timeout

	if not _purchased_items.has(purchase_token):
		var result := {
			"status": 8,  # ITEM_NOT_OWNED
			"error_message": "Purchase token not found",
			"purchase_token": purchase_token
		}
		_log_error("Acknowledge FAILED: token not found")
		purchase_acknowledged.emit(result)
		return

	if _should_fail():
		var result := {
			"status": 6,  # ERROR
			"error_message": "Mock acknowledge failed (simulated)",
			"purchase_token": purchase_token
		}
		_log("Acknowledge FAILED")
		purchase_acknowledged.emit(result)
		return

	_purchased_items[purchase_token]["acknowledged"] = true

	var result := {"status": 0, "purchase_token": purchase_token}

	_log("Acknowledge SUCCESS")
	purchase_acknowledged.emit(result)


func consumePurchase(purchase_token: String) -> void:
	_log("consumePurchase(token: %s)" % purchase_token)

	await get_tree().create_timer(network_delay * 0.5).timeout

	if not _purchased_items.has(purchase_token):
		var result := {
			"status": 8,  # ITEM_NOT_OWNED
			"error_message": "Purchase token not found",
			"purchase_token": purchase_token
		}
		_log_error("Consume FAILED: token not found")
		purchase_consumed.emit(result)
		return

	if _should_fail():
		var result := {
			"status": 6,  # ERROR
			"error_message": "Mock consume failed (simulated)",
			"purchase_token": purchase_token
		}
		_log("Consume FAILED")
		purchase_consumed.emit(result)
		return

	var purchase = _purchased_items[purchase_token]
	purchase["consumed"] = true
	purchase["acknowledged"] = true

	# Remove from owned items (can be purchased again)
	var sku = purchase.sku
	_owned_products.erase(sku)

	var result := {"status": 0, "purchase_token": purchase_token}

	_log("Consume SUCCESS: %s can be purchased again" % sku)
	purchase_consumed.emit(result)


# ============================================================================
# Mock Control Functions (for testing different scenarios)
# ============================================================================


## Add a custom product to the mock catalog
func mock_add_product(sku: String, title: String, price: String, type: String = "inapp") -> void:
	_product_catalog[sku] = {
		"sku": sku,
		"title": title,
		"description": "Mock product",
		"price": price,
		"price_currency_code": "USD",
		"price_amount_micros": 0,
		"type": type
	}
	_log("Added mock product: %s" % sku)


## Simulate a purchase without going through the flow (for testing restore)
func mock_grant_purchase(sku: String) -> String:
	var purchase_token := "mock_granted_%d" % _next_purchase_token
	_next_purchase_token += 1

	var purchase := {
		"sku": sku,
		"purchase_token": purchase_token,
		"order_id": "GPA.MOCK.%d" % _next_order_id,
		"purchase_time": Time.get_unix_time_from_system() - 86400,  # Yesterday
		"signature": "mock_signature",
		"acknowledged": true,
		"purchase_state": 1
	}

	_next_order_id += 1
	_purchased_items[purchase_token] = purchase

	var product = _product_catalog.get(sku)
	if product:
		if product.type == "inapp":
			if not sku in _owned_products:
				_owned_products.append(sku)
		elif product.type == "subs":
			if not sku in _active_subscriptions:
				_active_subscriptions.append(sku)

	_log("Granted mock purchase: %s (token: %s)" % [sku, purchase_token])
	return purchase_token


## Clear all purchase history (reset mock state)
func mock_clear_purchases() -> void:
	_purchased_items.clear()
	_owned_products.clear()
	_active_subscriptions.clear()
	_log("Cleared all mock purchases")


## Get all mock purchase data (for debugging)
func mock_get_purchase_history() -> Dictionary:
	return {
		"purchased_items": _purchased_items,
		"owned_products": _owned_products,
		"active_subscriptions": _active_subscriptions
	}


## Simulate a specific error on next operation
var _next_operation_fails := false


func mock_fail_next_operation() -> void:
	_next_operation_fails = true
	_log("Next operation will fail (one-time)")


# ============================================================================
# Internal Helpers
# ============================================================================


func _should_fail() -> bool:
	if _next_operation_fails:
		_next_operation_fails = false
		return true
	return randf() < failure_rate


func _log(message: String) -> void:
	if debug_enabled:
		print("[MockGodotBilling] ", message)


func _log_warn(message: String) -> void:
	if debug_enabled:
		push_warning("[MockGodotBilling] WARNING: " + message)


func _log_error(message: String) -> void:
	if debug_enabled:
		push_error("[MockGodotBilling] ERROR: " + message)


# ============================================================================
# Deprecated Methods (for backward compatibility testing)
# ============================================================================


## @deprecated Use getConnectionState() instead
func getConnectionState() -> int:
	return 2 if _is_connected else 0  # 2 = CONNECTED, 0 = DISCONNECTED


## @deprecated Use purchase() instead
func updateSubscription(old_token: String, sku: String, replacement_mode: int) -> Dictionary:
	_log_warn("updateSubscription() is deprecated, using purchase() instead")
	return purchase(sku, "subs")


## @deprecated Price changes handled automatically now
func confirmPriceChange(sku: String) -> Dictionary:
	_log_warn("confirmPriceChange() is deprecated")
	return {"status": 0}


## @deprecated Not in unified interface
func setObfuscatedAccountId(account_id: String) -> void:
	_log_warn("setObfuscatedAccountId() is deprecated (Android-only)")


## @deprecated Not in unified interface
func setObfuscatedProfileId(profile_id: String) -> void:
	_log_warn("setObfuscatedProfileId() is deprecated (Android-only)")
