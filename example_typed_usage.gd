extends Node
## Example: Using strongly-typed billing classes
##
## This demonstrates how to use the BillingTypes classes for type-safe
## billing operations with full autocomplete support.

var billing

# Store products with type safety
var product_catalog: Dictionary = {}  # String -> BillingTypes.Product

func _ready():
	# Setup billing (mock or real)
	if Engine.is_editor_hint():
		billing = MockGodotBilling.new()
		add_child(billing)
	else:
		if OS.get_name() == "iOS":
			billing = Engine.get_singleton("GodotBilling")
		else:
			billing = Engine.get_singleton("GodotBilling")

	# Connect signals with typed handlers
	billing.billing_connected.connect(_on_billing_connected)
	billing.sku_details_query_completed.connect(_on_sku_details_completed)
	billing.purchase_updated.connect(_on_purchase_updated)
	billing.purchase_acknowledged.connect(_on_purchase_acknowledged)
	billing.purchase_consumed.connect(_on_purchase_consumed)
	billing.purchases_restored.connect(_on_purchases_restored)

	billing.startConnection()

# ============================================================================
# Typed Signal Handlers
# ============================================================================

func _on_billing_connected(result_dict: Dictionary) -> void:
	# Convert Dictionary to strongly-typed result
	var result := BillingTypes.ConnectionResult.from_dict(result_dict)

	if result.is_success():
		print("✅ Connected to billing service")
		_query_all_products()
	else:
		# Type-safe error handling with autocomplete
		print("❌ Connection failed: ", result.get_error())

func _on_sku_details_completed(result_dict: Dictionary) -> void:
	var result := BillingTypes.ProductQueryResult.from_dict(result_dict)

	if not result.is_success():
		print("❌ Product query failed: ", result.get_error())
		return

	print("✅ Found %d products" % result.products.size())

	# Type-safe iteration over products
	for product in result.products:
		# Full autocomplete on Product properties!
		print("  %s - %s (%s)" % [product.sku, product.title, product.price])
		print("    Price value: $%.2f" % product.get_price_value())
		print("    Is subscription: ", product.is_subscription())

		# Store in catalog
		product_catalog[product.sku] = product

	# Check for invalid SKUs (iOS)
	if result.invalid_skus.size() > 0:
		print("⚠️ Invalid SKUs: ", result.invalid_skus)

func _on_purchase_updated(result_dict: Dictionary) -> void:
	var result := BillingTypes.PurchaseResult.from_dict(result_dict)

	# Type-safe status checking
	if result.is_cancelled():
		print("User cancelled purchase")
		return

	if not result.is_success():
		print("❌ Purchase failed: ", result.get_error())
		return

	print("✅ Purchase successful!")

	# Type-safe iteration over purchases
	for purchase in result.purchases:
		# Full autocomplete on Purchase properties!
		print("  SKU: ", purchase.sku)
		print("  Token: ", purchase.purchase_token)
		print("  Order: ", purchase.order_id)
		print("  Time: ", purchase.get_purchase_datetime())
		print("  Needs acknowledgement: ", purchase.needs_acknowledgement())

		# Handle based on product type
		_handle_purchase_typed(purchase)

func _on_purchase_acknowledged(result_dict: Dictionary) -> void:
	var result := BillingTypes.AcknowledgementResult.from_dict(result_dict)

	if result.is_success():
		print("✅ Acknowledged: ", result.purchase_token)
	else:
		print("❌ Acknowledge failed: ", result.get_error())

func _on_purchase_consumed(result_dict: Dictionary) -> void:
	var result := BillingTypes.ConsumptionResult.from_dict(result_dict)

	if result.is_success():
		print("✅ Consumed: ", result.purchase_token)
	else:
		print("❌ Consume failed: ", result.get_error())

func _on_purchases_restored(result_dict: Dictionary) -> void:
	var result := BillingTypes.PurchaseResult.from_dict(result_dict)

	if not result.is_success():
		print("❌ Restore failed: ", result.get_error())
		return

	if not result.has_purchases():
		print("No purchases to restore")
		return

	print("✅ Restoring %d purchases" % result.purchases.size())

	# Get all unique SKUs
	var restored_skus := result.get_skus()
	print("  Restored SKUs: ", restored_skus)

	# Process each purchase
	for purchase in result.purchases:
		_restore_purchase_typed(purchase)

# ============================================================================
# Type-Safe Business Logic
# ============================================================================

func _handle_purchase_typed(purchase: BillingTypes.Purchase) -> void:
	# Get product info (type-safe!)
	var product := product_catalog.get(purchase.sku) as BillingTypes.Product
	if not product:
		print("⚠️ Product not in catalog: ", purchase.sku)
		return

	# Type-safe product checking
	if product.is_subscription():
		_handle_subscription(purchase, product)
	elif product.sku.begins_with("coins_"):
		_handle_consumable(purchase, product)
	else:
		_handle_non_consumable(purchase, product)

func _handle_consumable(purchase: BillingTypes.Purchase, product: BillingTypes.Product) -> void:
	print("💰 Granting consumable: ", product.title)

	# Extract coin amount from SKU
	var amount := _extract_coin_amount(product.sku)
	_grant_coins(amount)

	# Consume so it can be purchased again
	billing.consumePurchase(purchase.purchase_token)

func _handle_non_consumable(purchase: BillingTypes.Purchase, product: BillingTypes.Product) -> void:
	print("⭐ Unlocking: ", product.title)

	match product.sku:
		"premium_unlock":
			_unlock_premium()
		"remove_ads":
			_remove_ads()
		_:
			print("Unknown non-consumable: ", product.sku)

	# Acknowledge (required on Android within 3 days!)
	billing.acknowledgePurchase(purchase.purchase_token)

func _handle_subscription(purchase: BillingTypes.Purchase, product: BillingTypes.Product) -> void:
	print("📅 Activating subscription: ", product.title)

	_activate_subscription(product.sku)

	# Acknowledge
	billing.acknowledgePurchase(purchase.purchase_token)

func _restore_purchase_typed(purchase: BillingTypes.Purchase) -> void:
	var product := product_catalog.get(purchase.sku) as BillingTypes.Product
	if not product:
		return

	# Only restore non-consumables and subscriptions
	if product.is_subscription():
		_activate_subscription(product.sku)
	elif not product.sku.begins_with("coins_"):
		# Restore non-consumable
		match product.sku:
			"premium_unlock":
				_unlock_premium()
			"remove_ads":
				_remove_ads()

# ============================================================================
# UI Functions (Type-Safe)
# ============================================================================

func show_store_ui() -> void:
	# Get products with type safety
	var inapp_products := _get_products_by_type("inapp")
	var sub_products := _get_products_by_type("subs")

	print("=== In-App Products ===")
	for product in inapp_products:
		_display_product_button(product)

	print("=== Subscriptions ===")
	for product in sub_products:
		_display_product_button(product)

func _get_products_by_type(type: String) -> Array[BillingTypes.Product]:
	var result: Array[BillingTypes.Product] = []
	for sku in product_catalog:
		var product := product_catalog[sku] as BillingTypes.Product
		if product.type == type:
			result.append(product)
	return result

func _display_product_button(product: BillingTypes.Product) -> void:
	# Full autocomplete on product properties
	print("  [%s] %s - %s" % [product.sku, product.title, product.price])

	# Could create actual UI button here
	# button.text = "%s - %s" % [product.title, product.price]
	# button.pressed.connect(func(): _buy_product(product))

func _buy_product(product: BillingTypes.Product) -> void:
	if not billing.isReady():
		print("Billing not ready!")
		return

	print("Purchasing: ", product.title)

	# Type parameter helps with iOS, ignored on Android
	var result_dict := billing.purchase(product.sku, product.type)
	var result := BillingTypes.BillingResult.from_dict(result_dict)

	if not result.is_success():
		print("Failed to start purchase: ", result.get_error())

# ============================================================================
# Type-Safe Query Functions
# ============================================================================

func _query_all_products() -> void:
	# Query in-app products
	billing.querySkuDetails([
		"coins_100",
		"coins_500",
		"coins_1000",
		"premium_unlock",
		"remove_ads"
	], "inapp")

	# Query subscriptions
	billing.querySkuDetails([
		"premium_monthly",
		"premium_yearly"
	], "subs")

func get_product_info(sku: String) -> BillingTypes.Product:
	return product_catalog.get(sku) as BillingTypes.Product

func is_product_available(sku: String) -> bool:
	return product_catalog.has(sku)

func get_product_price(sku: String) -> String:
	var product := get_product_info(sku)
	return product.price if product else ""

func get_product_price_value(sku: String) -> float:
	var product := get_product_info(sku)
	return product.get_price_value() if product else 0.0

# ============================================================================
# Example: Using Status Enum
# ============================================================================

func handle_purchase_with_enum(result_dict: Dictionary) -> void:
	var result := BillingTypes.PurchaseResult.from_dict(result_dict)

	# Type-safe enum comparison
	match result.status:
		BillingTypes.Status.OK:
			print("✅ Success!")
			for purchase in result.purchases:
				_handle_purchase_typed(purchase)

		BillingTypes.Status.USER_CANCELLED:
			print("User cancelled")

		BillingTypes.Status.BILLING_UNAVAILABLE:
			print("Billing not available on this device")

		BillingTypes.Status.ITEM_NOT_OWNED:
			print("Item not owned")

		BillingTypes.Status.DEVELOPER_ERROR:
			print("Developer error - check your code!")

		_:
			print("Error: ", BillingTypes.status_to_string(result.status))

# ============================================================================
# Example: Advanced Typed Queries
# ============================================================================

func find_cheapest_coin_pack() -> BillingTypes.Product:
	var coin_products := _get_products_by_type("inapp")
	var cheapest: BillingTypes.Product = null
	var min_price := INF

	for product in coin_products:
		if product.sku.begins_with("coins_"):
			var price := product.get_price_value()
			if price < min_price:
				min_price = price
				cheapest = product

	return cheapest

func get_subscription_savings() -> Dictionary:
	var monthly := get_product_info("premium_monthly")
	var yearly := get_product_info("premium_yearly")

	if not monthly or not yearly:
		return {}

	var monthly_annual_cost := monthly.get_price_value() * 12
	var yearly_cost := yearly.get_price_value()
	var savings := monthly_annual_cost - yearly_cost
	var savings_percent := (savings / monthly_annual_cost) * 100

	return {
		"monthly_annual": monthly_annual_cost,
		"yearly": yearly_cost,
		"savings": savings,
		"savings_percent": savings_percent
	}

# ============================================================================
# Example: Type-Safe Purchase Validation
# ============================================================================

func validate_purchase(purchase: BillingTypes.Purchase) -> bool:
	# Check purchase is completed
	if not purchase.is_completed():
		print("⚠️ Purchase not completed")
		return false

	# Check we have product info
	var product := get_product_info(purchase.sku)
	if not product:
		print("⚠️ Unknown product: ", purchase.sku)
		return false

	# Check purchase token exists
	if purchase.purchase_token.is_empty():
		print("⚠️ No purchase token")
		return false

	# Check purchase isn't too old (optional)
	var purchase_age := Time.get_unix_time_from_system() - purchase.purchase_time
	if purchase_age > 86400 * 7:  # 7 days
		print("⚠️ Purchase is very old")

	return true

# ============================================================================
# Placeholder implementations
# ============================================================================

func _grant_coins(amount: int) -> void:
	print("💰 Granted %d coins" % amount)

func _unlock_premium() -> void:
	print("⭐ Premium unlocked")

func _remove_ads() -> void:
	print("🚫 Ads removed")

func _activate_subscription(sku: String) -> void:
	print("📅 Subscription activated: ", sku)

func _extract_coin_amount(sku: String) -> int:
	# Extract number from "coins_100" -> 100
	var parts := sku.split("_")
	if parts.size() > 1:
		return int(parts[1])
	return 0
