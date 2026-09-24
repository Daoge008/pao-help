import 'card.dart';
import 'meld.dart';

/// 牌局完整状态快照
class PaoGameState {
  final List<PaoCard> handCards;           // 手牌
  final List<Meld> exposedMelds;           // 我已经亮出的门子 (提/跑/偎/碰/吃)
  final List<Meld> opponentMelds;          // 其他两家亮出的门子
  final List<PaoCard> tableDiscards;       // 桌面已打出的弃牌
  final PaoCard? currentCard;              // 当前刚翻出或刚打出的一张牌
  final bool isMyTurn;                     // 是否到我出牌
  final bool isDrawnCard;                  // 当前牌是否是摸出来的（摸出来的不能直接放过提/跑）

  const PaoGameState({
    required this.handCards,
    this.exposedMelds = const [],
    this.opponentMelds = const [],
    this.tableDiscards = const [],
    this.currentCard,
    this.isMyTurn = true,
    this.isDrawnCard = false,
  });

  /// 统计某张牌已经在明面（手牌+明门子+对手明门子+弃牌）上出现的数量
  int getRevealedCount(PaoCard card) {
    int count = 0;
    count += handCards.where((c) => c == card).length;
    for (final m in exposedMelds) {
      count += m.cards.where((c) => c == card).length;
    }
    for (final m in opponentMelds) {
      count += m.cards.where((c) => c == card).length;
    }
    count += tableDiscards.where((c) => c == card).length;
    if (currentCard == card) count += 1;
    return count;
  }

  /// 某张牌在未现牌（底牌+对手暗手牌）中的剩余估算数量（单种牌最多 4 张）
  int getRemainingUnseenCount(PaoCard card) {
    final revealed = getRevealedCount(card);
    final remain = 4 - revealed;
    return remain > 0 ? remain : 0;
  }

  /// 当前手中与门子中的总红字数量
  int get totalRedCardCount {
    int count = handCards.where((c) => c.isRed).length;
    for (final m in exposedMelds) {
      count += m.cards.where((c) => c.isRed).length;
    }
    return count;
  }

  PaoGameState copyWith({
    List<PaoCard>? handCards,
    List<Meld>? exposedMelds,
    List<Meld>? opponentMelds,
    List<PaoCard>? tableDiscards,
    PaoCard? currentCard,
    bool? isMyTurn,
    bool? isDrawnCard,
  }) {
    return PaoGameState(
      handCards: handCards ?? this.handCards,
      exposedMelds: exposedMelds ?? this.exposedMelds,
      opponentMelds: opponentMelds ?? this.opponentMelds,
      tableDiscards: tableDiscards ?? this.tableDiscards,
      currentCard: currentCard ?? this.currentCard,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      isDrawnCard: isDrawnCard ?? this.isDrawnCard,
    );
  }
}
