/*************************************************************************/
/*  GooglePlayBillingUtils.java                                          */
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

package org.godotengine.godot.plugin.googleplaybilling.utils;

import org.godotengine.godot.Dictionary;

import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;

import java.util.List;

/** Converts Play Billing objects into the Dictionaries the unified GodotBilling signals carry. */
public class GooglePlayBillingUtils {
	private static Dictionary purchaseToDictionary(Purchase purchase) {
		List<String> productIds = purchase.getProducts();
		Dictionary dictionary = new Dictionary();
		dictionary.put("original_json", orEmpty(purchase.getOriginalJson()));
		// Pending purchases have no order ID yet, and the game's String fields cannot hold null.
		dictionary.put("order_id", orEmpty(purchase.getOrderId()));
		dictionary.put("package_name", purchase.getPackageName());
		dictionary.put("purchase_state", purchase.getPurchaseState());
		dictionary.put("purchase_time", purchase.getPurchaseTime());
		dictionary.put("purchase_token", purchase.getPurchaseToken());
		dictionary.put("quantity", purchase.getQuantity());
		dictionary.put("signature", orEmpty(purchase.getSignature()));
		dictionary.put("sku", productIds.isEmpty() ? "" : productIds.get(0));
		dictionary.put("skus", productIds.toArray(new String[0]));
		dictionary.put("acknowledged", purchase.isAcknowledged());
		dictionary.put("is_auto_renewing", purchase.isAutoRenewing());
		return dictionary;
	}

	public static Object[] purchasesToArray(List<Purchase> purchases) {
		Object[] dictionaries = new Object[purchases.size()];
		for (int i = 0; i < purchases.size(); i++) {
			dictionaries[i] = purchaseToDictionary(purchases.get(i));
		}
		return dictionaries;
	}

	// Subscriptions carry no single price, so their price keys are left out.
	public static Dictionary productDetailsToDictionary(ProductDetails details) {
		Dictionary dictionary = new Dictionary();
		dictionary.put("sku", details.getProductId());
		// getName() is the store title without the " (App name)" suffix that getTitle() adds.
		dictionary.put("title", details.getName());
		dictionary.put("description", details.getDescription());
		dictionary.put("type", details.getProductType());
		ProductDetails.OneTimePurchaseOfferDetails offer = details.getOneTimePurchaseOfferDetails();
		if (offer != null) {
			dictionary.put("price", offer.getFormattedPrice());
			dictionary.put("price_currency_code", offer.getPriceCurrencyCode());
			dictionary.put("price_amount_micros", offer.getPriceAmountMicros());
		}
		return dictionary;
	}

	private static String orEmpty(String value) {
		return value != null ? value : "";
	}
}
