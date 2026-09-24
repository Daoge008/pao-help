import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/detected_card.dart';
import '../models/game_state.dart';
import '../models/rule_config.dart';
import '../engine/decision_engine.dart';
import 'spatial_tracker.dart';
import 'yolo_detector.dart';

/// 实时视觉识别与决策数据流总线 (ChangeNotifier)
class VisionPipeline extends ChangeNotifier {
  final YoloDetector detector;
  final SpatialTracker tracker;
  RuleConfig _config;
  late DecisionEngine _decisionEngine;

  bool _isProcessing = false;
  DateTime _lastProcessTime = DateTime.now();

  // 当前状态
  List<DetectedCard> _confirmedDetections = [];
  PaoGameState _currentState = const PaoGameState(handCards: []);
  List<ActionRecommendation> _recommendations = [];

  // 获取器
  List<DetectedCard> get confirmedDetections => _confirmedDetections;
  PaoGameState get currentState => _currentState;
  List<ActionRecommendation> get recommendations => _recommendations;
  RuleConfig get config => _config;

  VisionPipeline({
    RuleConfig? config,
    YoloDetector? detector,
    SpatialTracker? tracker,
  })  : _config = config ?? RuleConfig.changdeStandard(),
        detector = detector ?? YoloDetector(),
        tracker = tracker ?? SpatialTracker() {
    _decisionEngine = DecisionEngine(_config);
    _initDetector();
  }

  Future<void> _initDetector() async {
    await detector.loadModel();
  }

  /// 更新规则配置（切换玩法或自定义胡息时调用）
  void updateRuleConfig(RuleConfig newConfig) {
    _config = newConfig;
    _decisionEngine = DecisionEngine(_config);
    // 重新根据最新规则分析已有状态
    _recommendations = _decisionEngine.analyze(_currentState);
    notifyListeners();
  }

  /// 摄像头每帧数据回调处理
  Future<void> processCameraFrame(dynamic cameraImage) async {
    // 节流控制：跑胡子每秒推理 5~8 帧即可实现流畅辅助，避免手机发热
    final now = DateTime.now();
    if (_isProcessing || now.difference(_lastProcessTime).inMilliseconds < 150) {
      return;
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      // 1. 目标检测
      final rawDetections = await detector.detect(cameraImage);

      // 2. 空间追踪与时序去抖动
      _confirmedDetections = tracker.update(rawDetections);

      // 3. 构建牌局状态
      _currentState = tracker.buildGameState(_confirmedDetections);

      // 4. AI 决策引擎生成动作与出牌建议
      _recommendations = _decisionEngine.analyze(_currentState);

      // 5. 通知 UI 刷新
      notifyListeners();
    } catch (e) {
      debugPrint('VisionPipeline 处理异常: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// 清空或重置当前局识别缓存
  void resetState() {
    tracker.reset();
    _confirmedDetections.clear();
    _currentState = const PaoGameState(handCards: []);
    _recommendations.clear();
    notifyListeners();
  }
}
