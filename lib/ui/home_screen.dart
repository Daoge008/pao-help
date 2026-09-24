import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../vision/vision_pipeline.dart';
import 'camera_scanner_screen.dart';
import 'rule_settings_screen.dart';

/// 跑胡子助手主界面
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pipeline = context.watch<VisionPipeline>();

    return Scaffold(
      backgroundColor: const Color(0xFF141916), // 深色国风牌桌质感
      appBar: AppBar(
        title: const Text('跑胡子助手 (常德跑胡子)'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E2620),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // 核心主入口：开启摄像头连续识别
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.tealAccent, size: 40),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '开始实物连续识别',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '对准手里牌和桌面，实时给出最佳出牌与吃碰提跑动作建议',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 当前规则概览卡片
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2620),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '当前生效规则',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.tune, size: 16, color: Colors.tealAccent),
                        label: const Text('修改规则', style: TextStyle(color: Colors.tealAccent)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RuleSettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  _RuleBadgeItem(label: '模式', value: '湖南常德跑胡子 (全名堂)'),
                  _RuleBadgeItem(label: '起胡胡息', value: '${pipeline.config.minHuXi} 胡息'),
                  _RuleBadgeItem(
                    label: '名堂支持',
                    value: [
                      if (pipeline.config.enableHongHu) '红胡',
                      if (pipeline.config.enableDianHu) '点胡',
                      if (pipeline.config.enableHeiHu) '黑胡',
                      if (pipeline.config.enableShiSanHong) '十三红',
                      if (pipeline.config.enablePengPengHu) '碰碰胡',
                    ].join(' / '),
                  ),
                  _RuleBadgeItem(
                    label: '进牌规则',
                    value: '${pipeline.config.chouPaiLimit ? "臭牌禁吃" : ""}  ${pipeline.config.guoZhangLimit ? "过张不碰" : ""}  ${pipeline.config.biPaiRule ? "比牌" : ""}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 实物对局使用技巧说明
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2620),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '实物纸牌识别技巧',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _TipRow(
                    index: '1',
                    content: '手机置于手牌斜上方（或使用桌面支架），手牌整齐握持或扇形排列在视野下半区。',
                  ),
                  const _TipRow(
                    index: '2',
                    content: '桌面中间保留弃牌与出牌区，系统会自动按空间坐标区分手牌与桌面牌。',
                  ),
                  const _TipRow(
                    index: '3',
                    content: '内置时序空间平滑算法（至少连续出现 3 帧确认），消除手部移动与反光干扰。',
                  ),
                  const _TipRow(
                    index: '4',
                    content: '可随时点击顶部右上角灯泡按钮开启补光灯，提高暗光识别准确率。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleBadgeItem extends StatelessWidget {
  final String label;
  final String value;

  const _RuleBadgeItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String index;
  final String content;

  const _TipRow({required this.index, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Text(index, style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
