package com.example

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.data.AppDatabase
import com.example.data.TransactionEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "SmsReceiver"
        const val CHANNEL_ID = "sms_transactions_channel"
        const val NOTIFICATION_ID = 81395
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive invoked with action: ${intent.action}")
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle = intent.extras ?: return
            try {
                val pdus = bundle.get("pdus") as? Array<*> ?: return
                val format = bundle.getString("format")
                for (pdu in pdus) {
                    val message = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        SmsMessage.createFromPdu(pdu as ByteArray, format)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsMessage.createFromPdu(pdu as ByteArray)
                    }
                    val body = message.messageBody ?: ""
                    val sender = message.originatingAddress ?: "Unknown"

                    Log.d(TAG, "SMS received from '$sender': '$body'")
                    parseAndInsertTransaction(context, sender, body)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing received SMS", e)
            }
        }
    }

    private fun parseAndInsertTransaction(context: Context, sender: String, body: String) {
        val amount = parseAmount(body)
        if (amount == null) {
            Log.d(TAG, "SMS ignored (no transaction amount found or matches regex)")
            return
        }

        val type = parseType(body)
        val category = determineCategory(body)
        val merchant = parseMerchant(body) ?: sender

        // For dynamic title
        val title = if (merchant != sender) {
            if (type == "EXPENSE") "Paid to $merchant" else "Credited from $merchant"
        } else {
            if (type == "EXPENSE") "Expense from $sender" else "Income from $sender"
        }

        val transaction = TransactionEntity(
            title = title,
            category = category,
            amount = amount,
            type = type,
            dateMillis = System.currentTimeMillis(),
            merchantName = merchant
        )

        Log.d(TAG, "Parsed Transaction: Amount=$amount, Type=$type, Merchant=$merchant, Category=$category")

        // Store into Room DB
        val scope = CoroutineScope(Dispatchers.IO)
        val db = AppDatabase.getDatabase(context.applicationContext, scope)
        scope.launch {
            try {
                db.transactionDao().insertTransaction(transaction)
                Log.d(TAG, "Successfully saved SMS transaction to database!")
                showSmsNotification(context, sender, amount, type, merchant)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write transaction to database", e)
            }
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

    private fun showSmsNotification(context: Context, sender: String, amount: Double, type: String, merchant: String) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Transaction Detections",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alerts for real-time parsed transactions"
                    enableLights(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(context, 0, intent, pendingIntentFlags)

            val typeText = if (type == "EXPENSE") "Sent/Spent" else "Received/Credited"
            val bodyText = "$typeText Rs.$amount at $merchant. Auto-saved safely to ledger!"

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("New SMS Transaction!")
                .setContentText(bodyText)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .build()

            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Error posting notification", e)
        }
    }
}
