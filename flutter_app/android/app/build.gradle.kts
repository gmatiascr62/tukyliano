plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.gmatiascr62.tukyliano"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Durante la migración lleva el sufijo ".flutter" para que esta app y
        // la versión Kivy (org.gmatiascr62.tukyliano) puedan convivir en el
        // mismo celular y se puedan comparar. Al terminar la fase 5 se saca.
        applicationId = "org.gmatiascr62.tukyliano.flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // La firma de verdad. Android solo deja actualizar una app si el APK nuevo
    // está firmado con la misma clave que el instalado, así que sin esto cada
    // build sería una app distinta y habría que desinstalar para actualizar.
    //
    // El archivo de la firma NUNCA va en el repo, que es público: lo arma el
    // workflow a partir de un secreto de GitHub. Cuando no está (compilando
    // en una máquina cualquiera) se sigue firmando con la de debug, así
    // `flutter build` funciona igual.
    val archivoFirma = file("tukyliano.jks")
    val claveFirma = System.getenv("TUKYLIANO_KEYSTORE_PASSWORD")
    val hayFirmaPropia = archivoFirma.exists() && !claveFirma.isNullOrEmpty()

    if (hayFirmaPropia) {
        signingConfigs {
            create("tukyliano") {
                storeFile = archivoFirma
                storePassword = claveFirma
                keyAlias = "tukyliano"
                keyPassword = claveFirma
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayFirmaPropia) {
                signingConfigs.getByName("tukyliano")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
