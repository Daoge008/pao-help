import 'package:flutter/material.dart';
import '../../models/detected_card.dart';

/// 摄像头画面上的卡牌识别框与标签绘制器
class CardOverlayPainter extends CustomPainter {
  final List<DetectedCard> detections;
  final bool isFrontCamera;

  CardOverlayPainter({
    required this.detections,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      // 归一化坐标转换到屏幕像素坐标
      double left = d.left * size.width;
      double top = d.top * size.height;
      double width = d.width * size.width;
      double height = d.height * size.height;

      if (isFrontCamera) {
        left = size.width - left - width;
      }

      final rect = Rect.fromLTWH(left, top, width, height);

      // 根据区域配置颜色
      Color boxColor;
      Color textColor;
      switch (d.zone) {
        case CardZone.hand:
          boxColor = Colors.tealAccent;
          textColor = Colors.black;
          break;
        case CardZone.currentCard:
          boxColor = Colors.amberAccent;
          textColor = Colors.black;
          break;
        case CardZone.tableDiscards:
          boxColor = Colors.blueGrey.shade300;
          textColor = Colors.white;
          break;
        case CardZone.melds:
          boxColor = Colors.purpleAccent;
          textColor = Colors.white;
          break;
      }

      // 1. 绘制边框
      final borderPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = d.zone == CardZone.currentCard ? 3.0 : 2.0;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, borderPaint);

      // 2. 绘制卡牌名称标签背景
      final labelText = '${d.card.name} ${(d.confidence * 100).toInt()}%';
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: d.card.isRed ? Colors.red.shade900 : textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelBgRect = Rect.fromLTWH(
        left,
        top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      final bgPaint = Paint()..color = boxColor.withValues(alpha: 0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelBgRect, const Radius.circular(4)),
        bgPaint,
      );

      textPainter.paint(canvas, Offset(left + 4, top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CardOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
