import 'dart:math';
import '../models/card.dart';
import '../models/detected_card.dart';

/// YOLOv8/YOLO11 实物跑胡子卡牌目标检测器
class YoloDetector {
  bool _isModelLoaded = false;
  final double confidenceThreshold;
  final double iouThreshold;

  YoloDetector({
    this.confidenceThreshold = 0.55,
    this.iouThreshold = 0.45,
  });

  bool get isModelLoaded => _isModelLoaded;

  /// 加载本地 TFLite 跑胡子专用轻量模型与标签映射
  Future<void> loadModel({String modelPath = 'assets/models/pao_yolov8n.tflite'}) async {
    try {
      // 实际硬件环境下调用:
      // _interpreter = await Interpreter.fromAsset(modelPath);
      _isModelLoaded = true;
    } catch (e) {
      _isModelLoaded = false;
    }
  }

  /// 针对输入图像进行前向推理并后处理
  Future<List<DetectedCard>> detect(dynamic imageInput) async {
    if (!_isModelLoaded) {
      return _generateSimulatedDetections();
    }

    // 模型推理管线逻辑：
    // 1. Resize 输入到 640x640 并归一化到 [0, 1]
    // 2. 运行 Interpreter.runForMultipleInputs(...)
    // 3. 输出形状通常为 [1, 24, 8400] (4坐标 + 20类别置信度)
    // 4. 解析候选框并执行 NMS (Non-Maximum Suppression)
    return _generateSimulatedDetections();
  }

  /// 模拟实物牌局检测数据（便于在无外设模拟器中直接调测 UI、空间追踪与规则决策）
  List<DetectedCard> _generateSimulatedDetections() {
    final list = <DetectedCard>[];

    // 手牌区域牌 (小一、小二、小三、大壹、大贰、大叁、小七、小七、小十、大拾、大拾)
    final sampleHand = [
      PaoCard(value: 1, isBig: false),
      PaoCard(value: 2, isBig: false),
      PaoCard(value: 3, isBig: false),
      PaoCard(value: 1, isBig: true),
      PaoCard(value: 2, isBig: true),
      PaoCard(value: 3, isBig: true),
      PaoCard(value: 7, isBig: false),
      PaoCard(value: 7, isBig: false),
      PaoCard(value: 10, isBig: false),
      PaoCard(value: 10, isBig: true),
      PaoCard(value: 10, isBig: true),
    ];

    double startX = 0.15;
    const double stepX = 0.07;
    for (int i = 0; i < sampleHand.length; i++) {
      list.add(DetectedCard(
        card: sampleHand[i],
        confidence: 0.88 + (Random().nextDouble() * 0.1),
        x: (startX + i * stepX).clamp(0.05, 0.95),
        y: 0.78 + (i % 2 == 0 ? 0.02 : -0.01),
        width: 0.08,
        height: 0.16,
        zone: CardZone.hand,
      ));
    }

    // 桌面弃牌区 (小五、大捌、小九)
    list.add(DetectedCard(
      card: PaoCard(value: 5, isBig: false),
      confidence: 0.92,
      x: 0.40,
      y: 0.25,
      width: 0.08,
      height: 0.15,
      zone: CardZone.tableDiscards,
    ));
    list.add(DetectedCard(
      card: PaoCard(value: 8, isBig: true),
      confidence: 0.91,
      x: 0.55,
      y: 0.22,
      width: 0.08,
      height: 0.15,
      zone: CardZone.tableDiscards,
    ));

    // 即时焦点牌 (摸出小七，可以偎或跑)
    list.add(DetectedCard(
      card: PaoCard(value: 7, isBig: false),
      confidence: 0.95,
      x: 0.50,
      y: 0.48,
      width: 0.09,
      height: 0.17,
      zone: CardZone.currentCard,
    ));

    return list;
  }

  /// NMS (非极大值抑制)
  List<DetectedCard> applyNMS(List<DetectedCard> boxes) {
    if (boxes.isEmpty) return [];
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selected = <DetectedCard>[];
    for (final box in boxes) {
      bool shouldSelect = true;
      for (final s in selected) {
        if (box.card == s.card && _calculateIoU(box, s) > iouThreshold) {
          shouldSelect = false;
          break;
        }
      }
      if (shouldSelect) {
        selected.add(box);
      }
    }
    return selected;
  }

  double _calculateIoU(DetectedCard a, DetectedCard b) {
    final x1 = max(a.left, b.left);
    final y1 = max(a.top, b.top);
    final x2 = min(a.right, b.right);
    final y2 = min(a.bottom, b.bottom);

    final intersectionArea = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    final unionArea = (a.width * a.height) + (b.width * b.height) - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }
}
