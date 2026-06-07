// ===== app 레벨 build.gradle.kts =====
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

val localProperties = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) load(FileInputStream(f))
}

val keystoreProperties = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "com.example.moimtalk"
    compileSdk = 36

    defaultConfig {
        applicationId = "kr.ac.ajou.psytalk"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        // local.properties: onesignal.app.id=... (docs/PUBLISH_ANDROID.md)
        buildConfigField(
            "String",
            "ONESIGNAL_APP_ID",
            "\"${localProperties.getProperty("onesignal.app.id", "").replace("\"", "\\\"")}\"",
        )
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfigs.findByName("release")?.let { signingConfig = it }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    // --- Compose BOM (UI 버전 일괄 관리) ---
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")

    // --- Lifecycle / ViewModel ---
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    // --- Supabase (BOM) ---
    implementation(platform("io.github.jan-tennert.supabase:bom:3.3.0"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")

    // --- Ktor (Realtime WebSocket — Android 엔진은 WS 미지원, OkHttp 사용) ---
    implementation("io.ktor:ktor-client-okhttp:3.0.3")

    // --- 직렬화 ---
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // --- 이미지 로딩 (채팅 사진 첨부 표시) ---
    implementation("io.coil-kt:coil-compose:2.7.0")

    // --- 푸시 알림 (OneSignal) ---
    implementation("com.onesignal:OneSignal:5.1.6")
}

// FCM 연동: app/google-services.json 이 있을 때만 플러그인 적용
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
