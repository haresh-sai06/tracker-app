package com.example

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.example.data.AppDatabase
import com.example.data.TransactionEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.regex.Pattern

class MyNotificationListenerService : NotificationListenerService() {
    companion object {
        const val TAG = "NotificationListener"
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener service connected successfully!")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val packageName = sbn.packageName ?: "Unknown"
            val extras = sbn.notification.extras ?: return
            val title = extras.getString("android.title") ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""

            val combinedText = "$title | $text | $bigText"
            Log.d(TAG, "Notification received from app: $packageName with text: $combinedText")

            // Filter for transaction-looking notifications
            val lowerText = combinedText.lowercase()
            val hasAmount = lowerText.contains("rs") || lowerText.contains("inr")
            val hasTxKeywords = lowerText.contains("debited") || 
                                lowerText.contains("credited") || 
                                lowerText.contains("spent") || 
                                lowerText.contains("payment") || 
                                lowerText.contains("transfer") || 
                                lowerText.contains("sent") || 
                                lowerText.contains("received") || 
                                lowerText.contains("paid")

            if (hasAmount && hasTxKeywords) {
                parseAndInsertNotificationTransaction(packageName, combinedText)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
    }

    private fun parseAndInsertNotificationTransaction(sourceApp: String, fullText: String) {
        try {
            val amount = parseAmount(fullText) ?: return
            val type = parseType(fullText)
            val category = determineCategory(fullText)
            val merchant = parseMerchant(fullText) ?: sourceApp.substringAfterLast(".")

            val title = if (type == "EXPENSE") "Paid to $merchant (Notification)" else "Credited from $merchant (Notification)"

            val transaction = TransactionEntity(
                title = title,
                category = category,
                amount = amount,
                type = type,
                dateMillis = System.currentTimeMillis(),
                merchantName = merchant
            )

            Log.d(TAG, "Notification Parser found Transaction: Amount=$amount, Type=$type, Merchant=$merchant, Category=$category")

            val scope = CoroutineScope(Dispatchers.IO)
            val db = AppDatabase.getDatabase(applicationContext, scope)
            scope.launch {
                try {
                    db.transactionDao().insertTransaction(transaction)
                    Log.d(TAG, "Successfully saved notification transaction to database!")
                } catch (e: Exception) {
                    Log.e(TAG, "Error writing transaction from notification to database", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in parseAndInsertNotificationTransaction", e)
        }
    }

    private fun parseAmount(text: String): Double? {
        val patterns = listOf(
            Pattern.compile("(?i)(?:Rs|INR|Rs\\.|INR\\s*)\\s*([\\d,]+\\.?\\d*)"),
            Pattern.compile("(?i)Sent\\s+(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*)"),
            Pattern.compile("(?i)debited\\s+(?:with|by|of)?\\s*(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*)"),
            Pattern.compile("(?i)credited\\s+(?:with|by|of)?\\s*(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*)")
        )

        for (pattern in patterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val match = matcher.group(1) ?: continue
                val clean = match.replace(",", "").trim()
                val doubleVal = clean.toDoubleOrNull()
                if (doubleVal != null) {
                    return doubleVal
                }
            }
        }
        return null
    }

    private fun parseType(text: String): String {
        val lower = text.lowercase()
        return if (lower.contains("credited") || 
            lower.contains("received") || 
            lower.contains("deposited") || 
            lower.contains("refund") || 
            lower.contains("added") || 
            lower.contains("cashback")) {
            "INCOME"
        } else {
            "EXPENSE"
        }
    }

    private fun determineCategory(text: String): String {
        val lower = text.lowercase()
        return when {
            lower.contains("food") || lower.contains("swiggy") || lower.contains("zomato") || lower.contains("restaurant") || lower.contains("grocery") || lower.contains("din") -> "food"
            lower.contains("uber") || lower.contains("ola") || lower.contains("metro") || lower.contains("ride") || lower.contains("cab") || lower.contains("petrol") || lower.contains("fuel") -> "transport"
            lower.contains("movie") || lower.contains("netflix") || lower.contains("spotify") || lower.contains("prime") || lower.contains("hotstar") || lower.contains("theatre") || lower.contains("entertainment") -> "entertainment"
            lower.contains("rent") || lower.contains("electricity") || lower.contains("bill") || lower.contains("water") || lower.contains("recharge") -> "rent"
            lower.contains("salary") || lower.contains("stipend") || lower.contains("wages") -> "salary"
            lower.contains("investment") || lower.contains("bonus") || lower.contains("cash") || lower.contains("dividend") -> "bonus"
            else -> "shopping"
        }
    }

    private fun parseMerchant(text: String): String? {
        val patterns = listOf(
            Pattern.compile("(?i)To\\s+([A-Za-z0-9\\s&]+?)(?:\\s+On|\\s+at|\\s+Ref|\\s+from|\\spaid|\\.|$)"),
            Pattern.compile("(?i)at\\s+([A-Za-z0-9\\s&]+?)(?:\\s+On|\\s+Ref|\\.|$)"),
            Pattern.compile("(?i)from\\s+([A-Za-z0-9\\s&]+?)(?:\\s+On|\\s+Ref|\\.|$)")
        )
        for (pattern in patterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val raw = matcher.group(1)?.trim() ?: continue
                if (raw.isNotEmpty() && !raw.lowercase().contains("bank") && !raw.lowercase().contains("account") && !raw.lowercase().contains("a/c")) {
                    return raw
                }
            }
        }
        return null
    }
}
