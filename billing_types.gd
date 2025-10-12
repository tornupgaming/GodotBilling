## Strongly-typed data classes for Godot Billing
##
## These classes provide type-safe wrappers around the Dictionary responses
## from the billing plugins, enabling better autocomplete and type checking.
##
## Usage:
##   var result = BillingResult.from_dict(billing_result_dict)
##   if result.is_success():
##       for product in result.get_products():
##           print(product.title, " - ", product.price)

class_name BillingTypes

# ============================================================================
# Enums
# ============================================================================

## Billing operation status codes
enum Status {
	OK = 0,                    ## Operation succeeded
	USER_CANCELLED = 1,        ## User cancelled the purchase
	SERVICE_UNAVAILABLE = 2,   ## Service temporarily unavailable
	BILLING_UNAVAILABLE = 3,   ## Billing not available on this device
	ITEM_UNAVAILABLE = 4,      ## Requested item not available for purchase
	DEVELOPER_ERROR = 5,       ## Invalid arguments or developer error
	ERROR = 6,                 ## Generic error
	ITEM_ALREADY_OWNED = 7,    ## Item already owned
	ITEM_NOT_OWNED = 8,        ## Item not owned (can't consume/acknowledge)
}

## Product type
enum ProductType {
	INAPP,     ## One-time purchase (consumable or non-consumable)
	SUBS,      ## Subscription
}

## Purchase state
enum PurchaseState {
	PENDING = 0,    ## Purchase is pending
	PURCHASED = 1,  ## Purchase completed successfully
	FAILED = 2,     ## Purchase failed
}

# ============================================================================
# Base Result Class
# ============================================================================

## Base class for all billing results
class BillingResult extends RefCounted:
	## Status code of the operation
	var status: Status = Status.OK

	## Error message (only present on error)
	var error_message: String = ""

	## Raw response code from platform (for debugging)
	var response_code: int = 0

	## Check if operation was successful
	func is_success() -> bool:
		return status == Status.OK

	## Check if user cancelled
	func is_cancelled() -> bool:
		return status == Status.USER_CANCELLED

	## Get error description
	func get_error() -> String:
		if is_success():
			return ""
		if error_message:
			return error_message
		return _get_status_string(status)

	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> BillingResult:
		var result = BillingResult.new()
		result._parse_common(dict)
		return result

	func _parse_common(dict: Dictionary) -> void:
		status = dict.get("status", Status.OK) as Status
		error_message = dict.get("error_message", "")
		response_code = dict.get("response_code", 0)

	static func _get_status_string(s: Status) -> String:
		match s:
			Status.OK: return "Success"
			Status.USER_CANCELLED: return "User cancelled"
			Status.SERVICE_UNAVAILABLE: return "Service unavailable"
			Status.BILLING_UNAVAILABLE: return "Billing unavailable"
			Status.ITEM_UNAVAILABLE: return "Item unavailable"
			Status.DEVELOPER_ERROR: return "Developer error"
			Status.ERROR: return "Error"
			Status.ITEM_ALREADY_OWNED: return "Item already owned"
			Status.ITEM_NOT_OWNED: return "Item not owned"
			_: return "Unknown error"

# ============================================================================
# Product (SKU Details)
# ============================================================================

## Product information from the store
class Product extends RefCounted:
	## Product ID (SKU)
	var sku: String = ""

	## Localized product title
	var title: String = ""

	## Localized product description
	var description: String = ""

	## Formatted price string (e.g., "$0.99")
	var price: String = ""

	## Currency code (e.g., "USD")
	var price_currency_code: String = ""

	## Price in micros (990000 = $0.99)
	var price_amount_micros: int = 0

	## Product type ("inapp" or "subs")
	var type: String = "inapp"

	## Get price as float (dollars/euros/etc)
	func get_price_value() -> float:
		return price_amount_micros / 1000000.0

	## Check if this is a subscription
	func is_subscription() -> bool:
		return type == "subs"

	## Check if this is an in-app purchase
	func is_inapp() -> bool:
		return type == "inapp"

	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> Product:
		var product = Product.new()
		product.sku = dict.get("sku", "")
		product.title = dict.get("title", "")
		product.description = dict.get("description", "")
		product.price = dict.get("price", "")
		product.price_currency_code = dict.get("price_currency_code", "")
		product.price_amount_micros = dict.get("price_amount_micros", 0)
		product.type = dict.get("type", "inapp")
		return product

	## Convert array of Dictionaries to array of Products
	static func array_from_dict(array: Array) -> Array[Product]:
		var products: Array[Product] = []
		for dict in array:
			if dict is Dictionary:
				products.append(Product.from_dict(dict))
		return products

# ============================================================================
# Purchase
# ============================================================================

## Purchase/transaction information
class Purchase extends RefCounted:
	## Product ID (SKU)
	var sku: String = ""

	## Platform-specific purchase token (required for acknowledge/consume)
	var purchase_token: String = ""

	## Order ID / Transaction ID
	var order_id: String = ""

	## Purchase time (Unix timestamp)
	var purchase_time: int = 0

	## Receipt signature (Android only)
	var signature: String = ""

	## Whether purchase has been acknowledged
	var acknowledged: bool = false

	## Purchase state (0=pending, 1=purchased, 2=failed)
	var purchase_state: PurchaseState = PurchaseState.PURCHASED

	## Get purchase time as DateTime
	func get_purchase_datetime() -> Dictionary:
		return Time.get_datetime_dict_from_unix_time(purchase_time)

	## Check if purchase is completed
	func is_completed() -> bool:
		return purchase_state == PurchaseState.PURCHASED

	## Check if purchase is pending
	func is_pending() -> bool:
		return purchase_state == PurchaseState.PENDING

	## Check if purchase needs acknowledgement
	func needs_acknowledgement() -> bool:
		return is_completed() and not acknowledged

	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> Purchase:
		var purchase = Purchase.new()
		purchase.sku = dict.get("sku", "")
		purchase.purchase_token = dict.get("purchase_token", "")
		purchase.order_id = dict.get("order_id", "")
		purchase.purchase_time = dict.get("purchase_time", 0)
		purchase.signature = dict.get("signature", "")
		purchase.acknowledged = dict.get("acknowledged", false)
		purchase.purchase_state = dict.get("purchase_state", PurchaseState.PURCHASED) as PurchaseState
		return purchase

	## Convert array of Dictionaries to array of Purchases
	static func array_from_dict(array: Array) -> Array[Purchase]:
		var purchases: Array[Purchase] = []
		for dict in array:
			if dict is Dictionary:
				purchases.append(Purchase.from_dict(dict))
		return purchases

# ============================================================================
# Connection Result
# ============================================================================

## Result of startConnection()
class ConnectionResult extends BillingResult:
	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> ConnectionResult:
		var result = ConnectionResult.new()
		result._parse_common(dict)
		return result

# ============================================================================
# Product Query Result
# ============================================================================

## Result of querySkuDetails()
class ProductQueryResult extends BillingResult:
	## Array of products found
	var products: Array[Product] = []

	## Array of invalid/unknown SKUs (iOS only)
	var invalid_skus: Array[String] = []

	## Check if any products were found
	func has_products() -> bool:
		return products.size() > 0

	## Get product by SKU
	func get_product(sku: String) -> Product:
		for product in products:
			if product.sku == sku:
				return product
		return null

	## Get all products as Dictionary (sku -> Product)
	func get_products_dict() -> Dictionary:
		var dict := {}
		for product in products:
			dict[product.sku] = product
		return dict

	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> ProductQueryResult:
		var result = ProductQueryResult.new()
		result._parse_common(dict)

		# Parse products array
		var products_array = dict.get("products", [])
		if products_array is Array:
			result.products = Product.array_from_dict(products_array)

		# Parse invalid SKUs (iOS only)
		var invalid_array = dict.get("invalid_skus", [])
		if invalid_array is Array:
			for sku in invalid_array:
				if sku is String:
					result.invalid_skus.append(sku)

		return result

# ============================================================================
# Purchase Result
# ============================================================================

## Result of purchase(), queryPurchases(), or restorePurchases()
class PurchaseResult extends BillingResult:
	## Array of purchases
	var purchases: Array[Purchase] = []

	## Check if any purchases were found
	func has_purchases() -> bool:
		return purchases.size() > 0

	## Get first purchase (convenience for single-item purchases)
	func get_purchase() -> Purchase:
		if purchases.size() > 0:
			return purchases[0]
		return null

	## Get all purchases for a specific SKU
	func get_purchases_for_sku(sku: String) -> Array[Purchase]:
		var result: Array[Purchase] = []
		for purchase in purchases:
			if purchase.sku == sku:
				result.append(purchase)
		return result

	## Get all SKUs from purchases
	func get_skus() -> Array[String]:
		var skus: Array[String] = []
		for purchase in purchases:
			if not skus.has(purchase.sku):
				skus.append(purchase.sku)
		return skus

	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> PurchaseResult:
		var result = PurchaseResult.new()
		result._parse_common(dict)

		# Parse purchases array
		var purchases_array = dict.get("purchases", [])
		if purchases_array is Array:
			result.purchases = Purchase.array_from_dict(purchases_array)

		return result

# ============================================================================
# Acknowledgement Result
# ============================================================================

## Result of acknowledgePurchase()
class AcknowledgementResult extends BillingResult:
	## The acknowledged purchase token
	var purchase_token: String = ""

	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> AcknowledgementResult:
		var result = AcknowledgementResult.new()
		result._parse_common(dict)
		result.purchase_token = dict.get("purchase_token", "")
		return result

# ============================================================================
# Consumption Result
# ============================================================================

## Result of consumePurchase()
class ConsumptionResult extends BillingResult:
	## The consumed purchase token
	var purchase_token: String = ""

	## Create from Dictionary
	static func from_dict(dict: Dictionary) -> ConsumptionResult:
		var result = ConsumptionResult.new()
		result._parse_common(dict)
		result.purchase_token = dict.get("purchase_token", "")
		return result

# ============================================================================
# Helper Functions
# ============================================================================

## Parse any billing result Dictionary into the appropriate typed result
static func parse_result(dict: Dictionary, result_type: String = "generic") -> BillingResult:
	match result_type:
		"connection":
			return ConnectionResult.from_dict(dict)
		"product_query", "sku_details":
			return ProductQueryResult.from_dict(dict)
		"purchase", "purchases", "restore":
			return PurchaseResult.from_dict(dict)
		"acknowledge":
			return AcknowledgementResult.from_dict(dict)
		"consume":
			return ConsumptionResult.from_dict(dict)
		_:
			return BillingResult.from_dict(dict)

## Convert status code to enum
static func status_from_int(code: int) -> Status:
	return code as Status

## Convert status enum to string
static func status_to_string(s: Status) -> String:
	return BillingResult._get_status_string(s)
