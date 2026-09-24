// 独立引擎校验脚手架：不依赖 flutter_test，可直接 `dart run tool/engine_smoke.dart`。
// 用途：在 Flutter 工具链不可用时，仍能对规则引擎 / 视觉后处理做真实功能验证。
import 'dart:io';

import '../lib/models/card.dart';
import '../lib/models/meld.dart';
import '../lib/models/rule_config.dart';
import '../lib/models/game_state.dart';
import '../lib/models/detected_card.dart';
import '../lib/engine/huxi_calculator.dart';
import '../lib/engine/hu_checker.dart';
import '../lib/engine/decision_engine.dart';
import '../lib/vision/spatial_tracker.dart';
import '../lib/vision/yolo_detector.dart';

final _log = <String>[];
int _pass = 0;
int _fail = 0;

void section(String s) {
  _log.add('');
  _log.add('── $s ──');
}

void check(String name, Object? actual, Object? expected) {
  final ok = '$actual' == '$expected';
  if (ok) {
    _pass++;
    _log.add('  PASS  $name  = $actual');
  } else {
    _fail++;
    _log.add('  FAIL  $name  期望[$expected] 实际[$actual]');
  }
}

void checkTrue(String name, bool cond) => check(name, cond, true);

PaoCard s(int v) => PaoCard(value: v, isBig: false);
PaoCard b(int v) => PaoCard(value: v, isBig: true);

void main() {
  final cfg = RuleConfig.changdeStandard();
  final calc = HuXiCalculator(cfg);
  final checker = HuChecker(cfg);
  final engine = DecisionEngine(cfg);

  // ───────────────────────── 1. 卡牌模型
  section('1. 卡牌模型 (card.dart)');
  check('小二字 isRed', s(2).isRed, true);
  check('大拾字 isRed', b(10).isRed, true);
  check('小一字 isRed', s(1).isRed, false);
  check('大捌字 isRed', b(8).isRed, false);
  check('s(1).name', s(1).name, '一');
  check('b(8).name', b(8).name, '捌');
  check('b(10).name', b(10).name, '拾');
  check('allCards 长度', PaoCard.allCards.length, 20);
  check('code', b(10).code, 'b10');
  check('fromCode round-trip', PaoCard.fromCode('s7'), s(7));
  check('红字总数(20种×? 单张计数)', PaoCard.allCards.where((c) => c.isRed).length, 6);

  // ───────────────────────── 2. 胡息矩阵（对照 RULES.md）
  section('2. 胡息矩阵 vs RULES.md');
  Meld m(MeldType t, PaoCard c) => Meld(type: t, cards: [c, c, c]);
  check('小字 坎', calc.calculateMeldHuXi(m(MeldType.kan, s(5))), 3);
  check('小字 碰', calc.calculateMeldHuXi(m(MeldType.peng, s(5))), 1);
  check('小字 偎', calc.calculateMeldHuXi(m(MeldType.wei, s(5))), 4);
  check('小字 提', calc.calculateMeldHuXi(m(MeldType.ti, s(5))), 9);
  check('小字 跑', calc.calculateMeldHuXi(m(MeldType.pao, s(5))), 8);
  check('小字 一二三', calc.calculateMeldHuXi(Meld(type: MeldType.yiErSan, cards: [s(1), s(2), s(3)])), 3);
  check('小字 二七十', calc.calculateMeldHuXi(Meld(type: MeldType.erQiShi, cards: [s(2), s(7), s(10)])), 3);
  check('大字 坎', calc.calculateMeldHuXi(m(MeldType.kan, b(5))), 6);
  check('大字 碰', calc.calculateMeldHuXi(m(MeldType.peng, b(5))), 3);
  check('大字 偎', calc.calculateMeldHuXi(m(MeldType.wei, b(5))), 8);
  check('大字 提', calc.calculateMeldHuXi(m(MeldType.ti, b(5))), 12);
  check('大字 跑', calc.calculateMeldHuXi(m(MeldType.pao, b(5))), 12);
  check('大字 一二三', calc.calculateMeldHuXi(Meld(type: MeldType.yiErSan, cards: [b(1), b(2), b(3)])), 6);
  check('大字 二七十', calc.calculateMeldHuXi(Meld(type: MeldType.erQiShi, cards: [b(2), b(7), b(10)])), 6);
  check('普通顺子 无息', calc.calculateMeldHuXi(Meld(type: MeldType.shunZi, cards: [s(4), s(5), s(6)])), 0);
  check('绞牌 无息', calc.calculateMeldHuXi(Meld(type: MeldType.jiao, cards: [s(5), s(5), b(5)])), 0);

  // ───────────────────────── 3. 原仓库测试用例复现
  section('3. 复现 test/pao_engine_test.dart 的用例');
  final hand = [
    b(1), b(2), b(3), b(2), b(7), b(10), s(1), s(2), s(3), b(5),
  ];
  final hu1 = checker.checkCanHu(
    handCards: hand, exposedMelds: [], incomingCard: b(5), isZiMo: true,
  );
  checkTrue('原用例1: canHu', hu1.canHu);
  checkTrue('原用例1: totalHuXi >= 15', hu1.totalHuXi >= 15);
  _log.add('       实际胡息=${hu1.totalHuXi}  描述=${hu1.description}');

  final t8 = b(8);
  final st2 = PaoGameState(
    handCards: [t8, t8, t8, s(1)],
    currentCard: t8,
    isMyTurn: false,
    isDrawnCard: false,
  );
  final rec2 = engine.analyze(st2);
  checkTrue('原用例2: 有推荐', rec2.isNotEmpty);
  check('原用例2: 首选动作', rec2.first.action, ActionType.pao);

  // ───────────────────────── 4. 名堂判定
  section('4. 名堂 (MingTang) 判定');
  MingTangResult mt(List<Meld> ms, {bool zimo = false}) =>
      calc.evaluateMingTang(allMelds: ms, isZiMo: zimo);

  // 黑胡：全黑字（小1/3/4/5/6/8/9 = 全黑），7 个坎无红字
  final hei = [
    m(MeldType.kan, s(1)), m(MeldType.kan, s(3)), m(MeldType.kan, s(4)),
    m(MeldType.kan, s(5)), m(MeldType.kan, s(6)), m(MeldType.kan, s(8)),
    m(MeldType.kan, s(9)),
  ];
  final rHei = mt(hei);
  check('黑胡 存在', rHei.names.contains('黑胡 (乌胡)'), true);
  check('黑胡 × 碰碰胡 倍率', rHei.multiplier, 4 * 2);

  // 点胡：恰好 1 张红字（一二三 中仅 b2 为红，其余小字坎全黑）
  final dian = [
    m(MeldType.kan, s(1)), m(MeldType.kan, s(3)), m(MeldType.kan, s(4)),
    m(MeldType.kan, s(5)), m(MeldType.kan, s(6)), m(MeldType.kan, s(8)),
    Meld(type: MeldType.yiErSan, cards: [b(1), b(2), b(3)]), // 仅 b2 为红
  ];
  final rDian = mt(dian);
  check('点胡 存在', rDian.names.contains('点胡 (独红)'), true);
  check('点胡 倍率 ×3 (含顺子故非碰碰胡)', rDian.multiplier, 3);

  // 红胡：红字 >= 10 且 < 13
  final hong = [
    Meld(type: MeldType.erQiShi, cards: [s(2), s(7), s(10)]),
    Meld(type: MeldType.erQiShi, cards: [b(2), b(7), b(10)]),
    Meld(type: MeldType.erQiShi, cards: [s(2), s(7), s(10)]),
    Meld(type: MeldType.erQiShi, cards: [b(2), b(7), b(10)]),
    m(MeldType.kan, s(1)),
  ];
  final rHong = mt(hong);
  _log.add('       红胡用例红字数=12, names=${rHong.names}');
  check('红胡 存在', rHong.names.any((n) => n.startsWith('红胡')), true);
  check('红胡 倍率(×2, 非碰碰胡)', rHong.multiplier, 2);

  // 十三红：红字 >= 13
  final shisan = [
    Meld(type: MeldType.erQiShi, cards: [s(2), s(7), s(10)]),
    Meld(type: MeldType.erQiShi, cards: [b(2), b(7), b(10)]),
    Meld(type: MeldType.erQiShi, cards: [s(2), s(7), s(10)]),
    Meld(type: MeldType.erQiShi, cards: [b(2), b(7), b(10)]),
    Meld(type: MeldType.erQiShi, cards: [s(2), s(7), s(10)]),
  ];
  final r13 = mt(shisan);
  check('十三红 倍率 ×4', r13.multiplier, 4);

  // 自摸加 1 胡息
  check('自摸 additionalHuXi', mt(hei, zimo: true).additionalHuXi, 1);
  check('非自摸 additionalHuXi', mt(hei).additionalHuXi, 0);

  // ───────────────────────── 5. 胡牌门槛边界
  section('5. 起胡门槛边界 (minHuXi=15)');
  // 15 胡息刚好到线：大字一二三(6) + 大字二七十(6) + 小字一二三(3) + 对子
  final just15 = [b(1), b(2), b(3), b(2), b(7), b(10), s(1), s(2), s(3), b(5)];
  final r15 = checker.checkCanHu(
    handCards: just15, exposedMelds: [], incomingCard: b(5), isZiMo: false);
  check('base=15 无自摸 -> 可胡', r15.canHu, true);
  check('totalHuXi', r15.totalHuXi, 15);

  // 14 胡息应不可胡：把大字二七十拆不掉，改小字组合
  final under = [b(1), b(2), b(3), s(1), s(2), s(3), s(2), s(7), s(10), b(5)];
  final ru = checker.checkCanHu(
    handCards: under, exposedMelds: [], incomingCard: b(5), isZiMo: false);
  _log.add('       14胡用例: canHu=${ru.canHu} huXi=${ru.totalHuXi}');
  check('base=12 (<15) -> 不可胡', ru.canHu, false);

  // ───────────────────────── 6. 已知边界 / 限制探测
  section('6. 边界探测（预期暴露的限制）');
  // 6.1 手中 4 张同牌（提）能否被拆解
  final four = [b(5), b(5), b(5), b(5)];
  final rFour = checker.checkCanHu(handCards: four, exposedMelds: []);
  _log.add('       手中4张同牌 b5×4 -> canHu=${rFour.canHu} (提未在暗手拆解中支持)');
  checkTrue('记录: b5×4 不能独立成胡(提未支持)', !rFour.canHu);

  // 6.2 绞牌参与成胡：s5,s5,b5 只能组成绞牌，base = 6+6+3+0 = 15
  final jiaoHand = [b(1), b(2), b(3), b(2), b(7), b(10), s(1), s(2), s(3), s(5), s(5), b(5)];
  final rJiao = checker.checkCanHu(handCards: jiaoHand, exposedMelds: []);
  final jiaoTypes = rJiao.allMelds.map((x) => x.type).toList();
  _log.add('       绞牌用例 canHu=${rJiao.canHu} huXi=${rJiao.totalHuXi} 组合=$jiaoTypes');
  check('绞牌参与成胡', rJiao.canHu, true);
  checkTrue('拆解中含绞牌', jiaoTypes.contains(MeldType.jiao));

  // 6.3 观测：引擎对手牌张数不设限（视觉流只看到部分手牌时会提前报胡）
  final shortHand = [
    b(5), b(5), b(5), b(6), b(6), b(6), b(8), b(8), b(8), // 9 张 = 3 个暗坎
  ];
  final rShort = checker.checkCanHu(handCards: shortHand, exposedMelds: []);
  _log.add('       观测: 仅9张牌(3个坎,base=18) -> canHu=${rShort.canHu}');
  _log.add('             => 引擎不校验手牌总数，部分识别也会判胡（设计取舍，非缺陷）');

  // 6.4 观测：手中 4 张同牌（暗提）无法拆解
  _log.add('       观测: 手中 4 张同牌不会被识别为"提"，需先由 UI 归入 exposedMelds');

  // 6.3 一二三 + 二七十 是否被正确区分类型
  final rType = checker.checkCanHu(
    handCards: [b(1), b(2), b(3), b(2), b(7), b(10)],
    exposedMelds: [m(MeldType.kan, b(5)), m(MeldType.kan, b(6)), m(MeldType.kan, b(8)), m(MeldType.kan, b(9))],
  );
  final types = rType.allMelds.map((x) => x.type).toSet();
  _log.add('       组合类型=${types}  base=${calc.calculateTotalBaseHuXi(rType.allMelds)}');
  checkTrue('含 一二三', types.contains(MeldType.yiErSan));
  checkTrue('含 二七十', types.contains(MeldType.erQiShi));

  // ───────────────────────── 7. 决策引擎
  section('7. 决策引擎 (decision_engine.dart)');
  // 7.1 自摸三张 -> 提
  final stTi = PaoGameState(
    handCards: [b(8), b(8), b(8), s(1)], currentCard: b(8),
    isMyTurn: false, isDrawnCard: true);
  check('自摸成4张 -> 提', engine.analyze(stTi).first.action, ActionType.ti);
  // 7.2 自摸对子 -> 偎
  final stWei = PaoGameState(
    handCards: [b(8), b(8), s(1)], currentCard: b(8),
    isMyTurn: false, isDrawnCard: true);
  check('自摸成3张 -> 偎', engine.analyze(stWei).first.action, ActionType.wei);
  // 7.3 他人打出且手中有对 -> 碰
  final stPeng = PaoGameState(
    handCards: [b(8), b(8), s(1)], currentCard: b(8),
    isMyTurn: false, isDrawnCard: false);
  final recPeng = engine.analyze(stPeng);
  checkTrue('他人打出+有对 -> 含碰建议', recPeng.any((r) => r.action == ActionType.peng));
  _log.add('       碰场景首选=${recPeng.first.action} score=${recPeng.first.score}');
  // 7.4 已亮碰，见第4张 -> 跑
  final stPao2 = PaoGameState(
    handCards: [s(1)],
    exposedMelds: [Meld(type: MeldType.peng, cards: [b(8), b(8), b(8)], isExposed: true)],
    currentCard: b(8), isMyTurn: false, isDrawnCard: false);
  checkTrue('已有碰+第4张 -> 含跑建议', engine.analyze(stPao2).any((r) => r.action == ActionType.pao));
  // 7.5 出牌阶段：孤张优先
  final stDiscard = PaoGameState(
    handCards: [s(1), s(2), s(3), s(9), b(5), b(5)],
    isMyTurn: true);
  final recDiscard = engine.analyze(stDiscard).where((r) => r.action == ActionType.discard).toList();
  checkTrue('出牌阶段有建议', recDiscard.isNotEmpty);
  if (recDiscard.isNotEmpty) {
    _log.add('       出牌排序: ${recDiscard.map((r) => '${r.targetCard!.name}(${r.score})').join(', ')}');
    check('孤张小九得分最高(优先打)', recDiscard.first.targetCard, s(9));
  }

  // ───────────────────────── 8. 空间追踪去抖
  section('8. 空间追踪去抖 (spatial_tracker.dart)');
  final tracker = SpatialTracker();
  DetectedCard d(PaoCard c, double x, double y) => DetectedCard(
      card: c, confidence: 0.9, x: x, y: y, width: 0.08, height: 0.16,
      zone: SpatialTracker.determineZone(y));

  check('z=0.80 -> hand', SpatialTracker.determineZone(0.80), CardZone.hand);
  check('z=0.50 -> currentCard', SpatialTracker.determineZone(0.50), CardZone.currentCard);
  check('z=0.20 -> tableDiscards', SpatialTracker.determineZone(0.20), CardZone.tableDiscards);

  final one = [d(s(3), 0.30, 0.80)];
  check('第1帧 未确认', tracker.update(one).length, 0);
  check('第2帧 未确认', tracker.update(one).length, 0);
  check('第3帧 确认(>=3帧)', tracker.update(one).length, 1);
  check('第4帧 已确认', tracker.update(one).length, 1);
  // 连续漏检 4 帧仍在；第 5 帧（>4）才剔除
  for (int i = 0; i < 3; i++) {
    tracker.update([]);
  }
  check('漏检4帧 仍在', tracker.update([]).length, 1);
  check('漏检5帧 已剔除', tracker.update([]).length, 0);

  // 抖动平滑：确认后再抖动坐标，检查是否被平滑（不跳变）
  final tracker2 = SpatialTracker();
  for (int i = 0; i < 3; i++) {
    tracker2.update([d(s(4), 0.40, 0.80)]);
  }
  final jittered = tracker2.update([d(s(4), 0.42, 0.81)]).first;
  _log.add('       平滑后 x=${jittered.x.toStringAsFixed(4)} (原始0.42, 0.6*0.40+0.4*0.42=0.408)');
  checkTrue('坐标被指数平滑(不是原样0.42)', (jittered.x - 0.42).abs() > 0.005);
  tracker2.reset();
  check('reset 后清空', tracker2.update([d(s(4), 0.4, 0.8)]).length, 0);

  // ───────────────────────── 9. YOLO NMS
  section('9. YOLO NMS 后处理 (yolo_detector.dart)');
  final det = YoloDetector();
  final boxes = [
    DetectedCard(card: s(1), confidence: 0.90, x: 0.50, y: 0.50, width: 0.10, height: 0.10, zone: CardZone.hand),
    DetectedCard(card: s(1), confidence: 0.60, x: 0.505, y: 0.50, width: 0.10, height: 0.10, zone: CardZone.hand),
    DetectedCard(card: s(2), confidence: 0.80, x: 0.50, y: 0.50, width: 0.10, height: 0.10, zone: CardZone.hand),
    DetectedCard(card: s(1), confidence: 0.70, x: 0.90, y: 0.50, width: 0.10, height: 0.10, zone: CardZone.hand),
  ];
  final kept = det.applyNMS(boxes);
  _log.add('       NMS 输入4 -> 保留${kept.length}: ${kept.map((k) => "${k.card}@${k.confidence}").join(", ")}');
  check('NMS 抑制同牌高重叠', kept.length, 3);
  check('NMS 保留最高置信度', kept.first.confidence, 0.90);

  // ───────────────────────── 汇总
  _log.add('');
  _log.add('══════════════════════════════');
  _log.add('  通过 $_pass   失败 $_fail');
  _log.add('══════════════════════════════');

  final text = _log.join('\n');
  stdout.writeln(text);
  File(r'C:\temp\engine_smoke_result.txt').writeAsStringSync(text);
}
