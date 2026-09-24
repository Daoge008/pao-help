import 'dart:math';
import '../models/card.dart';
import '../models/detected_card.dart';
import '../models/game_state.dart';

/// 帧历史记录项（用于时间平滑）
class _TrackedItem {
  final int id;
  PaoCard card;
  double x;
  double y;
  double width;
  double height;
  CardZone zone;
  int hitStreak = 1;
  int missedStreak = 0;

  _TrackedItem({
    required this.id,
    required this.card,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zone,
  });
}

/// 连续视觉空间追踪与去抖动平滑器
class SpatialTracker {
  int _nextTrackId = 1;
  final List<_TrackedItem> _activeTracks = [];

  // 平滑与确认阈值
  static const int minHitsToConfirm = 3;   // 连续出现至少3帧才确认为稳定牌
  static const int maxMissesToDrop = 4;    // 连续丢失超过4帧才移除
  static const double matchDistanceThreshold = 0.08; // 空间中心欧氏距离匹配门槛 (归一化坐标)

  /// 根据物理卡牌在视野中的垂直分布自动划分区域
  static CardZone determineZone(double y) {
    if (y >= 0.62) {
      return CardZone.hand;          // 屏幕下半部为手牌区
    } else if (y >= 0.38) {
      return CardZone.currentCard;   // 屏幕中央偏下为摸出/打出的即时焦点牌
    } else {
      return CardZone.tableDiscards; // 屏幕上半部为桌面公共牌/弃牌区
    }
  }

  /// 处理当前帧原始检测结果，返回平滑去抖后的稳定卡牌列表
  List<DetectedCard> update(List<DetectedCard> rawDetections) {
    final matchedTracks = <_TrackedItem>{};

    for (final raw in rawDetections) {
      _TrackedItem? bestTrack;
      double minDistance = double.infinity;

      for (final track in _activeTracks) {
        if (matchedTracks.contains(track)) continue;
        if (track.card != raw.card) continue; // 同种牌才匹配

        // 计算中心距离
        final dx = track.x - raw.x;
        final dy = track.y - raw.y;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < minDistance && dist < matchDistanceThreshold) {
          minDistance = dist;
          bestTrack = track;
        }
      }

      if (bestTrack != null) {
        matchedTracks.add(bestTrack);
        // 指数加权平均平滑坐标，消除抖动
        bestTrack.x = bestTrack.x * 0.6 + raw.x * 0.4;
        bestTrack.y = bestTrack.y * 0.6 + raw.y * 0.4;
        bestTrack.width = bestTrack.width * 0.6 + raw.width * 0.4;
        bestTrack.height = bestTrack.height * 0.6 + raw.height * 0.4;
        bestTrack.zone = determineZone(bestTrack.y);
        bestTrack.hitStreak++;
        bestTrack.missedStreak = 0;
      } else {
        // 新建追踪目标
        final newZone = determineZone(raw.y);
        final item = _TrackedItem(
          id: _nextTrackId++,
          card: raw.card,
          x: raw.x,
          y: raw.y,
          width: raw.width,
          height: raw.height,
          zone: newZone,
        );
        _activeTracks.add(item);
        matchedTracks.add(item);
      }
    }

    // 更新未匹配项的漏检计数
    _activeTracks.removeWhere((track) {
      if (!matchedTracks.contains(track)) {
        track.missedStreak++;
        return track.missedStreak > maxMissesToDrop;
      }
      return false;
    });

    // 过滤出达到稳定置信度的卡牌
    final confirmedCards = <DetectedCard>[];
    for (final track in _activeTracks) {
      if (track.hitStreak >= minHitsToConfirm) {
        confirmedCards.add(DetectedCard(
          card: track.card,
          confidence: 0.95,
          x: track.x,
          y: track.y,
          width: track.width,
          height: track.height,
          zone: track.zone,
          trackId: track.id,
        ));
      }
    }

    return confirmedCards;
  }

  /// 从平滑确认的卡牌集合中还原牌局状态
  PaoGameState buildGameState(List<DetectedCard> confirmedCards) {
    final hand = <PaoCard>[];
    final discards = <PaoCard>[];
    PaoCard? current;

    for (final item in confirmedCards) {
      switch (item.zone) {
        case CardZone.hand:
          hand.add(item.card);
          break;
        case CardZone.tableDiscards:
          discards.add(item.card);
          break;
        case CardZone.currentCard:
          current = item.card;
          break;
        case CardZone.melds:
          // 预留已摆牌区域
          break;
      }
    }
    hand.sort();

    return PaoGameState(
      handCards: hand,
      tableDiscards: discards,
      currentCard: current,
      isMyTurn: current == null, // 如果中央无即时牌，默认为自己出牌轮
    );
  }

  void reset() {
    _activeTracks.clear();
    _nextTrackId = 1;
  }
}
