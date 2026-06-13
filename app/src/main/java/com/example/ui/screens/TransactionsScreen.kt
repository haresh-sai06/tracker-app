package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.data.TransactionEntity
import com.example.ui.FinanceUiState
import com.example.ui.FinanceViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionsScreen(
    state: FinanceUiState,
    viewModel: FinanceViewModel,
    modifier: Modifier = Modifier
) {
    var searchQuery by remember { mutableStateOf("") }
    var filterType by remember { mutableStateOf("ALL") } // "ALL", "EXPENSE", "INCOME"
    var showAddDialog by remember { mutableStateOf(false) }

    // Filter and search transactions
    val filteredTransactions = state.transactions.filter { tx ->
        val matchesSearch = tx.title.contains(searchQuery, ignoreCase = true) || 
                            tx.merchantName?.contains(searchQuery, ignoreCase = true) == true
        val matchesType = when (filterType) {
            "EXPENSE" -> tx.type == "EXPENSE"
            "INCOME" -> tx.type == "INCOME"
            else -> true
        }
        matchesSearch && matchesType
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Ledger Entries", fontWeight = FontWeight.Bold) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddDialog = true },
                containerColor = MaterialTheme.colorScheme.primary,
                modifier = Modifier.testTag("transactions_add_fab")
            ) {
                Icon(imageVector = Icons.Default.Add, contentDescription = "Add Transaction")
            }
        },
        containerColor = Color.Transparent,
        modifier = modifier.fillMaxSize()
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp)
        ) {
            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("Search transactions...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp)
                    .testTag("ledger_search_field"),
                shape = MaterialTheme.shapes.medium
            )

            // Dynamic filter chips row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChip(
                    selected = filterType == "ALL",
                    onClick = { filterType = "ALL" },
                    label = { Text("All") },
                    modifier = Modifier.testTag("filter_all_chip")
                )
                FilterChip(
                    selected = filterType == "EXPENSE",
                    onClick = { filterType = "EXPENSE" },
                    label = { Text("Expenses") },
                    modifier = Modifier.testTag("filter_expense_chip")
                )
                FilterChip(
                    selected = filterType == "INCOME",
                    onClick = { filterType = "INCOME" },
                    label = { Text("Incomes") },
                    modifier = Modifier.testTag("filter_income_chip")
                )
            }

            // Ledger items
            if (filteredTransactions.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = Icons.Default.FilterListOff,
                            contentDescription = "No Results",
                            modifier = Modifier.size(56.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "No matching transactions found",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(filteredTransactions, key = { it.id }) { transaction ->
                        val category = state.categories.find { it.id == transaction.category }
                        TransactionDashboardRow(
                            transaction = transaction,
                            categoryName = category?.name ?: "Uncategorized",
                            categoryColor = category?.colorHex ?: "#1A73E8",
                            categoryIcon = category?.iconName ?: "AttachMoney",
                            currency = state.currency,
                            onDeleteClick = { viewModel.deleteTransaction(transaction.id) },
                            modifier = Modifier.animateItem()
                        )
                    }
                }
            }
        }
    }

    if (showAddDialog) {
        QuickAddTransactionDialog(
            state = state,
            onDismiss = { showAddDialog = false },
            onSave = { title, amount, type, categoryId, merchant ->
                viewModel.addTransaction(title, amount, type, categoryId, merchant)
                showAddDialog = false
            }
        )
    }
}
