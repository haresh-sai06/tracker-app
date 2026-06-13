package com.yourapp.tracker

import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class TransactionNotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "TxNotificationListener"
        
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
            "in.amazon.mShop.android.shopping"        // Amazon Pay
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
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        if (title.isEmpty() && text.isEmpty()) return

        Log.d(TAG, "Received notification from $packageName - Title: $title, Text: $text")

        // Forward to Flutter side
        MainActivity.onNotificationReceived(packageName, title, text)
    }
}
