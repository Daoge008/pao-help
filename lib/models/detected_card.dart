import 'card.dart';

/// 卡牌所在视觉区域划分
enum CardZone {
  hand,           // 手牌区域（通常在视野下部）
  tableDiscards,  // 桌面已出弃牌区（视野中间）
  melds,          // 各家桌面上已摆出的门子（碰/跑/偎/提）
  currentCard,    // 当前场上刚摸出或刚打出的一张牌
}

/// 摄像头视觉检测到的单张卡牌
class DetectedCard {
  final PaoCard card;
  final double confidence;
  final double x;        // 归一化中心 X (0.0 ~ 1.0)
  final double y;        // 归一化中心 Y (0.0 ~ 1.0)
  final double width;    // 归一化宽度 (0.0 ~ 1.0)
  final double height;   // 归一化高度 (0.0 ~ 1.0)
  final CardZone zone;
  final int? trackId;    // 连续帧追踪 ID

  const DetectedCard({
    required this.card,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zone,
    this.trackId,
  });

  /// 左上角 X
  double get left => x - width / 2;
  /// 左上角 Y
  double get top => y - height / 2;
  /// 右下角 X
  double get right => x + width / 2;
  /// 右下角 Y
  double get bottom => y + height / 2;

  DetectedCard copyWith({
    PaoCard? card,
    double? confidence,
    double? x,
    double? y,
    double? width,
    double? height,
    CardZone? zone,
    int? trackId,
  }) {
    return DetectedCard(
      card: card ?? this.card,
      confidence: confidence ?? this.confidence,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zone: zone ?? this.zone,
      trackId: trackId ?? this.trackId,
    );
  }
}
