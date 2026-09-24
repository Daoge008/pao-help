import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rule_config.dart';
import '../services/settings_service.dart';
import '../vision/vision_pipeline.dart';

/// 跑胡子规则设置与微调界面
class RuleSettingsScreen extends StatefulWidget {
  const RuleSettingsScreen({super.key});

  @override
  State<RuleSettingsScreen> createState() => _RuleSettingsScreenState();
}

class _RuleSettingsScreenState extends State<RuleSettingsScreen> {
  late RuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = context.read<VisionPipeline>().config;
  }

  void _updateConfig(RuleConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    context.read<VisionPipeline>().updateRuleConfig(newConfig);
    SettingsService.saveConfig(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('跑胡子规则设置'),
        actions: [
          TextButton(
            onPressed: () {
              _updateConfig(RuleConfig.changdeStandard());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已恢复常德跑胡子默认规则')),
              );
            },
            child: const Text('恢复默认', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 预设模式快捷切换
          const Text('玩法预设', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('湖南常德跑胡子 (15胡)'),
                selected: _config.minHuXi == 15,
                onSelected: (val) {
                  if (val) _updateConfig(RuleConfig.changdeStandard());
                },
              ),
              ChoiceChip(
                label: const Text('快速碰胡 (10胡)'),
                selected: _config.minHuXi == 10,
                onSelected: (val) {
                  if (val) _updateConfig(RuleConfig.quick10Hu());
                },
              ),
            ],
          ),
          const Divider(height: 32),

          // 起胡门槛设置
          const Text('基础起胡条件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ListTile(
            title: const Text('起胡胡息'),
            subtitle: Text('当前设置: ${_config.minHuXi} 胡息（常德标准为 15 胡）'),
            trailing: DropdownButton<int>(
              value: _config.minHuXi,
              items: const [
                DropdownMenuItem(value: 10, child: Text('10 胡')),
                DropdownMenuItem(value: 15, child: Text('15 胡 (推荐)')),
                DropdownMenuItem(value: 18, child: Text('18 胡')),
                DropdownMenuItem(value: 21, child: Text('21 胡')),
              ],
              onChanged: (val) {
                if (val != null) {
                  _updateConfig(_config.copyWith(minHuXi: val));
                }
              },
            ),
          ),
          const Divider(height: 32),

          // 常德全名堂番数开关
          const Text('常德名堂设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('红胡'),
            subtitle: const Text('红字达到 10 张以上翻倍'),
            value: _config.enableHongHu,
            onChanged: (val) => _updateConfig(_config.copyWith(enableHongHu: val)),
          ),
          SwitchListTile(
            title: const Text('点胡 (独红)'),
            subtitle: const Text('全副牌仅 1 张红字翻 3 倍'),
            value: _config.enableDianHu,
            onChanged: (val) => _updateConfig(_config.copyWith(enableDianHu: val)),
          ),
          SwitchListTile(
            title: const Text('黑胡 (乌胡)'),
            subtitle: const Text('全副牌无红字翻 4 倍'),
            value: _config.enableHeiHu,
            onChanged: (val) => _updateConfig(_config.copyWith(enableHeiHu: val)),
          ),
          SwitchListTile(
            title: const Text('十三红'),
            subtitle: const Text('红字达到 13 张及以上翻 4 倍'),
            value: _config.enableShiSanHong,
            onChanged: (val) => _updateConfig(_config.copyWith(enableShiSanHong: val)),
          ),
          SwitchListTile(
            title: const Text('碰碰胡'),
            subtitle: const Text('全部由坎/碰/偎/提/跑/绞组成，无顺子翻倍'),
            value: _config.enablePengPengHu,
            onChanged: (val) => _updateConfig(_config.copyWith(enablePengPengHu: val)),
          ),
          SwitchListTile(
            title: const Text('自摸'),
            subtitle: const Text('自摸胡牌额外增加胡息或番数'),
            value: _config.enableZiMo,
            onChanged: (val) => _updateConfig(_config.copyWith(enableZiMo: val)),
          ),
          const Divider(height: 32),

          // 进牌规则限制
          const Text('出牌与进牌规则限制', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          CheckboxListTile(
            title: const Text('臭牌不可吃'),
            subtitle: const Text('过手或本人曾打出的牌不可再吃'),
            value: _config.chouPaiLimit,
            onChanged: (val) => _updateConfig(_config.copyWith(chouPaiLimit: val ?? true)),
          ),
          CheckboxListTile(
            title: const Text('过张不碰'),
            subtitle: const Text('他人打出未碰的牌，同圈内不得再碰'),
            value: _config.guoZhangLimit,
            onChanged: (val) => _updateConfig(_config.copyWith(guoZhangLimit: val ?? true)),
          ),
          CheckboxListTile(
            title: const Text('比牌规则'),
            subtitle: const Text('手中若有相同进牌组合，必须一同下牌'),
            value: _config.biPaiRule,
            onChanged: (val) => _updateConfig(_config.copyWith(biPaiRule: val ?? true)),
          ),
        ],
      ),
    );
  }
}
