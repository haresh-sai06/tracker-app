package com.haresh.transactiontracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.SmsMessage
import androidx.core.app.NotificationCompat

import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL_ID = "sms_transactions_channel"
        const val NOTIFICATION_ID = 81395
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SmsReceiver", "onReceive action: ${intent.action}")
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle = intent.extras ?: return
            try {
                val pdus = bundle.get("pdus") as Array<*>? ?: return
                for (pdu in pdus) {
                    val format = bundle.getString("format")
                    val message = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        SmsMessage.createFromPdu(pdu as ByteArray, format)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsMessage.createFromPdu(pdu as ByteArray)
                    }

                    val sender = message.originatingAddress ?: "Unknown"
                    val body = message.messageBody ?: ""

                    Log.d("SmsReceiver", "Received SMS from: $sender - Body: $body")

                    // Forward to active Flutter runner if it is alive, else cache it in background
                    if (MainActivity.activeChannel != null) {
                        Log.d("SmsReceiver", "App active, forwarding SMS to Flutter MethodChannel")
                        MainActivity.onSmsReceived(context, sender, body)
                    } else {
                        Log.d("SmsReceiver", "App backgrounded/closed, caching SMS in SharedPreferences")
                        BackgroundCacheHelper.addPendingTransaction(context, sender, body)
                    }

                    // Also check if text looks like a transaction (debited/credited/spent/rs)
                    val bodyLower = body.lowercase()
                    val isTransaction = bodyLower.contains("debited") || 
                                        bodyLower.contains("debitted") || 
                                        bodyLower.contains("credited") || 
                                        bodyLower.contains("creditted") || 
                                        bodyLower.contains("spent") || 
                                        bodyLower.contains("sent") || 
                                        bodyLower.contains("paid") || 
                                        bodyLower.contains("transaction") ||
                                        bodyLower.contains("payment") || 
                                        bodyLower.contains("rs.") || 
                                        bodyLower.contains("rs ") || 
                                        bodyLower.contains("rupee") || 
                                        bodyLower.contains("rupees") || 
                                        bodyLower.contains("inr")

                    if (isTransaction) {
                        showSmsNotification(context, sender, body)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun showSmsNotification(context: Context, sender: String, body: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS Transaction Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows alerts for parsed SMS transactions"
                enableLights(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Action / Tap intent: Launches MainActivity with SMS extras
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("sms_sender", sender)
            putExtra("sms_body", body)
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val tapPendingIntent = PendingIntent.getActivity(
            context,
            1,
            tapIntent,
            pendingIntentFlags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("New Transaction Detected")
            .setContentText("Tap to review transaction details from $sender.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Transaction SMS from $sender:\n$body"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(tapPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_edit,
                "Review Transaction",
                tapPendingIntent
            )
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
