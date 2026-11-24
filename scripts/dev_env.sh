#!/usr/bin/env bash
# 本工作区已经把 Flutter / Android SDK 装在项目外层的 .tools/ 下，
# source 这个脚本就能直接用（Windows Git Bash 亲测）。
#
#   source scripts/dev_env.sh
#   flutter analyze && flutter test
#   flutter build apk --release

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$(cd "$ROOT/../.tools" && pwd)"

export PATH="$TOOLS/flutter/bin:$PATH"
export PUB_CACHE="$TOOLS/pub-cache"
export GRADLE_USER_HOME="$TOOLS/gradle-home"

export ANDROID_SDK_ROOT="$TOOLS/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export JAVA_HOME="${JAVA_HOME:-C:/Program Files/Java/latest/jdk-26}"

# 国内镜像：pub / Flutter 引擎产物 / Gradle 依赖都在工程里配好了镜像地址
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# flutter_tester 与 gradle 的本地连接不能走系统代理
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy

echo "flutter : $(command -v flutter)"
echo "android : $ANDROID_SDK_ROOT"
echo "java    : $JAVA_HOME"
