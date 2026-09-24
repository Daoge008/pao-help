import 'card.dart';

/// 门子（搭子）类型
enum MeldType {
  ti,       // 提 (4张同牌，起手或暗摸)
  pao,      // 跑 (4张同牌，亮牌碰跑或坎跑)
  wei,      // 偎 (3张同牌，自己摸到暗亮)
  kan,      // 坎 (3张同牌，手中暗坎)
  peng,     // 碰 (3张同牌，他人出牌碰亮)
  jiao,     // 绞牌 (如两小一大、两大小一，同点数)
  yiErSan,  // 一二三 / 壹贰叁 (特殊顺子，有胡息)
  erQiShi,  // 二七十 / 贰柒拾 (特殊顺子，有胡息)
  shunZi,   // 普通顺子 (如 2-3-4，无胡息)
  duiZi,    // 对子 (半块/将牌，2张相同)
  danZhang, // 单张
}

/// 门子（搭子）对象
class Meld {
  final MeldType type;
  final List<PaoCard> cards;
  final bool isExposed; // 是否已经在桌面上亮出

  const Meld({
    required this.type,
    required this.cards,
    this.isExposed = false,
  });

  /// 描述信息
  String get displayName {
    switch (type) {
      case MeldType.ti:
        return '提 (${cards.first.name})';
      case MeldType.pao:
        return '跑 (${cards.first.name})';
      case MeldType.wei:
        return '偎 (${cards.first.name})';
      case MeldType.kan:
        return '坎 (${cards.first.name})';
      case MeldType.peng:
        return '碰 (${cards.first.name})';
      case MeldType.jiao:
        return '绞牌 (${cards.map((c) => c.name).join()})';
      case MeldType.yiErSan:
        return '一二三 (${cards.map((c) => c.name).join()})';
      case MeldType.erQiShi:
        return '二七十 (${cards.map((c) => c.name).join()})';
      case MeldType.shunZi:
        return '顺子 (${cards.map((c) => c.name).join()})';
      case MeldType.duiZi:
        return '对子 (${cards.first.name}对)';
      case MeldType.danZhang:
        return '单张 (${cards.first.name})';
    }
  }

  @override
  String toString() => displayName;
}
