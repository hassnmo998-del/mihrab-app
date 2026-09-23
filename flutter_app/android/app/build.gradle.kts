import java.util.Properties
import java.io.FileInputStream

// مفاتيح التوقيع من android/key.properties، وهو خارج git.
//
// الملف غائب على أجهزة أخرى وفي CI (حيث تُمرَّر القيم كمتغيّرات بيئة بدلاً منه)،
// فغيابه ليس خطأ — يسقط البناء عندها إلى توقيع debug، وهو المطلوب للتجربة
// المحلية وغير صالح للنشر.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.masjed.mihrab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        
        applicationId = "com.masjed.mihrab"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    ndkVersion = "29.0.14206865"

    signingConfigs {
        create("release") {
            // متغيّرات البيئة أولاً (مسار CI)، ثم key.properties (المسار المحلي).
            keyAlias      = System.getenv("KEY_ALIAS")      ?: keystoreProperties.getProperty("keyAlias")
            keyPassword   = System.getenv("KEY_PASSWORD")   ?: keystoreProperties.getProperty("keyPassword")
            storePassword = System.getenv("STORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
            val storePath = System.getenv("KEYSTORE_PATH")  ?: keystoreProperties.getProperty("storeFile")
            if (storePath != null) storeFile = file(storePath)
        }
    }

    buildTypes {
        release {
            // مفتاح الإصدار متى توفّر، وإلا debug.
            //
            // أندرويد يرفض أي تحديث موقّع بمفتاح غير مفتاح النسخة المثبّتة. فنشر
            // APK موقّع بمفتاح debug يجعل أول تحديث مستحيلاً على كل من ثبّته، ولا
            // علاج له سوى الحذف وفقدان البيانات. لذلك تُتحقَّق النسخة المنشورة
            // بفحص توقيعها فعلاً، لا بمجرّد نجاح بنائها.
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
