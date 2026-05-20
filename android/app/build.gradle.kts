plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ← AJOUT POUR FIREBASE
}

android {
    namespace = "com.rama.shopping"  // ← CHANGÉ pour correspondre à google-services.json
    compileSdk = 34  // ← CHANGÉ (fixe au lieu de flutter.compileSdkVersion)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.rama.shopping"  // ← CHANGÉ pour correspondre à google-services.json
        minSdk = 23  // ← CHANGÉ (Firebase nécessite min 21, on met 23)
        targetSdk = 34  // ← CHANGÉ (fixe)
        versionCode = 1
        versionName = "1.0"
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