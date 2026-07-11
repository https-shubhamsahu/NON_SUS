import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.nosus.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.nosus.app"
        minSdk = flutter.minSdkVersion  // flutter_secure_storage requires API 23+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = Properties()
            if (keystorePropertiesFile.exists()) {
                keystorePropertiesFile.inputStream().use { stream ->
                    keystoreProperties.load(stream)
                }
                // A present-but-blank key.properties (e.g. checked out fresh,
                // template never filled in) must be treated the same as a
                // missing file. Properties.getProperty("storeFile") on a line
                // like "storeFile=" returns "" (empty string), which is not
                // null — file("") resolves to the project directory itself,
                // a non-null File that would otherwise slip past the
                // `storeFile != null` check below and get selected as a
                // broken "release" signing config instead of falling back
                // to debug signing.
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                if (!storeFilePath.isNullOrBlank()) {
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    storeFile = file(storeFilePath)
                    storePassword = keystoreProperties.getProperty("storePassword")
                }
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.findByName("release")
            if (releaseConfig != null && releaseConfig.storeFile != null && releaseConfig.storeFile!!.exists()) {
                signingConfig = releaseConfig
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            // Enable R8 minification and resource shrinking with custom rules
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Required for pdfrx native PDF renderer — AGP 8+ equivalent of extractNativeLibs="true"
            packaging {
                jniLibs {
                    useLegacyPackaging = true
                }
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

dependencies {
    // Modern Android 12+ SplashScreen API, backported to minSdk via the
    // compat shim so pre-12 devices get equivalent behavior through the
    // same windowSplashScreen* theme attributes (see styles.xml).
    implementation("androidx.core:core-splashscreen:1.0.1")
}
