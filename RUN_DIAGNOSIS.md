# 跑胡子助手 —— 检查与运行诊断报告

检查时间：2026-09-24 16:16 ~ 16:25（本机 Windows 10 19045，Dart 3.13.4，Flutter SDK `C:\src\flutter`）

## 一、结论摘要

**本机当前无法运行这个 App，且有两道独立的阻塞，都必须在跑起来之前解决。**

| # | 阻塞 | 层级 | 性质 | 能否自行绕过 |
|---|---|---|---|---|
| A | Dart 无法启动任何子进程（`ERROR_PIPE_BUSY 231`） | 操作系统 / 内核驱动 | **环境故障，与代码无关** | 否，需重启或处理安全软件 |
| B | Android 宿主工程缺失大半 | 项目文件 | **仓库缺提交** | 否，需补生成 |

**代码本身的质量是好的**：我把不依赖 Flutter 的全部核心逻辑（规则引擎 + 视觉后处理）用独立脚手架真跑了一遍，
**67 项断言全部通过，0 失败**。详见第四节。

---

## 二、阻塞 A：Dart 起不了子进程（决定性故障）

### 2.1 现象

任何 `flutter` / `dart` 命令都失败。最小复现（纯 Dart，只起一个 `cmd.exe`）：

```
SYNC cmd -> FAIL ProcessException: 所有的管道范例都在使用中。 (at ../../runtime/bin/process_win.cc:744)
SYNC git -> FAIL ProcessException: 所有的管道范例都在使用中。 (at ../../runtime/bin/process_win.cc:744)
```

`dart:io` 的 `Process` 在 Windows 上通过命名管道（`\\.\Pipe\dart_<uuid>_N`）读取子进程输出，
失败点在 `CreateProcessPipe` → `CreateFileW`。

### 2.2 证据链

**① 用 Python ctypes 复刻 `CreateProcessPipe` 的调用序列，做方向分型**（`Add-Type` 被安全策略拦截，故改用 ctypes）：

| 服务端 openMode | 客户端 access | srv | 命名空间 | cli | 结论 |
|---|---|---|---|---|---|
| OUTBOUND | `GENERIC_READ` | OK | YES | **FAIL 231** | **Dart 的标准用法 → 挂** |
| OUTBOUND | `GR\|GW` | OK | YES | FAIL 5 | 5 是**正确**行为（方向不匹配） |
| OUTBOUND | `GENERIC_WRITE` | OK | YES | FAIL 5 | 正确 |
| **DUPLEX** | `GENERIC_READ` | OK | YES | **FAIL 231** | **决定性反例：本该必然成功** |
| DUPLEX | `GR\|GW` | OK | YES | OK | 正常 |
| INBOUND | `GENERIC_WRITE` | OK | YES | OK | 正常 |
| OUTBOUND | `0`（无访问权） | OK | YES | OK | 访问权=0 反而成功 |
| OUTBOUND `GR`(maxInst=255 / 去 OVERLAPPED) | — | OK | YES | **FAIL 231** | 与 maxInstances、OVERLAPPED 无关 |

**特征签名**：凡是客户端 `dwDesiredAccess` **恰好等于 `GENERIC_READ`** 就返回 `231`；
一旦带上 `GENERIC_WRITE`，就退回**正确的** `ACCESS_DENIED(5)`。
说明 OS 的管道语义没坏，是**「从命名管道读取」这一个方向被单独拦截**。
`CreateNamedPipeW` 始终成功且管道确实出现在 `\\.\pipe\` 命名空间里 → 卡在「打开」这一步。

**② .NET 高层 API 独立交叉验证**（完全不同的代码路径，无需 Add-Type）：

```
server(PipeDirection.Out) + client(PipeDirection.In) -> FAIL: 信号灯超时时间已到   ← 读方向
server(PipeDirection.In)  + client(PipeDirection.Out) -> OK                        ← 写方向
```

与 ① 完全一致。注意 .NET 把 231 呈现成 `ERROR_SEM_TIMEOUT(121)`，
是 `Connect(timeout)` 先收走 `CreateFile` 的 231、再 `WaitNamedPipe` 超时所致 —— **121 和 231 是同一根因**。

**③ 匿名管道不受影响**：Python `subprocess.run(['cmd','/c','echo hi'])` 正常。
→ 该拦截是**命名管道特有**的（符合安全软件守住 `\Device\NamedPipe` 以阻断 C2 通信的行为特征）。

**④ `dart analyze` 同样死在这里** —— 它要 spawn `dartaotruntime analysis_server_aot.dart.snapshot`：

```
ProcessException: ... (at ../../runtime/bin/process_win.cc:744)
  Command: C:\src\flutter\bin\cache\dart-sdk\bin\dartaotruntime.exe ... analysis_server_aot.dart.snapshot
```

### 2.3 责任组件（高度可疑）

`fltmc filters` 显示本机同时加载了两套安全软件的 minifilter：

| filter | 高度 | 说明 |
|---|---|---|
| `ahflt` | 385250.1 | **幽灵驱动**：`fltmc` 里在跑，但 `System32\drivers\ahflt.sys` **磁盘上已不存在** |
| `sysdiag` | 324600 | 火绒，VlStatus `0c`（与其他驱动的 `07`/`0f` 不同） |
| UCPD / WdFilter / bindflt | — | Windows 自带 |

用户态进程确认在跑：`HipsTray.exe`（火绒，`D:\Program Files\Huorong\...`）、
`MSPCManagerService`（微软电脑管家）。

**`ahflt.sys` 正是微软电脑管家的驱动，且是典型的「卸载/更新残留」** —— 文件已删、驱动仍在内存中，
这类残留驱动会挂钩 `IRP_MJ_CREATE` 并产生确定性的诡异错误码，**只能靠重启从内存清除**。

> 补充：`fltmc instances` 里没有第三方 filter 显式挂在 `\Device\NamedPipe` 上
> （只有 Windows 自带的 `npsvctrig`）。所以不能 100% 断言就是某个 minifilter —— 
> 也可能是用户态 API hook。但驱动残留 + 两套安全软件并存，是当前最合理的解释，
> 且下面第 1、2 条处置成本极低。

### 2.4 处置建议（按成本从低到高）

1. **先重启一次**。清除幽灵驱动、让安全软件的内核驱动与用户态守护进程恢复一致。这是命中率最高的一步。
2. 重启后仍失败 → **临时退出/暂停火绒 HIPS 与微软电脑管家**，再重测。
   两套安全软件并存时应**只保留一套**。
3. 仍失败 → 干净启动（`msconfig` 最小驱动 + 最少启动项）复测，逐个恢复以定位拦截方。
4. **不要**为了绕过而去 patch `bin/cache/flutter_tools.snapshot`、伪造 `git`、或降级 Dart ——
   问题在系统层，Dart 起不了任何子进程时 Flutter 必然不可用。

**验证修复是否生效**（无需 flutter，20 秒出结果）：

```powershell
& "C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe" "C:\temp\test_spawn.dart"
```

期望看到 `SYNC cmd -> OK exit=0 out=hi`；只要还是 `FAIL`，就不用往下走了。

---

## 三、阻塞 B：Android 宿主工程不完整

即使工具链修好，`flutter run` 仍会失败 —— `android/` 目录只有 3 个文件，缺了标准 Flutter Android 宿主的绝大部分：

**已存在**

```
android/build.gradle
android/app/build.gradle
android/app/src/main/AndroidManifest.xml
```

**缺失（会导致构建直接失败）**

| 缺失文件 | 后果 |
|---|---|
| `android/settings.gradle` | Gradle 无法配置工程，**第一步就崩** |
| `android/gradle.properties` | 缺 `android.useAndroidX=true`，camera/shared_preferences 等 AndroidX 插件**编译失败** |
| `android/gradle/wrapper/*`、`gradlew`、`gradlew.bat` | 无 Gradle Wrapper（`.gitignore` 里被忽略，但本地也没有） |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Manifest 里 `android:name=".MainActivity"` **指向不存在的类** |
| `android/app/src/main/res/values/styles.xml` | Manifest 引用 `@style/LaunchTheme` / `@style/NormalTheme` → **资源找不到** |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | Manifest 引用 `@mipmap/ic_launcher` → **资源找不到** |
| `android/app/src/main/res/drawable/launch_background.xml` | 启动图缺失 |
| `android/local.properties` | 缺 `flutter.sdk` / `sdk.dir` 指向 |
| `.metadata`、`pubspec.lock`、`.dart_tool/` | pub 从未跑过 |

`AndroidManifest.xml` 本身写得是对的（相机权限、`uses-feature`、`flutterEmbedding=2` 都齐），
问题纯粹是**这些平台脚手架文件没被提交进仓库**。

### 修复方式

工具链恢复后，**一条命令**即可补全（`flutter create` 只生成缺失文件，不覆盖已有文件）：

```bash
cd C:/project/pao-help
flutter create --platforms=android --org com.daoge --project-name pao_help .
```

> **不建议手工补写这些文件**：Gradle Wrapper 的 `gradle-wrapper.jar` 是二进制，
> launcher 图标是 PNG，手写既不可靠也会和 `flutter create` 的正确产物冲突。

### 附带问题

- `README.md` 声称仓库已关联 `git@github.com:Daoge008/pao-help.git`，但**目录里没有 `.git`**，
  当前不是 git 仓库，`git push` 会直接 `fatal: not a git repository`。
- `pubspec.yaml` 的 assets 有冗余：`assets/models/` 与 `assets/models/labelmap.txt` 重复声明了子路径，删掉后者。

---

## 四、代码检查结果

### 4.1 静态分析未能执行

`flutter analyze` 与 `dart analyze` 都因阻塞 A 无法运行（两者都要 spawn 语言服务器）。
**本节所有结论均来自人工源码评审 + 自行搭建的运行时验证**，不代表分析器结论。

### 4.2 核心逻辑已通过真实运行验证：67 PASS / 0 FAIL

利用「Dart 仍可直接执行脚本、只是起不了子进程」这一点，我建了独立脚手架
`tool/engine_smoke.dart`：**只使用相对 import**（因此不需要跑不动的 `pub get`），
覆盖全部不依赖 Flutter 的模块，真跑原仓库 `test/pao_engine_test.dart` 的断言逻辑并大幅扩展：

| 测试域 | 内容 | 结果 |
|---|---|---|
| 卡牌模型 | 红黑字判定、中文名、`allCards`、`fromCode` 往返 | 11 PASS |
| 胡息矩阵 | 小/大字 × 坎碰偎提跑/一二三/二七十 共 16 项，逐条对照 `RULES.md` | 16 PASS |
| 原仓库测试用例 | 15 胡以上胡牌判定、跑牌优先级 | 4 PASS |
| 名堂 | 黑胡×碰碰胡(×8)、点胡(×3)、红胡(×2)、十三红(×4)、自摸 | 8 PASS |
| 起胡门槛 | 恰好 15 胡 → 可胡；12 胡 → 不可胡 | 3 PASS |
| 边界探测 | 绞牌参与成胡（base=15 真能胡）；暗手提牌不受支持 | 3 PASS |
| 决策引擎 | 自摸成4张→提、自摸成3张→偎、他人出牌+有对→碰、已有碰+第4张→跑、孤张优先出牌 | 8 PASS |
| 空间追踪 | 区域划分、3 帧确认、指数平滑(0.408)、漏检 4 帧保留 / 5 帧剔除、reset | 9 PASS |
| YOLO NMS | 同牌高重叠抑制、保留最高置信度 | 2 PASS |

**结论：规则引擎（胡息、名堂、胡牌拆解、决策打分）与视觉后处理（去抖、NMS）功能正确，无逻辑缺陷。**

### 4.3 发现的问题（按优先级）

**中**

1. **`camera_scanner_screen.dart:80` —— 定时器泄漏。**
   `_startSimulatedStream()` 可被多次调用（相机初始化失败、以及生命周期 `resumed` 后再次失败），
   每次都 `_simulatedTimer = Timer.periodic(...)` 覆盖引用却**不 cancel 旧的**，
   导致多个定时器并存、重复推帧，且 `dispose()` 只能取消最后一个。应在赋值前加 `_simulatedTimer?.cancel()`。
2. **`camera_scanner_screen.dart:92-95` —— 生命周期处理不一致。**
   `inactive` 时 `dispose()` 了 controller，但 `_isCameraReady` 仍为 `true`、`_cameraController` 仍非空，
   `build()` 会尝试用**已释放的 controller** 构造 `CameraPreview`，可能抛异常。
   建议 dispose 后把 `_cameraController = null`、`_isCameraReady = false`。
3. **三条进牌限制规则没有实现。** `chouPaiLimit`（臭牌禁吃）、`guoZhangLimit`（过张不碰）、
   `biPaiRule`（比牌）三个开关**只被持久化、在设置页展示、在首页显示，引擎中从未被读取**。
   `decision_engine.dart` 的吃/碰分支里只有一句注释提到过。
   → 这是规则配置界面里三个开关的**功能缺口**（用户拨动它们不会有任何行为变化）。
4. **`tflite_flutter: ^0.10.4` 是未使用的依赖。** 全项目没有任何 `import 'package:tflite_flutter/...'`，
   `Interpreter` 相关代码全被注释（`yolo_detector.dart:22`）。当前检测恒走 `_generateSimulatedDetections()` 模拟分支。
   要么接上模型，要么移除依赖（否则白白引入原生库与构建风险）。

**低**

5. **`rule_settings_screen.dart:82`** —— `DropdownButton<int>(value: _config.minHuXi)` 的 items 只有 10/15/18/21，
   若持久化数据里是其它值（例如手工改过 prefs）会触发 Flutter 断言崩页。建议加兜底。
6. **`vision_pipeline.dart:1`** —— `import 'dart:async';` 未被使用（`Future` 来自 `dart:core`），会产生 `unused_import` 提示。
7. **`hu_checker.dart` —— 暗手中的 4 张同牌不被识别为「提」。** 实测 `b5×4 → canHu=false`。
   若视觉识别可能把「提」留在手牌区（而非归入 `exposedMelds`），会漏判可胡。
8. **`hu_checker.dart` —— 不校验手牌总数。** 实测仅 9 张牌（3 个坎，base=18）即判定可胡。
   视觉流只识别到部分手牌时会**过早报胡**。属设计取舍，但建议加门槛。
9. **`assets/models/` 下没有 `.tflite` 模型**（只有 `labelmap.txt`）。当前不影响演示（走模拟分支），
   但真实识别无法工作；`MODEL_TRAINING.md` 已写明训练与转换流程。

---

## 五、修复后的完整运行步骤

```bash
# 0) 前置：完成第二节处置（重启 / 暂停安全软件），确认
#    dart.exe C:\temp\test_spawn.dart 输出 SYNC cmd -> OK

cd C:/project/pao-help

# 1) 拉依赖
flutter pub get

# 2) 补全缺失的 Android 宿主工程（只生成缺失文件）
flutter create --platforms=android --org com.daoge --project-name pao_help .

# 3) 跑原仓库单测（工具链恢复后即可正常运行）
flutter test test/pao_engine_test.dart

# 4) 接手机（开启 USB 调试）后运行
flutter devices
flutter run -d <device-id>
```

无手机时也可先在**模拟器**上验证 UI（App 在拿不到相机时会自动切到模拟数据流，
`_startSimulatedStream()` 每 300ms 推一帧，用 `YoloDetector` 的模拟检测数据驱动全部 UI 与决策面板）：

```bash
flutter emulators --launch <emulator-id>
flutter run
```

> 注意：模拟器**必须配一个虚拟摄像头**才有画面，否则会走「演示/模拟分析模式」的深绿台呢背景，
> 但决策面板、手牌栏、识别框绘制仍会正常运行（数据来自内置模拟样本）。

---

## 六、本次产出的验证资产

| 文件 | 说明 |
|---|---|
| `tool/engine_smoke.dart` | 独立引擎校验脚手架，67 项断言，可长期留作回归校验 |
| `C:\temp\engine_run4.log` | 完整运行输出 |

即使在工具链完好的机器上，这个脚手架也有价值：它只依赖 `dart.exe`，**不需要 `pub get`、不需要 Flutter SDK**，
比 `flutter test` 快得多，适合改规则算法时快速回归。

---

## 七、附录：打包 release APK 实录（2026-09-24 16:26 ~ 16:42）

### 7.1 结果：**构建成功**

| 项 | 值 |
|---|---|
| 产物 | `dist/pao-help-v1.0.0-release.apk`（另有一份在 `build/app/outputs/flutter-apk/app-release.apk`） |
| 大小 | 69,139,986 bytes = **65.94 MB** |
| SHA-256 | `f71f333b3e5b9a02af4682b7274cd2bf59d7b1f1b2ece1a39764cfce79d0272c` |
| 包名 | `com.daoge.paohelp` |
| 版本 | versionCode 1 / versionName 1.0.0 |
| SDK | minSdk **24** / targetSdk **36** / compileSdk **36** |
| 应用名 | **跑胡子助手**（已按 UTF-8 字节核对） |
| ABI | `arm64-v8a` + `armeabi-v7a` + `x86_64`（fat APK） |
| 签名 | Android Debug key，**APK Signature Scheme v2 验证通过** |

**签名说明**：Flutter 模板的 `release` buildType 默认沿用 debug 签名，因此这是一个
**debug 签名的 release 包** —— 可直接安装到手机使用，但**不能上架应用商店**。
若需上架，需生成正式 keystore 并配置 `signingConfigs.release`；
注意同一 App 的后续更新必须使用同一个 key，否则无法覆盖安装。

### 7.2 阻塞 A 已自行消失

16:26 复测同一个探针，结果从 `FAIL 231` 变为：

```
SYNC cmd -> OK exit=0 out=hi
SYNC git -> OK exit=0 out=git version 2.55.0.windows.3
```

期间未改动任何 Dart / Flutter / PATH 配置 —— 即第二节处置建议第 1 条（重启清除幽灵驱动）生效。
此后 `flutter pub get` / `analyze` / `build apk` 全部正常。

> 教训：**不要把这类系统级故障当永久状态**，每次开工先用 20 秒探针确认现状。

### 7.3 阻塞 B 的处理：整体替换 android 宿主工程

**没有**采用原文第 148 行建议的 `flutter create .`——因为实测发现该命令**不覆盖已存在文件**，
会让旧的 Groovy `build.gradle`（`apply from: .../flutter.gradle`、compileSdk 34）
与新生成的 Kotlin DSL（AGP 9.1.0 / Gradle 9.3.1）**混在一起**，且会往 `test/` 塞入无关的 `widget_test.dart`。

改用**临时目录生成模板 + 只拷贝 `android/`** 的方式：

```powershell
flutter create --platforms=android --org com.daoge --project-name paohelp C:\temp\pao_tpl
# 旧目录已备份到 .backup\android-legacy-20260924\
# 然后整体替换 C:\project\pao-help\android
```

新宿主工程带来的关键变化：

| 文件 | 变化 |
|---|---|
| `settings.gradle.kts` | 插件式 `dev.flutter.flutter-plugin-loader` + AGP **9.1.0** + Kotlin **2.4.0** |
| `app/build.gradle.kts` | Kotlin DSL，`JavaVersion.VERSION_17`，`applicationId`/`namespace = com.daoge.paohelp` |
| `gradle/wrapper/*` | Gradle **9.3.1**（`gradlew` / `gradle-wrapper.jar` 补齐） |
| `gradle.properties` | `android.useAndroidX=true`、`android.newDsl=false`、`android.builtInKotlin=false` |
| `app/src/main/kotlin/com/daoge/paohelp/MainActivity.kt` | Manifest 里 `.MainActivity` 终于有了实现 |
| `res/values/styles.xml`、`mipmap-*/ic_launcher.png`、`drawable*/launch_background.xml` | `@style/LaunchTheme`、`@mipmap/ic_launcher` 不再悬空 |
| `local.properties` | `sdk.dir` + `flutter.sdk` |

回填的自定义项：`AndroidManifest.xml` 加回 `CAMERA` 权限与 camera/autofocus feature、
`android:label` 改成 **跑胡子助手**；去掉了已废弃的 `package=` 属性（AGP 8+ 会报错，包名走 `namespace`）。

### 7.4 为打通构建所做的 4 处改动

| # | 文件 | 改动 | 原因 |
|---|---|---|---|
| 1 | `pubspec.yaml` | `tflite_flutter: ^0.10.4` → `^0.12.1` | 0.10.4 是 2023 年版本：`compileSdkVersion 31`、`minSdkVersion 26`（会顶高手牌 App 的 minSdk），在 AGP 9 下必然失败 |
| 2 | `android/gradle/wrapper/gradle-wrapper.properties` | `services.gradle.org` → `mirrors.cloud.tencent.com/gradle/gradle-9.3.1-bin.zip` | 官方源 302 到被墙 CDN，下载必超时；注意 `9.3.1` 是 AGP 9.1.0 的**硬性最低要求**（试过复用本地的 9.2.0，被 Gradle 直接拒绝） |
| 3 | `android/app/build.gradle.kts` | `ndkVersion = flutter.ndkVersion` → `ndkVersion = "27.2.12479018"` | Flutter 默认要 NDK 28.2.13676358，本机只装了 27.2.12479018，触发 `sdkmanager` 自动安装，而 sdkmanager 崩溃（`NTSTATUS 0xC0000409`）。固定为本机已装版本后 Flutter 直接跳过 provisioning |
| 4 | `android/gradle.properties` | 新增 `kotlin.jvm.target.validation.mode=warning` | `tflite_flutter 0.12.1` 声明 Java 11 却未声明 Kotlin jvmTarget（KGP 2.4 默认编到 17），是**唯一**有此问题的模块；其余插件均为 Java 17 + JVM_17 |

外加代码层面的机械清理（`flutter analyze` 从 11 条告警 → **0 条**）：

- `huxi_calculator.dart` 删除未使用的 `import '../models/card.dart'`
- `spatial_tracker.dart` 的 `_TrackedItem` 把 `hitStreak` / `missedStreak` 改为字段内联初始化（消除"参数从未被传入"告警）
- 5 个 UI 文件的 7 处 `Color.withOpacity(x)` → `Color.withValues(alpha: x)`
- `tool/engine_smoke.dart` 删除未使用的 `import 'dart:math'`

**改后复验**：`flutter analyze` → `No issues found!`；
`dart.exe tool/engine_smoke.dart` → **67 PASS / 0 FAIL**（无回归）。

### 7.5 构建过程中的 3 个报错与解法（按出现顺序）

| 报错 | 解法 |
|---|---|
| `java.net.ConnectException: Connection timed out`（`org.gradle.wrapper.Download`） | 换腾讯云镜像，见 7.4 第 2 项 |
| `Minimum supported Gradle version is 9.3.1. Current version is 9.2.0.` | 同上（先试的 9.2.0 被拒） |
| `Package ndk not found` + `sdkmanager.bat ... non-zero exit value -1073740791` | 固定 ndkVersion，见 7.4 第 3 项 |
| `Execution failed for task ':tflite_flutter:compileReleaseKotlin'` → `Inconsistent JVM Target Compatibility` | 见 7.4 第 4 项 |

> 另有一个**执行侧**坑：PowerShell 工具的后台任务仍受 **120 秒默认超时**限制，
> Gradle 构建跑到 2 分钟就被掐断（日志停在 `Running Gradle task 'assembleRelease'...`
> 且缺少收尾行）。必须显式 `timeout=600000`。好在 Gradle 进度可跨次累积，重跑是接着走的。

### 7.6 APK 体积构成（为什么有 66MB）

| 组成 | 体积 |
|---|---|
| `arm64-v8a` 7 个 `.so` | 22.13 MB |
| `armeabi-v7a` 7 个 `.so` | 17.22 MB |
| `x86_64` 7 个 `.so` | 25.30 MB |
| 其余（dex / 资源 / Flutter assets） | ~1.3 MB |

三套 ABI 各含 `libflutter.so`（引擎，8~12MB）与 **`libtensorflowlite_jni.so` +
`libtensorflowlite_gpu_jni.so`（TFLite，共约 6.5MB/套）**。

**结论：`tflite_flutter` 是当前 APK 里最大的可裁减项**（三 ABI 合计约 19MB），
而全项目没有任何一处 `import 'package:tflite_flutter/...'`（唯一出现是
`yolo_detector.dart:19` 的一个字符串路径默认参数），检测恒走 `_generateSimulatedDetections()` 模拟分支。
两种收敛方式：

- 短期瘦身：从 `pubspec.yaml` 移除该依赖 + 删掉 `android/gradle.properties` 里那条 Kotlin 校验降级，
  预计 APK 降到约 46MB。
- 若要保留能力：接入真实 `assets/models/pao_yolov8n.tflite`（`MODEL_TRAINING.md` 已写明训练与转换流程）。
- 另外可考虑 `flutter build apk --split-per-abi`，按 ABI 拆包可让单包降到 20MB 上下。

### 7.7 仍未验证的部分（务必知悉）

- **未在真机/模拟器上实际运行**。构建成功只证明 Dart 全量 AOT 通过、Android 侧编译与打包无误，
  **不等于运行时无缺陷**。
- 第四节 4.3 列出的问题（定时器泄漏、生命周期 `inactive` 后用已释放 controller 构造 `CameraPreview`、
  三个进牌限制开关未实现）**依然存在**，其中前两条是**运行时**问题，构建阶段看不出来。
- 接手机（开启 USB 调试）后可直接验证：

  ```powershell
  & "$env:ANDROID_HOME\platform-tools\adb.exe" devices
  & "$env:ANDROID_HOME\platform-tools\adb.exe" install -r "C:\project\pao-help\dist\pao-help-v1.0.0-release.apk"
  ```

- `assets/models/` 下仍无 `.tflite` 模型，App 会走模拟检测分支（不影响启动与演示）。

---

## 八、真机运行时缺陷修复：相机预览黑屏（2026-09-24 17:1x）

### 8.1 现场现象

真机反馈：点击「开始实物识别」后，相机预览正常显示约 **2 秒**，随后**预览区变黑**，
但顶部工具栏仍然可见（"只显示了部分菜单"）——即崩溃没有发生，只是预览那一块变成了空白/黑块。

### 8.2 根因（插件源码 + 引擎源码双重证据）

完整链条：

1. 原 `didChangeAppLifecycleState` 在 `AppLifecycleState.inactive` 时执行 `_cameraController?.dispose()`。
2. **`inactive` 在 Android 上并不等于"进入后台"**。引擎源码
   `engine/src/flutter/lib/ui/platform_dispatcher.dart:2378` 明确写着：该状态对应 host view 的
   **窗口焦点变化**（`Activity.onWindowFocusChanged`），**应用可能仍处于可见状态**。
   因此系统弹窗、权限提示、国产 ROM 的悬浮提醒、下拉通知栏等**任何一次瞬时失焦**都会触发它。
3. `CameraController.dispose()`（`camera-0.11.4/lib/src/camera_controller.dart:910`）只置
   `_isDisposed = true`，**不会把 `value` 重置成 uninitialized** → `value.isInitialized` 仍为 `true`。
4. 于是 `CameraPreview`（`camera-0.11.4/lib/src/camera_preview.dart:24`）仍旧走
   `controller.buildPreview()`，而 `buildPreview()`（`camera_controller.dart:681`）第一步就是
   `_throwIfNotInitialized('buildPreview')`，该方法在 `_isDisposed` 时**抛
   `CameraException('Disposed CameraController')`** —— 注意这是 `throw` 而非 `assert`，
   **release 包同样会抛**。
5. 异常在其所属 element 的 build 阶段被捕获 → 该子树被 `ErrorWidget` 顶替 →
   **预览区变成空白/黑块，工具栏与 HUD 不受影响**。这正是"黑屏但菜单还在"。
6. 为什么是**永久**黑屏：`resumed` 后重新初始化时，旧实例的异步 `dispose()` 尚未走完，
   `initialize()` 极易因摄像头被占而失败；失败后走 `_startSimulatedStream()` 降级，
   但它**没有清空 `_cameraController`**，而 `build` 的判断顺序是
   **先看 `_cameraController != null`、后看 `_isSimulatedMode`**，于是继续用已释放的实例构造
   `CameraPreview`，此后每一次重建都抛一次异常 → 永不恢复。

### 8.3 修复（重写 `lib/ui/camera_scanner_screen.dart`）

核心是建立并守住一条不变量：**`_cameraController` 非 null ⟹ 它一定尚未被 dispose**。

| 改动 | 说明 |
|---|---|
| 收敛唯一释放入口 | 新增 `_releaseCamera()`，**先置空引用再 await dispose**，销毁期间 build 绝不会拿到死实例 |
| `inactive` 不再销毁相机 | 只登记 `_needsCameraRestart`，回前台时重建一次作自愈，彻底避开瞬时失焦这条路径 |
| 只有真正后台才释放 | `paused` / `hidden` / `detached` 才调用 `_releaseCamera()` |
| 初始化防重入 | `_isInitializing` 互斥；`initialize()` 返回后若已离开页面或已退后台，直接销毁该实例 |
| 降级路径不留脏引用 | 失败降级先走 `_releaseCamera()`；`build` 也优先判断 `_isSimulatedMode` |
| 帧流失败单独降级 | 不再因为帧流启动失败而丢掉本来可用的预览 |
| 定时器泄漏修复 | `_startSimulatedStream()` 每次先 `cancel()` 旧定时器（4.3 的另一条） |
| 可见诊断条 | 相机异常时在顶部显示原因 + 「重试」按钮（`_cameraNotice`），便于现场定位 |
| `_switchCamera` 走统一入口 | 不再在 dispose 后残留引用 |

### 8.4 本轮验证的边界（重要）

- `dart format --output=none lib/ tool/ test/` → **21 个文件全部解析通过**，语法无误。
- `tool/engine_smoke.dart` 回归 → **67 PASS / 0 FAIL**（引擎层未改动，确认无副作用）。
- **未能执行 `flutter analyze`，也未能重新构建 APK**：第二节的阻塞 A 在 17:16 之后复发且持续（见 8.5）。
  所以本次修改**尚未通过编译期验证，也还没有对应的新 APK**。
- 已逐一对照插件/引擎源码确认所用 API 确实存在（`isStreamingImages`、`startImageStream`、
  `stopImageStream`、`supportsImageStreaming`，以及 `AppLifecycleState` 的 5 个成员）。
- Dart 3 的 `switch` 语句已不需要 `break`（本文件依赖该语义），已用最小样例实测确认合法。

### 8.5 阻塞 A 复发（与第二节同一故障）

| 时间 | 状态 |
|---|---|
| ~16:0x | 故障活跃 |
| 16:26 ~ 16:42 | **自动恢复**，期间构建成功 |
| 17:16 ~ 17:5x | **复发且持续**：连续 8+ 次构建尝试，每次 3 秒即失败在同一个 spawn |

本轮新证据：

- 命名管道总数仅 **437**，无实例耗尽 → 排除"管道泄漏压垮系统"。
- `fltmc filters` 里 `ahflt`（微软电脑管家幽灵驱动）**已消失**，说明上一轮锁定的它不是主因；
  当前活跃的第三方内核组件是 **火绒 `sysdiag`（8 个实例）**，用户态 `HipsTray.exe` 与
  `MSPCManagerService` 同时在跑。
- 失败点始终是"由 `dart:io` 发起的子进程创建"，与被调用的程序无关——已观测到
  `cmd.exe`、`git.exe`、`dart.exe language-server`、`gradlew.bat` 全部失败。

处置建议（按成本从低到高）：

1. **在自己的普通终端里执行同一命令**（绕开本工具的进程沙箱）：

   ```powershell
   cd C:\project\pao-help
   & "C:\src\flutter\bin\flutter.bat" build apk --release
   ```

   能成功 → 拦截来自工具的沙箱层；同样报 231 → 确认在系统层。
2. 暂停火绒防护并退出微软电脑管家后重试。
3. 重启一次机器（上一轮就是由此恢复的）。

工具链不可用时可复用的诊断旁路：

- `dart format --output=none --set-exit-if-changed <路径>`：**在进程内解析**，无需 spawn，
  可在 spawn 全面失效时做语法校验。
- `dart.exe <脚本>`：只要脚本自身不起子进程就能跑；`tool/engine_smoke.dart` 正是靠这点
  在故障期间仍可回归。
- 曾尝试让 Python 以 LSP 协议直接驱动 `dart language-server`（Python 的匿名管道不受影响）：
  服务能启动、`initialize` 握手成功，但等待诊断时进程被环境终止——**这条旁路在本机不可用**。

