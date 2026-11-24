# 校园口袋 · caii_pocket

一个 Android 端校园门户助手。三件事拼起来：

- **技术栈与 UI 语言**：照 `Kazumi-技术拆解与批量复刻工作流.md`——Flutter + MobX + flutter_modular + Hive CE + dio + Material 3（动态取色、色调表面卡片、单一外壳五 Tab）。
- **功能形态**：照 [ZZUPocket](https://github.com/3beuml/ZZUPocket)——首页时间轴 / 课表 / 专注番茄钟 / 校园卡与电费 / 图书馆 / 更多与设置。
- **登录**：直接对接学校门户 `https://portal.caii.edu.cn` 背后的金智统一身份认证（`authservernew.caii.edu.cn`），在 App 内完成登录并**把会话 Cookie 拿到本机**，后续所有请求都带着它。

> 非官方项目。接口以公开网页协议为准，学校调整后可能失效；App 只做只读，不做缴费、转账、抢座。

---

## 一、当前状态

| 模块 | 状态 | 说明 |
|---|---|---|
| 统一认证登录（学号+密码） | ✅ 已实现并**对真实服务器验证过协议** | 抓登录页 → 取 `salt`/`execution` → AES-CBC 加密密码 → POST → 跟随票据回门户 |
| 会话持久化与静默续期 | ✅ | Cookie 落磁盘（`PersistCookieJar`），`CASTGC` 在就能无感换票 |
| 验证码（图片） | ✅ | 服务端要求时自动拉 `/authserver/getCaptcha.htl` 并给输入框 |
| 网页登录兜底 + Cookie 回灌 | ✅ | 短信验证/设备绑定这类人工步骤，在 WebView 里登完点「同步 Cookie」把会话收回 dio |
| Cookie 管理页 | ✅ | 列出两条域的 Cookie（打码显示），可复制、可清空 |
| 首页时间轴 / 课程高亮 | ✅ | 本地课表驱动 |
| 课表（周切换、增删改、开学周设置） | ✅ | 数据存本机 Hive |
| 专注番茄钟 + 统计 + 7 日柱状 | ✅ | 靠时间戳推算，杀进程可恢复 |
| 外观（三态主题/纯黑/动态取色/种子色/配色方案/字号） | ✅ | Material 3 |
| 门户 / 图书馆内嵌页 | ✅（需填地址） | `services/portal/portal_endpoints.dart` 里 `libraryUrl` 留空则给出明确提示 |
| 网页登录自动接管会话 | ✅ 真机验证 | 落在校内页面自动抓 Cookie → 写本机 → 向服务端核实；冷启动还有自愈 |
| 真实姓名 / 院系 / 学号 | ✅ 真机验证 | 门户 `/jsonp/userInfo.json` |
| 头像与姓名（个人信息页） | ✅ 真机验证 | 更多 → 点头像 → 抓 `.personal_img img` 的 base64 头像（压缩到 160px）+ 姓名 |
| 扫一扫（扫码签到） | ✅ 真机验证 | 扫到校内链接 → 带会话的 WebView 直接打开 |
| 课表导入 | ✅ 抓取式 | 网页里点进「我的课表」，App 截页面自己的 XHR，不依赖写死接口 |
| 校园卡余额、电费余额 | ⚠️ **接口待校准** | 门户业务接口要在登录后抓一次包，见第四节 |
| 桌面小组件、前台服务通知 | ❌ 未做（下一版） | |

`flutter analyze` 零 issue、`flutter test` 8 个用例全过、真实服务器协议验证通过（见 `docs/统一认证协议实测.md`）。

---

## 二、跑起来

### 1. 环境
Flutter stable（本项目用 3.50.0 / Dart 3.14 验证）+ Android SDK（minSdk 24）。

本工作区把 Flutter SDK 装在 `.tools/flutter`（与工程同级的上层目录，不影响项目本身）：

```bash
export PATH="$PWD/../.tools/flutter/bin:$PATH"
export PUB_CACHE="$PWD/../.tools/pub-cache"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### 2. 常用命令

```bash
flutter pub get
flutter analyze                  # 应为 No issues found
flutter test                     # 8 passed
flutter run -d <device>
flutter build apk --release      # 产物在 build/app/outputs/flutter-apk/
```

一键环境脚本（本工作区已验证可用）：

```bash
source scripts/dev_env.sh        # 导出 flutter/android/java/镜像，并清掉系统代理
flutter build apk --release
```

**已经构建好的安装包**：`dist/caii_pocket-0.2.1-release.apk`（71.9 MB，release 签名用的是模板自带的 debug key，仅供自用安装；上架前换成自己的签名）。

```bash
adb install -r dist/caii_pocket-0.2.1-release.apk
```

> 本项目**不依赖代码生成**：MobX 用的是运行时 API（`Observable`/`ObservableList`/`runInAction`），Hive 存 JSON 字符串。所以不需要 `build_runner`，clone 下来 `flutter run` 就能跑。想换成 `@observable` + `@HiveType` 的写法，见 `docs/架构与移植说明.md`。

### 3. 文档

| 文件 | 内容 |
|---|---|
| `docs/统一认证协议实测.md` | 登录页字段、密码加密、请求体、响应分支、拿 Cookie 的四步、还没验证的部分 |
| `docs/门户接口与会话.md` | 真机实测：Cookie 组成、domain 带协议导致丢会话的坑、门户 JSONP 接口、课表为什么必须抓 XHR |
| `docs/架构与移植说明.md` | 分层、为什么不用 codegen、DI 形态、加页面的标准动作、已踩过的坑 |
| `tool/cas_probe.dart` | 命令行探针：对真实服务器验证加密与登录请求格式 |

### 3. 真机自检顺序
1. 冷启动 → 看到骨架/空态，不白屏
2. 更多 → 登录（学号密码）→ 成功返回后「更多」顶部出现账号、Cookie 计数 > 0
3. 杀进程重开 → 仍是登录态（说明 Cookie 落盘了）
4. Cookie 管理 → 能看到 `CASTGC`、`JSESSIONID`
5. 课表 → 加一门课 → 切周往返 → 杀进程重开仍在
6. 专注 → 开 15 分钟 → 退到后台 2 分钟 → 回来倒计时对得上
7. 深色 / 纯黑 / 跟随系统 三种模式各看一遍

---

## 三、统一认证是怎么拿到 Cookie 的

四步，全部在 `services/cas/` 里：

1. **GET 登录页** `…/authserver/login?service=<门户首页>`，从 HTML 里取 `pwdEncryptSalt`、`execution`、`lt`，并让 cookie jar 收下 `JSESSIONID`。
2. **算密码**：`AES-128-CBC( key=salt, iv=16位随机, 明文=64位随机前缀+密码 ) → base64`，随机字符表与页面 `encrypt.js` 完全一致。
3. **POST 表单**：`username / password / captcha / _eventId=submit / cllt=userNameLogin / dllt=generalLogin / lt / execution / rmShown=1`。
4. **跟随票据**：302 → `…?ticket=ST-xxx` → 门户，逐跳手动跟随（`followRedirects: false`），每一跳的 `Set-Cookie` 都进 jar。到手的就是能直接访问门户的会话。

失败路径也接了：401/200 带错误提示时读页面里 `showErrorTip` 的原文（服务端自己写的中文，比我们编的好）；`needCaptcha=true` 时拉验证码图；命中短信/绑定类页面时引导走网页登录。

**实测证据**：拿错误密码打真实服务器，返回 `401 + 该账号非常用账号或用户名密码有误`，说明请求体与加密格式都被服务端接受（若格式不对会是参数错误或解密失败）。复现命令：

```bash
dart run tool/cas_probe.dart 你的学号
```

---

## 四、把「接口待校准」变成真数据

校园卡、电费、教务课表这些数据在门户的**业务接口**上，路径与字段必须登录后实测一次才能对上。App 里已经内置了工作台：

1. 登录后进 **更多 → 接口调试台**
2. 填一个以 `/` 开头的路径（例如 `/ywtb-portal/standard/index.html?browser=no` 先确认会话可用），点发送
3. 把返回（JSON 或 HTML）贴出来 → 在 `lib/services/portal/portal_endpoints.dart` 里填上真实路径
4. 在 `lib/services/portal/portal_api.dart` 上加一个方法，`repositories/` 里加一个解析，页面换成 `StatePresentation` 的 data 态即可

调试台自带会话续期：被 302 到 authserver 时它会先静默换票再重试，不会让你在「登录过期」上卡住。

---

## 五、目录结构

```
lib/
├── main.dart / app.dart / app_module.dart   # 入口、MaterialApp、路由表
├── core/
│   ├── graph.dart            # 组合根：所有服务在这里显式装配
│   ├── theme/                # 主题 Store + 配色方案枚举
│   ├── network/              # dio 工厂、错误文案映射、Cookie 仓储
│   ├── storage/              # Hive 箱子与偏好键
│   └── strings.dart          # 全部中文文案
├── models/                   # 纯数据（course / focus / auth），不含 UI
├── repositories/             # 只碰 models + 箱子
├── services/
│   ├── cas/                  # 统一认证：加密、页面解析、登录流程
│   ├── portal/               # 门户地址表与带会话的访问层
│   └── schedule/             # 教学周换算
├── ui/                       # 横切 UI 零件（卡片/列表行/四态/弹层/骨架/图片）
├── features/                 # 每个功能一个目录：page + controller + route
└── utils/                    # 日期、id 等纯函数
```

依赖方向：`features → repositories → services/core → models/utils`，`ui/` 只能被 features 用。

---

## 六、隐私边界

- 不保存密码：只在内存里用一次，落盘的只有 Cookie 与会话摘要。
- 不经过任何自建服务器：账号与数据只在手机和学校系统之间流动。
- 不做写操作：不缴费、不转账、不抢座。
- 无统计、无崩溃上报、无广告。
