plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // ADD THIS
}

android {
    compileSdk = 34

    defaultConfig {
        applicationId = "com.loveucifer.black"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
}
