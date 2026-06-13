package com.example

import android.app.Application
import android.content.Intent
import android.util.Log
import kotlin.system.exitProcess

class TrackerApplication : Application() {
    companion object {
        const val TAG = "TrackerApplication"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "TrackerApplication created successfully!")

        // Enable global resilience against background and main thread crashes
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            Log.e(TAG, "Caught uncaught exception on thread ${thread.name}", throwable)

            // 1. If the exception occurred on a background thread, fail-safe.
            // Do not terminate the process, as background thread death is usually recoverable.
            if (thread.name != "main") {
                Log.w(TAG, "Resiliency: Prevented app closure from background thread crash.")
                return@setDefaultUncaughtExceptionHandler
            }

            // 2. If the main UI thread crashes, gracefully self-heal by restarting MainActivity
            try {
                Log.e(TAG, "Resiliency: Main thread crashed! Self-healing by restarting UI Activity...")
                val intent = Intent(applicationContext, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                }
                startActivity(intent)
                exitProcess(0)
            } catch (e: Exception) {
                Log.e(TAG, "Resiliency: Graceful recovery launch failed. Fallback to default handler.", e)
                defaultHandler?.uncaughtException(thread, throwable)
            }
        }
    }
}
