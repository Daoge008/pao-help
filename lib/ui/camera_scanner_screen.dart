import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card.dart';
import '../vision/vision_pipeline.dart';
import 'widgets/card_overlay_painter.dart';
import 'widgets/decision_hud.dart';
import 'widgets/hand_display_widget.dart';
import 'rule_settings_screen.dart';

/// 跑胡子实物摄像头连续识别与决策助手主界面
class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isTorchOn = false;
  bool _isSimulatedMode = false;
  Timer? _simulatedTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _startSimulatedStream();
        return;
      }

      final camera = _cameras[_selectedCameraIndex];
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
      });

      // 开启连续视频流帧检测
      final pipeline = context.read<VisionPipeline>();
      controller.startImageStream((CameraImage image) {
        pipeline.processCameraFrame(image);
      });
    } catch (e) {
      debugPrint('相机初始化失败，切换为模拟演示流: $e');
      _startSimulatedStream();
    }
  }

  void _startSimulatedStream() {
    if (!mounted) return;
    setState(() {
      _isSimulatedMode = true;
      _isCameraReady = true;
    });

    final pipeline = context.read<VisionPipeline>();
    // 定时模拟推送帧数据进行决策演练
    _simulatedTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) {
        pipeline.processCameraFrame(null);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _simulatedTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  void _toggleTorch() async {
    if (_cameraController == null || _isSimulatedMode) return;
    try {
      if (_isTorchOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  void _switchCamera() async {
    if (_cameras.length <= 1 || _isSimulatedMode) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = context.watch<VisionPipeline>();
    final isFrontCamera = _cameras.isNotEmpty &&
        _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 摄像头预览画面 / 模拟背景
          Positioned.fill(
            child: _isCameraReady
                ? (_cameraController != null && _cameraController!.value.isInitialized
                    ? CameraPreview(_cameraController!)
                    : Container(
                        color: const Color(0xFF1E2620), // 仿牌桌深绿台呢
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_outlined, color: Colors.tealAccent.withValues(alpha: 0.5), size: 64),
                              const SizedBox(height: 12),
                              Text(
                                '实物跑胡子连续视觉识别中\n(当前为演示/模拟分析模式)',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ))
                : const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
          ),

          // 2. 视野区域划分参考线 (手牌区 / 桌面区)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ZoneGuidePainter(),
              ),
            ),
          ),

          // 3. 卡牌识别框绘制层
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: CardOverlayPainter(
                  detections: pipeline.confirmedDetections,
                  isFrontCamera: isFrontCamera,
                ),
              ),
            ),
          ),

          // 4. 顶部状态栏与工具按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // 当前规则胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '常德跑胡子 (${pipeline.config.minHuXi}胡起)',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  // 补光灯
                  IconButton(
                    icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                    onPressed: _toggleTorch,
                  ),
                  // 翻转镜头
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: _switchCamera,
                  ),
                  // 规则设置
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RuleSettingsScreen()),
                      );
                    },
                  ),
                  // 重置/清空状态
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => pipeline.resetState(),
                  ),
                ],
              ),
            ),
          ),

          // 5. 底部 HUD 与手牌栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 识别到的手牌条状缩略图展示
                if (pipeline.currentState.handCards.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: HandDisplayWidget(
                      handCards: pipeline.currentState.handCards,
                      onCardSelected: (PaoCard card) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已选中 [${card.name}]，可在出牌阶段打出'),
                            duration: const Duration(milliseconds: 800),
                          ),
                        );
                      },
                    ),
                  ),
                // 决策卡片
                DecisionHUD(
                  recommendations: pipeline.recommendations,
                  gameState: pipeline.currentState,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 辅助绘制区域参考线
class _ZoneGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 绘制桌面弃牌与手牌区分割线
    final handLineY = size.height * 0.62;
    canvas.drawLine(Offset(0, handLineY), Offset(size.width, handLineY), paint);

    // 绘制指示文字
    const handText = TextSpan(
      text: '▼ 手牌识别区（对准自己手牌）',
      style: TextStyle(color: Colors.white38, fontSize: 12),
    );
    final handPainter = TextPainter(text: handText, textDirection: TextDirection.ltr)..layout();
    handPainter.paint(canvas, Offset(16, handLineY + 6));

    const tableText = TextSpan(
      text: '▲ 桌面弃牌 / 焦点牌区',
      style: TextStyle(color: Colors.white38, fontSize: 12),
    );
    final tablePainter = TextPainter(text: tableText, textDirection: TextDirection.ltr)..layout();
    tablePainter.paint(canvas, Offset(16, handLineY - 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
