package com.example.ui.screens

import android.os.Build
import android.widget.Toast
import androidx.biometric.BiometricPrompt
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentActivity
import java.util.concurrent.Executors

@Composable
fun BiometricLockScreen(
    storedPasscode: String?,
    onSavePasscode: (String) -> Unit,
    onUnlockSuccess: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var passcodeEntered by remember { mutableStateOf("") }
    var firstEnteredPasscode by remember { mutableStateOf("") }
    var isConfirmingStage by remember { mutableStateOf(false) }

    val hasPinSet = !storedPasscode.isNullOrEmpty()

    // Initiate native BioPrompt if possible (Unlock flow only)
    LaunchedEffect(storedPasscode) {
        if (!storedPasscode.isNullOrEmpty()) {
            try {
                val activity = context as? FragmentActivity
                if (activity != null) {
                    val executor = Executors.newSingleThreadExecutor()
                    val biometricPrompt = BiometricPrompt(
                        activity,
                        executor,
                        object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                                super.onAuthenticationSucceeded(result)
                                activity.runOnUiThread {
                                    onUnlockSuccess()
                                }
                            }

                            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                super.onAuthenticationError(errorCode, errString)
                                // Fall back silently to PIN code entry
                            }
                        }
                    )

                    val promptInfo = BiometricPrompt.PromptInfo.Builder()
                        .setTitle("Secure Ledger Authentication")
                        .setSubtitle("Confirm dynamic state authentication to unlock")
                        .setNegativeButtonText("Use Passcode PIN")
                        .build()

                    biometricPrompt.authenticate(promptInfo)
                }
            } catch (e: Throwable) {
                // Biometrics hardware unavailable fallback to PIN code
            }
        }
    }

    fun handleDigitClick(digit: String) {
        if (passcodeEntered.length < 4) {
            passcodeEntered += digit
            if (passcodeEntered.length == 4) {
                if (!hasPinSet) {
                    // SETUP FLOW
                    if (!isConfirmingStage) {
                        // Stage 1: Input PIN
                        firstEnteredPasscode = passcodeEntered
                        passcodeEntered = ""
                        isConfirmingStage = true
                        Toast.makeText(context, "Please confirm your 4-digit PIN", Toast.LENGTH_SHORT).show()
                    } else {
                        // Stage 2: Confirm PIN
                        if (passcodeEntered == firstEnteredPasscode) {
                            onSavePasscode(passcodeEntered)
                            Toast.makeText(context, "Passcode configured successfully!", Toast.LENGTH_SHORT).show()
                            onUnlockSuccess()
                        } else {
                            Toast.makeText(context, "PINs do NOT match. Try again!", Toast.LENGTH_SHORT).show()
                            passcodeEntered = ""
                            firstEnteredPasscode = ""
                            isConfirmingStage = false
                        }
                    }
                } else {
                    // UNLOCK FLOW
                    if (passcodeEntered == storedPasscode) {
                        onUnlockSuccess()
                    } else {
                        Toast.makeText(context, "Incorrect PIN!", Toast.LENGTH_SHORT).show()
                        passcodeEntered = ""
                    }
                }
            }
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF0F2027),
                        Color(0xFF203A43),
                        Color(0xFF2C5364)
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
        ) {
            Icon(
                imageVector = if (!hasPinSet) Icons.Default.LockOpen else Icons.Default.Lock,
                contentDescription = "App Security State",
                tint = if (!hasPinSet) Color(0xFF81C784) else Color(0xFF64B5F6),
                modifier = Modifier
                    .size(64.dp)
                    .padding(bottom = 12.dp)
            )

            val majorTitle = if (!hasPinSet) {
                if (!isConfirmingStage) "CREATE PASSCODE PIN" else "CONFIRM PASSCODE"
            } else {
                "LOCKED LEDGER"
            }

            val subtitle = if (!hasPinSet) {
                if (!isConfirmingStage) "Set a 4-digit security PIN to restrict local access" else "Confirm your new key to save security setup"
            } else {
                "Enter dynamic passcode PIN to unlock details"
            }

            Text(
                text = majorTitle,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                letterSpacing = 2.sp
            )
            Text(
                text = subtitle,
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.padding(bottom = 32.dp, start = 16.dp, end = 16.dp)
            )

            // Circular Passcode placeholders
            Row(
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.padding(bottom = 40.dp)
            ) {
                (1..4).forEach { index ->
                    val isFilled = passcodeEntered.length >= index
                    Box(
                        modifier = Modifier
                            .size(16.dp)
                            .clip(CircleShape)
                            .background(
                                if (isFilled) Color(0xFF64B5F6) else Color.White.copy(alpha = 0.2f)
                            )
                    )
                }
            }

            // Interactive Passcode entry keyboard
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.width(260.dp)
            ) {
                val buttonRows = listOf(
                    listOf("1", "2", "3"),
                    listOf("4", "5", "6"),
                    listOf("7", "8", "9")
                )

                buttonRows.forEach { row ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        row.forEach { digit ->
                            PasscodeButton(
                                digit = digit,
                                onClick = { handleDigitClick(digit) },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }

                // Row for Clear, 0, and Bio Bypass
                Row(
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    // Clear Key
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(56.dp)
                            .clip(RoundedCornerShape(28.dp))
                            .clickable { passcodeEntered = "" },
                        contentAlignment = Alignment.Center
                    ) {
                        Text("CLR", color = Color.White.copy(alpha = 0.8f), fontWeight = FontWeight.Bold)
                    }

                    // Digit 0
                    PasscodeButton(
                        digit = "0",
                        onClick = { handleDigitClick("0") },
                        modifier = Modifier.weight(1f)
                    )

                    // Fingerprint or lock layout spacer/bypass (Unlock mode only)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(56.dp)
                            .clip(RoundedCornerShape(28.dp))
                            .background(if (hasPinSet) Color(0xFF1976D2) else Color.White.copy(alpha = 0.05f))
                            .clickable(enabled = hasPinSet) {
                                if (hasPinSet) {
                                    onUnlockSuccess()
                                }
                            }
                            .testTag("bio_unlock_bypass_btn"),
                        contentAlignment = Alignment.Center
                    ) {
                        if (hasPinSet) {
                            Icon(
                                imageVector = Icons.Default.Fingerprint,
                                contentDescription = "Simulated Bypass",
                                tint = Color.White
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Default.Lock,
                                contentDescription = "Active Setup",
                                tint = Color.White.copy(alpha = 0.3f)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun PasscodeButton(
    digit: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .height(56.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(Color.White.copy(alpha = 0.1f))
            .clickable { onClick() }
            .testTag("passcode_btn_$digit"),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = digit,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp
        )
    }
}
