package com.haresh.transactiontracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat

class TransactionNotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "TxNotificationListener"
        private const val CHANNEL_ID = "sms_transactions_channel"
        private const val NOTIFICATION_ID = 81395 // Matches SmsReceiver to prevent duplicates
        
        // Configurable list of monitored banking packages
        val MONITORED_PACKAGES = setOf(
            "com.snapwork.hdfc",                      // HDFC Bank
            "com.sbi.sbifreedom",                     // YONO SBI
            "com.sbi.anywhere",                       // SBI Anywhere
            "net.one97.paytm",                        // Paytm
            "com.phonepe.app",                        // PhonePe
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.icicibank.imobile",                  // ICICI iMobile
            "com.axis.mobile",                        // Axis Mobile
            "in.amazon.mShop.android.shopping",       // Amazon Pay
            
            // SMS & Messaging Apps
            "com.truecaller",                         // Truecaller SMS client
            "com.google.android.apps.messaging",      // Google Messages
            "com.samsung.android.messaging",          // Samsung Messages
            "com.android.mms"                         // Generic system MMS/SMS client
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        
        // Ignore notifications from ourselves
        if (packageName == applicationContext.packageName) {
            return
        }

        // Only process if it matches the monitored list of packages
        if (!MONITORED_PACKAGES.contains(packageName)) {
            Log.d(TAG, "Ignored notification from unmonitored package: $packageName")
            return
        }

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        
        var text = extras.getCharSequence("android.text")?.toString() ?: ""
        if (text.isEmpty()) {
            text = extras.getCharSequence("android.bigText")?.toString() ?: ""
        }
        if (text.isEmpty()) {
            val ticker = sbn.notification?.tickerText
            if (ticker != null) {
                text = ticker.toString()
            }
        }
        if (text.isEmpty()) {
            val lines = extras.getCharSequenceArray("android.textLines")
            if (lines != null && lines.isNotEmpty()) {
                text = lines.joinToString("\n")
            }
        }

        if (title.isEmpty() && text.isEmpty()) return

        val bodyLower = "$title $text".lowercase()
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

        Log.d(TAG, "Received notification from $packageName - Title: $title, Text: $text")

        // 1. If Flutter channel is active, forward directly for immediate foreground review, else cache in background
        if (MainActivity.activeNotificationChannel != null) {
            MainActivity.onNotificationReceived(packageName, title, text)
        } else if (isTransaction) {
            val sender = when (packageName) {
                "com.snapwork.hdfc" -> "HDFC Bank"
                "com.sbi.sbifreedom" -> "SBI YONO"
                "com.sbi.anywhere" -> "SBI"
                "net.one97.paytm" -> "Paytm"
                "com.phonepe.app" -> "PhonePe"
                "com.google.android.apps.nbu.paisa.user" -> "Google Pay"
                "com.icicibank.imobile" -> "ICICI Bank"
                "com.axis.mobile" -> "Axis Bank"
                "in.amazon.mShop.android.shopping" -> "Amazon Pay"
                "com.truecaller" -> "Truecaller"
                "com.google.android.apps.messaging" -> "Google Messages"
                "com.samsung.android.messaging" -> "Samsung Messages"
                "com.android.mms" -> "SMS Message"
                else -> "Bank Notification"
            }
            BackgroundCacheHelper.addPendingTransaction(applicationContext, sender, "$title: $text")
        }

        // 2. Also check if we need to show a native system tray notification
        if (isTransaction) {
            val sender = when (packageName) {
                "com.snapwork.hdfc" -> "HDFC Bank"
                "com.sbi.sbifreedom" -> "SBI YONO"
                "com.sbi.anywhere" -> "SBI"
                "net.one97.paytm" -> "Paytm"
                "com.phonepe.app" -> "PhonePe"
                "com.google.android.apps.nbu.paisa.user" -> "Google Pay"
                "com.icicibank.imobile" -> "ICICI Bank"
                "com.axis.mobile" -> "Axis Bank"
                "in.amazon.mShop.android.shopping" -> "Amazon Pay"
                "com.truecaller" -> "Truecaller"
                "com.google.android.apps.messaging" -> "Google Messages"
                "com.samsung.android.messaging" -> "Samsung Messages"
                "com.android.mms" -> "SMS Message"
                else -> "Bank Notification"
            }
            
            showTransactionNotification(applicationContext, sender, title, text)
        }
    }

    private fun showTransactionNotification(context: Context, sender: String, title: String, text: String) {
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

        // Tap intent: Launches MainActivity and forwards it as a parsed SMS payload
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("sms_sender", sender)
            putExtra("sms_body", "$title: $text")
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val tapPendingIntent = PendingIntent.getActivity(
            context,
            3,
            tapIntent,
            pendingIntentFlags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("New Transaction Detected")
            .setContentText("Tap to review transaction details from $sender.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Transaction from $sender:\n$title: $text"))
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
