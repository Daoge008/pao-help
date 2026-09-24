/// 跑胡子（字牌）卡牌模型
class PaoCard implements Comparable<PaoCard> {
  final int value; // 1 ~ 10
  final bool isBig; // true: 大字 (壹~拾), false: 小字 (一~十)

  const PaoCard({required this.value, required this.isBig})
      : assert(value >= 1 && value <= 10, '卡牌面值必须在 1 到 10 之间');

  /// 是否为红字（二、七、十 及 贰、柒、拾 为红字）
  bool get isRed => value == 2 || value == 7 || value == 10;

  /// 卡牌中文名称
  String get name {
    if (isBig) {
      const bigNames = ['壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖', '拾'];
      return bigNames[value - 1];
    } else {
      const smallNames = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
      return smallNames[value - 1];
    }
  }

  /// 类别代码 (s1~s10 代表小一至小十, b1~b10 代表大壹至大拾)
  String get code => '${isBig ? 'b' : 's'}$value';

  /// 从代码解析 (如 "s1", "b10")
  factory PaoCard.fromCode(String code) {
    final isBig = code.startsWith('b') || code.startsWith('B');
    final val = int.parse(code.substring(1));
    return PaoCard(value: val, isBig: isBig);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaoCard &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          isBig == other.isBig;

  @override
  int get hashCode => value.hashCode ^ (isBig ? 100 : 0).hashCode;

  @override
  int compareTo(PaoCard other) {
    if (isBig != other.isBig) {
      return isBig ? 1 : -1; // 小字在前，大字在后
    }
    return value.compareTo(other.value);
  }

  @override
  String toString() => name;

  /// 全副牌标准 20 种卡牌定义
  static List<PaoCard> get allCards {
    final list = <PaoCard>[];
    for (int i = 1; i <= 10; i++) {
      list.add(PaoCard(value: i, isBig: false));
    }
    for (int i = 1; i <= 10; i++) {
      list.add(PaoCard(value: i, isBig: true));
    }
    return list;
  }
}
