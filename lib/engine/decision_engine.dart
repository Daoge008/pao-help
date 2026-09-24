import '../models/card.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../models/rule_config.dart';
import 'hu_checker.dart';
import 'huxi_calculator.dart';

/// 动作建议类型
enum ActionType {
  hu,      // 胡牌
  ti,      // 提牌
  pao,     // 跑牌
  wei,     // 偎牌
  peng,    // 碰牌
  chi,     // 吃牌
  discard, // 出牌 (打出某张手牌)
  pass,    // 过 (不进行动作)
}

/// 动作推荐项
class ActionRecommendation {
  final ActionType action;
  final PaoCard? targetCard;
  final List<PaoCard>? meldCards; // 吃牌时组合的牌
  final double score;             // 综合评分 (0 ~ 100)
  final String title;             // 动作标题，例如 "建议打出 [小七]" 或 "立即【胡牌】"
  final String explanation;       // 详细理由分析
  final int expectedHuXi;         // 预期胡息

  const ActionRecommendation({
    required this.action,
    this.targetCard,
    this.meldCards,
    required this.score,
    required this.title,
    required this.explanation,
    this.expectedHuXi = 0,
  });
}

/// 跑胡子 AI 决策建议引擎
class DecisionEngine {
  final RuleConfig config;
  final HuChecker huChecker;
  final HuXiCalculator calculator;

  DecisionEngine(this.config)
      : huChecker = HuChecker(config),
        calculator = HuXiCalculator(config);

  /// 根据当前牌局状态生成最佳动作建议
  List<ActionRecommendation> analyze(PaoGameState state) {
    final recommendations = <ActionRecommendation>[];

    // 1. 如果场上有正在出示的牌 (摸出或上家/他人打出)
    if (state.currentCard != null) {
      final card = state.currentCard!;

      // A. 优先判定是否能胡牌
      final huResult = huChecker.checkCanHu(
        handCards: state.handCards,
        exposedMelds: state.exposedMelds,
        incomingCard: card,
        isZiMo: state.isDrawnCard,
      );
      if (huResult.canHu) {
        recommendations.add(ActionRecommendation(
          action: ActionType.hu,
          targetCard: card,
          score: 100.0,
          title: '🔥 建议【胡牌】！',
          explanation: huResult.description,
          expectedHuXi: huResult.totalHuXi,
        ));
        return recommendations; // 能胡牌时，绝大多数情况胡牌是最优解
      }

      // B. 检查 提 / 跑 (4张成牌，跑胡子规则中摸到提通常强制起提)
      final sameInHand = state.handCards.where((c) => c == card).length;
      final existingPeng = state.exposedMelds.any((m) => m.type == MeldType.peng && m.cards.first == card);
      final existingWei = state.exposedMelds.any((m) => m.type == MeldType.wei && m.cards.first == card);

      if (sameInHand == 3) {
        if (state.isDrawnCard) {
          recommendations.add(ActionRecommendation(
            action: ActionType.ti,
            targetCard: card,
            score: 98.0,
            title: '🚀 必须【提牌】(${card.name})',
            explanation: '起手或自摸形成四张暗坎，规则强制起提，增加大额胡息！',
            expectedHuXi: card.isBig ? config.huXiBigTi : config.huXiSmallTi,
          ));
        } else {
          recommendations.add(ActionRecommendation(
            action: ActionType.pao,
            targetCard: card,
            score: 95.0,
            title: '⚡ 建议【跑牌】(${card.name})',
            explanation: '他人出牌与手中三张成四张，跑牌可得跑胡息并维持进张优势。',
            expectedHuXi: card.isBig ? config.huXiBigPao : config.huXiSmallPao,
          ));
        }
      } else if (existingPeng || existingWei) {
        recommendations.add(ActionRecommendation(
          action: ActionType.pao,
          targetCard: card,
          score: 94.0,
          title: '⚡ 建议【跑牌】(${card.name})',
          explanation: '场上已有碰/偎牌，见第四张立即跑牌增加胡息。',
          expectedHuXi: card.isBig ? config.huXiBigPao : config.huXiSmallPao,
        ));
      }

      // C. 检查 偎 (自摸两张相同成三张)
      if (state.isDrawnCard && sameInHand == 2) {
        recommendations.add(ActionRecommendation(
          action: ActionType.wei,
          targetCard: card,
          score: 90.0,
          title: '🛡️ 建议【偎牌】(${card.name})',
          explanation: '自摸对子成坎（偎牌），进牌不公开，且享有更高胡息！',
          expectedHuXi: card.isBig ? config.huXiBigWei : config.huXiSmallWei,
        ));
      }

      // D. 检查 碰 (他人打出，手中有对子)
      if (!state.isDrawnCard && sameInHand == 2) {
        // 过张不碰检查
        recommendations.add(ActionRecommendation(
          action: ActionType.peng,
          targetCard: card,
          score: 80.0,
          title: '👊 建议【碰牌】(${card.name})',
          explanation: '手中有对，碰牌能锁定一门，并获得 ${card.isBig ? config.huXiBigPeng : config.huXiSmallPeng} 胡息。',
          expectedHuXi: card.isBig ? config.huXiBigPeng : config.huXiSmallPeng,
        ));
      }

      // E. 检查 吃牌 (仅限于上家出牌或自摸，且为合法组合)
      final eatOptions = _findEatOptions(state.handCards, card);
      for (final option in eatOptions) {
        final optionName = option.map((c) => c.name).join();
        int optionHuXi = 0;
        if (card.value == 1 && option.any((c) => c.value == 2) && option.any((c) => c.value == 3)) {
          optionHuXi = card.isBig ? config.huXiBig123 : config.huXiSmall123;
        } else if (option.any((c) => c.value == 2) && option.any((c) => c.value == 7) && option.any((c) => c.value == 10)) {
          optionHuXi = card.isBig ? config.huXiBig2710 : config.huXiSmall2710;
        }

        recommendations.add(ActionRecommendation(
          action: ActionType.chi,
          targetCard: card,
          meldCards: option,
          score: 70.0 + optionHuXi,
          title: '🥢 建议【吃牌】组成 [$optionName]',
          explanation: optionHuXi > 0
              ? '吃牌可形成带胡息组合 (+${optionHuXi}胡息)，加快进张！'
              : '吃牌消化单张，形成顺子门子。',
          expectedHuXi: optionHuXi,
        ));
      }

      // F. 兜底动作：过
      recommendations.add(ActionRecommendation(
        action: ActionType.pass,
        targetCard: card,
        score: 50.0,
        title: '✋ 建议【过】',
        explanation: '此牌无法有效增加胡牌几率或容易拆散原有高息门子，建议放过。',
      ));
    }

    // 2. 如果轮到我方出牌 (生成打牌推荐排序)
    if (state.isMyTurn && state.handCards.isNotEmpty) {
      final discardSuggestions = _evaluateDiscards(state);
      recommendations.addAll(discardSuggestions);
    }

    // 按推荐评分降序排列
    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations;
  }

  /// 寻找所有合法的吃牌搭配组合
  List<List<PaoCard>> _findEatOptions(List<PaoCard> hand, PaoCard target) {
    final results = <List<PaoCard>>[];
    final cardCounts = <PaoCard, int>{};
    for (final c in hand) {
      cardCounts[c] = (cardCounts[c] ?? 0) + 1;
    }

    // 1. 一二三
    if (target.value == 1 || target.value == 2 || target.value == 3) {
      final c1 = PaoCard(value: 1, isBig: target.isBig);
      final c2 = PaoCard(value: 2, isBig: target.isBig);
      final c3 = PaoCard(value: 3, isBig: target.isBig);
      final needed = [c1, c2, c3]..remove(target);
      if (needed.every((c) => (cardCounts[c] ?? 0) > 0)) {
        results.add([c1, c2, c3]);
      }
    }

    // 2. 二七十
    if (target.value == 2 || target.value == 7 || target.value == 10) {
      final c2 = PaoCard(value: 2, isBig: target.isBig);
      final c7 = PaoCard(value: 7, isBig: target.isBig);
      final c10 = PaoCard(value: 10, isBig: target.isBig);
      final needed = [c2, c7, c10]..remove(target);
      if (needed.every((c) => (cardCounts[c] ?? 0) > 0)) {
        results.add([c2, c7, c10]);
      }
    }

    // 3. 顺子 (target-2, target-1, target)
    if (target.value >= 3) {
      final cPrev2 = PaoCard(value: target.value - 2, isBig: target.isBig);
      final cPrev1 = PaoCard(value: target.value - 1, isBig: target.isBig);
      if ((cardCounts[cPrev2] ?? 0) > 0 && (cardCounts[cPrev1] ?? 0) > 0) {
        results.add([cPrev2, cPrev1, target]);
      }
    }
    // 顺子 (target-1, target, target+1)
    if (target.value >= 2 && target.value <= 9) {
      final cPrev1 = PaoCard(value: target.value - 1, isBig: target.isBig);
      final cNext1 = PaoCard(value: target.value + 1, isBig: target.isBig);
      if ((cardCounts[cPrev1] ?? 0) > 0 && (cardCounts[cNext1] ?? 0) > 0) {
        results.add([cPrev1, target, cNext1]);
      }
    }
    // 顺子 (target, target+1, target+2)
    if (target.value <= 8) {
      final cNext1 = PaoCard(value: target.value + 1, isBig: target.isBig);
      final cNext2 = PaoCard(value: target.value + 2, isBig: target.isBig);
      if ((cardCounts[cNext1] ?? 0) > 0 && (cardCounts[cNext2] ?? 0) > 0) {
        results.add([target, cNext1, cNext2]);
      }
    }

    // 4. 绞牌 (两小一大 或 两大小一)
    final oppSuit = PaoCard(value: target.value, isBig: !target.isBig);
    // 自己有 1 张本色 + 1 张对色
    if ((cardCounts[target] ?? 0) >= 1 && (cardCounts[oppSuit] ?? 0) >= 1) {
      results.add([target, target, oppSuit]);
    }
    // 自己有 2 张对色
    if ((cardCounts[oppSuit] ?? 0) >= 2) {
      results.add([target, oppSuit, oppSuit]);
    }

    return results;
  }

  /// 评估所有手牌，给出出牌优先级建议
  List<ActionRecommendation> _evaluateDiscards(PaoGameState state) {
    final list = <ActionRecommendation>[];
    final uniqueCards = state.handCards.toSet().toList();

    for (final card in uniqueCards) {
      double score = 50.0;
      final reasons = <String>[];

      final countInHand = state.handCards.where((c) => c == card).length;
      final revealedCount = state.getRevealedCount(card);

      // A. 结构分析（坎/对子绝不轻易打出）
      if (countInHand >= 3) {
        score -= 40.0;
        reasons.add('此牌手中已有3张成坎，绝对保留');
      } else if (countInHand == 2) {
        score -= 20.0;
        reasons.add('手中有对，留作碰或将');
      }

      // B. 顺子关联度
      bool hasNeighbor = false;
      for (final offset in [-2, -1, 1, 2]) {
        final neighborVal = card.value + offset;
        if (neighborVal >= 1 && neighborVal <= 10) {
          final neighbor = PaoCard(value: neighborVal, isBig: card.isBig);
          if (state.handCards.contains(neighbor)) {
            hasNeighbor = true;
            break;
          }
        }
      }
      if (!hasNeighbor && countInHand == 1) {
        score += 25.0;
        reasons.add('孤张无搭，优先舍弃');
      }

      // C. 红字策略 (常德跑胡子红胡加番，红字二七十价值极高)
      if (card.isRed) {
        if (state.totalRedCardCount >= 8) {
          score -= 15.0;
          reasons.add('当前红字充足，正在做红胡，保留红字');
        } else {
          score -= 5.0;
        }
      }

      // D. 安全度评估 (已出现张数越多越安全)
      if (revealedCount >= 3) {
        score += 15.0;
        reasons.add('场上已现 $revealedCount 张，绝张熟牌非常安全');
      } else if (revealedCount == 1) {
        score -= 5.0;
        reasons.add('场上生牌，需防对手碰/吃');
      }

      list.add(ActionRecommendation(
        action: ActionType.discard,
        targetCard: card,
        score: score.clamp(0.0, 100.0),
        title: '🎴 建议出牌 [${card.name}]',
        explanation: reasons.join('；'),
      ));
    }

    return list;
  }
}
