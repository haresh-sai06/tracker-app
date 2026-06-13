package com.example.ui.screens

import android.app.DatePickerDialog
import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.animation.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.TransactionEntity
import com.example.ui.FinanceUiState
import com.example.ui.FinanceViewModel
import com.example.ui.getIconVector
import com.example.ui.parseColor
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

enum class AnalysisPeriod {
    WEEKLY, MONTHLY, YEARLY, CUSTOM
}

data class BarItem(
    val label: String,
    val value: Float
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InsightsScreen(
    state: FinanceUiState,
    viewModel: FinanceViewModel,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var selectedPeriod by remember { mutableStateOf(AnalysisPeriod.WEEKLY) }
    
    // Custom date range bounds
    val calendar = Calendar.getInstance()
    var customStartDate by remember { mutableStateOf<Long?>(null) }
    var customEndDate by remember { mutableStateOf<Long?>(null) }

    val now = System.currentTimeMillis()
    val dayMillis = 86400000L

    // Unified dynamic filtering logic for expenses
    val filteredExpenses = remember(state.transactions, selectedPeriod, customStartDate, customEndDate) {
        val expensesOnly = state.transactions.filter { it.type == "EXPENSE" }
        when (selectedPeriod) {
            AnalysisPeriod.WEEKLY -> {
                val start = now - 7 * dayMillis
                expensesOnly.filter { it.dateMillis >= start }
            }
            AnalysisPeriod.MONTHLY -> {
                val start = now - 30 * dayMillis
                expensesOnly.filter { it.dateMillis >= start }
            }
            AnalysisPeriod.YEARLY -> {
                val start = now - 365 * dayMillis
                expensesOnly.filter { it.dateMillis >= start }
            }
            AnalysisPeriod.CUSTOM -> {
                expensesOnly.filter {
                    val matchesStart = customStartDate == null || it.dateMillis >= customStartDate!!
                    val matchesEnd = customEndDate == null || it.dateMillis <= (customEndDate!! + dayMillis)
                    matchesStart && matchesEnd
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Financial Insights", fontWeight = FontWeight.Bold) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
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
            // Section: Filter chips selector
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        AnalysisPeriod.values().forEach { period ->
                            FilterChip(
                                selected = selectedPeriod == period,
                                onClick = { selectedPeriod = period },
                                label = {
                                    Text(
                                        text = when (period) {
                                            AnalysisPeriod.WEEKLY -> "Weekly"
                                            AnalysisPeriod.MONTHLY -> "Monthly"
                                            AnalysisPeriod.YEARLY -> "Yearly"
                                            AnalysisPeriod.CUSTOM -> "Custom Range"
                                        }
                                    )
                                },
                                modifier = Modifier.testTag("period_chip_${period.name.lowercase()}")
                            )
                        }
                    }

                    // Render Custom Date Pickers if CUSTOM selected
                    AnimatedVisibility(
                        visible = selectedPeriod == AnalysisPeriod.CUSTOM,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically()
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val formatDay = SimpleDateFormat("dd MMM yyyy", Locale.getDefault())

                            // Start Date selector button
                            OutlinedCard(
                                onClick = {
                                    val cal = Calendar.getInstance().apply {
                                        customStartDate?.let { timeInMillis = it }
                                    }
                                    DatePickerDialog(
                                        context,
                                        { _, y, m, d ->
                                            val c = Calendar.getInstance()
                                            c.set(y, m, d, 0, 0, 0)
                                            customStartDate = c.timeInMillis
                                        },
                                        cal.get(Calendar.YEAR),
                                        cal.get(Calendar.MONTH),
                                        cal.get(Calendar.DAY_OF_MONTH)
                                    ).show()
                                },
                                modifier = Modifier.weight(1f).testTag("custom_start_date_btn")
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Text("Start Date", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = customStartDate?.let { formatDay.format(Date(it)) } ?: "Select Date",
                                        fontWeight = FontWeight.Bold,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                }
                            }

                            // End Date selector button
                            OutlinedCard(
                                onClick = {
                                    val cal = Calendar.getInstance().apply {
                                        customEndDate?.let { timeInMillis = it }
                                    }
                                    DatePickerDialog(
                                        context,
                                        { _, y, m, d ->
                                            val c = Calendar.getInstance()
                                            c.set(y, m, d, 23, 59, 59)
                                            customEndDate = c.timeInMillis
                                        },
                                        cal.get(Calendar.YEAR),
                                        cal.get(Calendar.MONTH),
                                        cal.get(Calendar.DAY_OF_MONTH)
                                    ).show()
                                },
                                modifier = Modifier.weight(1f).testTag("custom_end_date_btn")
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Text("End Date", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = customEndDate?.let { formatDay.format(Date(it)) } ?: "Select Date",
                                        fontWeight = FontWeight.Bold,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                }
                            }
                        }
                    }
                }
            }

            if (filteredExpenses.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(300.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.PieChart,
                                contentDescription = "Empty Charts",
                                modifier = Modifier.size(56.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = "No expenses recorded in this period",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            } else {
                // Category Spending Card containing unique Custom Canvas Pie Chart
                item {
                    CategoryPieChartCard(expenses = filteredExpenses, state = state)
                }

                // Daily/Interval Expenses Bar Graph Card displaying actual values
                item {
                    DailyExpensesBarGraphCard(
                        expenses = filteredExpenses,
                        state = state,
                        period = selectedPeriod,
                        customStart = customStartDate,
                        customEnd = customEndDate
                    )
                }

                // Top Merchant Leaderboard Card
                item {
                    TopMerchantsCard(expenses = filteredExpenses, currency = state.currency)
                }
            }
        }
    }
}

@Composable
fun CategoryPieChartCard(
    expenses: List<TransactionEntity>,
    state: FinanceUiState,
    modifier: Modifier = Modifier
) {
    val totalExpense = expenses.sumOf { it.amount }

    // Map categories with non-zero spends
    val spendingByCategory = remember(expenses, state.categories) {
        val groups = expenses.groupBy { it.category }
        groups.mapNotNull { (catId, txs) ->
            val cat = state.categories.find { it.id == catId } ?: return@mapNotNull null
            val sum = txs.sumOf { it.amount }
            val percentage = if (totalExpense > 0) (sum / totalExpense * 100).toFloat() else 0f
            Triple(cat, sum, percentage)
        }.sortedByDescending { it.second }
    }

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Distribution in Period",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Render custom Canvas arc segments
                Box(
                    modifier = Modifier
                        .size(130.dp)
                        .padding(8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        var startAngle = -90f
                        spendingByCategory.forEach { (cat, _, percentage) ->
                            val sweepAngle = (percentage / 100f) * 360f
                            drawArc(
                                color = parseColor(cat.colorHex),
                                startAngle = startAngle,
                                sweepAngle = sweepAngle,
                                useCenter = false,
                                style = Stroke(width = 24f),
                                size = Size(size.width, size.height)
                            )
                            startAngle += sweepAngle
                        }
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "TOTAL",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "${state.currency} ${String.format("%.0f", totalExpense)}",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                Spacer(modifier = Modifier.width(16.dp))

                // Breakdown list next to the Pie
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    spendingByCategory.take(4).forEach { (cat, sum, percent) ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(parseColor(cat.colorHex))
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = cat.name,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1,
                                    modifier = Modifier.widthIn(max = 70.dp)
                                )
                            }
                            Text(
                                text = "${String.format("%.1f", percent)}%",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun DailyExpensesBarGraphCard(
    expenses: List<TransactionEntity>,
    state: FinanceUiState,
    period: AnalysisPeriod,
    customStart: Long?,
    customEnd: Long?,
    modifier: Modifier = Modifier
) {
    val dayMillis = 86400000L
    val now = System.currentTimeMillis()

    // Determine bar segments dynamically with smart scaling depending on period scope
    val barItems = remember(expenses, period, customStart, customEnd) {
        val sdfDay = SimpleDateFormat("EEE", Locale.getDefault())
        val sdfMonth = SimpleDateFormat("MMM", Locale.getDefault())

        when (period) {
            AnalysisPeriod.WEEKLY -> {
                val days = (0..6).map { now - it * dayMillis }.reversed()
                days.map { d ->
                    val dayStart = d - (d % dayMillis)
                    val dayEnd = dayStart + dayMillis
                    val sum = expenses.filter { it.dateMillis in dayStart until dayEnd }.sumOf { it.amount }
                    BarItem(sdfDay.format(Date(d)), sum.toFloat())
                }
            }
            AnalysisPeriod.MONTHLY -> {
                // Map the last 30 days into 5 sequential bar ranges
                val buckets = listOf(
                    "Days 1-6" to (now - 30 * dayMillis until now - 24 * dayMillis),
                    "Days 7-12" to (now - 24 * dayMillis until now - 18 * dayMillis),
                    "Days 13-18" to (now - 18 * dayMillis until now - 12 * dayMillis),
                    "Days 19-24" to (now - 12 * dayMillis until now - 6 * dayMillis),
                    "Days 25-30" to (now - 6 * dayMillis..now)
                )
                buckets.map { (label, range) ->
                    val sum = expenses.filter { it.dateMillis in range }.sumOf { it.amount }
                    BarItem(label, sum.toFloat())
                }
            }
            AnalysisPeriod.YEARLY -> {
                // Past 12 Monthly buckets
                val cal = Calendar.getInstance()
                val monthlyPoints = (0..11).map { offset ->
                    val c = Calendar.getInstance().apply {
                        add(Calendar.MONTH, -offset)
                    }
                    c
                }.reversed()

                monthlyPoints.map { c ->
                    val yr = c.get(Calendar.YEAR)
                    val mnt = c.get(Calendar.MONTH)
                    val sum = expenses.filter {
                        val txCal = Calendar.getInstance().apply { timeInMillis = it.dateMillis }
                        txCal.get(Calendar.YEAR) == yr && txCal.get(Calendar.MONTH) == mnt
                    }.sumOf { it.amount }
                    val label = sdfMonth.format(c.time)
                    BarItem(label, sum.toFloat())
                }
            }
            AnalysisPeriod.CUSTOM -> {
                val start = customStart ?: (now - 7 * dayMillis)
                val end = customEnd ?: now
                val diff = end - start
                if (diff <= 10 * dayMillis) {
                    val numDays = (diff / dayMillis).toInt().coerceAtLeast(1)
                    val days = (0..numDays).map { start + it * dayMillis }
                    val formatBrief = SimpleDateFormat("dd MMM", Locale.getDefault())
                    days.map { d ->
                        val dayStart = d - (d % dayMillis)
                        val dayEnd = dayStart + dayMillis
                        val sum = expenses.filter { it.dateMillis in dayStart until dayEnd }.sumOf { it.amount }
                        BarItem(formatBrief.format(Date(d)), sum.toFloat())
                    }
                } else if (diff <= 60 * dayMillis) {
                    val numWeeks = (diff / (7 * dayMillis)).toInt().coerceAtLeast(1)
                    (0 until numWeeks).map { w ->
                        val bStart = start + w * 7 * dayMillis
                        val bEnd = bStart + 7 * dayMillis
                        val sum = expenses.filter { it.dateMillis in bStart until bEnd }.sumOf { it.amount }
                        BarItem("Wk ${w + 1}", sum.toFloat())
                    }
                } else {
                    val grouped = expenses.groupBy {
                        val c = Calendar.getInstance().apply { timeInMillis = it.dateMillis }
                        c.get(Calendar.YEAR) to c.get(Calendar.MONTH)
                    }
                    grouped.map { (key, txs) ->
                        val c = Calendar.getInstance().apply {
                            set(Calendar.YEAR, key.first)
                            set(Calendar.MONTH, key.second)
                        }
                        val label = SimpleDateFormat("MMM yy", Locale.getDefault()).format(c.time)
                        val sum = txs.sumOf { it.amount }
                        BarItem(label, sum.toFloat())
                    }.sortedBy { it.label }
                }
            }
        }
    }

    val maxVal = barItems.maxOf { it.value }.coerceAtLeast(10f)

    // Dynamic coloring based on M3 palette
    val barColor = MaterialTheme.colorScheme.primary
    val labelColorHex = MaterialTheme.colorScheme.onSurfaceVariant.toArgb()
    val valueColorHex = MaterialTheme.colorScheme.onSurface.toArgb()

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Expense Analysis",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            Text(
                text = "Real-time bar allocations centering exact transaction totals.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Custom Canvas holding Bar Charts and exactly drawn values above
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .testTag("expense_bar_canvas")
            ) {
                val canvasWidth = size.width
                val canvasHeight = size.height
                
                // Boundaries inside the canvas
                val labelAreaHeight = 45f // Bottom label margin (pixels)
                val valueAreaHeight = 45f // Top value label margin (pixels)
                val drawingHeight = canvasHeight - (labelAreaHeight + valueAreaHeight)
                
                val itemsCount = barItems.size
                if (itemsCount > 0) {
                    val totalSpacers = itemsCount + 1
                    val spacerWidth = 24f
                    val barWidth = (canvasWidth - (totalSpacers * spacerWidth)) / itemsCount

                    // Base horizontal axis grid line
                    val baselineY = canvasHeight - labelAreaHeight
                    drawLine(
                        color = Color.LightGray.copy(alpha = 0.4f),
                        start = Offset(0f, baselineY),
                        end = Offset(canvasWidth, baselineY),
                        strokeWidth = 3f
                    )

                    // Set up dynamic native Paints for texts inside DrawScope
                    val labelPaint = Paint().apply {
                        color = labelColorHex
                        textSize = 28f
                        textAlign = Paint.Align.CENTER
                        typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
                    }

                    val valuePaint = Paint().apply {
                        color = valueColorHex
                        textSize = 26f
                        textAlign = Paint.Align.CENTER
                        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                    }

                    barItems.forEachIndexed { idx, bar ->
                        val spacerOffset = (idx + 1) * spacerWidth
                        val x = spacerOffset + idx * barWidth
                        val barHeight = (bar.value / maxVal) * drawingHeight
                        val topY = baselineY - barHeight

                        // 1. Draw Rounded Bar
                        drawRoundRect(
                            color = if (bar.value > 0) barColor else barColor.copy(alpha = 0.2f),
                            topLeft = Offset(x, topY),
                            size = Size(barWidth, barHeight.coerceAtLeast(4f)),
                            cornerRadius = CornerRadius(8f, 8f)
                        )

                        // 2. Draw amount spent exactly on top of the bar
                        val currencyPrefix = state.currency
                        val cleanAmt = if (bar.value == bar.value.toInt().toFloat()) {
                            String.format("%.0f", bar.value)
                        } else {
                            String.format("%.1f", bar.value)
                        }
                        
                        drawContext.canvas.nativeCanvas.drawText(
                            "$currencyPrefix$cleanAmt",
                            x + barWidth / 2f,
                            topY - 14f,
                            valuePaint
                        )

                        // 3. Draw Axis Label underneath the bar
                        drawContext.canvas.nativeCanvas.drawText(
                            bar.label,
                            x + barWidth / 2f,
                            baselineY + 34f,
                            labelPaint
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun TopMerchantsCard(
    expenses: List<TransactionEntity>,
    currency: String,
    modifier: Modifier = Modifier
) {
    val topMerchants = remember(expenses) {
        expenses
            .filter { !it.merchantName.isNullOrBlank() }
            .groupBy { it.merchantName!!.trim() }
            .map { (merchant, txs) ->
                merchant to txs.sumOf { it.amount }
            }
            .sortedByDescending { it.second }
            .take(3)
    }

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Frequent Merchants Leaderboard",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 12.dp)
            )

            if (topMerchants.isEmpty()) {
                Text(
                    text = "No merchants listed in this period.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            } else {
                topMerchants.forEachIndexed { index, (merchant, sum) ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(24.dp)
                                    .clip(CircleShape)
                                    .background(
                                        when (index) {
                                            0 -> Color(0xFFFFD700) // Gold
                                            1 -> Color(0xFFC0C0C0) // Silver
                                            else -> Color(0xFFCD7F32) // Bronze
                                        }
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = (index + 1).toString(),
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.Black
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = merchant,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold
                            )
                        }

                        Text(
                            text = "$currency ${String.format("%.2f", sum)}",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        }
    }
}
