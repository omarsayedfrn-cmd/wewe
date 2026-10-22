plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.solver.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.solver.client"
        minSdk = 26
        targetSdk = 34
        versionCode = 10
        versionName = "1.7.0"
    }

    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = "solverpassword2024"
            keyAlias = "solverkey"
            keyPassword = "solverpassword2024"
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
