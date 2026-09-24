/// 跑胡子规则配置模型（以湖南常德跑胡子为默认模板，支持灵活自定义配置）
class RuleConfig {
  // 基础起胡门槛
  final int minHuXi;             // 起胡胡息，常德跑胡子通常为 15 胡（亦可设置 10 或 21）
  final int maxCardsPerHand;     // 正常手牌门子数通常 7 门加一对，共 21 张/20 张

  // 胡息分值表 - 小字
  final int huXiSmallKan;        // 小字暗坎胡息 (默认 3)
  final int huXiSmallPeng;       // 小字碰胡息 (默认 1)
  final int huXiSmallWei;        // 小字偎/臭偎胡息 (默认 4)
  final int huXiSmallTi;         // 小字提胡息 (默认 9)
  final int huXiSmallPao;        // 小字跑胡息 (默认 8)
  final int huXiSmall123;        // 小字一二三胡息 (默认 3)
  final int huXiSmall2710;       // 小字二七十胡息 (默认 3)

  // 胡息分值表 - 大字
  final int huXiBigKan;          // 大字暗坎胡息 (默认 6)
  final int huXiBigPeng;         // 大字碰胡息 (默认 3)
  final int huXiBigWei;          // 大字偎/臭偎胡息 (默认 8)
  final int huXiBigTi;           // 大字提胡息 (默认 12)
  final int huXiBigPao;          // 大字跑胡息 (默认 12)
  final int huXiBig123;          // 大字壹贰叁胡息 (默认 6)
  final int huXiBig2710;         // 大字贰柒拾胡息 (默认 6)

  // 名堂番数与倍率开关 (常德全名堂)
  final bool enableHongHu;       // 红胡 (红字 >= 10 张，翻 2 倍)
  final bool enableDianHu;       // 点胡 (红字 == 1 张，翻 3 倍)
  final bool enableHeiHu;        // 黑胡/乌胡 (红字 == 0 张，翻 4 倍)
  final bool enableShiSanHong;   // 十三红 (红字 >= 13 张，翻 4 倍)
  final bool enablePengPengHu;   // 碰碰胡 (无顺子，翻 2 倍)
  final bool enableZiMo;         // 自摸 (加番或加 1 囤)

  // 出牌与进牌限制
  final bool chouPaiLimit;       // 臭牌不可吃（自己曾弃过的牌或同家路过的牌不可吃）
  final bool guoZhangLimit;      // 过张不碰（过手不碰）
  final bool biPaiRule;          // 比牌规则（有同类顺子必须一起吃下）

  const RuleConfig({
    this.minHuXi = 15,
    this.maxCardsPerHand = 21,
    this.huXiSmallKan = 3,
    this.huXiSmallPeng = 1,
    this.huXiSmallWei = 4,
    this.huXiSmallTi = 9,
    this.huXiSmallPao = 8,
    this.huXiSmall123 = 3,
    this.huXiSmall2710 = 3,
    this.huXiBigKan = 6,
    this.huXiBigPeng = 3,
    this.huXiBigWei = 8,
    this.huXiBigTi = 12,
    this.huXiBigPao = 12,
    this.huXiBig123 = 6,
    this.huXiBig2710 = 6,
    this.enableHongHu = true,
    this.enableDianHu = true,
    this.enableHeiHu = true,
    this.enableShiSanHong = true,
    this.enablePengPengHu = true,
    this.enableZiMo = true,
    this.chouPaiLimit = true,
    this.guoZhangLimit = true,
    this.biPaiRule = true,
  });

  /// 预设：常德跑胡子（标准全名堂 15 胡）
  factory RuleConfig.changdeStandard() {
    return const RuleConfig(
      minHuXi: 15,
      enableHongHu: true,
      enableDianHu: true,
      enableHeiHu: true,
      enableShiSanHong: true,
      enablePengPengHu: true,
      enableZiMo: true,
      chouPaiLimit: true,
      guoZhangLimit: true,
      biPaiRule: true,
    );
  }

  /// 预设：快速碰胡/简易玩法（10 胡起）
  factory RuleConfig.quick10Hu() {
    return const RuleConfig(
      minHuXi: 10,
      enableHongHu: true,
      enableDianHu: true,
      enableHeiHu: true,
      enableShiSanHong: false,
      enablePengPengHu: true,
      enableZiMo: true,
      chouPaiLimit: false,
      guoZhangLimit: false,
      biPaiRule: false,
    );
  }

  RuleConfig copyWith({
    int? minHuXi,
    int? maxCardsPerHand,
    int? huXiSmallKan,
    int? huXiSmallPeng,
    int? huXiSmallWei,
    int? huXiSmallTi,
    int? huXiSmallPao,
    int? huXiSmall123,
    int? huXiSmall2710,
    int? huXiBigKan,
    int? huXiBigPeng,
    int? huXiBigWei,
    int? huXiBigTi,
    int? huXiBigPao,
    int? huXiBig123,
    int? huXiBig2710,
    bool? enableHongHu,
    bool? enableDianHu,
    bool? enableHeiHu,
    bool? enableShiSanHong,
    bool? enablePengPengHu,
    bool? enableZiMo,
    bool? chouPaiLimit,
    bool? guoZhangLimit,
    bool? biPaiRule,
  }) {
    return RuleConfig(
      minHuXi: minHuXi ?? this.minHuXi,
      maxCardsPerHand: maxCardsPerHand ?? this.maxCardsPerHand,
      huXiSmallKan: huXiSmallKan ?? this.huXiSmallKan,
      huXiSmallPeng: huXiSmallPeng ?? this.huXiSmallPeng,
      huXiSmallWei: huXiSmallWei ?? this.huXiSmallWei,
      huXiSmallTi: huXiSmallTi ?? this.huXiSmallTi,
      huXiSmallPao: huXiSmallPao ?? this.huXiSmallPao,
      huXiSmall123: huXiSmall123 ?? this.huXiSmall123,
      huXiSmall2710: huXiSmall2710 ?? this.huXiSmall2710,
      huXiBigKan: huXiBigKan ?? this.huXiBigKan,
      huXiBigPeng: huXiBigPeng ?? this.huXiBigPeng,
      huXiBigWei: huXiBigWei ?? this.huXiBigWei,
      huXiBigTi: huXiBigTi ?? this.huXiBigTi,
      huXiBigPao: huXiBigPao ?? this.huXiBigPao,
      huXiBig123: huXiBig123 ?? this.huXiBig123,
      huXiBig2710: huXiBig2710 ?? this.huXiBig2710,
      enableHongHu: enableHongHu ?? this.enableHongHu,
      enableDianHu: enableDianHu ?? this.enableDianHu,
      enableHeiHu: enableHeiHu ?? this.enableHeiHu,
      enableShiSanHong: enableShiSanHong ?? this.enableShiSanHong,
      enablePengPengHu: enablePengPengHu ?? this.enablePengPengHu,
      enableZiMo: enableZiMo ?? this.enableZiMo,
      chouPaiLimit: chouPaiLimit ?? this.chouPaiLimit,
      guoZhangLimit: guoZhangLimit ?? this.guoZhangLimit,
      biPaiRule: biPaiRule ?? this.biPaiRule,
    );
  }
}
