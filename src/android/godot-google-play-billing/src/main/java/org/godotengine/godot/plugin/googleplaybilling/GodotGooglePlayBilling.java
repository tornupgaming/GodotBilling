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
import org.godotengine.godot.plugin.UsedByGodot;
import org.godotengine.godot.plugin.googleplaybilling.utils.GooglePlayBillingUtils;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;
import com.android.billingclient.api.UnfetchedProduct;

import android.util.Log;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Android half of the unified GodotBilling plugin, built on Google Play Billing.
 * It mirrors the iOS StoreKit plugin: every signal carries one Dictionary with a
 * "status" whose codes (0-8) are the Play Billing response codes, which the iOS
 * plugin reuses. See UNIFIED_IAP_DESIGN.md at the repository root.
 */
public class GodotGooglePlayBilling extends GodotPlugin implements PurchasesUpdatedListener, BillingClientStateListener {
	private static final String LOG_TAG = "GodotBilling";
	private static final int STATUS_OK = 0;
	private static final int STATUS_ERROR = 6;
	private static final int MAX_UNIFIED_STATUS = 8;

	private final BillingClient billingClient;
	// Purchases need the ProductDetails of an earlier querySkuDetails().
	private final HashMap<String, ProductDetails> productDetailsCache = new HashMap<>();

	public GodotGooglePlayBilling(Godot godot) {
		super(godot);
		billingClient = BillingClient.newBuilder(getActivity())
				.enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
				.enableAutoServiceReconnection()
				.setListener(this)
				.build();
	}

	/** Connects to Google Play. Emits "billing_connected". */
	@UsedByGodot
	public void startConnection() {
		billingClient.startConnection(this);
	}

	@UsedByGodot
	public void endConnection() {
		billingClient.endConnection();
	}

	@UsedByGodot
	public boolean isReady() {
		return billingClient.isReady();
	}

	@UsedByGodot
	public String getPlatform() {
		return "android";
	}

	/** Does nothing; it exists to match the iOS plugin, since Play always needs an explicit acknowledge or consume. */
	@UsedByGodot
	public void setAutoFinishTransactions(boolean autoFinish) {
	}

	/** Fetches store details for productIds of type "inapp" or "subs". Emits "sku_details_query_completed". */
	@UsedByGodot
	public void querySkuDetails(final String[] productIds, String type) {
		Log.v(LOG_TAG, String.format("querySkuDetails(type: %s, ids: %s)", type, Arrays.toString(productIds)));
		List<QueryProductDetailsParams.Product> products = new ArrayList<>();
		for (String productId : productIds) {
			products.add(QueryProductDetailsParams.Product.newBuilder()
					.setProductId(productId)
					.setProductType(type)
					.build());
		}
		QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder().setProductList(products).build();

		billingClient.queryProductDetailsAsync(params, (billingResult, queryResult) -> {
			if (!isOk(billingResult)) {
				Dictionary result = errorResult(billingResult);
				result.put("products", new Object[0]);
				result.put("invalid_skus", new String[0]);
				emitSignal("sku_details_query_completed", (Object)result);
				emitSignal("sku_details_query_error", billingResult.getResponseCode(), billingResult.getDebugMessage(), productIds);
				return;
			}

			List<ProductDetails> detailsList = queryResult.getProductDetailsList();
			Object[] productDictionaries = new Object[detailsList.size()];
			for (int i = 0; i < detailsList.size(); i++) {
				ProductDetails details = detailsList.get(i);
				productDetailsCache.put(details.getProductId(), details);
				productDictionaries[i] = GooglePlayBillingUtils.productDetailsToDictionary(details);
			}

			List<UnfetchedProduct> unfetched = queryResult.getUnfetchedProductList();
			String[] invalidIds = new String[unfetched.size()];
			for (int i = 0; i < unfetched.size(); i++) {
				invalidIds[i] = unfetched.get(i).getProductId();
			}

			Dictionary result = okResult();
			result.put("products", productDictionaries);
			result.put("invalid_skus", invalidIds);
			emitSignal("sku_details_query_completed", (Object)result);
		});
	}

	/**
	 * Opens the Play purchase sheet for a product from an earlier querySkuDetails().
	 * The outcome arrives on "purchase_updated"; the returned Dictionary only says whether the sheet opened.
	 */
	@UsedByGodot
	public Dictionary purchase(String productId) {
		Log.v(LOG_TAG, String.format("purchase(id: %s)", productId));
		ProductDetails details = productDetailsCache.get(productId);
		if (details == null) {
			return emitPurchaseFailure(errorResult(BillingClient.BillingResponseCode.DEVELOPER_ERROR,
					"Query " + productId + " with querySkuDetails() and wait for the result before purchasing"));
		}

		BillingFlowParams.ProductDetailsParams.Builder productParams =
				BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details);
		String offerToken = offerTokenOf(details);
		if (offerToken != null) {
			productParams.setOfferToken(offerToken);
		}
		BillingFlowParams flowParams = BillingFlowParams.newBuilder()
				.setProductDetailsParamsList(Collections.singletonList(productParams.build()))
				.build();

		BillingResult billingResult = billingClient.launchBillingFlow(getActivity(), flowParams);
		Log.v(LOG_TAG, String.format("purchase(id: %s): launchBillingFlow returned %s", productId, billingResult));
		return isOk(billingResult) ? okResult() : emitPurchaseFailure(errorResult(billingResult));
	}

	/** Matches the iOS purchase(sku, type); Godot exposes one Java method per name, so it needs its own. */
	@UsedByGodot
	public Dictionary purchaseWithType(String productId, String type) {
		return purchase(productId);
	}

	// purchase() reports failures Play may never send; a duplicate of one Play does send only re-clears the in-progress state.
	private Dictionary emitPurchaseFailure(Dictionary result) {
		result.put("purchases", new Object[0]);
		emitSignal("purchase_updated", (Object)result);
		return result;
	}

	/** Lists owned purchases of type "inapp" or "subs". Emits "query_purchases_response". */
	@UsedByGodot
	public void queryPurchases(String type) {
		billingClient.queryPurchasesAsync(purchasesParams(type), (billingResult, purchases) ->
				emitSignal("query_purchases_response", (Object)purchasesResult(billingResult, purchases)));
	}

	/** Lists owned in-app purchases and subscriptions together. Emits "purchases_restored". */
	@UsedByGodot
	public void restorePurchases() {
		billingClient.queryPurchasesAsync(purchasesParams(BillingClient.ProductType.INAPP), (inappResult, inappPurchases) -> {
			if (!isOk(inappResult)) {
				emitSignal("purchases_restored", (Object)purchasesResult(inappResult, inappPurchases));
				return;
			}
			billingClient.queryPurchasesAsync(purchasesParams(BillingClient.ProductType.SUBS), (subsResult, subsPurchases) -> {
				List<Purchase> allPurchases = new ArrayList<>(inappPurchases);
				allPurchases.addAll(subsPurchases);
				emitSignal("purchases_restored", (Object)purchasesResult(subsResult, allPurchases));
			});
		});
	}

	/** For non-consumables and subscriptions; Play refunds them if not acknowledged within 3 days. Emits "purchase_acknowledged". */
	@UsedByGodot
	public void acknowledgePurchase(final String purchaseToken) {
		AcknowledgePurchaseParams params = AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchaseToken).build();
		billingClient.acknowledgePurchase(params, billingResult ->
				emitSignal("purchase_acknowledged", (Object)tokenResult(billingResult, purchaseToken)));
	}

	/** For consumables; also acknowledges, so the product can be bought again. Emits "purchase_consumed". */
	@UsedByGodot
	public void consumePurchase(final String purchaseToken) {
		ConsumeParams params = ConsumeParams.newBuilder().setPurchaseToken(purchaseToken).build();
		billingClient.consumeAsync(params, (billingResult, consumedToken) ->
				emitSignal("purchase_consumed", (Object)tokenResult(billingResult, purchaseToken)));
	}

	@Override
	public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
		Log.v(LOG_TAG, String.format("onBillingSetupFinished(%s)", billingResult));
		emitSignal("billing_connected", (Object)(isOk(billingResult) ? okResult() : errorResult(billingResult)));
	}

	@Override
	public void onBillingServiceDisconnected() {
		emitSignal("billing_disconnected");
	}

	@Override
	public void onPurchasesUpdated(@NonNull BillingResult billingResult, @Nullable List<Purchase> purchases) {
		Log.v(LOG_TAG, String.format("onPurchasesUpdated(%s)", billingResult));
		if (!isOk(billingResult)) {
			emitPurchaseFailure(errorResult(billingResult));
			emitSignal("purchase_error", billingResult.getResponseCode(), billingResult.getDebugMessage());
			return;
		}
		if (purchases == null) {
			// The game cannot act on OK without purchases, so fail it and release the product.
			emitPurchaseFailure(errorResult(STATUS_ERROR, "Play reported OK without any purchases"));
			return;
		}
		Dictionary result = okResult();
		result.put("purchases", GooglePlayBillingUtils.purchasesToArray(purchases));
		emitSignal("purchase_updated", (Object)result);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "GodotBilling";
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(new SignalInfo("billing_connected", Object.class));
		signals.add(new SignalInfo("billing_disconnected"));
		signals.add(new SignalInfo("sku_details_query_completed", Object.class));
		signals.add(new SignalInfo("purchase_updated", Object.class));
		signals.add(new SignalInfo("purchases_restored", Object.class));
		signals.add(new SignalInfo("purchase_acknowledged", Object.class));
		signals.add(new SignalInfo("purchase_consumed", Object.class));
		// Android-only signals that Ore Buster still listens to.
		signals.add(new SignalInfo("query_purchases_response", Object.class));
		signals.add(new SignalInfo("purchase_error", Integer.class, String.class));
		signals.add(new SignalInfo("sku_details_query_error", Integer.class, String.class, String[].class));
		return signals;
	}

	private static boolean isOk(BillingResult billingResult) {
		return billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK;
	}

	private static Dictionary okResult() {
		Dictionary result = new Dictionary();
		result.put("status", STATUS_OK);
		return result;
	}

	// Play's codes 0-8 are the unified statuses; its negative and newer codes become a generic error.
	private static Dictionary errorResult(BillingResult billingResult) {
		return errorResult(billingResult.getResponseCode(), billingResult.getDebugMessage());
	}

	private static Dictionary errorResult(int code, String message) {
		Dictionary result = new Dictionary();
		result.put("status", code >= STATUS_OK && code <= MAX_UNIFIED_STATUS ? code : STATUS_ERROR);
		result.put("response_code", code);
		result.put("error_message", message);
		return result;
	}

	private static Dictionary purchasesResult(BillingResult billingResult, List<Purchase> purchases) {
		if (!isOk(billingResult)) {
			Dictionary result = errorResult(billingResult);
			result.put("purchases", new Object[0]);
			return result;
		}
		Dictionary result = okResult();
		result.put("purchases", GooglePlayBillingUtils.purchasesToArray(purchases));
		return result;
	}

	private static Dictionary tokenResult(BillingResult billingResult, String purchaseToken) {
		Dictionary result = isOk(billingResult) ? okResult() : errorResult(billingResult);
		result.put("purchase_token", purchaseToken);
		return result;
	}

	private static QueryPurchasesParams purchasesParams(String type) {
		return QueryPurchasesParams.newBuilder().setProductType(type).build();
	}

	// Subscriptions must name a base plan offer; one-time products use their default offer.
	@Nullable
	private static String offerTokenOf(ProductDetails details) {
		List<ProductDetails.SubscriptionOfferDetails> subscriptionOffers = details.getSubscriptionOfferDetails();
		if (subscriptionOffers != null && !subscriptionOffers.isEmpty()) {
			return subscriptionOffers.get(0).getOfferToken();
		}
		ProductDetails.OneTimePurchaseOfferDetails oneTimeOffer = details.getOneTimePurchaseOfferDetails();
		return oneTimeOffer != null ? oneTimeOffer.getOfferToken() : null;
	}
}
