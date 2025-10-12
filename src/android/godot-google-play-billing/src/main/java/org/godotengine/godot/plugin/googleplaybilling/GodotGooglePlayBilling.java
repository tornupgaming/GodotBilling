/*************************************************************************/
/*  GodotGooglePlayBilling.java                                          */
/*************************************************************************/
/*                       This file is part of:                           */
/*                           GODOT ENGINE                                */
/*                      https://godotengine.org                          */
/*************************************************************************/
/* Copyright (c) 2007-2020 Juan Linietsky, Ariel Manzur.                 */
/* Copyright (c) 2014-2020 Godot Engine contributors (cf. AUTHORS.md).   */
/*                                                                       */
/* Permission is hereby granted, free of charge, to any person obtaining */
/* a copy of this software and associated documentation files (the       */
/* "Software"), to deal in the Software without restriction, including   */
/* without limitation the rights to use, copy, modify, merge, publish,   */
/* distribute, sublicense, and/or sell copies of the Software, and to    */
/* permit persons to whom the Software is furnished to do so, subject to */
/* the following conditions:                                             */
/*                                                                       */
/* The above copyright notice and this permission notice shall be        */
/* included in all copies or substantial portions of the Software.       */
/*                                                                       */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*/
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                */
/*************************************************************************/

package org.godotengine.godot.plugin.googleplaybilling;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.googleplaybilling.utils.GooglePlayBillingUtils;
import org.godotengine.godot.plugin.UsedByGodot;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.collection.ArraySet;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.AcknowledgePurchaseResponseListener;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.ConsumeResponseListener;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesResponseListener;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.SkuDetails;
import com.android.billingclient.api.SkuDetailsParams;
import com.android.billingclient.api.SkuDetailsResponseListener;
import com.android.billingclient.api.UserChoiceDetails;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Set;

import android.util.Log;

/**
 * Unified In-App Purchase plugin for Godot Engine (Android implementation)
 *
 * This plugin provides a consistent cross-platform interface for in-app purchases
 * on Android using Google Play Billing Library. It implements the same API as the
 * iOS GodotIAP plugin to enable write-once, run-anywhere IAP code.
 *
 * <h2>Platform-Specific Behaviors:</h2>
 * <ul>
 *   <li><b>startConnection():</b> Required on Android to connect to Google Play Billing.
 *       On iOS, this is a no-op (always connected).</li>
 *   <li><b>restorePurchases():</b> Queries both "inapp" and "subs" purchases on Android.
 *       On iOS, this triggers StoreKit's restoreCompletedTransactions.</li>
 *   <li><b>acknowledgePurchase():</b> Calls Google Play acknowledgePurchase API.
 *       On iOS, this calls finishTransaction.</li>
 *   <li><b>consumePurchase():</b> Calls Google Play consumePurchase API.
 *       On iOS, this marks as consumed and calls finishTransaction.</li>
 *   <li><b>setAutoFinishTransactions():</b> No-op on Android (included for iOS compatibility).
 *       Android requires explicit acknowledgement/consumption.</li>
 * </ul>
 *
 * <h2>Unified Signal System:</h2>
 * All events are emitted through signals with consistent Dictionary-based parameters:
 * <ul>
 *   <li><b>billing_connected:</b> Emitted when connected to billing service.
 *       Dictionary: {status: 0 (OK) or error code, error_message: "..." (if error)}</li>
 *   <li><b>billing_disconnected:</b> Emitted when disconnected from billing service.</li>
 *   <li><b>sku_details_query_completed:</b> Emitted when product details are retrieved.
 *       Dictionary: {status: 0 (OK) or error code, products: [...]}</li>
 *   <li><b>purchase_updated:</b> Emitted when purchase state changes.
 *       Dictionary: {status: 0 (OK) or error code, purchases: [...]}</li>
 *   <li><b>purchases_updated:</b> Emitted for queryPurchases() results.
 *       Dictionary: {status: 0 (OK) or error code, purchases: [...]}</li>
 *   <li><b>purchases_restored:</b> Emitted when purchases are restored.
 *       Dictionary: {status: 0 (OK) or error code, purchases: [...]}</li>
 *   <li><b>purchase_acknowledged:</b> Emitted when purchase is acknowledged.
 *       Dictionary: {status: 0 (OK) or error code, purchase_token: "..."}</li>
 *   <li><b>purchase_consumed:</b> Emitted when purchase is consumed.
 *       Dictionary: {status: 0 (OK) or error code, purchase_token: "..."}</li>
 * </ul>
 *
 * <h2>Status Codes:</h2>
 * <ul>
 *   <li>0 = OK</li>
 *   <li>1 = USER_CANCELLED</li>
 *   <li>3 = BILLING_UNAVAILABLE</li>
 *   <li>5 = DEVELOPER_ERROR</li>
 *   <li>6 = ERROR (generic)</li>
 *   <li>8 = ITEM_NOT_OWNED</li>
 * </ul>
 *
 * <h2>Backward Compatibility:</h2>
 * Old signal names and formats are still emitted for backward compatibility but are
 * deprecated and will be removed in a future version. New code should use the unified
 * signal names (billing_connected, purchase_updated, etc.) and Dictionary-based parameters.
 *
 * @see <a href="https://developer.android.com/google/play/billing">Google Play Billing Library</a>
 */
public class GodotGooglePlayBilling extends GodotPlugin implements PurchasesUpdatedListener, BillingClientStateListener {

	private final String LOG_TAG = "GodotBilling";

	private final BillingClient billingClient;
	private final HashMap<String, SkuDetails> skuDetailsCache = new HashMap<>(); // sku → SkuDetails
	private boolean calledStartConnection;
	private String obfuscatedAccountId;
	private String obfuscatedProfileId;

	public GodotGooglePlayBilling(Godot godot) {
		super(godot);

		PendingPurchasesParams pendingPurchasesParams = 
			PendingPurchasesParams.newBuilder().enableOneTimeProducts().build();

		billingClient = BillingClient
								.newBuilder(getActivity())
								.enablePendingPurchases(pendingPurchasesParams)
								.setListener(this)
								.build();
		calledStartConnection = false;
		obfuscatedAccountId = "";
		obfuscatedProfileId = "";
	}

	/**
	 * Initialize the billing system and connect to Google Play Billing.
	 *
	 * <p>This method must be called before any other billing operations.
	 * On Android, this establishes a connection to the Google Play Billing service.
	 * On iOS, this is a no-op (StoreKit is always "connected").
	 *
	 * <p><b>Emits:</b> "billing_connected" signal with Dictionary result containing:
	 * <ul>
	 *   <li>status: 0 (OK) on success, or error code on failure</li>
	 *   <li>error_message: Error description (only present on failure)</li>
	 * </ul>
	 */
	public void startConnection() {
		calledStartConnection = true;
		billingClient.startConnection(this);
	}

	/**
	 * End the billing connection and cleanup resources.
	 *
	 * <p>Call this when you're done with billing operations (e.g., when the app is closing).
	 *
	 * <p><b>Emits:</b> "billing_disconnected" signal
	 */
	public void endConnection() {
		billingClient.endConnection();
	}

	/**
	 * Check if the billing system is ready for operations.
	 *
	 * <p>On Android, returns true if connected to Google Play Billing.
	 * On iOS, returns true if StoreKit is available and payments are allowed.
	 *
	 * @return true if billing is ready, false otherwise
	 */
	@UsedByGodot
	public boolean isReady() {
		return this.billingClient.isReady();
	}
	/**
	 * @deprecated Use isReady() instead. This method will be removed in a future version.
	 */
	@Deprecated
	@UsedByGodot
	public int getConnectionState() {
		return billingClient.getConnectionState();
	}

	@UsedByGodot
	public void queryPurchases(String type) {
		Log.v(LOG_TAG, String.format("queryPurchases(type: %s)", type));
		billingClient.queryPurchasesAsync(type, (billingResult, purchaseList) -> {
            Dictionary returnValue = new Dictionary();
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                returnValue.put("status", 0); // OK = 0
                returnValue.put("purchases", GooglePlayBillingUtils.convertPurchaseListToDictionaryObjectArray(purchaseList));
            } else {
                returnValue.put("status", 1); // FAILED = 1
                returnValue.put("response_code", billingResult.getResponseCode());
                returnValue.put("debug_message", billingResult.getDebugMessage());
            }
            emitSignal("query_purchases_response", (Object)returnValue);
        });
	}

	/**
	 * Restore all purchases associated with the user's account.
	 *
	 * <p>On Android, this queries both in-app and subscription purchases and
	 * consolidates the results. On iOS, this triggers StoreKit's
	 * restoreCompletedTransactions.
	 *
	 * <p>Use this to restore purchases when the user reinstalls the app or
	 * signs in on a new device (especially important for non-consumables and
	 * subscriptions).
	 *
	 * <p><b>Emits:</b> "purchases_restored" signal with Dictionary:
	 * <ul>
	 *   <li>status: 0 (OK) or error code</li>
	 *   <li>purchases: Array of all restored purchases (same format as purchase_updated)</li>
	 *   <li>error_message: Error description (only present on failure)</li>
	 * </ul>
	 */
	@UsedByGodot
	public void restorePurchases() {
		Log.v(LOG_TAG, "restorePurchases() - querying both inapp and subs");

		// On Android, restore is implemented by querying both types
		final Dictionary[] inappResult = {null};
		final Dictionary[] subsResult = {null};

		// Query in-app purchases
		billingClient.queryPurchasesAsync(BillingClient.ProductType.INAPP, (billingResult, purchaseList) -> {
            Dictionary result = new Dictionary();
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                result.put("status", 0); // OK = 0
                result.put("purchases", GooglePlayBillingUtils.convertPurchaseListToDictionaryObjectArray(purchaseList));
            } else {
                result.put("status", 6); // ERROR = 6
                result.put("response_code", billingResult.getResponseCode());
                result.put("error_message", billingResult.getDebugMessage());
                result.put("purchases", new Object[0]);
            }
            inappResult[0] = result;

            // Check if both queries completed
            if (subsResult[0] != null) {
                emitRestoreResults(inappResult[0], subsResult[0]);
            }
        });

		// Query subscriptions
		billingClient.queryPurchasesAsync(BillingClient.ProductType.SUBS, (billingResult, purchaseList) -> {
            Dictionary result = new Dictionary();
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                result.put("status", 0); // OK = 0
                result.put("purchases", GooglePlayBillingUtils.convertPurchaseListToDictionaryObjectArray(purchaseList));
            } else {
                result.put("status", 6); // ERROR = 6
                result.put("response_code", billingResult.getResponseCode());
                result.put("error_message", billingResult.getDebugMessage());
                result.put("purchases", new Object[0]);
            }
            subsResult[0] = result;

            // Check if both queries completed
            if (inappResult[0] != null) {
                emitRestoreResults(inappResult[0], subsResult[0]);
            }
        });
	}

	private void emitRestoreResults(Dictionary inappResult, Dictionary subsResult) {
		Dictionary finalResult = new Dictionary();

		// If either query failed, return error status
		int inappStatus = (int)inappResult.get("status");
		int subsStatus = (int)subsResult.get("status");

		if (inappStatus != 0) {
			finalResult.put("status", inappStatus);
			finalResult.put("response_code", inappResult.get("response_code"));
			finalResult.put("error_message", inappResult.get("error_message"));
			finalResult.put("purchases", new Object[0]);
		} else if (subsStatus != 0) {
			finalResult.put("status", subsStatus);
			finalResult.put("response_code", subsResult.get("response_code"));
			finalResult.put("error_message", subsResult.get("error_message"));
			finalResult.put("purchases", new Object[0]);
		} else {
			// Both succeeded - merge the purchase arrays
			finalResult.put("status", 0); // OK = 0

			Object[] inappPurchases = (Object[])inappResult.get("purchases");
			Object[] subsPurchases = (Object[])subsResult.get("purchases");

			Object[] allPurchases = new Object[inappPurchases.length + subsPurchases.length];
			System.arraycopy(inappPurchases, 0, allPurchases, 0, inappPurchases.length);
			System.arraycopy(subsPurchases, 0, allPurchases, inappPurchases.length, subsPurchases.length);

			finalResult.put("purchases", allPurchases);
		}

		emitSignal("purchases_restored", (Object)finalResult);
	}

	/**
	 * Enable/disable automatic transaction finishing (iOS only, no-op on Android).
	 *
	 * <p>On iOS, when enabled, transactions are automatically finished after successful
	 * purchase. When disabled (default), you must manually call acknowledgePurchase()
	 * or consumePurchase().
	 *
	 * <p>On Android, this is a no-op as Android always requires explicit
	 * acknowledgement/consumption.
	 *
	 * @param autoFinish true to enable auto-finish, false to require manual finish
	 */
	@UsedByGodot
	public void setAutoFinishTransactions(boolean autoFinish) {
		// No-op on Android - included for iOS compatibility
		// Android requires explicit acknowledgement/consumption
		Log.v(LOG_TAG, "setAutoFinishTransactions(" + autoFinish + ") - no-op on Android");
	}

	/**
	 * Get the current platform.
	 *
	 * @return "android" on Android, "ios" on iOS
	 */
	@UsedByGodot
	public String getPlatform() {
		return "android";
	}
	/**
	 * Query product details from the store.
	 *
	 * <p>Retrieves detailed information about products (SKUs) from Google Play,
	 * including prices, descriptions, and product type. You must call this before
	 * attempting to purchase a product.
	 *
	 * @param list Array of product IDs (SKUs) to query (e.g., ["coins_100", "premium_sub"])
	 * @param type Product type: "inapp" for one-time/consumables, "subs" for subscriptions
	 *
	 * <p><b>Emits:</b> "sku_details_query_completed" signal with Dictionary result:
	 * <ul>
	 *   <li>status: 0 (OK) or error code</li>
	 *   <li>products: Array of product Dictionaries, each containing:
	 *     <ul>
	 *       <li>sku: Product ID</li>
	 *       <li>title: Localized title</li>
	 *       <li>description: Localized description</li>
	 *       <li>price: Formatted price string (e.g., "$0.99")</li>
	 *       <li>price_currency_code: Currency code (e.g., "USD")</li>
	 *       <li>price_amount_micros: Price in micros (990000 = $0.99)</li>
	 *       <li>type: "inapp" or "subs"</li>
	 *     </ul>
	 *   </li>
	 *   <li>error_message: Error description (only present on failure)</li>
	 * </ul>
	 */
	@UsedByGodot
	public void querySkuDetails(final String[] list, String type) {
		Log.v(LOG_TAG, String.format("querySkuDetails(type: %s, list: %s)", type, Arrays.toString(list)));
		List<String> skuList = Arrays.asList(list);

		SkuDetailsParams.Builder params = SkuDetailsParams.newBuilder()
												  .setSkusList(skuList)
												  .setType(type);



		billingClient.querySkuDetailsAsync(params.build(), (billingResult, skuDetailsList) -> {
            Log.v(LOG_TAG, String.format("onSkuDetailsResponse(billingResult: %s, skuDetailsListSize: %d)", billingResult, skuDetailsList.size()));
            Dictionary result = new Dictionary();
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                for (SkuDetails skuDetails : skuDetailsList) {
                    skuDetailsCache.put(skuDetails.getSku(), skuDetails);
                }
                result.put("status", 0); // OK = 0
                result.put("products", GooglePlayBillingUtils.convertSkuDetailsListToDictionaryObjectArray(skuDetailsList));
                emitSignal("sku_details_query_completed", (Object)result);
                // Backward compatibility: emit old signal format too
                emitSignal("sku_details_query_completed", (Object)GooglePlayBillingUtils.convertSkuDetailsListToDictionaryObjectArray(skuDetailsList));
            } else {
                result.put("status", 6); // ERROR = 6
                result.put("response_code", billingResult.getResponseCode());
                result.put("error_message", billingResult.getDebugMessage());
                result.put("products", new Object[0]);
                emitSignal("sku_details_query_completed", (Object)result);
                // Backward compatibility: emit old error signal too
                emitSignal("sku_details_query_error", billingResult.getResponseCode(), billingResult.getDebugMessage(), list);
            }
        });

		// Updated version for new billing APIs
		List<QueryProductDetailsParams.Product> product_list = new ArrayList<>();
		for (String sku: list) {
			QueryProductDetailsParams.Product.Builder qb = QueryProductDetailsParams.Product.newBuilder();
			qb.setProductId(sku);
			qb.setProductType(type);
			product_list.add(qb.build());
		}
		QueryProductDetailsParams.Builder productParamsBuilder = QueryProductDetailsParams.newBuilder().setProductList(product_list);
		billingClient.queryProductDetailsAsync(productParamsBuilder.build(), (@NonNull BillingResult billingResult, @NonNull List<ProductDetails> productDetailsList) -> {
			Log.v(LOG_TAG, "queryProductDetailsAsync result! Size:  " + productDetailsList.size());
			if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK) {
				Log.e(LOG_TAG, billingResult.toString());
				return;
			}
			for (ProductDetails productDetails : productDetailsList) {
				Log.v(LOG_TAG, productDetails.toString());
			}
		});
	}
	/**
	 * Acknowledge a non-consumable purchase or subscription.
	 *
	 * <p>On Android, you must acknowledge purchases within 3 days or Google Play will
	 * automatically refund them. Use this for non-consumable items and subscriptions.
	 * For consumables, use consumePurchase() instead.
	 *
	 * <p>On iOS, this calls finishTransaction.
	 *
	 * @param purchaseToken Purchase token from the purchase result
	 *
	 * <p><b>Emits:</b> "purchase_acknowledged" signal with Dictionary:
	 * <ul>
	 *   <li>status: 0 (OK) or error code</li>
	 *   <li>purchase_token: The acknowledged purchase token</li>
	 *   <li>error_message: Error description (only present on failure)</li>
	 * </ul>
	 */
	@UsedByGodot
	public void acknowledgePurchase(final String purchaseToken) {
		AcknowledgePurchaseParams acknowledgePurchaseParams =
				AcknowledgePurchaseParams.newBuilder()
						.setPurchaseToken(purchaseToken)
						.build();
		billingClient.acknowledgePurchase(acknowledgePurchaseParams, new AcknowledgePurchaseResponseListener() {
			@Override
			public void onAcknowledgePurchaseResponse(BillingResult billingResult) {
				Dictionary result = new Dictionary();
				result.put("purchase_token", purchaseToken);
				if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
					result.put("status", 0); // OK = 0
					emitSignal("purchase_acknowledged", (Object)result);
					// Backward compatibility
					emitSignal("purchase_acknowledged", purchaseToken);
				} else {
					result.put("status", 6); // ERROR = 6
					result.put("response_code", billingResult.getResponseCode());
					result.put("error_message", billingResult.getDebugMessage());
					emitSignal("purchase_acknowledged", (Object)result);
					// Backward compatibility
					emitSignal("purchase_acknowledgement_error", billingResult.getResponseCode(), billingResult.getDebugMessage(), purchaseToken);
				}
			}
		});
	}

	/**
	 * Consume a consumable purchase, allowing it to be purchased again.
	 *
	 * <p>Use this for consumable items like coins, gems, etc. After consuming,
	 * the item can be purchased again. This also acknowledges the purchase,
	 * so you don't need to call acknowledgePurchase() separately.
	 *
	 * <p>On iOS, this marks the product as consumed and calls finishTransaction.
	 *
	 * @param purchaseToken Purchase token from the purchase result
	 *
	 * <p><b>Emits:</b> "purchase_consumed" signal with Dictionary:
	 * <ul>
	 *   <li>status: 0 (OK) or error code</li>
	 *   <li>purchase_token: The consumed purchase token</li>
	 *   <li>error_message: Error description (only present on failure)</li>
	 * </ul>
	 */
	@UsedByGodot
	public void consumePurchase(String purchaseToken) {
		ConsumeParams consumeParams = ConsumeParams.newBuilder()
											  .setPurchaseToken(purchaseToken)
											  .build();

		billingClient.consumeAsync(consumeParams, new ConsumeResponseListener() {
			@Override
			public void onConsumeResponse(BillingResult billingResult, String purchaseToken) {
				Dictionary result = new Dictionary();
				result.put("purchase_token", purchaseToken);
				if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
					result.put("status", 0); // OK = 0
					emitSignal("purchase_consumed", (Object)result);
					// Backward compatibility
					emitSignal("purchase_consumed", purchaseToken);
				} else {
					result.put("status", 6); // ERROR = 6
					result.put("response_code", billingResult.getResponseCode());
					result.put("error_message", billingResult.getDebugMessage());
					emitSignal("purchase_consumed", (Object)result);
					// Backward compatibility
					emitSignal("purchase_consumption_error", billingResult.getResponseCode(), billingResult.getDebugMessage(), purchaseToken);
				}
			}
		});
	}

	@Override
	public void onBillingSetupFinished(BillingResult billingResult) {
		Log.v(LOG_TAG, String.format("onBillingSetupFinished(billingResult: %s)", billingResult.toString()));
		Dictionary result = new Dictionary();
		if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
			result.put("status", 0); // OK = 0
			emitSignal("billing_connected", (Object)result);
			// Backward compatibility: emit old signal too
			emitSignal("connected");
		} else {
			result.put("status", 6); // ERROR = 6
			result.put("response_code", billingResult.getResponseCode());
			result.put("error_message", billingResult.getDebugMessage());
			emitSignal("billing_connected", (Object)result);
			// Backward compatibility: emit old signal too
			emitSignal("connect_error", billingResult.getResponseCode(), billingResult.getDebugMessage());
		}
	}

	@Override
	public void onBillingServiceDisconnected() {
		emitSignal("billing_disconnected");
		// Backward compatibility: emit old signal too
		emitSignal("disconnected");
	}
	/**
	 * @deprecated This method is deprecated and will be removed in a future version.
	 * Price changes are now handled automatically by Google Play.
	 */
	@Deprecated
	@UsedByGodot
	public Dictionary confirmPriceChange(String sku) {
		if (!skuDetailsCache.containsKey(sku)) {
			Dictionary returnValue = new Dictionary();
			returnValue.put("status", 1); // FAILED = 1
			returnValue.put("response_code", null); // Null since there is no ResponseCode to return but to keep the interface (status, response_code, debug_message)
			returnValue.put("debug_message", "You must query the sku details and wait for the result before confirming a price change!");
			return returnValue;
		}

		SkuDetails skuDetails = skuDetailsCache.get(sku);

		Dictionary returnValue = new Dictionary();
		returnValue.put("status", 0); // OK = 0
		return returnValue;
	}
	/**
	 * Initiate a purchase flow for the specified product.
	 *
	 * <p>Launches the Google Play purchase UI for the specified SKU. You must call
	 * querySkuDetails() first and wait for the result before purchasing.
	 *
	 * @param sku Product ID to purchase (must have been queried via querySkuDetails)
	 * @return Dictionary with immediate result:
	 *         {status: 0 (OK) or error code, error_message: "..." (if error)}
	 *
	 * <p><b>Emits:</b> "purchase_updated" signal when purchase completes with Dictionary:
	 * <ul>
	 *   <li>status: 0 (OK), 1 (user cancelled), or error code</li>
	 *   <li>purchases: Array of purchase Dictionaries, each containing:
	 *     <ul>
	 *       <li>sku: Product ID</li>
	 *       <li>purchase_token: Platform-specific purchase token</li>
	 *       <li>order_id: Transaction ID (GPA.xxxx on Android)</li>
	 *       <li>purchase_time: Unix timestamp</li>
	 *       <li>signature: Receipt signature (Android only)</li>
	 *       <li>acknowledged: Whether purchase is acknowledged</li>
	 *       <li>purchase_state: 1=purchased, 0=pending</li>
	 *     </ul>
	 *   </li>
	 *   <li>error_message: Error description (only present on failure)</li>
	 * </ul>
	 */
	@UsedByGodot
	public Dictionary purchase(String sku) {
		Log.v(LOG_TAG, String.format("purchase(sku: %s)", sku));
		return purchaseInternal("", sku,
			BillingFlowParams.SubscriptionUpdateParams.ReplacementMode.UNKNOWN_REPLACEMENT_MODE);
	}

	/**
	 * Initiate a purchase flow for the specified product with explicit type.
	 *
	 * <p>On Android, the type parameter is ignored as the product type is determined
	 * by the cached SKU details. This overload exists for iOS compatibility.
	 *
	 * @param sku Product ID to purchase
	 * @param type Product type: "inapp" or "subs" (ignored on Android)
	 * @return Dictionary with immediate result (see purchase(String) for details)
	 *
	 * <p><b>Emits:</b> "purchase_updated" signal (see purchase(String) for details)
	 */
	@UsedByGodot
	public Dictionary purchase(String sku, String type) {
		// Type parameter is ignored on Android as the type is determined by querySkuDetails
		// Included for iOS compatibility
		Log.v(LOG_TAG, String.format("purchase(sku: %s, type: %s)", sku, type));
		return purchase(sku);
	}
	/**
	 * @deprecated Use purchase() for regular purchases. For subscription upgrades/downgrades,
	 * consider implementing with the new Google Play Billing API directly.
	 * This method will be removed in a future version.
	 */
	@Deprecated
	@UsedByGodot
	public Dictionary updateSubscription(String oldToken, String sku, int replacementMode) {
		return purchaseInternal(oldToken, sku, replacementMode);
	}

	private Dictionary purchaseInternal(String oldToken, String sku, int replacementMode) {
		Log.v(LOG_TAG, String.format("purchaseInternal(sku: %s)", sku));
		if (!skuDetailsCache.containsKey(sku)) {
			Log.e(LOG_TAG, String.format("purchaseInternal - skuDetailsCache did not contain %s", sku));
			Dictionary returnValue = new Dictionary();
			returnValue.put("status", 1); // FAILED = 1
			returnValue.put("response_code", null); // Null since there is no ResponseCode to return but to keep the interface (status, response_code, debug_message)
			returnValue.put("debug_message", "You must query the sku details and wait for the result before purchasing!");
			return returnValue;
		}

		SkuDetails skuDetails = skuDetailsCache.get(sku);
		if (skuDetails == null) {
			Log.e(LOG_TAG, String.format("purchaseInternal - skuDetails was null for %s", sku));
			Dictionary returnValue = new Dictionary();
			returnValue.put("status", 1); // FAILED = 1
			returnValue.put("response_code", null); // Null since there is no ResponseCode to return but to keep the interface (status, response_code, debug_message)
			returnValue.put("debug_message", "You must query the sku details and wait for the result before purchasing!");
			return returnValue;
		}

		BillingFlowParams.Builder purchaseParamsBuilder = BillingFlowParams.newBuilder();
		purchaseParamsBuilder.setSkuDetails(skuDetails);
		if (!obfuscatedAccountId.isEmpty()) {
			purchaseParamsBuilder.setObfuscatedAccountId(obfuscatedAccountId);
		}
		if (!obfuscatedProfileId.isEmpty()) {
			purchaseParamsBuilder.setObfuscatedProfileId(obfuscatedProfileId);
		}
		if (!oldToken.isEmpty() && replacementMode != BillingFlowParams.SubscriptionUpdateParams.ReplacementMode.UNKNOWN_REPLACEMENT_MODE) {
			BillingFlowParams.SubscriptionUpdateParams updateParams =
				BillingFlowParams.SubscriptionUpdateParams.newBuilder()
					.setOldPurchaseToken(oldToken)
					.setSubscriptionReplacementMode(replacementMode)
					.build();
			purchaseParamsBuilder.setSubscriptionUpdateParams(updateParams);
		}

		Log.v(LOG_TAG, String.format("purchaseInternal(sku: %s): launchBillingFlow invoking...", sku));
		BillingResult result = billingClient.launchBillingFlow(getActivity(), purchaseParamsBuilder.build());

		Log.v(LOG_TAG, String.format("purchaseInternal(sku: %s): launchBillingFlow result was '%s'", sku, result));

		Dictionary returnValue = new Dictionary();
		if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
			returnValue.put("status", 0); // OK = 0
		} else {
			returnValue.put("status", 1); // FAILED = 1
			returnValue.put("response_code", result.getResponseCode());
			returnValue.put("debug_message", result.getDebugMessage());
		}

		return returnValue;
	}
	/**
	 * @deprecated Not part of the unified cross-platform interface. Android-specific feature.
	 * May be removed in a future version for consistency with iOS.
	 */
	@Deprecated
	@UsedByGodot
	public void setObfuscatedAccountId(String accountId) {
		obfuscatedAccountId = accountId;
	}

	/**
	 * @deprecated Not part of the unified cross-platform interface. Android-specific feature.
	 * May be removed in a future version for consistency with iOS.
	 */
	@Deprecated
	@UsedByGodot
	public void setObfuscatedProfileId(String profileId) {
		obfuscatedProfileId = profileId;
	}

	@Override
	public void onPurchasesUpdated(@NonNull final BillingResult billingResult, @Nullable final List<Purchase> list) {
		Log.v(LOG_TAG, String.format("onPurchasesUpdated(billingResult: %s)", billingResult));
		Dictionary result = new Dictionary();
		if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && list != null) {
			result.put("status", 0); // OK = 0
			result.put("purchases", GooglePlayBillingUtils.convertPurchaseListToDictionaryObjectArray(list));
			emitSignal("purchase_updated", (Object)result);
			// Backward compatibility: emit old signal too
			emitSignal("purchases_updated", (Object)GooglePlayBillingUtils.convertPurchaseListToDictionaryObjectArray(list));
		} else {
			// Map response codes to unified status codes
			int status = 6; // Default: ERROR
			if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED) {
				status = 1; // USER_CANCELLED
			} else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.BILLING_UNAVAILABLE) {
				status = 3; // BILLING_UNAVAILABLE
			} else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.DEVELOPER_ERROR) {
				status = 5; // DEVELOPER_ERROR
			} else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.ITEM_NOT_OWNED) {
				status = 8; // ITEM_NOT_OWNED
			}
			result.put("status", status);
			result.put("response_code", billingResult.getResponseCode());
			result.put("error_message", billingResult.getDebugMessage());
			result.put("purchases", new Object[0]);
			emitSignal("purchase_updated", (Object)result);
			// Backward compatibility: emit old error signal too
			emitSignal("purchase_error", billingResult.getResponseCode(), billingResult.getDebugMessage());
		}
	}

	@Override
	public void onMainResume() {
		if (calledStartConnection) {
			emitSignal("billing_resume");
		}
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "GodotBilling";
	}

	@NonNull
	@Override
	public List<String> getPluginMethods() {
		return Arrays.asList("startConnection", "endConnection", "isReady", "querySkuDetails", "purchase", "queryPurchases", "restorePurchases", "acknowledgePurchase", "consumePurchase", "setAutoFinishTransactions", "getPlatform", "confirmPriceChange", "updateSubscription", "getConnectionState", "setObfuscatedAccountId", "setObfuscatedProfileId");
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new ArraySet<>();

		// Unified signals (cross-platform compatible)
		signals.add(new SignalInfo("billing_connected", Object.class));
		signals.add(new SignalInfo("billing_disconnected"));
		signals.add(new SignalInfo("sku_details_query_completed", Object.class));
		signals.add(new SignalInfo("purchase_updated", Object.class));
		signals.add(new SignalInfo("purchases_updated", Object.class));  // Also used by queryPurchases
		signals.add(new SignalInfo("purchases_restored", Object.class));
		signals.add(new SignalInfo("purchase_acknowledged", Object.class));
		signals.add(new SignalInfo("purchase_consumed", Object.class));
		signals.add(new SignalInfo("billing_error", Object.class));

		// Backward compatibility signals (deprecated, will be removed in future version)
		signals.add(new SignalInfo("connected"));
		signals.add(new SignalInfo("disconnected"));
		signals.add(new SignalInfo("billing_resume"));
		signals.add(new SignalInfo("connect_error", Integer.class, String.class));
		signals.add(new SignalInfo("query_purchases_response", Object.class));
		signals.add(new SignalInfo("purchase_error", Integer.class, String.class));
		signals.add(new SignalInfo("sku_details_query_error", Integer.class, String.class, String[].class));
		signals.add(new SignalInfo("price_change_acknowledged", Integer.class));
		signals.add(new SignalInfo("purchase_acknowledgement_error", Integer.class, String.class, String.class));
		signals.add(new SignalInfo("purchase_consumption_error", Integer.class, String.class, String.class));

		return signals;
	}
}
