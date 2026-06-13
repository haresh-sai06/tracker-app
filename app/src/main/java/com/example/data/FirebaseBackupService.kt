package com.example.data

import android.content.Context
import android.util.Log
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import com.example.BuildConfig


object FirebaseBackupService {
    private const val TAG = "FirebaseBackupService"
    private val PROJECT_ID = BuildConfig.ANDROID_FIREBASE_PROJECT_ID
    private val API_KEY = BuildConfig.ANDROID_FIREBASE_API_KEY
    private val BASE_URL = "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/backups"

    private fun isConfigured(): Boolean {
        return PROJECT_ID.isNotEmpty() &&
               API_KEY.isNotEmpty() &&
               PROJECT_ID != "YOUR_ANDROID_FIREBASE_PROJECT_ID" &&
               API_KEY != "YOUR_ANDROID_FIREBASE_API_KEY"
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

    suspend fun performBackup(backupKey: String, transactions: List<TransactionEntity>, budgets: List<BudgetEntity>): Result<Unit> {
        if (!isConfigured()) {
            Log.w(TAG, "Firebase credentials are not configured.")
            return Result.failure(Exception("Firebase credentials are not configured."))
        }
        return try {
            val transactionsJson = JSONArray()
            transactions.forEach { tx ->
                val obj = JSONObject().apply {
                    put("title", tx.title)
                    put("category", tx.category)
                    put("amount", tx.amount)
                    put("type", tx.type)
                    put("dateMillis", tx.dateMillis)
                    put("merchantName", tx.merchantName ?: "")
                    put("isDeleted", tx.isDeleted)
                }
                transactionsJson.put(obj)
            }

            val budgetsJson = JSONArray()
            budgets.forEach { b ->
                val obj = JSONObject().apply {
                    put("categoryId", b.categoryId)
                    put("limitAmount", b.limitAmount)
                }
                budgetsJson.put(obj)
            }

            val backupPayload = JSONObject().apply {
                put("transactions", transactionsJson)
                put("budgets", budgetsJson)
            }

            // Wrap in firestore document format
            // PATCH http url to perform create-or-overwrite of backup
            val url = "$BASE_URL/$backupKey?key=$API_KEY"

            val documentJson = JSONObject().apply {
                put("name", "projects/$PROJECT_ID/databases/(default)/documents/backups/$backupKey")
                val fieldsObj = JSONObject().apply {
                    put("dataJson", JSONObject().apply {
                        put("stringValue", backupPayload.toString())
                    })
                    put("timestamp", JSONObject().apply {
                        put("stringValue", System.currentTimeMillis().toString())
                    })
                }
                put("fields", fieldsObj)
            }

            val requestBody = documentJson.toString().toRequestBody(JSON_MEDIA_TYPE)
            val request = Request.Builder()
                .url(url)
                .patch(requestBody)
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    Log.d(TAG, "Backup successfully uploaded for key: $backupKey")
                    Result.success(Unit)
                } else {
                    val errMsg = "HTTP error code: ${response.code}, msg: ${response.body?.string()}"
                    Log.e(TAG, errMsg)
                    Result.failure(Exception(errMsg))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception during backup upload", e)
            Result.failure(e)
        }
    }

    suspend fun performRestore(backupKey: String): Result<Pair<List<TransactionEntity>, List<BudgetEntity>>> {
        if (!isConfigured()) {
            Log.w(TAG, "Firebase credentials are not configured.")
            return Result.failure(Exception("Firebase credentials are not configured."))
        }
        return try {
            val url = "$BASE_URL/$backupKey?key=$API_KEY"
            val request = Request.Builder()
                .url(url)
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val responseStr = response.body?.string() ?: return Result.failure(Exception("Empty response body"))
                    val docObj = JSONObject(responseStr)
                    val fieldsObj = docObj.optJSONObject("fields") ?: return Result.failure(Exception("Invalid backup format: fields missing"))
                    val dataJsonObj = fieldsObj.optJSONObject("dataJson") ?: return Result.failure(Exception("No backup payload found for this key"))
                    val dataRaw = dataJsonObj.optString("stringValue") ?: return Result.failure(Exception("Backup payload empty or corrupted"))

                    val root = JSONObject(dataRaw)
                    val txsArray = root.optJSONArray("transactions") ?: JSONArray()
                    val budgetsArray = root.optJSONArray("budgets") ?: JSONArray()

                    val restoredTransactions = mutableListOf<TransactionEntity>()
                    for (i in 0 until txsArray.length()) {
                        val obj = txsArray.getJSONObject(i)
                        restoredTransactions.add(
                            TransactionEntity(
                                title = obj.optString("title", "Restored Entry"),
                                category = obj.optString("category", "others"),
                                amount = obj.optDouble("amount", 0.0),
                                type = obj.optString("type", "EXPENSE"),
                                dateMillis = obj.optLong("dateMillis", System.currentTimeMillis()),
                                merchantName = obj.optString("merchantName").let { if (it.isEmpty()) null else it },
                                isDeleted = obj.optBoolean("isDeleted", false)
                            )
                        )
                    }

                    val restoredBudgets = mutableListOf<BudgetEntity>()
                    for (i in 0 until budgetsArray.length()) {
                        val obj = budgetsArray.getJSONObject(i)
                        restoredBudgets.add(
                            BudgetEntity(
                                categoryId = obj.optString("categoryId"),
                                limitAmount = obj.optDouble("limitAmount", 0.0)
                            )
                        )
                    }

                    Log.d(TAG, "Backup successfully downloaded and parsed. Transactions: ${restoredTransactions.size}, Budgets: ${restoredBudgets.size}")
                    Result.success(Pair(restoredTransactions, restoredBudgets))
                } else if (response.code == 404) {
                    Result.failure(Exception("Backup key not found. Please double check the key."))
                } else {
                    val errMsg = "HTTP error code: ${response.code}"
                    Result.failure(Exception(errMsg))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception during backup restore", e)
            Result.failure(e)
        }
    }
}
