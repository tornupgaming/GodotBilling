extends Node
## Example: How to use MockGodotBilling in your game
##
## This shows how to set up the billing plugin with automatic mock injection
## when running in the editor, and real billing when deployed to device.

var billing  # Will be either real GodotBilling or MockGodotBilling

func _ready():
	# Setup billing plugin
	if Engine.is_editor_hint() or OS.has_feature("editor"):
		# Running in editor - use mock
		print("⚠️ Running in EDITOR mode - using MockGodotBilling")
		_setup_mock_billing()
	else:
		# Running on device - use real plugin
		print("✅ Running on DEVICE - using real billing")
		_setup_real_billing()

	# Connect to signals (same for both mock and real)
	_connect_signals()

	# Start connection
	billing.startConnection()

func _setup_mock_billing() -> void:
	# Create and configure mock
	billing = MockGodotBilling.new()
	billing.debug_enabled = true
	billing.network_delay = 0.5  # Simulate 500ms network delay
	billing.failure_rate = 0.0   # 0% failure rate (change to test errors)
	billing.mock_platform = "android"  # or "ios"

	# Add the mock as a child so signals work
	add_child(billing)

	# Optional: Add extra mock products for testing
	billing.mock_add_product("test_item", "Test Item", "$99.99", "inapp")

	# Optional: Pre-grant some purchases (for testing restore)
	# billing.mock_grant_purchase("premium_unlock")

func _setup_real_billing() -> void:
	# Get platform-specific plugin
	if OS.get_name() == "iOS":
		billing = Engine.get_singleton("GodotBilling")
	elif OS.get_name() == "Android":
		billing = Engine.get_singleton("GodotBilling")
	else:
		push_error("Unsupported platform: " + OS.get_name())
		billing = null

func _connect_signals() -> void:
	if not billing:
		return

	billing.billing_connected.connect(_on_billing_connected)
	billing.billing_disconnected.connect(_on_billing_disconnected)
	billing.sku_details_query_completed.connect(_on_sku_details_completed)
	billing.purchase_updated.connect(_on_purchase_updated)
	billing.purchases_updated.connect(_on_purchases_updated)
	billing.purchases_restored.connect(_on_purchases_restored)
	billing.purchase_acknowledged.connect(_on_purchase_acknowledged)
	billing.purchase_consumed.connect(_on_purchase_consumed)

# ============================================================================
# Signal Handlers
# ============================================================================

func _on_billing_connected(result: Dictionary) -> void:
	if result.status == 0:
		print("✅ Billing connected!")

		# Query products
		billing.querySkuDetails([
			"coins_100",
			"coins_500",
			"premium_unlock"
		], "inapp")

		billing.querySkuDetails([
			"premium_monthly"
		], "subs")
	else:
		print("❌ Billing connection failed: ", result.get("error_message"))

func _on_billing_disconnected() -> void:
	print("Billing disconnected")

func _on_sku_details_completed(result: Dictionary) -> void:
	if result.status != 0:
		print("❌ SKU query failed: ", result.get("error_message"))
		return

	print("✅ Found %d products:" % result.products.size())
	for product in result.products:
		print("  - %s: %s (%s)" % [product.sku, product.title, product.price])

func _on_purchase_updated(result: Dictionary) -> void:
	if result.status == 1:
		print("User cancelled purchase")
		return

	if result.status != 0:
		print("❌ Purchase failed: ", result.get("error_message"))
		return

	print("✅ Purchase successful!")
	for purchase in result.purchases:
		print("  Purchased: ", purchase.sku)
		print("  Token: ", purchase.purchase_token)

		# Handle the purchase
		_handle_purchase(purchase)

func _on_purchases_updated(result: Dictionary) -> void:
	print("Purchases queried: %d found" % result.purchases.size())

func _on_purchases_restored(result: Dictionary) -> void:
	if result.status != 0:
		print("❌ Restore failed: ", result.get("error_message"))
		return

	print("✅ Restored %d purchases" % result.purchases.size())
	for purchase in result.purchases:
		_handle_purchase(purchase)

func _on_purchase_acknowledged(result: Dictionary) -> void:
	if result.status == 0:
		print("✅ Purchase acknowledged: ", result.purchase_token)
	else:
		print("❌ Acknowledge failed: ", result.get("error_message"))

func _on_purchase_consumed(result: Dictionary) -> void:
	if result.status == 0:
		print("✅ Purchase consumed: ", result.purchase_token)
	else:
		print("❌ Consume failed: ", result.get("error_message"))

# ============================================================================
# Business Logic
# ============================================================================

func _handle_purchase(purchase: Dictionary) -> void:
	var sku = purchase.sku
	var token = purchase.purchase_token

	# In production, verify with your server here!
	# For mock/testing, we'll just grant immediately

	match sku:
		"coins_100":
			_grant_coins(100)
			billing.consumePurchase(token)

		"coins_500":
			_grant_coins(500)
			billing.consumePurchase(token)

		"coins_1000":
			_grant_coins(1000)
			billing.consumePurchase(token)

		"premium_unlock":
			_unlock_premium()
			billing.acknowledgePurchase(token)

		"remove_ads":
			_remove_ads()
			billing.acknowledgePurchase(token)

		"premium_monthly", "premium_yearly":
			_activate_subscription()
			billing.acknowledgePurchase(token)

func _grant_coins(amount: int) -> void:
	print("💰 Granted %d coins" % amount)
	# Your code here: player_data.coins += amount

func _unlock_premium() -> void:
	print("⭐ Premium unlocked!")
	# Your code here: player_data.is_premium = true

func _remove_ads() -> void:
	print("🚫 Ads removed!")
	# Your code here: player_data.ads_removed = true

func _activate_subscription() -> void:
	print("📅 Subscription activated!")
	# Your code here: player_data.subscription_active = true

# ============================================================================
# Example: Purchase Flow
# ============================================================================

func example_buy_coins() -> void:
	if not billing or not billing.isReady():
		print("Billing not ready!")
		return

	var result = billing.purchase("coins_100")
	if result.status != 0:
		print("Failed to start purchase: ", result.get("error_message"))

func example_restore_purchases() -> void:
	if not billing or not billing.isReady():
		print("Billing not ready!")
		return

	billing.restorePurchases()

# ============================================================================
# Mock-Specific Testing Functions
# ============================================================================

## Call these from debug menu to test different scenarios
func test_simulate_failure() -> void:
	if billing is MockGodotBilling:
		billing.mock_fail_next_operation()
		print("⚠️ Next operation will fail")

func test_increase_failure_rate() -> void:
	if billing is MockGodotBilling:
		billing.failure_rate = min(billing.failure_rate + 0.1, 1.0)
		print("⚠️ Failure rate: %.0f%%" % (billing.failure_rate * 100))

func test_clear_purchases() -> void:
	if billing is MockGodotBilling:
		billing.mock_clear_purchases()
		print("🗑️ Cleared all mock purchases")

func test_view_purchase_history() -> void:
	if billing is MockGodotBilling:
		var history = billing.mock_get_purchase_history()
		print("📜 Purchase History:")
		print("  Purchased Items: ", history.purchased_items.keys())
		print("  Owned Products: ", history.owned_products)
		print("  Active Subscriptions: ", history.active_subscriptions)
