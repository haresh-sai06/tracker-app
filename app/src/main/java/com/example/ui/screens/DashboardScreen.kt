package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.TransactionEntity
import com.example.ui.FinanceUiState
import com.example.ui.FinanceViewModel
import com.example.ui.getIconVector
import com.example.ui.parseColor
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    state: FinanceUiState,
    viewModel: FinanceViewModel,
    onNavigateToTransactions: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showQuickAddDialog by remember { mutableStateOf(false) }

    // Aggregate statistics
    val totalIncome = state.transactions
        .filter { it.type == "INCOME" }
        .sumOf { it.amount }
    
    val totalExpense = state.transactions
        .filter { it.type == "EXPENSE" }
        .sumOf { it.amount }

    val currentBalance = totalIncome - totalExpense

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Transaction Tracker",
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showQuickAddDialog = true },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier
                    .testTag("dashboard_add_fab")
                    .padding(bottom = 16.dp, end = 8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Quick Add Transaction"
                )
            }
        },
        containerColor = Color.Transparent,
        modifier = modifier.fillMaxSize()
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Gradient Hero Balance Card
            item {
                BalanceHeroCard(
                    balance = currentBalance,
                    income = totalIncome,
                    expense = totalExpense,
                    currency = state.currency
                )
            }

            // Budgets alert banner if exceeding limits
            val exceededBudgets = state.budgets.mapNotNull { budget ->
                val categorySpent = state.transactions
                    .filter { it.category == budget.categoryId && it.type == "EXPENSE" }
                    .sumOf { it.amount }
                if (categorySpent > budget.limitAmount) {
                    val cat = state.categories.find { it.id == budget.categoryId }
                    cat?.name to (categorySpent - budget.limitAmount)
                } else null
            }

            if (exceededBudgets.isNotEmpty()) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.9f))
                            .padding(12.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Warning,
                                tint = MaterialTheme.colorScheme.error,
                                contentDescription = "Budget Warning"
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Budget Exceeded Alerts!",
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onErrorContainer
                            )
                        }
                        exceededBudgets.forEach { (catName, over) ->
                            Text(
                                text = "• $catName is over budget by ${state.currency} ${String.format("%.2f", over)}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                modifier = Modifier.padding(start = 24.dp, top = 4.dp)
                            )
                        }
                    }
                }
            }

            // Quick Stats Row
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    BudgetSummaryCard(
                        modifier = Modifier.weight(1f),
                        state = state,
                        currency = state.currency
                    )
                }
            }

            // Recent Transactions Section Header
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Recent Ledger Entries",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "See All",
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clickable { onNavigateToTransactions() }
                            .padding(8.dp),
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            if (state.transactions.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.Inbox,
                                contentDescription = "Empty",
                                modifier = Modifier.size(48.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "No logged entries yet",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            } else {
                items(state.transactions.take(5)) { transaction ->
                    val category = state.categories.find { it.id == transaction.category }
                    TransactionDashboardRow(
                        transaction = transaction,
                        categoryName = category?.name ?: "Uncategorized",
                        categoryColor = category?.colorHex ?: "#1A73E8",
                        categoryIcon = category?.iconName ?: "AttachMoney",
                        currency = state.currency,
                        onDeleteClick = { viewModel.deleteTransaction(transaction.id) }
                    )
                }
            }
        }
    }

    if (showQuickAddDialog) {
        QuickAddTransactionDialog(
            state = state,
            onDismiss = { showQuickAddDialog = false },
            onSave = { title, amount, type, categoryId, merchant ->
                viewModel.addTransaction(title, amount, type, categoryId, merchant)
                showQuickAddDialog = false
            }
        )
    }
}

@Composable
fun BalanceHeroCard(
    balance: Double,
    income: Double,
    expense: Double,
    currency: String,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .testTag("hero_balance_card"),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF1E3C72),
                            Color(0xFF2A5298)
                        )
                    )
                )
                .padding(24.dp)
        ) {
            Column {
                Text(
                    text = "LOCAL WALLET BALANCE",
                    color = Color.White.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "$currency ${String.format("%,.2f", balance)}",
                    color = Color.White,
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.ExtraBold
                )
                
                Spacer(modifier = Modifier.height(24.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    // Income Flow
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.15f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.ArrowDownward,
                                contentDescription = "Income Flow",
                                tint = Color(0xFF81C784),
                                modifier = Modifier.size(18.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = "INCOME",
                                color = Color.White.copy(alpha = 0.6f),
                                style = MaterialTheme.typography.labelSmall,
                            )
                            Text(
                                text = "$currency ${String.format("%,.2f", income)}",
                                color = Color.White,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }

                    // Expense Flow
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.15f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.ArrowUpward,
                                contentDescription = "Expense Flow",
                                tint = Color(0xFFE57373),
                                modifier = Modifier.size(18.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = "EXPENSES",
                                color = Color.White.copy(alpha = 0.6f),
                                style = MaterialTheme.typography.labelSmall,
                            )
                            Text(
                                text = "$currency ${String.format("%,.2f", expense)}",
                                color = Color.White,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun BudgetSummaryCard(
    state: FinanceUiState,
    currency: String,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Budget & Category Allowances",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(12.dp))

            if (state.budgets.isEmpty()) {
                Text(
                    text = "No limits set. Secure budgets inside Settings to track spending ratios.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            } else {
                state.budgets.forEach { budget ->
                    val cat = state.categories.find { it.id == budget.categoryId } ?: return@forEach
                    val categorySpent = state.transactions
                        .filter { it.category == budget.categoryId && it.type == "EXPENSE" }
                        .sumOf { it.amount }

                    val progress = if (budget.limitAmount > 0) {
                        (categorySpent / budget.limitAmount).toFloat().coerceIn(0f, 1f)
                    } else 0f

                    val color = parseColor(cat.colorHex)

                    Column(modifier = Modifier.padding(vertical = 4.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = getIconVector(cat.iconName),
                                    contentDescription = cat.name,
                                    tint = color,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = cat.name,
                                    style = MaterialTheme.typography.bodySmall,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                            Text(
                                text = "$currency ${String.format("%.1f", categorySpent)} / ${String.format("%.0f", budget.limitAmount)}",
                                style = MaterialTheme.typography.labelSmall,
                                color = if (categorySpent > budget.limitAmount) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        LinearProgressIndicator(
                            progress = { progress },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(6.dp)
                                .clip(RoundedCornerShape(3.dp)),
                            color = if (categorySpent > budget.limitAmount) MaterialTheme.colorScheme.error else color,
                            trackColor = Color.LightGray.copy(alpha = 0.3f)
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun TransactionDashboardRow(
    transaction: TransactionEntity,
    categoryName: String,
    categoryColor: String,
    categoryIcon: String,
    currency: String,
    onDeleteClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val dateString = remember(transaction.dateMillis) {
        val sdf = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())
        sdf.format(Date(transaction.dateMillis))
    }

    val isExpense = transaction.type == "EXPENSE"
    val colorVector = parseColor(categoryColor)

    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(colorVector.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = getIconVector(categoryIcon),
                    contentDescription = categoryName,
                    tint = colorVector
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = transaction.title,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = if (transaction.merchantName.isNullOrBlank()) dateString else "At: ${transaction.merchantName}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "${if (isExpense) "-" else "+"} $currency ${String.format("%.2f", transaction.amount)}",
                    fontWeight = FontWeight.Bold,
                    color = if (isExpense) Color(0xFFD32F2F) else Color(0xFF388E3C),
                    style = MaterialTheme.typography.bodyMedium
                )
                IconButton(
                    onClick = onDeleteClick,
                    modifier = Modifier.size(24.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "Delete Transaction",
                        tint = MaterialTheme.colorScheme.error.copy(alpha = 0.6f),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickAddTransactionDialog(
    state: FinanceUiState,
    onDismiss: () -> Unit,
    onSave: (title: String, amount: Double, type: String, categoryId: String, merchant: String?) -> Unit
) {
    var title by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var transactionType by remember { mutableStateOf("EXPENSE") }
    var selectedCategory by remember { mutableStateOf("") }
    var merchant by remember { mutableStateOf("") }

    val categoriesFiltered = remember(state.categories, transactionType) {
        state.categories.filter {
            if (transactionType == "INCOME") it.isIncome else !it.isIncome
        }
    }

    LaunchedEffect(transactionType) {
        if (categoriesFiltered.none { it.id == selectedCategory }) {
            selectedCategory = categoriesFiltered.firstOrNull()?.id ?: ""
        }
    }

    var dropdownExpanded by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Log Transaction", fontWeight = FontWeight.Bold) },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Type Switcher
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Button(
                        onClick = { transactionType = "EXPENSE" },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (transactionType == "EXPENSE") MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.surfaceVariant
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Expense", color = if (transactionType == "EXPENSE") Color.White else MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Button(
                        onClick = { transactionType = "INCOME" },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (transactionType == "INCOME") Color(0xFF388E3C) else MaterialTheme.colorScheme.surfaceVariant
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Income", color = if (transactionType == "INCOME") Color.White else MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Title / Description") },
                    modifier = Modifier.fillMaxWidth().testTag("add_title_field")
                )

                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it },
                    label = { Text("Amount (${state.currency})") },
                    modifier = Modifier.fillMaxWidth().testTag("add_amount_field")
                )

                OutlinedTextField(
                    value = merchant,
                    onValueChange = { merchant = it },
                    label = { Text("At Merchant") },
                    modifier = Modifier.fillMaxWidth()
                )

                Text("Category", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                
                val currentSelectedCat = state.categories.find { it.id == selectedCategory }

                Box(
                    modifier = Modifier.fillMaxWidth()
                ) {
                    OutlinedCard(
                        onClick = { dropdownExpanded = true },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp)
                            .testTag("category_dropdown_trigger"),
                        shape = MaterialTheme.shapes.medium
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                if (currentSelectedCat != null) {
                                    Icon(
                                        imageVector = getIconVector(currentSelectedCat.iconName),
                                        contentDescription = null,
                                        tint = parseColor(currentSelectedCat.colorHex),
                                        modifier = Modifier.size(24.dp)
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text(
                                        text = currentSelectedCat.name,
                                        style = MaterialTheme.typography.bodyLarge
                                    )
                                } else {
                                    Text(
                                        text = "Select a category",
                                        style = MaterialTheme.typography.bodyLarge,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                                    )
                                }
                            }
                            Icon(
                                imageVector = if (dropdownExpanded) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown,
                                contentDescription = "Dropdown Indicator"
                            )
                        }
                    }

                    DropdownMenu(
                        expanded = dropdownExpanded,
                        onDismissRequest = { dropdownExpanded = false },
                        modifier = Modifier
                            .fillMaxWidth(0.75f)
                            .testTag("category_dropdown_menu")
                    ) {
                        categoriesFiltered.forEach { cat ->
                            DropdownMenuItem(
                                leadingIcon = {
                                    Icon(
                                        imageVector = getIconVector(cat.iconName),
                                        contentDescription = null,
                                        tint = parseColor(cat.colorHex),
                                        modifier = Modifier.size(20.dp)
                                    )
                                },
                                text = { 
                                    Text(
                                        text = cat.name,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = if (selectedCategory == cat.id) FontWeight.Bold else FontWeight.Normal
                                    ) 
                                },
                                onClick = {
                                    selectedCategory = cat.id
                                    dropdownExpanded = false
                                }
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val parsedAmount = amount.toDoubleOrNull() ?: 0.0
                    if (title.isNotBlank() && parsedAmount > 0) {
                        onSave(title, parsedAmount, transactionType, selectedCategory, merchant.ifBlank { null })
                    }
                },
                modifier = Modifier.testTag("save_transaction_button")
            ) {
                Text("Securely Log")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
