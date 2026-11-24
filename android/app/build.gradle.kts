import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名：从 android/key.properties 读取（本地）或环境变量读取（CI 由 workflow 注入）。
// key.properties 与 keystore 文件均不入库。
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
fun keystoreProp(name: String, envVar: String): String? =
    System.getenv(envVar) ?: keystoreProperties.getProperty(name)

android {
    namespace = "com.caii.caii_pocket"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.caii.pocket"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProp("storeFile", "KEYSTORE_FILE")
            val storePassword = keystoreProp("storePassword", "KEYSTORE_PASSWORD")
            val keyAlias = keystoreProp("keyAlias", "KEY_ALIAS")
            val keyPassword = keystoreProp("keyPassword", "KEY_PASSWORD")
            if (storeFilePath != null && storePassword != null) {
                storeFile = file(storeFilePath)
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            // 有正式签名配置时用正式签名，否则回退 debug 签名（本地无密钥也能跑 release）
            if (keystoreProp("storeFile", "KEYSTORE_FILE") != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        optIn.add("androidx.camera.camera2.interop.ExperimentalCamera2Interop")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 微信开源扫码引擎（WeChatCV/WeChatQRCode，jenly1314 封装的 Maven 构件）：
    //   opencv        -> org.opencv.* Java 类，含 org.opencv.wechat_qrcode.WeChatQRCode
    //   opencv-armv64 -> arm64-v8a 的 libopencv_java4.so（内含 wechat 检测 native 代码）
    //   opencv-armv7a -> armeabi-v7a 同上
    //   opencv-x86_64 -> x86_64 模拟器用
    // 注意 1：官方 org.opencv:opencv 构件不含 wechat_qrcode 模块，不能替代。
    // 注意 2：ABI 构件名是 opencv-armv64 / opencv-armv7a（带 v），
    //         作者 README 里写的 opencv-arm64 是笔误，Maven Central 上不存在。
    implementation("com.github.jenly1314.WeChatQRCode:opencv:2.6.0")
    implementation("com.github.jenly1314.WeChatQRCode:opencv-armv64:2.6.0")
    implementation("com.github.jenly1314.WeChatQRCode:opencv-armv7a:2.6.0")
    implementation("com.github.jenly1314.WeChatQRCode:opencv-x86_64:2.6.0")
    //
    // wechat_qrcode 的 4 个模型文件放在 src/main/assets/opencv_wechat/：
    //   detect.prototxt / detect.caffemodel / sr.prototxt / sr.caffemodel
    // 官方来源（opencv_contrib wechat_qrcode 模块的 CMakeLists 指定地址，
    // 带官方 MD5：detect.caffemodel=238e2b2d6f3c18d6c3a30de0c31e23cf、
    // sr.caffemodel=cbfcd60361a73beb8c583eea7e8e6664）：
    //   https://raw.githubusercontent.com/WeChatCV/opencv_3rdparty/a8b69ccc738421293254aec5ddb38bd523503252/<文件名>
    // 若文件缺失，引擎 init 会失败并回传 error 给 Flutter，回退 MLKit，不会崩溃。

    // CameraX：原生扫码预览 + YUV 帧分析（物理长焦直切需要 1.4+）
    // 注意：Camera2Interop / ExperimentalCamera2Interop 等 interop 类都在
    // camera-camera2 里（1.4.x 起不再有独立的 camera-camera2-interop 构件）
    val camerax = "1.4.2"
    implementation("androidx.camera:camera-core:$camerax")
    implementation("androidx.camera:camera-camera2:$camerax")
    implementation("androidx.camera:camera-lifecycle:$camerax")
    implementation("androidx.camera:camera-view:$camerax")

    // coreLibraryDesugaring 依赖（Java 8+ desugaring 需要）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
