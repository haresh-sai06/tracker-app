package com.example.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.FinanceUiState
import com.example.ui.FinanceViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    state: FinanceUiState,
    viewModel: FinanceViewModel,
    onNavigateToPrivacy: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var showBudgetDialog by remember { mutableStateOf(false) }
    var selectedCategoryIdForBudget by remember { mutableStateOf("") }
    var budgetLimitStr by remember { mutableStateOf("") }

    var showGoogleChooser by remember { mutableStateOf(false) }
    var isSyncingGoogleState by remember { mutableStateOf(false) }

    var showCustomEmailOption by remember { mutableStateOf(false) }
    var customGoogleEmailInput by remember { mutableStateOf("") }
    var customGoogleNameInput by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings & Device Security", fontWeight = FontWeight.Bold) },
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
            // Section 0: Google Account Login & Live Cloud Connection
            item {
                if (state.googleEmail == null) {
                    Card(
                        modifier = Modifier.fillMaxWidth().testTag("google_login_promo_card"),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f))
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(40.dp)
                                        .clip(CircleShape)
                                        .background(Color.White),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = "G",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 20.sp,
                                        color = Color(0xFF4285F4)
                                    )
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Google Account Sync",
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                    Text(
                                        text = "Connect to secure on-cloud Sync backups",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = "By connecting your Google Account, your device transactions and budget templates will automatically back up inside secure live cloud sync.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f)
                            )
                            Spacer(modifier = Modifier.height(14.dp))
                            Button(
                                onClick = { showGoogleChooser = true },
                                modifier = Modifier.fillMaxWidth().testTag("google_login_action_btn"),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.primary
                                )
                            ) {
                                Icon(Icons.Default.AccountCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Sign in with Google")
                            }
                        }
                    }
                } else {
                    Card(
                        modifier = Modifier.fillMaxWidth().testTag("google_profile_connected_card"),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(44.dp)
                                            .clip(CircleShape)
                                            .background(MaterialTheme.colorScheme.primaryContainer),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = state.googlePhoto ?: state.googleName?.take(1) ?: "G",
                                            fontWeight = FontWeight.Bold,
                                            style = MaterialTheme.typography.titleMedium,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = state.googleName ?: "Google User",
                                                style = MaterialTheme.typography.bodyMedium,
                                                fontWeight = FontWeight.Bold,
                                                color = MaterialTheme.colorScheme.onSurface
                                            )
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Icon(
                                                imageVector = Icons.Default.CheckCircle,
                                                contentDescription = "Verified connected",
                                                tint = Color(0xFF4CAF50),
                                                modifier = Modifier.size(16.dp)
                                            )
                                        }
                                        Text(
                                            text = state.googleEmail ?: "",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }

                                TextButton(
                                    onClick = { viewModel.signOutFromGoogle() },
                                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                                ) {
                                    Icon(Icons.Default.ExitToApp, contentDescription = null, modifier = Modifier.size(14.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Disconnect", fontSize = 11.sp)
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                            Spacer(modifier = Modifier.height(12.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = "Cloud Sync Connection",
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = "Automatically synchronizes ledger updates.",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Switch(
                                    checked = state.isGoogleSynced,
                                    onCheckedChange = { viewModel.setGoogleSyncEnabled(it) },
                                    modifier = Modifier.testTag("google_autosync_switch")
                                )
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            Button(
                                onClick = {
                                    isSyncingGoogleState = true
                                    viewModel.syncGoogleData(
                                        onSuccess = {
                                            isSyncingGoogleState = false
                                            Toast.makeText(context, "Cloud sync complete!", Toast.LENGTH_SHORT).show()
                                        },
                                        onError = { error ->
                                            isSyncingGoogleState = false
                                            Toast.makeText(context, "Sync failed: $error", Toast.LENGTH_LONG).show()
                                        }
                                    )
                                },
                                enabled = !isSyncingGoogleState,
                                modifier = Modifier.fillMaxWidth().testTag("sync_google_now_btn"),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.secondaryContainer,
                                    contentColor = MaterialTheme.colorScheme.onSecondaryContainer
                                )
                            ) {
                                if (isSyncingGoogleState) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(18.dp),
                                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                                        strokeWidth = 2.dp
                                    )
                                } else {
                                    Icon(Icons.Default.Sync, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Sync Now to Cloud Account")
                                }
                            }
                        }
                    }
                }
            }

            // Section 1: Security Toggles
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Secured Local Bounds",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        // Biometrics Lock Setting
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Biometric Passcode Lock",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Require fingerprint check on startup.",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Switch(
                                checked = state.isBiometricEnabled,
                                onCheckedChange = { viewModel.setBiometricEnabled(it) },
                                modifier = Modifier.testTag("biometric_lock_switch")
                            )
                        }
                    }
                }
            }

            // Section 2: Regional/Functional Params
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Functional Customization",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        // Currency code options
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = "Local Currency Denomination",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Active currency symbol across screens.",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            
                            val currencies = listOf("USD", "EUR", "GBP", "INR", "JPY")
                            var expanded by remember { mutableStateOf(false) }
                            Box {
                                Button(
                                    onClick = { expanded = true },
                                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondaryContainer, contentColor = MaterialTheme.colorScheme.onSecondaryContainer),
                                    modifier = Modifier.testTag("currency_picker_btn")
                                ) {
                                    Text(state.currency)
                                }
                                DropdownMenu(
                                    expanded = expanded,
                                    onDismissRequest = { expanded = false }
                                ) {
                                    currencies.forEach { code ->
                                        DropdownMenuItem(
                                            text = { Text(code) },
                                            onClick = {
                                                viewModel.setCurrency(code)
                                                expanded = false
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Section 2.5: Firebase Cloud Backup & Restore
            item {
                var backupKey by remember { mutableStateOf("sharesh-backup") }
                var isOperating by remember { mutableStateOf(false) }

                Card(
                    modifier = Modifier.fillMaxWidth().testTag("firebase_backup_card"),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Cloud Backup & Sync",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Securely backup/sync or restore your financial transactions and category budgets with Firebase.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        OutlinedTextField(
                            value = backupKey,
                            onValueChange = { backupKey = it.trim() },
                            label = { Text("Backup / Sync Identifier Key") },
                            placeholder = { Text("Enter a unique string") },
                            singleLine = true,
                            enabled = !isOperating,
                            modifier = Modifier.fillMaxWidth().testTag("backup_key_input"),
                            leadingIcon = {
                                Icon(Icons.Default.Cloud, contentDescription = null)
                            }
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Button(
                                onClick = {
                                    if (backupKey.isBlank()) {
                                        Toast.makeText(context, "Please enter a valid backup key", Toast.LENGTH_SHORT).show()
                                        return@Button
                                    }
                                    isOperating = true
                                    viewModel.backupToCloud(
                                        backupKey = backupKey,
                                        onSuccess = {
                                            isOperating = false
                                            Toast.makeText(context, "Successfully backed up data!", Toast.LENGTH_LONG).show()
                                        },
                                        onError = { err ->
                                            isOperating = false
                                            Toast.makeText(context, "Error: $err", Toast.LENGTH_LONG).show()
                                        }
                                    )
                                },
                                enabled = !isOperating,
                                modifier = Modifier.weight(1f).testTag("backup_to_cloud_btn"),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.primary
                                )
                            ) {
                                if (isOperating) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(20.dp),
                                        color = MaterialTheme.colorScheme.onPrimary,
                                        strokeWidth = 2.dp
                                    )
                                } else {
                                    Icon(Icons.Default.CloudUpload, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Backup")
                                }
                            }

                            ElevatedButton(
                                onClick = {
                                    if (backupKey.isBlank()) {
                                        Toast.makeText(context, "Please enter a valid backup key", Toast.LENGTH_SHORT).show()
                                        return@ElevatedButton
                                    }
                                    isOperating = true
                                    viewModel.restoreFromCloud(
                                        backupKey = backupKey,
                                        onSuccess = {
                                            isOperating = false
                                            Toast.makeText(context, "Successfully restored backup data!", Toast.LENGTH_LONG).show()
                                        },
                                        onError = { err ->
                                            isOperating = false
                                            Toast.makeText(context, "Error: $err", Toast.LENGTH_LONG).show()
                                        }
                                    )
                                },
                                enabled = !isOperating,
                                modifier = Modifier.weight(1f).testTag("restore_from_cloud_btn")
                            ) {
                                if (isOperating) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(20.dp),
                                        color = MaterialTheme.colorScheme.primary,
                                        strokeWidth = 2.dp
                                    )
                                } else {
                                    Icon(Icons.Default.CloudDownload, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Restore")
                                }
                            }
                        }
                    }
                }
            }

            // Section 3: Budget Setups
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Category Budget Allowances",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(8.dp))

                        state.categories.filter { !it.isIncome }.forEach { category ->
                            val currentBudget = state.budgets.find { it.categoryId == category.id }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 6.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = category.name,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                                Button(
                                    onClick = {
                                        selectedCategoryIdForBudget = category.id
                                        budgetLimitStr = currentBudget?.limitAmount?.toString() ?: ""
                                        showBudgetDialog = true
                                    },
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                                        contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                                    ),
                                    modifier = Modifier.testTag("set_budget_chip_${category.id}")
                                ) {
                                    Text(
                                        text = if (currentBudget != null) {
                                            "${state.currency} ${currentBudget.limitAmount}"
                                        } else "None set"
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Section 4: Secure Simulator Taps and Privacy Info
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Privacy & Advanced Testing",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        // Privacy info and security configuration guidelines
                        Spacer(modifier = Modifier.height(4.dp))

                        // Privacy Button linking securely
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onNavigateToPrivacy() }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.PrivacyTip,
                                    contentDescription = "Privacy Policy",
                                    tint = MaterialTheme.colorScheme.outline
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Privacy Promise Policy",
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = "Read our secure on-device Privacy Promise.",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            Icon(imageVector = Icons.Default.ChevronRight, contentDescription = "Open Privacy Policy", tint = MaterialTheme.colorScheme.outline)
                        }
                    }
                }
            }
        }
    }

    if (showBudgetDialog) {
        val activeCategoryName = state.categories.find { it.id == selectedCategoryIdForBudget }?.name ?: ""
        AlertDialog(
            onDismissRequest = { showBudgetDialog = false },
            title = { Text("Configure Budget for $activeCategoryName", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) },
            text = {
                OutlinedTextField(
                    value = budgetLimitStr,
                    onValueChange = { budgetLimitStr = it },
                    placeholder = { Text("Enter weekly limit limit e.g. 500") },
                    label = { Text("Allowance Limit (${state.currency})") },
                    modifier = Modifier.fillMaxWidth().testTag("budget_input_field")
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        val limitVal = budgetLimitStr.toDoubleOrNull() ?: 0.0
                        if (limitVal > 0) {
                            viewModel.updateBudget(selectedCategoryIdForBudget, limitVal)
                        } else {
                            viewModel.deleteBudget(selectedCategoryIdForBudget)
                        }
                        showBudgetDialog = false
                    },
                    modifier = Modifier.testTag("save_budget_dialog_btn")
                ) {
                    Text("Save Budget")
                }
            },
            dismissButton = {
                TextButton(onClick = { showBudgetDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (showGoogleChooser) {
        AlertDialog(
            onDismissRequest = { 
                showGoogleChooser = false 
                showCustomEmailOption = false
            },
            title = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFEEEEEE)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "G",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp,
                            color = Color(0xFF4285F4)
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Sign in with Google",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = "to continue to Tracker applet",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                }
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                    if (!showCustomEmailOption) {
                        Surface(
                            onClick = {
                                viewModel.signInWithGoogle(
                                    email = "Shareshsainaath@gmail.com",
                                    name = "Sharesh Sainaath",
                                    photoUrl = "S"
                                ) {
                                    showGoogleChooser = false
                                    Toast.makeText(context, "Connected to Sharesh Sainaath's Google Profile!", Toast.LENGTH_LONG).show()
                                }
                            },
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.fillMaxWidth().testTag("primary_google_choice")
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFF1E88E5)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("S", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text("Sharesh Sainaath", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
                                    Text("Shareshsainaath@gmail.com", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }

                        Surface(
                            onClick = { showCustomEmailOption = true },
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.fillMaxWidth().testTag("custom_google_choice")
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.secondaryContainer),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSecondaryContainer)
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Text("Use another Google account", fontWeight = FontWeight.Medium, style = MaterialTheme.typography.bodyMedium)
                            }
                        }
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                text = "Enter Google Account Details",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                            
                            OutlinedTextField(
                                value = customGoogleNameInput,
                                onValueChange = { customGoogleNameInput = it },
                                label = { Text("Google Display Name") },
                                placeholder = { Text("e.g. John Doe") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("custom_google_name_field")
                            )

                            OutlinedTextField(
                                value = customGoogleEmailInput,
                                onValueChange = { customGoogleEmailInput = it.trim() },
                                label = { Text("Google Email Address") },
                                placeholder = { Text("e.g. john.doe@gmail.com") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("custom_google_email_field")
                            )

                            Spacer(modifier = Modifier.height(6.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                TextButton(
                                    onClick = { showCustomEmailOption = false },
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text("Back")
                                }

                                Button(
                                    onClick = {
                                        if (customGoogleEmailInput.isBlank() || customGoogleNameInput.isBlank()) {
                                            Toast.makeText(context, "Please enter all fields", Toast.LENGTH_SHORT).show()
                                            return@Button
                                        }
                                        viewModel.signInWithGoogle(
                                            email = customGoogleEmailInput,
                                            name = customGoogleNameInput,
                                            photoUrl = customGoogleNameInput.take(1).uppercase()
                                        ) {
                                            showGoogleChooser = false
                                            showCustomEmailOption = false
                                            Toast.makeText(context, "Connected to $customGoogleNameInput's Google account!", Toast.LENGTH_LONG).show()
                                        }
                                    },
                                    modifier = Modifier.weight(1.2f).testTag("custom_google_connect_btn")
                                ) {
                                    Text("Connect")
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "To continue, Google will share your name, email address, and profile picture with Tracker. Please review our privacy promise policy above.",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center
                    )
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(
                    onClick = {
                        showGoogleChooser = false
                        showCustomEmailOption = false
                    }
                ) {
                    Text("Cancel")
                }
            }
        )
    }
}
