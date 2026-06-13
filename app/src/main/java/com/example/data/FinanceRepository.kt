package com.example.data

import kotlinx.coroutines.flow.Flow

class FinanceRepository(private val db: AppDatabase) {
    val allTransactions: Flow<List<TransactionEntity>> = db.transactionDao().getAllTransactions()
    val allCategories: Flow<List<CategoryEntity>> = db.categoryDao().getCategoriesFlow()
    val allBudgets: Flow<List<BudgetEntity>> = db.budgetDao().getAllBudgets()
    val allSettings: Flow<List<SettingEntity>> = db.settingsDao().getSettingsFlow()

    suspend fun getCategories(): List<CategoryEntity> {
        return db.categoryDao().getCategories()
    }

    suspend fun getTransactionsOnce(): List<TransactionEntity> {
        return db.transactionDao().getTransactionsOnce()
    }

    suspend fun insertTransaction(transaction: TransactionEntity) {
        db.transactionDao().insertTransaction(transaction)
    }

    suspend fun updateTransaction(transaction: TransactionEntity) {
        db.transactionDao().updateTransaction(transaction)
    }

    suspend fun softDeleteTransaction(id: Int) {
        db.transactionDao().softDeleteTransaction(id)
    }

    suspend fun insertCategory(category: CategoryEntity) {
        db.categoryDao().insertCategory(category)
    }

    suspend fun deleteCategory(category: CategoryEntity) {
        db.categoryDao().deleteCategory(category)
    }

    suspend fun insertBudget(budget: BudgetEntity) {
        db.budgetDao().insertBudget(budget)
    }

    suspend fun deleteBudget(categoryId: String) {
        db.budgetDao().deleteBudget(categoryId)
    }

    suspend fun restoreData(transactions: List<TransactionEntity>, budgets: List<BudgetEntity>) {
        db.transactionDao().clearAllTransactions()
        db.transactionDao().insertTransactions(transactions)
        db.budgetDao().clearAllBudgets()
        db.budgetDao().insertBudgets(budgets)
    }

    suspend fun getSetting(key: String): String? {
        return db.settingsDao().getSetting(key)?.value
    }

    suspend fun saveSetting(key: String, value: String) {
        db.settingsDao().saveSetting(SettingEntity(key, value))
    }
}
