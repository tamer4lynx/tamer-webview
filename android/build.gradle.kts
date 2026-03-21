plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.kapt")
}

android {
    namespace = "com.nanofuxion.tamerwebview"
    compileSdk = 35

    defaultConfig {
        minSdk = 28
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
    compileOnly("org.lynxsdk.lynx:lynx:3.3.1")
    compileOnly("org.lynxsdk.lynx:lynx-jssdk:3.3.1")
    kapt("org.lynxsdk.lynx:lynx-processor:3.3.1")
    implementation("androidx.core:core-ktx:1.10.1")
    implementation("androidx.webkit:webkit:1.8.0")
}
