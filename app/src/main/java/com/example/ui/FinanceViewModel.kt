package com.example.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class FinanceUiState(
    val transactions: List<TransactionEntity> = emptyList(),
    val categories: List<CategoryEntity> = emptyList(),
    val budgets: List<BudgetEntity> = emptyList(),
    val isBiometricEnabled: Boolean = false,
    val passcode: String? = null,
    val currency: String = "USD",
    val isLoading: Boolean = true,
    val googleEmail: String? = null,
    val googleName: String? = null,
    val googlePhoto: String? = null,
    val isGoogleSynced: Boolean = false
)

class FinanceViewModel(application: Application) : AndroidViewModel(application) {
    private val db = AppDatabase.getDatabase(application, viewModelScope)
    val repository = FinanceRepository(db)

    private val _uiState = MutableStateFlow(FinanceUiState())
    val uiState: StateFlow<FinanceUiState> = _uiState.asStateFlow()

    init {
        // 1. Safe one-time check and insertion of default categories & mock transactions
        viewModelScope.launch(Dispatchers.IO) {
            val existingCats = repository.getCategories()
            if (existingCats.isEmpty()) {
                val defaults = listOf(
                    CategoryEntity("food", "Food & Dining", "Restaurant", "#FF7043", false),
                    CategoryEntity("shopping", "Shopping", "ShoppingBag", "#EC407A", false),
                    CategoryEntity("transport", "Transport", "DirectionsCar", "#26A69A", false),
                    CategoryEntity("entertainment", "Entertainment", "Movie", "#AB47BC", false),
                    CategoryEntity("rent", "Rent & Bills", "HomeWork", "#5C6BC0", false),
                    CategoryEntity("salary", "Salary", "Work", "#9CCC65", true),
                    CategoryEntity("bonus", "Investment & Bonus", "TrendingUp", "#26C6DA", true),
                    CategoryEntity("others", "Others", "Category", "#90A4AE", false)
                )
                defaults.forEach { repository.insertCategory(it) }
            } else if (existingCats.none { it.id == "others" }) {
                repository.insertCategory(CategoryEntity("others", "Others", "Category", "#90A4AE", false))
            }

            // Seed mock transactions if empty
            val existingTxs = repository.getTransactionsOnce()
            if (existingTxs.isEmpty()) {
                val now = System.currentTimeMillis()
                val day = 86400000L
                val mockData = listOf(
                    TransactionEntity(
                        title = "Monthly Salary",
                        category = "salary",
                        amount = 4500.00,
                        type = "INCOME",
                        dateMillis = now - 5 * day,
                        merchantName = "Acme Corp"
                    ),
                    TransactionEntity(
                        title = "Weekly Grocery",
                        category = "food",
                        amount = 142.50,
                        type = "EXPENSE",
                        dateMillis = now - 4 * day,
                        merchantName = "Whole Foods"
                    ),
                    TransactionEntity(
                        title = "Uber Ride",
                        category = "transport",
                        amount = 24.00,
                        type = "EXPENSE",
                        dateMillis = now - 3 * day,
                        merchantName = "Uber"
                    ),
                    TransactionEntity(
                        title = "Designer Shoes",
                        category = "shopping",
                        amount = 189.99,
                        type = "EXPENSE",
                        dateMillis = now - 2 * day,
                        merchantName = "Nike Store"
                    ),
                    TransactionEntity(
                        title = "Netflix Subscription",
                        category = "entertainment",
                        amount = 15.99,
                        type = "EXPENSE",
                        dateMillis = now - day,
                        merchantName = "Netflix"
                    )
                )
                for (tx in mockData) {
                    repository.insertTransaction(tx)
                }
            }
        }

        // 2. Observe database tables reactively (Pure read-only, NO DB writes!)
        viewModelScope.launch(Dispatchers.IO) {
            combine(
                repository.allTransactions,
                repository.allCategories,
                repository.allBudgets,
                repository.allSettings
            ) { txs, cats, budgets, settings ->
                val bioSetting = settings.find { it.key == "BIOMETRIC_LOCK" }?.value == "true"
                val currSetting = settings.find { it.key == "CURRENCY" }?.value ?: "USD"
                val pinSetting = settings.find { it.key == "PIN_CODE" }?.value
                val gEmail = settings.find { it.key == "GOOGLE_EMAIL" }?.value
                val gName = settings.find { it.key == "GOOGLE_NAME" }?.value
                val gPhoto = settings.find { it.key == "GOOGLE_PHOTO" }?.value
                val gSync = settings.find { it.key == "GOOGLE_SYNC" }?.value == "true"

                FinanceUiState(
                    transactions = txs,
                    categories = cats,
                    budgets = budgets,
                    isBiometricEnabled = bioSetting,
                    passcode = if (pinSetting.isNullOrEmpty()) null else pinSetting,
                    currency = currSetting,
                    isLoading = false,
                    googleEmail = if (gEmail.isNullOrBlank()) null else gEmail,
                    googleName = gName,
                    googlePhoto = gPhoto,
                    isGoogleSynced = gSync
                )
            }.collect {
                _uiState.value = it
            }
        }
    }

    fun savePasscode(code: String) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.saveSetting("PIN_CODE", code)
        }
    }

    fun clearPasscode() {
        viewModelScope.launch(Dispatchers.IO) {
            repository.saveSetting("PIN_CODE", "")
        }
    }

    fun addTransaction(title: String, amount: Double, type: String, categoryId: String, merchant: String? = null) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertTransaction(
                TransactionEntity(
                    title = title,
                    category = categoryId,
                    amount = amount,
                    type = type,
                    dateMillis = System.currentTimeMillis(),
                    merchantName = merchant
                )
            )
            val state = uiState.value
            if (state.googleEmail != null && state.isGoogleSynced) {
                syncGoogleData()
            }
        }
    }

    fun deleteTransaction(id: Int) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.softDeleteTransaction(id)
            val state = uiState.value
            if (state.googleEmail != null && state.isGoogleSynced) {
                syncGoogleData()
            }
        }
    }

    fun addCategory(id: String, name: String, iconName: String, colorHex: String, isIncome: Boolean) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertCategory(
                CategoryEntity(id, name, iconName, colorHex, isIncome)
            )
        }
    }

    fun updateBudget(categoryId: String, limit: Double) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertBudget(
                BudgetEntity(categoryId, limit)
            )
            val state = uiState.value
            if (state.googleEmail != null && state.isGoogleSynced) {
                syncGoogleData()
            }
        }
    }

    fun deleteBudget(categoryId: String) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.deleteBudget(categoryId)
            val state = uiState.value
            if (state.googleEmail != null && state.isGoogleSynced) {
                syncGoogleData()
            }
        }
    }

    fun setBiometricEnabled(enabled: Boolean) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.saveSetting("BIOMETRIC_LOCK", enabled.toString())
        }
    }

    fun setCurrency(currencyCode: String) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.saveSetting("CURRENCY", currencyCode)
        }
    }

    fun backupToCloud(backupKey: String, onSuccess: () -> Unit, onError: (String) -> Unit) {
        viewModelScope.launch(Dispatchers.IO) {
            val txs = uiState.value.transactions
            val bgs = uiState.value.budgets
            val result = FirebaseBackupService.performBackup(backupKey, txs, bgs)
            viewModelScope.launch(Dispatchers.Main) {
                result.fold(
                    onSuccess = { onSuccess() },
                    onFailure = { onError(it.message ?: "Backup failed") }
                )
            }
        }
    }

    fun restoreFromCloud(backupKey: String, onSuccess: () -> Unit, onError: (String) -> Unit) {
        viewModelScope.launch(Dispatchers.IO) {
            val result = FirebaseBackupService.performRestore(backupKey)
            viewModelScope.launch(Dispatchers.Main) {
                result.fold(
                    onSuccess = { (txs, bgs) ->
                        viewModelScope.launch(Dispatchers.IO) {
                            repository.restoreData(txs, bgs)
                            viewModelScope.launch(Dispatchers.Main) {
                                onSuccess()
                            }
                        }
                    },
                    onFailure = { onError(it.message ?: "Restore failed") }
                )
            }
        }
    }

    fun signInWithGoogle(email: String, name: String, photoUrl: String, onComplete: () -> Unit) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.saveSetting("GOOGLE_EMAIL", email)
            repository.saveSetting("GOOGLE_NAME", name)
            repository.saveSetting("GOOGLE_PHOTO", photoUrl)
            repository.saveSetting("GOOGLE_SYNC", "true")

            val sanitizedKey = sanitizeBackupKey(email)
            val restoreResult = FirebaseBackupService.performRestore(sanitizedKey)
            restoreResult.fold(
                onSuccess = { (txs, bgs) ->
                    if (txs.isNotEmpty() || bgs.isNotEmpty()) {
                        repository.restoreData(txs, bgs)
                    } else {
                        val currentTxs = repository.getTransactionsOnce()
                        val currentBgs = uiState.value.budgets
                        FirebaseBackupService.performBackup(sanitizedKey, currentTxs, currentBgs)
                    }
                },
                onFailure = {
                    val currentTxs = repository.getTransactionsOnce()
                    val currentBgs = uiState.value.budgets
                    FirebaseBackupService.performBackup(sanitizedKey, currentTxs, currentBgs)
                }
            )
            viewModelScope.launch(Dispatchers.Main) {
                onComplete()
            }
        }
    }

    fun signOutFromGoogle() {
        viewModelScope.launch(Dispatchers.IO) {
            repository.saveSetting("GOOGLE_EMAIL", "")
            repository.saveSetting("GOOGLE_NAME", "")
            repository.saveSetting("GOOGLE_PHOTO", "")
            repository.saveSetting("GOOGLE_SYNC", "false")
        }
    }

    fun setGoogleSyncEnabled(enabled: Boolean) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.saveSetting("GOOGLE_SYNC", enabled.toString())
            if (enabled) {
                syncGoogleData()
            }
        }
    }

    fun syncGoogleData(onSuccess: (() -> Unit)? = null, onError: ((String) -> Unit)? = null) {
        viewModelScope.launch(Dispatchers.IO) {
            val email = uiState.value.googleEmail
            if (email.isNullOrBlank()) {
                viewModelScope.launch(Dispatchers.Main) {
                    onError?.invoke("No Google Account connected.")
                }
                return@launch
            }
            val sanitizedKey = sanitizeBackupKey(email)
            val currentTxs = repository.getTransactionsOnce()
            val currentBgs = uiState.value.budgets
            val result = FirebaseBackupService.performBackup(sanitizedKey, currentTxs, currentBgs)
            viewModelScope.launch(Dispatchers.Main) {
                result.fold(
                    onSuccess = { onSuccess?.invoke() },
                    onFailure = { onError?.invoke(it.message ?: "Sync failed") }
                )
            }
        }
    }

    private fun sanitizeBackupKey(email: String): String {
        return "google-" + email.replace("@", "-at-").replace(".", "-dot-")
    }
}
