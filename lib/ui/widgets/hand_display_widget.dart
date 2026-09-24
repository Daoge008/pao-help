import 'package:flutter/material.dart';
import '../../models/card.dart';

/// 手牌卡片微缩组件（模拟跑胡子实物牌条形长矩形）
class PaoCardMiniTile extends StatelessWidget {
  final PaoCard card;
  final bool isSelected;
  final VoidCallback? onTap;

  const PaoCardMiniTile({
    super.key,
    required this.card,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6EE), // 仿纸牌米白底色
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.amberAccent : Colors.brown.shade400,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 3,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.name,
              style: TextStyle(
                color: card.isRed ? const Color(0xFFC62828) : const Color(0xFF212121),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 14,
              height: 2,
              color: card.isRed ? Colors.red.shade300 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部或浮层手牌展示横栏
class HandDisplayWidget extends StatelessWidget {
  final List<PaoCard> handCards;
  final PaoCard? selectedCard;
  final ValueChanged<PaoCard>? onCardSelected;

  const HandDisplayWidget({
    super.key,
    required this.handCards,
    this.selectedCard,
    this.onCardSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (handCards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: handCards.length,
        itemBuilder: (context, index) {
          final card = handCards[index];
          return PaoCardMiniTile(
            card: card,
            isSelected: card == selectedCard,
            onTap: () => onCardSelected?.call(card),
          );
        },
      ),
    );
  }
}
