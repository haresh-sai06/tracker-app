package com.example.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@Database(
    entities = [
        TransactionEntity::class,
        CategoryEntity::class,
        BudgetEntity::class,
        SettingEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun transactionDao(): TransactionDao
    abstract fun categoryDao(): CategoryDao
    abstract fun budgetDao(): BudgetDao
    abstract fun settingsDao(): SettingsDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context, scope: CoroutineScope): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "tracker_app_database"
                )
                .addCallback(AppDatabaseCallback(scope))
                .build()
                INSTANCE = instance
                instance
            }
        }
    }

    private class AppDatabaseCallback(
        private val scope: CoroutineScope
    ) : RoomDatabase.Callback() {
        override fun onCreate(db: SupportSQLiteDatabase) {
            super.onCreate(db)
            INSTANCE?.let { database ->
                scope.launch(Dispatchers.IO) {
                    populateDefaultCategories(database.categoryDao())
                }
            }
        }

        private suspend fun populateDefaultCategories(dao: CategoryDao) {
            val defaultCategories = listOf(
                CategoryEntity("food", "Food & Dining", "Restaurant", "#FF7043", false),
                CategoryEntity("shopping", "Shopping", "ShoppingBag", "#EC407A", false),
                CategoryEntity("transport", "Transport", "DirectionsCar", "#26A69A", false),
                CategoryEntity("entertainment", "Entertainment", "Movie", "#AB47BC", false),
                CategoryEntity("rent", "Rent & Bills", "HomeWork", "#5C6BC0", false),
                CategoryEntity("salary", "Salary", "Work", "#9CCC65", true),
                CategoryEntity("bonus", "Investment & Bonus", "TrendingUp", "#26C6DA", true),
                CategoryEntity("others", "Others", "Category", "#90A4AE", false)
            )
            dao.insertCategories(defaultCategories)
        }
    }
}
