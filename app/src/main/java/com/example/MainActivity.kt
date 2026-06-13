package com.example

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.fragment.app.FragmentActivity
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.ui.FinanceViewModel
import com.example.ui.screens.*
import com.example.ui.theme.MyApplicationTheme

enum class TabItem(val route: String) {
    DASHBOARD("dashboard"),
    TRANSACTIONS("transactions"),
    INSIGHTS("insights"),
    SETTINGS("settings")
}

class MainActivity : FragmentActivity() {
    private val viewModel: FinanceViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Request SMS and Notifications permissions on startup safely with a 16-bit request code
        val permissionsToRequest = mutableListOf(
            android.Manifest.permission.RECEIVE_SMS,
            android.Manifest.permission.READ_SMS
        )
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            permissionsToRequest.add(android.Manifest.permission.POST_NOTIFICATIONS)
        }
        androidx.core.app.ActivityCompat.requestPermissions(
            this,
            permissionsToRequest.toTypedArray(),
            101
        )
        
        setContent {
            MyApplicationTheme {
                val state by viewModel.uiState.collectAsStateWithLifecycle()
                var isUnlocked by remember { mutableStateOf(false) }
                var activeTab by remember { mutableStateOf(TabItem.DASHBOARD) }
                var showPrivacyScreen by remember { mutableStateOf(false) }

                // Force lock check on launch if bio setting is true in Room DB
                val needsLock = state.isBiometricEnabled && !isUnlocked

                if (state.isLoading) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.background),
                        contentAlignment = androidx.compose.ui.Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                } else if (needsLock) {
                    BiometricLockScreen(
                        storedPasscode = state.passcode,
                        onSavePasscode = { code -> viewModel.savePasscode(code) },
                        onUnlockSuccess = { isUnlocked = true }
                    )
                } else if (showPrivacyScreen) {
                    PrivacyPolicyScreen(
                        onNavigateBack = { showPrivacyScreen = false }
                    )
                } else {
                    Scaffold(
                        modifier = Modifier.fillMaxSize(),
                        containerColor = MaterialTheme.colorScheme.background,
                        bottomBar = {
                            NavigationBar(
                                modifier = Modifier.testTag("app_bottom_bar")
                            ) {
                                NavigationBarItem(
                                    selected = activeTab == TabItem.DASHBOARD,
                                    onClick = { activeTab = TabItem.DASHBOARD },
                                    icon = { Icon(imageVector = Icons.Default.Dashboard, contentDescription = "Dashboard") },
                                    label = { Text("Dashboard") },
                                    modifier = Modifier.testTag("tab_dashboard")
                                )
                                NavigationBarItem(
                                    selected = activeTab == TabItem.TRANSACTIONS,
                                    onClick = { activeTab = TabItem.TRANSACTIONS },
                                    icon = { Icon(imageVector = Icons.Default.List, contentDescription = "Ledger") },
                                    label = { Text("Ledger") },
                                    modifier = Modifier.testTag("tab_transactions")
                                )
                                NavigationBarItem(
                                    selected = activeTab == TabItem.INSIGHTS,
                                    onClick = { activeTab = TabItem.INSIGHTS },
                                    icon = { Icon(imageVector = Icons.Default.TrendingUp, contentDescription = "Insights") },
                                    label = { Text("Insights") },
                                    modifier = Modifier.testTag("tab_insights")
                                )
                                NavigationBarItem(
                                    selected = activeTab == TabItem.SETTINGS,
                                    onClick = { activeTab = TabItem.SETTINGS },
                                    icon = { Icon(imageVector = Icons.Default.Settings, contentDescription = "Settings") },
                                    label = { Text("Settings") },
                                    modifier = Modifier.testTag("tab_settings")
                                )
                            }
                        }
                    ) { innerPadding ->
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(innerPadding)
                        ) {
                            when (activeTab) {
                                TabItem.DASHBOARD -> {
                                    DashboardScreen(
                                        state = state,
                                        viewModel = viewModel,
                                        onNavigateToTransactions = { activeTab = TabItem.TRANSACTIONS }
                                    )
                                }
                                TabItem.TRANSACTIONS -> {
                                    TransactionsScreen(
                                        state = state,
                                        viewModel = viewModel
                                    )
                                }
                                TabItem.INSIGHTS -> {
                                    InsightsScreen(
                                        state = state,
                                        viewModel = viewModel
                                    )
                                }
                                TabItem.SETTINGS -> {
                                    SettingsScreen(
                                        state = state,
                                        viewModel = viewModel,
                                        onNavigateToPrivacy = { showPrivacyScreen = true }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
