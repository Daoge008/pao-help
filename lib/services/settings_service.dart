import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rule_config.dart';

/// 跑胡子规则配置持久化服务
class SettingsService {
  static const String _keyRuleConfig = 'user_rule_config';

  /// 加载已保存的规则配置（默认常德跑胡子）
  static Future<RuleConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyRuleConfig);
      if (jsonStr == null || jsonStr.isEmpty) {
        return RuleConfig.changdeStandard();
      }
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return RuleConfig(
        minHuXi: map['minHuXi'] ?? 15,
        maxCardsPerHand: map['maxCardsPerHand'] ?? 21,
        huXiSmallKan: map['huXiSmallKan'] ?? 3,
        huXiSmallPeng: map['huXiSmallPeng'] ?? 1,
        huXiSmallWei: map['huXiSmallWei'] ?? 4,
        huXiSmallTi: map['huXiSmallTi'] ?? 9,
        huXiSmallPao: map['huXiSmallPao'] ?? 8,
        huXiSmall123: map['huXiSmall123'] ?? 3,
        huXiSmall2710: map['huXiSmall2710'] ?? 3,
        huXiBigKan: map['huXiBigKan'] ?? 6,
        huXiBigPeng: map['huXiBigPeng'] ?? 3,
        huXiBigWei: map['huXiBigWei'] ?? 8,
        huXiBigTi: map['huXiBigTi'] ?? 12,
        huXiBigPao: map['huXiBigPao'] ?? 12,
        huXiBig123: map['huXiBig123'] ?? 6,
        huXiBig2710: map['huXiBig2710'] ?? 6,
        enableHongHu: map['enableHongHu'] ?? true,
        enableDianHu: map['enableDianHu'] ?? true,
        enableHeiHu: map['enableHeiHu'] ?? true,
        enableShiSanHong: map['enableShiSanHong'] ?? true,
        enablePengPengHu: map['enablePengPengHu'] ?? true,
        enableZiMo: map['enableZiMo'] ?? true,
        chouPaiLimit: map['chouPaiLimit'] ?? true,
        guoZhangLimit: map['guoZhangLimit'] ?? true,
        biPaiRule: map['biPaiRule'] ?? true,
      );
    } catch (_) {
      return RuleConfig.changdeStandard();
    }
  }

  /// 保存自定义规则配置
  static Future<void> saveConfig(RuleConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'minHuXi': config.minHuXi,
        'maxCardsPerHand': config.maxCardsPerHand,
        'huXiSmallKan': config.huXiSmallKan,
        'huXiSmallPeng': config.huXiSmallPeng,
        'huXiSmallWei': config.huXiSmallWei,
        'huXiSmallTi': config.huXiSmallTi,
        'huXiSmallPao': config.huXiSmallPao,
        'huXiSmall123': config.huXiSmall123,
        'huXiSmall2710': config.huXiSmall2710,
        'huXiBigKan': config.huXiBigKan,
        'huXiBigPeng': config.huXiBigPeng,
        'huXiBigWei': config.huXiBigWei,
        'huXiBigTi': config.huXiBigTi,
        'huXiBigPao': config.huXiBigPao,
        'huXiBig123': config.huXiBig123,
        'huXiBig2710': config.huXiBig2710,
        'enableHongHu': config.enableHongHu,
        'enableDianHu': config.enableDianHu,
        'enableHeiHu': config.enableHeiHu,
        'enableShiSanHong': config.enableShiSanHong,
        'enablePengPengHu': config.enablePengPengHu,
        'enableZiMo': config.enableZiMo,
        'chouPaiLimit': config.chouPaiLimit,
        'guoZhangLimit': config.guoZhangLimit,
        'biPaiRule': config.biPaiRule,
      };
      await prefs.setString(_keyRuleConfig, jsonEncode(map));
    } catch (e) {
      // 忽略或处理日志
    }
  }
}
