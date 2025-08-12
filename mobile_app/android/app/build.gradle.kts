plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    ndkVersion = "27.0.12077973"
    namespace = "com.example.gym_app_system"

    compileSdk = 35 // ✅ 明确写出 compileSdk

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.gym_app_system"
        minSdk = 23
        targetSdk = 35 // ✅ 明确写出 targetSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // ✅ Firebase BoM（统一版本控制）
    implementation(platform("com.google.firebase:firebase-bom:32.7.3"))

    // ✅ Firebase Messaging（通知功能）
    implementation("com.google.firebase:firebase-messaging")

    // ✅ Firebase Installations（FCM 依赖组件）
    implementation("com.google.firebase:firebase-installations")
}
