import '../models/meld.dart';
import '../models/rule_config.dart';

/// 名堂计算结果
class MingTangResult {
  final List<String> names;
  final int multiplier; // 番数倍率
  final int additionalHuXi;

  const MingTangResult({
    required this.names,
    required this.multiplier,
    required this.additionalHuXi,
  });
}

/// 跑胡子胡息与名堂计算器
class HuXiCalculator {
  final RuleConfig config;

  HuXiCalculator(this.config);

  /// 计算单个门子（搭子）的胡息
  int calculateMeldHuXi(Meld meld) {
    if (meld.cards.isEmpty) return 0;
    final isBig = meld.cards.first.isBig;

    switch (meld.type) {
      case MeldType.ti:
        return isBig ? config.huXiBigTi : config.huXiSmallTi;
      case MeldType.pao:
        return isBig ? config.huXiBigPao : config.huXiSmallPao;
      case MeldType.wei:
        return isBig ? config.huXiBigWei : config.huXiSmallWei;
      case MeldType.kan:
        return isBig ? config.huXiBigKan : config.huXiSmallKan;
      case MeldType.peng:
        return isBig ? config.huXiBigPeng : config.huXiSmallPeng;
      case MeldType.yiErSan:
        return isBig ? config.huXiBig123 : config.huXiSmall123;
      case MeldType.erQiShi:
        return isBig ? config.huXiBig2710 : config.huXiSmall2710;
      case MeldType.jiao:
      case MeldType.shunZi:
      case MeldType.duiZi:
      case MeldType.danZhang:
        return 0; // 绞牌、普通顺子、对子一般无胡息
    }
  }

  /// 计算一组门子的总基础胡息
  int calculateTotalBaseHuXi(List<Meld> melds) {
    int total = 0;
    for (final meld in melds) {
      total += calculateMeldHuXi(meld);
    }
    return total;
  }

  /// 计算名堂番数与附加胡息（常德跑胡子全名堂）
  MingTangResult evaluateMingTang({
    required List<Meld> allMelds,
    required bool isZiMo,
  }) {
    final names = <String>[];
    int multiplier = 1;
    int extraHuXi = 0;

    // 统计红字数量
    int redCount = 0;
    for (final m in allMelds) {
      redCount += m.cards.where((c) => c.isRed).length;
    }

    // 1. 十三红 / 红乌
    if (config.enableShiSanHong && redCount >= 13) {
      names.add('十三红');
      multiplier *= 4;
    }
    // 2. 红胡 (红字 >= 10)
    else if (config.enableHongHu && redCount >= 10) {
      names.add('红胡 (红字$redCount张)');
      multiplier *= 2;
    }
    // 3. 点胡 (红字恰好 1 张)
    else if (config.enableDianHu && redCount == 1) {
      names.add('点胡 (独红)');
      multiplier *= 3;
    }
    // 4. 黑胡 / 乌胡 (红字 0 张)
    else if (config.enableHeiHu && redCount == 0) {
      names.add('黑胡 (乌胡)');
      multiplier *= 4;
    }

    // 5. 碰碰胡 (全碰/提/跑/偎/坎/绞，无顺子)
    if (config.enablePengPengHu) {
      bool isPengPeng = allMelds.every((m) =>
          m.type == MeldType.ti ||
          m.type == MeldType.pao ||
          m.type == MeldType.wei ||
          m.type == MeldType.kan ||
          m.type == MeldType.peng ||
          m.type == MeldType.jiao ||
          m.type == MeldType.duiZi);
      if (isPengPeng && allMelds.isNotEmpty) {
        names.add('碰碰胡');
        multiplier *= 2;
      }
    }

    // 6. 自摸
    if (config.enableZiMo && isZiMo) {
      names.add('自摸');
      extraHuXi += 1; // 增加 1 囤或加番
    }

    return MingTangResult(
      names: names,
      multiplier: multiplier,
      additionalHuXi: extraHuXi,
    );
  }
}
