package com.example.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

fun getIconVector(iconName: String): ImageVector {
    return when (iconName) {
        "Restaurant" -> Icons.Default.Fastfood
        "ShoppingBag" -> Icons.Default.ShoppingBag
        "DirectionsCar" -> Icons.Default.DirectionsCar
        "Movie" -> Icons.Default.Movie
        "HomeWork" -> Icons.Default.Home
        "Work" -> Icons.Default.Work
        "TrendingUp" -> Icons.Default.TrendingUp
        "Medical" -> Icons.Default.LocalHospital
        "Education" -> Icons.Default.School
        "Savings" -> Icons.Default.Savings
        else -> Icons.Default.AttachMoney
    }
}

fun parseColor(colorHex: String): Color {
    return try {
        Color(android.graphics.Color.parseColor(colorHex))
    } catch (e: Exception) {
        Color(0xFF1A73E8) // Default elegant blue
    }
}
