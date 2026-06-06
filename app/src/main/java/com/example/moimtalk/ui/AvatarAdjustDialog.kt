package com.example.moimtalk.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.net.Uri
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private const val AVATAR_CROP_OUT_PX = 512

/** 프로필 사진 선택 후 확대·이동으로 맞추는 조절 창 (내 정보 아바타용) */
@Composable
fun AvatarAdjustDialog(
    sourceUri: Uri,
    onDismiss: () -> Unit,
    onConfirm: (ByteArray, String) -> Unit,
) {
    val context = LocalContext.current
    val sourceBitmap = remember(sourceUri) {
        runCatching {
            context.contentResolver.openInputStream(sourceUri)?.use { BitmapFactory.decodeStream(it) }
        }.getOrNull()
    }

    val bitmap = sourceBitmap
    if (bitmap == null) {
        LaunchedEffect(Unit) { onDismiss() }
        return
    }

    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }
    var cropSizePx by remember { mutableIntStateOf(0) }

    val transformState = rememberTransformableState { zoomChange, panChange, _ ->
        scale = (scale * zoomChange).coerceIn(1f, 4f)
        offsetX += panChange.x
        offsetY += panChange.y
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(modifier = Modifier.fillMaxSize(), color = Color(0xE6000000)) {
            Column(
                modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("사진 조절", color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Text(
                    "사진을 확대·이동해 원하는 영역을 맞춘 뒤 확인하세요.",
                    color = Color(0xCCFFFFFF),
                    fontSize = 12.5.sp,
                    modifier = Modifier.padding(top = 8.dp),
                )
                Spacer(Modifier.height(20.dp))
                Box(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.88f)
                            .aspectRatio(1f)
                            .onSizeChanged { cropSizePx = it.width }
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color.Black)
                            .transformable(state = transformState),
                    ) {
                        if (cropSizePx > 0) {
                            Canvas(modifier = Modifier.fillMaxSize()) {
                                val bmpW = bitmap.width.toFloat()
                                val bmpH = bitmap.height.toFloat()
                                val baseScale = max(cropSizePx / bmpW, cropSizePx / bmpH)
                                val totalScale = baseScale * scale
                                val scaledW = bmpW * totalScale
                                val scaledH = bmpH * totalScale
                                val left = cropSizePx / 2f - scaledW / 2f + offsetX
                                val top = cropSizePx / 2f - scaledH / 2f + offsetY
                                drawImage(
                                    image = bitmap.asImageBitmap(),
                                    dstOffset = IntOffset(left.roundToInt(), top.roundToInt()),
                                    dstSize = IntSize(
                                        scaledW.roundToInt().coerceAtLeast(1),
                                        scaledH.roundToInt().coerceAtLeast(1),
                                    ),
                                )
                            }
                        }
                    }
                }
                Spacer(Modifier.height(20.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    TextButton(onClick = onDismiss) { Text("취소", color = Color.White, fontSize = 15.sp) }
                    Button(
                        onClick = {
                            if (cropSizePx <= 0) return@Button
                            val cropped = exportAvatarCrop(bitmap, cropSizePx, scale, offsetX, offsetY)
                            val bytes = ByteArrayOutputStream().use { out ->
                                cropped.compress(Bitmap.CompressFormat.JPEG, 90, out)
                                if (cropped != bitmap) cropped.recycle()
                                out.toByteArray()
                            }
                            onConfirm(bytes, "avatar.jpg")
                        },
                        enabled = cropSizePx > 0,
                        colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Text("확인", fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

private fun buildAvatarCropMatrix(
    source: Bitmap,
    cropSizePx: Int,
    userScale: Float,
    offsetX: Float,
    offsetY: Float,
): Matrix {
    val bmpW = source.width.toFloat()
    val bmpH = source.height.toFloat()
    val baseScale = max(cropSizePx / bmpW, cropSizePx / bmpH)
    val totalScale = baseScale * userScale
    val scaledW = bmpW * totalScale
    val scaledH = bmpH * totalScale
    val left = cropSizePx / 2f - scaledW / 2f + offsetX
    val top = cropSizePx / 2f - scaledH / 2f + offsetY
    return Matrix().apply {
        postScale(totalScale, totalScale)
        postTranslate(left, top)
    }
}

private fun exportAvatarCrop(
    source: Bitmap,
    cropSizePx: Int,
    userScale: Float,
    offsetX: Float,
    offsetY: Float,
): Bitmap {
    val outSize = min(AVATAR_CROP_OUT_PX, cropSizePx)
    val result = Bitmap.createBitmap(outSize, outSize, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(result)
    val matrix = buildAvatarCropMatrix(source, cropSizePx, userScale, offsetX, offsetY)
    val outMatrix = Matrix(matrix).apply {
        postScale(outSize.toFloat() / cropSizePx, outSize.toFloat() / cropSizePx)
    }
    canvas.drawBitmap(source, outMatrix, Paint(Paint.FILTER_BITMAP_FLAG))
    return result
}
