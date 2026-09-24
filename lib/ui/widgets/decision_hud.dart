import 'package:flutter/material.dart';
import '../../engine/decision_engine.dart';
import '../../models/game_state.dart';

/// 底部实时决策建议面板 HUD
class DecisionHUD extends StatelessWidget {
  final List<ActionRecommendation> recommendations;
  final PaoGameState gameState;

  const DecisionHUD({
    super.key,
    required this.recommendations,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: const Center(
          child: Text(
            '正在对准实物手牌与桌面，请保持牌面清晰...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }

    final topAction = recommendations.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态简报指示条
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '手牌 ${gameState.handCards.length} 张',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: gameState.totalRedCardCount >= 10
                          ? Colors.red.shade800
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '红字: ${gameState.totalRedCardCount} 张${gameState.totalRedCardCount >= 10 ? " (达红胡)" : ""}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (gameState.currentCard != null)
                Text(
                  '场上牌: ${gameState.currentCard!.name}',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 主要动作推荐大卡片
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: topAction.action == ActionType.hu
                    ? [Colors.red.shade900, Colors.red.shade700]
                    : [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: topAction.action == ActionType.hu ? Colors.amber : Colors.tealAccent,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topAction.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topAction.explanation,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${topAction.score.toInt()}分',
                    style: TextStyle(
                      color: topAction.score > 85 ? Colors.greenAccent : Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 次选动作建议列表（如果有多项可选）
          if (recommendations.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length - 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final alt = recommendations[index + 1];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${alt.title} (${alt.score.toInt()}分)',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
