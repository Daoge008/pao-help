import '../models/card.dart';
import '../models/meld.dart';
import '../models/rule_config.dart';
import 'huxi_calculator.dart';

/// 胡牌判定详情
class HuDetail {
  final bool canHu;
  final int totalHuXi;
  final List<Meld> allMelds;
  final MingTangResult mingTang;
  final String description;

  const HuDetail({
    required this.canHu,
    required this.totalHuXi,
    required this.allMelds,
    required this.mingTang,
    required this.description,
  });

  static HuDetail cannotHu() {
    return const HuDetail(
      canHu: false,
      totalHuXi: 0,
      allMelds: [],
      mingTang: MingTangResult(names: [], multiplier: 1, additionalHuXi: 0),
      description: '未达到胡牌条件或胡息不足',
    );
  }
}

/// 跑胡子胡牌判定引擎
class HuChecker {
  final RuleConfig config;
  final HuXiCalculator calculator;

  HuChecker(this.config) : calculator = HuXiCalculator(config);

  /// 检查当前手牌加入一张新牌后是否可以胡牌
  HuDetail checkCanHu({
    required List<PaoCard> handCards,
    required List<Meld> exposedMelds,
    PaoCard? incomingCard,
    bool isZiMo = false,
  }) {
    final fullHand = List<PaoCard>.from(handCards);
    if (incomingCard != null) {
      fullHand.add(incomingCard);
    }
    fullHand.sort();

    // 统计各张手牌数量
    final cardCounts = <PaoCard, int>{};
    for (final c in fullHand) {
      cardCounts[c] = (cardCounts[c] ?? 0) + 1;
    }

    HuDetail bestDetail = HuDetail.cannotHu();

    // 递归寻找所有合法门子拆解组合
    void searchMelds(
      Map<PaoCard, int> remaining,
      List<Meld> currentHandMelds,
      bool hasPair,
    ) {
      // 检查是否所有手牌都已合理组合
      if (remaining.values.every((cnt) => cnt == 0)) {
        final allCombinedMelds = [...exposedMelds, ...currentHandMelds];
        final baseHuXi = calculator.calculateTotalBaseHuXi(allCombinedMelds);
        final mingTang = calculator.evaluateMingTang(
          allMelds: allCombinedMelds,
          isZiMo: isZiMo,
        );
        final totalHuXi = baseHuXi + mingTang.additionalHuXi;

        if (totalHuXi >= config.minHuXi) {
          if (!bestDetail.canHu || totalHuXi > bestDetail.totalHuXi) {
            final desc = '可胡牌！基础胡息: $baseHuXi，名堂: ${mingTang.names.isEmpty ? "平胡" : mingTang.names.join("+")}，'
                '翻数: ${mingTang.multiplier}倍，总分: ${totalHuXi * mingTang.multiplier}';
            bestDetail = HuDetail(
              canHu: true,
              totalHuXi: totalHuXi,
              allMelds: allCombinedMelds,
              mingTang: mingTang,
              description: desc,
            );
          }
        }
        return;
      }

      // 获取当前排序在最前的一张牌进行拼搭
      PaoCard? firstCard;
      for (final card in PaoCard.allCards) {
        if ((remaining[card] ?? 0) > 0) {
          firstCard = card;
          break;
        }
      }
      if (firstCard == null) return;

      final count = remaining[firstCard]!;

      // 1. 尝试作为坎 (3张相同)
      if (count >= 3) {
        remaining[firstCard] = count - 3;
        currentHandMelds.add(Meld(
          type: MeldType.kan,
          cards: [firstCard, firstCard, firstCard],
        ));
        searchMelds(remaining, currentHandMelds, hasPair);
        currentHandMelds.removeLast();
        remaining[firstCard] = count;
      }

      // 2. 尝试作为将牌/半块 (对子，一局胡牌仅允许 1 对)
      if (!hasPair && count >= 2) {
        remaining[firstCard] = count - 2;
        currentHandMelds.add(Meld(
          type: MeldType.duiZi,
          cards: [firstCard, firstCard],
        ));
        searchMelds(remaining, currentHandMelds, true);
        currentHandMelds.removeLast();
        remaining[firstCard] = count;
      }

      // 3. 尝试组合二七十 (2-7-10 / 贰-柒-拾)
      if (firstCard.value == 2) {
        final card7 = PaoCard(value: 7, isBig: firstCard.isBig);
        final card10 = PaoCard(value: 10, isBig: firstCard.isBig);
        if ((remaining[card7] ?? 0) > 0 && (remaining[card10] ?? 0) > 0) {
          remaining[firstCard] = remaining[firstCard]! - 1;
          remaining[card7] = remaining[card7]! - 1;
          remaining[card10] = remaining[card10]! - 1;

          currentHandMelds.add(Meld(
            type: MeldType.erQiShi,
            cards: [firstCard, card7, card10],
          ));
          searchMelds(remaining, currentHandMelds, hasPair);
          currentHandMelds.removeLast();

          remaining[firstCard] = remaining[firstCard]! + 1;
          remaining[card7] = remaining[card7]! + 1;
          remaining[card10] = remaining[card10]! + 1;
        }
      }

      // 4. 尝试组合一二三 (1-2-3 / 壹-贰-叁)
      if (firstCard.value == 1) {
        final card2 = PaoCard(value: 2, isBig: firstCard.isBig);
        final card3 = PaoCard(value: 3, isBig: firstCard.isBig);
        if ((remaining[card2] ?? 0) > 0 && (remaining[card3] ?? 0) > 0) {
          remaining[firstCard] = remaining[firstCard]! - 1;
          remaining[card2] = remaining[card2]! - 1;
          remaining[card3] = remaining[card3]! - 1;

          currentHandMelds.add(Meld(
            type: MeldType.yiErSan,
            cards: [firstCard, card2, card3],
          ));
          searchMelds(remaining, currentHandMelds, hasPair);
          currentHandMelds.removeLast();

          remaining[firstCard] = remaining[firstCard]! + 1;
          remaining[card2] = remaining[card2]! + 1;
          remaining[card3] = remaining[card3]! + 1;
        }
      }

      // 5. 尝试普通顺子 (如 2-3-4, 3-4-5, ..., 8-9-10)
      if (firstCard.value <= 8) {
        final cardNext1 = PaoCard(value: firstCard.value + 1, isBig: firstCard.isBig);
        final cardNext2 = PaoCard(value: firstCard.value + 2, isBig: firstCard.isBig);
        if ((remaining[cardNext1] ?? 0) > 0 && (remaining[cardNext2] ?? 0) > 0) {
          remaining[firstCard] = remaining[firstCard]! - 1;
          remaining[cardNext1] = remaining[cardNext1]! - 1;
          remaining[cardNext2] = remaining[cardNext2]! - 1;

          currentHandMelds.add(Meld(
            type: MeldType.shunZi,
            cards: [firstCard, cardNext1, cardNext2],
          ));
          searchMelds(remaining, currentHandMelds, hasPair);
          currentHandMelds.removeLast();

          remaining[firstCard] = remaining[firstCard]! + 1;
          remaining[cardNext1] = remaining[cardNext1]! + 1;
          remaining[cardNext2] = remaining[cardNext2]! + 1;
        }
      }

      // 6. 尝试绞牌 (同点数，两小一大或两大小一)
      final otherSuitCard = PaoCard(value: firstCard.value, isBig: !firstCard.isBig);
      // 情况 A: 2 张当前牌 + 1 张对色牌
      if (count >= 2 && (remaining[otherSuitCard] ?? 0) >= 1) {
        remaining[firstCard] = count - 2;
        remaining[otherSuitCard] = remaining[otherSuitCard]! - 1;

        currentHandMelds.add(Meld(
          type: MeldType.jiao,
          cards: [firstCard, firstCard, otherSuitCard],
        ));
        searchMelds(remaining, currentHandMelds, hasPair);
        currentHandMelds.removeLast();

        remaining[firstCard] = count;
        remaining[otherSuitCard] = remaining[otherSuitCard]! + 1;
      }
      // 情况 B: 1 张当前牌 + 2 张对色牌
      if ((remaining[otherSuitCard] ?? 0) >= 2) {
        remaining[firstCard] = count - 1;
        remaining[otherSuitCard] = remaining[otherSuitCard]! - 2;

        currentHandMelds.add(Meld(
          type: MeldType.jiao,
          cards: [firstCard, otherSuitCard, otherSuitCard],
        ));
        searchMelds(remaining, currentHandMelds, hasPair);
        currentHandMelds.removeLast();

        remaining[firstCard] = count;
        remaining[otherSuitCard] = remaining[otherSuitCard]! + 2;
      }
    }

    searchMelds(cardCounts, [], false);
    return bestDetail;
  }
}
