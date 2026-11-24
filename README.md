<div align="center">

# CAIIPocket

<img src="assets/images/logo.jpg" alt="CAIIPocket" width="200"/>

**为长春汽车职业技术大学学生打造的第三方校园口袋 App**

[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9-0175C2?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![Release](https://img.shields.io/github/v/release/hmaoraze/CAIIPocket?style=flat&color=blue)](https://github.com/hmaoraze/CAIIPocket/releases/latest)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat)](LICENSE)

[![下载最新版本](https://img.shields.io/badge/⬇%20下载最新版本-Releases-2ea44f?style=for-the-badge)](https://github.com/hmaoraze/CAIIPocket/releases/latest)

使用 Flutter 开发的校园综合工具程序。基于学校统一身份认证（CAS）实现免重复登录，支持**课表查看**、**二维码扫码**（微信开源扫码引擎 + OPPO 长焦镜头远距扫码）与**一卡通浴池使用码**查询。绝赞挖坑中 ～(∠・ω< )⌒☆

</div>

## 支持平台

- Android 10 及以上（[Releases 下载 APK](https://github.com/hmaoraze/CAIIPocket/releases/latest)）
- iOS 13 及以上（需要 [侧载自签](https://github.com/hmaoraze/CAIIPocket/releases/latest)，下载 `no_sign.ipa` 后使用 AltStore / Sideloadly 等工具安装）

## 功能特性

- **统一认证登录**：CAS 协议加密登录（AES + RSA + DES，与校方前端一致），一次登录长期有效
- **课程表**：学期课表展示、当前周定位、课程详情编辑、自定义颜色
- **扫码引擎**：内置微信开源扫码模型（OpenCV DNN，远距离小码增强识别），支持 OPPO 设备长焦镜头变焦对焦远处二维码
- **一卡通使用码**：浴室水控使用码一键领取（接口协议与加密方式已还原，AES-CBC）
- **专注模式**：课程时段自动进入专注，学习时长统计
- **深色模式**：跟随系统 / 手动切换

## 屏幕截图

<!-- TODO: 在此处放置应用截图
| 课表 | 扫码 | 一卡通 |
| --- | --- | --- |
| ![](docs/screenshots/schedule.png) | ![](docs/screenshots/scan.png) | ![](docs/screenshots/ykt.png) |
-->

## 下载安装

前往 [Releases](https://github.com/hmaoraze/CAIIPocket/releases/latest) 页面下载对应平台的安装包：

| 文件 | 说明 |
| --- | --- |
| `CAIIPocket_android_x.y.z.apk` | Android 安装包，直接安装 |
| `CAIIPocket_ios_x.y.z_no_sign.ipa` | iOS 未签名包，需自签后安装 |

> 发布 Release 时 GitHub Actions 会自动构建并附上安装包，无需手动打包。

## 开发构建

```bash
git clone https://github.com/hmaoraze/CAIIPocket.git
cd CAIIPocket
flutter pub get
flutter run
```

## 免责声明

- 本项目为**第三方**校园工具，与长春汽车职业技术大学官方无关
- 仅调用了学校向学生开放的网络接口，用于本人数据的便捷查询，不采集、不上传任何他人数据
- 请勿将本项目用于任何违反校规或法律法规的用途

## 许可

本项目基于 [GPL-3.0](LICENSE) 协议开源。
