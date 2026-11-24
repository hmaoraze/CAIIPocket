plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // 微信开源扫码引擎：OpenCV 官方 AAR（4.9+），含 wechat_qrcode 模块和
    // Java API org.opencv.wechat_qrcode.WeChatQRCode。仓库兜底见根 build.gradle.kts
    // 的 allprojects.repositories（aliyun -> google -> mavenCentral）。
    implementation("org.opencv:opencv:4.11.0")
    //
    // wechat_qrcode 的 4 个模型文件放在 src/main/assets/opencv_wechat/：
    //   detect.prototxt / detect.caffemodel / sr.prototxt / sr.caffemodel
    // 官方来源（opencv_contrib wechat_qrcode 模块的 CMakeLists 指定地址，
    // 带官方 MD5：detect.caffemodel=238e2b2d6f3c18d6c3a30de0c31e23cf、
    // sr.caffemodel=cbfcd60361a73beb8c583eea7e8e6664）：
    //   https://raw.githubusercontent.com/WeChatCV/opencv_3rdparty/a8b69ccc738421293254aec5ddb38bd523503252/<文件名>
    // 若文件缺失，引擎 init 会失败并回传 error 给 Flutter，回退 MLKit，不会崩溃。

    // CameraX：原生扫码预览 + YUV 帧分析（物理长焦直切需要 1.4+）
    val camerax = "1.4.2"
    implementation("androidx.camera:camera-core:$camerax")
    implementation("androidx.camera:camera-camera2:$camerax")
    implementation("androidx.camera:camera-camera2-interop:$camerax")
    implementation("androidx.camera:camera-lifecycle:$camerax")
    implementation("androidx.camera:camera-view:$camerax")

    // coreLibraryDesugaring 依赖（Java 8+ desugaring 需要）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
