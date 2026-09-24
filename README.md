# 跑胡子助手 (Pao-Help)

基于 **Flutter (Dart)** 开发的跑胡子（字牌）实物视觉辅助与决策建议安卓应用。

专为**线下实物纸牌**对局场景设计，通过手机摄像头连续实时扫描视野内的手牌与桌面弃牌/焦点牌，结合**湖南常德跑胡子（全名堂）**核心规则引擎与 AI 期望收益算法，在屏幕上即时提供最佳动作指引（出牌、胡牌、提、跑、偎、碰、吃、过），并支持全面的跑胡子规则个性化配置。

---

## 🌟 核心特性

1. **线下实物纸牌专用识别优化**
   - 针对实物跑胡子牌形狭长、握持扇形排布、反光及阴影特点设计。
   - 划分**手牌区（视野下方）**与**桌面弃牌/焦点牌区（视野中上方）**，自动通过空间坐标解构牌局。
2. **湖南常德跑胡子规则深度适配**
   - 默认采用**常德全名堂（15 胡起）**标准规则：
     - 小字：坎 3 / 碰 1 / 偎 4 / 提 9 / 跑 8 / 一二三 3 / 二七十 3。
     - 大字：坎 6 / 碰 3 / 偎 8 / 提 12 / 跑 12 / 壹贰叁 6 / 贰柒拾 6。
     - 全名堂番数计算：红胡（>=10红）、点胡（独红）、黑胡（全黑）、十三红、碰碰胡、自摸加息。
     - 规则约束：臭牌禁吃、过张不碰、比牌规则。
3. **可配置规则引擎**
   - 内置可视化规则设置界面，可自由调节起胡胡息（10胡、15胡、21胡）、开关各项名堂、修改各动作胡息矩阵，支持扩展为其他地域字牌玩法（如桂林字牌、衡阳六胡抢、永州扯胡子等）。
4. **摄像头连续实时流式识别与去抖**
   - 采用 Flutter Camera 连续视频帧回调（6~8 FPS 智能控温节流）。
   - 内置 `SpatialTracker` 空间时序追踪器：需连续命中至少 3 帧方确认为稳定手牌，防止手部晃动、临时遮挡造成的建议跳变。
5. **AI 决策与动作推荐 HUD**
   - 综合**胡牌距离（向听数）**、**胡息最大化期望**、**名堂做牌倾向（保留红字/黑胡）**与**防守安全度（桌面已现张数统计）**进行打分排序。
   - 优先提示最高优先级动作（如强制起提、碰跑、即时胡牌），并以清晰大卡片展示推荐理由。

---

## 📂 项目结构

```text
pao-help/
├── android/                   # Android 原生配置 (权限、相机特性、构建脚本)
│   └── app/src/main/AndroidManifest.xml
├── assets/
│   └── models/                # 端侧轻量目标检测模型与标签映射
│       └── labelmap.txt       # 20 种跑胡子卡牌标签 (s1~s10, b1~b10)
├── lib/
│   ├── main.dart              # 应用入口、主题配置与 Provider 挂载
│   ├── models/                # 核心数据模型
│   │   ├── card.dart          # 卡牌定义（大小字、红黑字判定、20种牌表）
│   │   ├── meld.dart          # 门子（坎、碰、提、跑、偎、绞、顺子、对子）
│   │   ├── rule_config.dart   # 规则参数配置实体（常德跑胡子、快速碰胡等预设）
│   │   ├── detected_card.dart # 视觉检测结果与视野区域属性
│   │   └── game_state.dart    # 牌局全局状态快照
│   ├── engine/                # 跑胡子规则与决策算法核心
│   │   ├── huxi_calculator.dart # 胡息与常德名堂计算器
│   │   ├── hu_checker.dart    # 回溯剪枝胡牌判定引擎
│   │   └── decision_engine.dart # 动作与出牌建议打分引擎
│   ├── vision/                # 计算机视觉管道与追踪
│   │   ├── yolo_detector.dart # YOLO 模型推理封装与 NMS 后处理
│   │   ├── spatial_tracker.dart # 连续帧空间追踪与去抖动平滑器
│   │   └── vision_pipeline.dart # 视频帧输入至决策输出的响应式总线
│   ├── ui/                    # Flutter 界面交互
│   │   ├── home_screen.dart   # 主页（入口、当前生效规则概览、实物对局指引）
│   │   ├── camera_scanner_screen.dart # 摄像头连续识别主屏幕与 AR 覆盖层
│   │   ├── rule_settings_screen.dart  # 规则与名堂自定义设置界面
│   │   └── widgets/           # 自定义组件 (卡框绘制器、决策 HUD、手牌栏)
│   └── services/
│       └── settings_service.dart # 规则配置本地持久化服务 (SharedPreferences)
├── test/
│   └── pao_engine_test.dart   # 核心引擎单元测试 (卡牌、胡息、15胡起胡判定、决策优先级)
├── ARCHITECTURE.md            # 系统架构与模块设计文档
├── RULES.md                   # 湖南常德跑胡子规则与名堂算法详述
├── MODEL_TRAINING.md          # 实物跑胡子 YOLO 模型训练与 TFLite 转换指南
└── pubspec.yaml               # Flutter 依赖配置
```

---

## 🚀 快速启动指南

### 1. 环境准备
- Flutter SDK >= 3.0.0
- Android Studio / Android SDK (API Level >= 21)
- 带有摄像头的真实安卓手机（推荐搭载骁龙/天玑中高端处理器）

### 2. 获取源码与依赖
```bash
git clone git@github.com:Daoge008/pao-help.git
cd pao-help
flutter pub get
```

### 3. 运行单元测试
验证常德跑胡子胡息与胡牌判定引擎：
```bash
flutter test test/pao_engine_test.dart
```

### 4. 安装到安卓设备
将手机通过 USB 连接电脑并开启开发者调试模式：
```bash
flutter run -d <your-device-id>
```

---

## 📖 详细文档导航

- [系统详细架构与视觉流 (ARCHITECTURE.md)](./ARCHITECTURE.md)
- [常德跑胡子详细规则与胡息换算 (RULES.md)](./RULES.md)
- [实物数据集构建与 YOLO 模型训练指南 (MODEL_TRAINING.md)](./MODEL_TRAINING.md)

---

## 📌 Git 提交与同步

本仓库已初始化并关联至远程地址：`git@github.com:Daoge008/pao-help.git`。
若需推送到远程仓库，在本地终端执行：
```bash
git push -u origin main
```
