package com.yourapp.tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.ComponentName
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Environment
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourapp.tracker/sms"
    private val NOTIFICATION_CHANNEL = "com.yourapp.tracker/notifications"
    private var pendingSmsSender: String? = null
    private var pendingSmsBody: String? = null

    companion object {
        var activeChannel: MethodChannel? = null
        var activeNotificationChannel: MethodChannel? = null

        fun onSmsReceived(context: Context, sender: String, body: String) {
            activeChannel?.invokeMethod("onSmsReceived", mapOf(
                "sender" to sender,
                "body" to body
            ))
        }

        fun onNotificationReceived(packageName: String, title: String, text: String) {
            activeNotificationChannel?.invokeMethod("onNotificationReceived", mapOf(
                "packageName" to packageName,
                "title" to title,
                "text" to text
            ))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent != null && intent.hasExtra("sms_body")) {
            pendingSmsSender = intent.getStringExtra("sms_sender")
            pendingSmsBody = intent.getStringExtra("sms_body")

            // If the channel is already active, notify Flutter immediately
            activeChannel?.invokeMethod("onSmsReceived", mapOf(
                "sender" to pendingSmsSender,
                "body" to pendingSmsBody
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        activeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingSms" -> {
                        if (pendingSmsBody != null) {
                            val data = mapOf(
                                "sender" to pendingSmsSender,
                                "body" to pendingSmsBody
                            )
                            pendingSmsSender = null
                            pendingSmsBody = null
                            result.success(data)
                        } else {
                            result.success(null)
                        }
                    }
                    "setSmsEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        setSmsReceiverEnabled(enabled)
                        result.success(true)
                    }
                    "isSmsEnabled" -> {
                        result.success(isSmsReceiverEnabled())
                    }
                    "showTestSmsNotification" -> {
                        val sender = call.argument<String>("sender") ?: "TestBank"
                        val body = call.argument<String>("body") ?: "Rs. 1500 debited from a/c XX1234"
                        showNotificationDirectly(sender, body)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        activeNotificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationListenerPermission" -> {
                        try {
                            val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (err: Exception) {
                                result.error("ERROR", "Could not open settings", err.message)
                            }
                        }
                    }
                    "isNotificationListenerGranted" -> {
                        val cn = ComponentName(applicationContext, TransactionNotificationListener::class.java)
                        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val enabled = flat != null && flat.contains(cn.flattenToString())
                        result.success(enabled)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yourapp.tracker/pdf").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "savePdfToDownloads") {
                    val pdfBytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "Statement.pdf"
                    if (pdfBytes == null) {
                        result.error("INVALID_ARGUMENT", "PDF bytes are null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val resolver = contentResolver
                            val contentValues = ContentValues().apply {
                                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                                put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/")
                            }
                            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                            if (uri != null) {
                                resolver.openOutputStream(uri)?.use { outputStream ->
                                    outputStream.write(pdfBytes)
                                }
                                result.success("Saved to Downloads: $fileName")
                            } else {
                                result.error("ERROR", "Failed to create MediaStore entry", null)
                            }
                        } else {
                            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                            if (!downloadsDir.exists()) {
                                downloadsDir.mkdirs()
                            }
                            val file = File(downloadsDir, fileName)
                            FileOutputStream(file).use { outputStream ->
                                outputStream.write(pdfBytes)
                            }
                            result.success("Saved to Downloads: ${file.absolutePath}")
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to save PDF: ${e.message}", e.stackTraceToString())
                    }
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        activeChannel = null
        activeNotificationChannel = null
        super.onDestroy()
    }

    private fun setSmsReceiverEnabled(enabled: Boolean) {
        val receiver = ComponentName(this, SmsReceiver::class.java)
        val pm = packageManager
        pm.setComponentEnabledSetting(
            receiver,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun isSmsReceiverEnabled(): Boolean {
        val receiver = ComponentName(this, SmsReceiver::class.java)
        val pm = packageManager
        val setting = pm.getComponentEnabledSetting(receiver)
        return setting != PackageManager.COMPONENT_ENABLED_STATE_DISABLED
    }

    private fun showNotificationDirectly(sender: String, body: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SmsReceiver.CHANNEL_ID,
                "SMS Transaction Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows alerts for parsed SMS transactions"
                enableLights(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val tapIntent = Intent(this, MainActivity::class.java).apply {
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
            this,
            2,
            tapIntent,
            pendingIntentFlags
        )

        val notification = NotificationCompat.Builder(this, SmsReceiver.CHANNEL_ID)
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

        notificationManager.notify(SmsReceiver.NOTIFICATION_ID, notification)
    }
}
