package com.haresh.transactiontracker

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object BackgroundCacheHelper {
    private const val PREFS_NAME = "background_transactions_prefs"
    private const val KEY_PENDING = "pending_transactions"

    fun addPendingTransaction(context: Context, sender: String, body: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val pendingStr = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        try {
            val jsonArray = JSONArray(pendingStr)
            val newTx = JSONObject().apply {
                put("sender", sender)
                put("body", body)
                put("timestamp", System.currentTimeMillis())
            }
            jsonArray.put(newTx)
            prefs.edit().putString(KEY_PENDING, jsonArray.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun getAndClearPendingTransactions(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val pendingStr = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        prefs.edit().putString(KEY_PENDING, "[]").apply()
        return pendingStr
    }
}
