extends Node

# Example usage of the unified GodotIAP plugin
# This code works identically on both iOS and Android

var iap

# Product IDs - these should match what you've configured in App Store Connect / Google Play Console
const COINS_100 = "coins_100"
const COINS_500 = "coins_500"
const PREMIUM_UNLOCK = "premium_unlock"
const MONTHLY_SUB = "premium_monthly"

func _ready():
	# Get the IAP singleton
	if Engine.has_singleton("GodotIAP"):
		iap = Engine.get_singleton("GodotIAP")
		_setup_iap()
	else:
		print("GodotIAP singleton not found - IAP disabled")

func _setup_iap():
	# Connect signals
	iap.connect("billing_connected", self, "_on_billing_connected")
	iap.connect("sku_details_query_completed", self, "_on_sku_details_completed")
	iap.connect("purchase_updated", self, "_on_purchase_updated")
	iap.connect("purchases_restored", self, "_on_purchases_restored")
	iap.connect("purchase_acknowledged", self, "_on_purchase_acknowledged")
	iap.connect("purchase_consumed", self, "_on_purchase_consumed")
	iap.connect("billing_error", self, "_on_billing_error")

	# Start the connection
	# iOS: Sets up transaction observer (instant)
	# Android: Connects to Google Play Billing (may take a moment)
	iap.startConnection()

# ============================================================================
# Signal Handlers
# ============================================================================

func _on_billing_connected(result):
	if result.status == 0:
		print("Billing connected successfully")
		print("Platform: ", iap.getPlatform())

		# Query product details
		var consumables = [COINS_100, COINS_500]
		var non_consumables = [PREMIUM_UNLOCK]
		var subscriptions = [MONTHLY_SUB]

		iap.querySkuDetails(consumables, "inapp")
		iap.querySkuDetails(subscriptions, "subs")

		# Check for existing purchases (important on app start!)
		iap.queryPurchases("inapp")
		iap.queryPurchases("subs")
	else:
		print("Billing connection failed: ", result)

func _on_sku_details_completed(result):
	if result.status == 0:
		print("Products loaded:")
		for product in result.products:
			print("  - %s: %s (%s)" % [product.sku, product.title, product.price])
			# Store product details to show in your shop UI
			_store_product_info(product)
	else:
		print("Failed to load products: ", result)

func _on_purchase_updated(result):
	if result.status == 0:
		print("Purchase successful!")
		for purchase in result.purchases:
			_handle_purchase(purchase)
	elif result.status == 1:
		print("User cancelled purchase")
	else:
		print("Purchase failed: ", result)

func _on_purchases_restored(result):
	if result.status == 0:
		print("Purchases restored: ", result.purchases.size(), " items")
		for purchase in result.purchases:
			_handle_purchase(purchase)
	else:
		print("Restore failed: ", result)

func _on_purchase_acknowledged(result):
	if result.status == 0:
		print("Purchase acknowledged: ", result.purchase_token)
	else:
		print("Failed to acknowledge: ", result)

func _on_purchase_consumed(result):
	if result.status == 0:
		print("Purchase consumed: ", result.purchase_token)
	else:
		print("Failed to consume: ", result)

func _on_billing_error(error):
	print("Billing error: ", error)

# ============================================================================
# Purchase Handling
# ============================================================================

func _handle_purchase(purchase):
	print("Handling purchase: ", purchase.sku)

	# Grant the item to the player
	match purchase.sku:
		COINS_100:
			_grant_coins(100)
			# Consumable - consume it so it can be purchased again
			iap.consumePurchase(purchase.purchase_token)

		COINS_500:
			_grant_coins(500)
			iap.consumePurchase(purchase.purchase_token)

		PREMIUM_UNLOCK:
			_unlock_premium()
			# Non-consumable - just acknowledge
			iap.acknowledgePurchase(purchase.purchase_token)

		MONTHLY_SUB:
			_activate_subscription()
			# Subscription - acknowledge
			iap.acknowledgePurchase(purchase.purchase_token)

# ============================================================================
# UI Actions
# ============================================================================

func _on_buy_button_pressed(sku):
	if iap and iap.isReady():
		# IMPORTANT: You must query product details before purchasing
		# This is required for the modern StoreKit API on iOS
		# If you try to purchase without querying first, it will fall back
		# to deprecated API (which still works but is not recommended)

		# Determine type based on SKU
		var type = "inapp"
		if sku == MONTHLY_SUB:
			type = "subs"

		print("Purchasing: ", sku)
		iap.purchase(sku, type)
	else:
		print("Billing not ready")

func _on_restore_button_pressed():
	# iOS requires a "Restore Purchases" button
	# Android will just query existing purchases
	if iap and iap.isReady():
		print("Restoring purchases...")
		iap.restorePurchases()
	else:
		print("Billing not ready")

# ============================================================================
# Game Logic (implement these for your game)
# ============================================================================

func _store_product_info(product):
	# Store product info to display in your shop
	# e.g., update button labels with prices
	pass

func _grant_coins(amount):
	# Add coins to player's account
	print("Granted ", amount, " coins")
	# SaveData.coins += amount
	# SaveData.save()

func _unlock_premium():
	# Unlock premium features
	print("Premium unlocked")
	# SaveData.is_premium = true
	# SaveData.save()

func _activate_subscription():
	# Activate subscription benefits
	print("Subscription activated")
	# SaveData.subscription_active = true
	# SaveData.subscription_expiry = purchase.expiry_time
	# SaveData.save()

# ============================================================================
# Important Notes
# ============================================================================

# 1. ALWAYS handle purchases on app start (queryPurchases)
#    - Users may have purchased while offline
#    - Purchases may not have been acknowledged yet
#
# 2. ALWAYS acknowledge or consume purchases
#    - Android will refund after 3 days if not acknowledged
#    - iOS will keep showing the transaction until finished
#
# 3. Store granted items BEFORE acknowledging/consuming
#    - If your server validates receipts, do that first
#    - Only acknowledge after you're sure the user got the item
#
# 4. iOS requires a "Restore Purchases" button in your UI
#    - App Store review will reject without it
#    - Android doesn't require it but it doesn't hurt
#
# 5. Test thoroughly with sandbox accounts
#    - iOS: Create sandbox testers in App Store Connect
#    - Android: Add test accounts in Google Play Console
#
# 6. For subscriptions, you'll want to verify receipts server-side
#    - iOS: Use the App Store Server API
#    - Android: Use the Google Play Developer API
