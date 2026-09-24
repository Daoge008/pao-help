import 'package:flutter_test/flutter_test.dart';
import 'package:pao_help/models/card.dart';
import 'package:pao_help/models/meld.dart';
import 'package:pao_help/models/rule_config.dart';
import 'package:pao_help/models/game_state.dart';
import 'package:pao_help/engine/huxi_calculator.dart';
import 'package:pao_help/engine/hu_checker.dart';
import 'package:pao_help/engine/decision_engine.dart';

void main() {
  group('跑胡子卡牌基础测试', () {
    test('卡牌生成与红字判定', () {
      final s2 = PaoCard(value: 2, isBig: false);
      final s7 = PaoCard(value: 7, isBig: false);
      final s10 = PaoCard(value: 10, isBig: false);
      final b2 = PaoCard(value: 2, isBig: true);
      final b7 = PaoCard(value: 7, isBig: true);
      final b10 = PaoCard(value: 10, isBig: true);

      expect(s2.isRed, isTrue);
      expect(s7.isRed, isTrue);
      expect(s10.isRed, isTrue);
      expect(b2.isRed, isTrue);
      expect(b7.isRed, isTrue);
      expect(b10.isRed, isTrue);

      final s1 = PaoCard(value: 1, isBig: false);
      final b8 = PaoCard(value: 8, isBig: true);
      expect(s1.isRed, isFalse);
      expect(b8.isRed, isFalse);
      expect(s1.name, '一');
      expect(b8.name, '捌');
      expect(b10.name, '拾');
    });

    test('全部 20 种卡牌生成数量', () {
      final all = PaoCard.allCards;
      expect(all.length, equals(20));
    });
  });

  group('常德跑胡子胡息计算测试', () {
    final config = RuleConfig.changdeStandard();
    final calculator = HuXiCalculator(config);

    test('大字与小字坎/碰/提/偎胡息', () {
      final smallKan = Meld(
        type: MeldType.kan,
        cards: [
          PaoCard(value: 5, isBig: false),
          PaoCard(value: 5, isBig: false),
          PaoCard(value: 5, isBig: false),
        ],
      );
      expect(calculator.calculateMeldHuXi(smallKan), equals(3));

      final bigKan = Meld(
        type: MeldType.kan,
        cards: [
          PaoCard(value: 5, isBig: true),
          PaoCard(value: 5, isBig: true),
          PaoCard(value: 5, isBig: true),
        ],
      );
      expect(calculator.calculateMeldHuXi(bigKan), equals(6));

      final bigTi = Meld(
        type: MeldType.ti,
        cards: [
          PaoCard(value: 10, isBig: true),
          PaoCard(value: 10, isBig: true),
          PaoCard(value: 10, isBig: true),
          PaoCard(value: 10, isBig: true),
        ],
      );
      expect(calculator.calculateMeldHuXi(bigTi), equals(12));

      final big123 = Meld(
        type: MeldType.yiErSan,
        cards: [
          PaoCard(value: 1, isBig: true),
          PaoCard(value: 2, isBig: true),
          PaoCard(value: 3, isBig: true),
        ],
      );
      expect(calculator.calculateMeldHuXi(big123), equals(6));
    });
  });

  group('胡牌检查与决策建议测试', () {
    final config = RuleConfig.changdeStandard();
    final huChecker = HuChecker(config);
    final decisionEngine = DecisionEngine(config);

    test('合法 15 胡以上手牌胡牌判定', () {
      final hand = [
        PaoCard(value: 1, isBig: true),
        PaoCard(value: 2, isBig: true),
        PaoCard(value: 3, isBig: true),
        PaoCard(value: 2, isBig: true),
        PaoCard(value: 7, isBig: true),
        PaoCard(value: 10, isBig: true),
        PaoCard(value: 1, isBig: false),
        PaoCard(value: 2, isBig: false),
        PaoCard(value: 3, isBig: false),
        PaoCard(value: 5, isBig: true),
      ];

      final incoming = PaoCard(value: 5, isBig: true);
      final result = huChecker.checkCanHu(
        handCards: hand,
        exposedMelds: [],
        incomingCard: incoming,
        isZiMo: true,
      );

      expect(result.canHu, isTrue);
      expect(result.totalHuXi, greaterThanOrEqualTo(15));
    });

    test('出牌决策与提跑动作优先级判定', () {
      final target = PaoCard(value: 8, isBig: true);
      final state = PaoGameState(
        handCards: [
          target, target, target,
          PaoCard(value: 1, isBig: false),
        ],
        currentCard: target,
        isMyTurn: false,
        isDrawnCard: false,
      );

      final recommendations = decisionEngine.analyze(state);
      expect(recommendations.isNotEmpty, isTrue);
      expect(recommendations.first.action, equals(ActionType.pao));
    });
  });
}
