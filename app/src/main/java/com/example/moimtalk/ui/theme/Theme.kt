package com.example.moimtalk.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.example.moimtalk.ui.MoimTheme

@Composable
fun PsyTalkTheme(
    darkTheme: Boolean = MoimTheme.dark,
    content: @Composable () -> Unit
) {
    val p = MoimTheme.palette
    val colorScheme = if (darkTheme) {
        darkColorScheme(
            primary = p.accent,
            onPrimary = Color.White,
            secondary = p.secondary,
            onSecondary = Color.White,
            background = p.bg,
            onBackground = p.ink,
            surface = p.paper,
            onSurface = p.ink,
            surfaceVariant = p.surface,
            onSurfaceVariant = p.sub,
            outline = p.line,
            error = p.admin,
            onError = Color.White,
        )
    } else {
        lightColorScheme(
            primary = p.accent,
            onPrimary = Color.White,
            secondary = p.secondary,
            onSecondary = Color.White,
            background = p.bg,
            onBackground = p.ink,
            surface = p.paper,
            onSurface = p.ink,
            surfaceVariant = p.surface,
            onSurfaceVariant = p.sub,
            outline = p.line,
            error = p.admin,
            onError = Color.White,
        )
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
