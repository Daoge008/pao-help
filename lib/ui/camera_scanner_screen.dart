import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card.dart';
import '../vision/vision_pipeline.dart';
import 'rule_settings_screen.dart';
import 'widgets/card_overlay_painter.dart';
import 'widgets/decision_hud.dart';
import 'widgets/hand_display_widget.dart';

/// 跑胡子实物摄像头连续识别与决策助手主界面
class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with WidgetsBindingObserver {
  late final VisionPipeline _pipeline;

  // ==================== 相机状态 ====================

  /// 当前相机控制器。
  ///
  /// **不变量：非 null 就一定尚未被 dispose。** 所有释放路径统一走
  /// [_releaseCamera]，它会先把引用置空、再调用 dispose()。
  ///
  /// 这个不变量是「黑屏」问题的根治点：`CameraController.dispose()` 并**不会**
  /// 把 `value` 重置成 uninitialized，所以一旦拿已释放的 controller 去构造
  /// `CameraPreview`，其内部 `buildPreview()` 会抛 `Disposed CameraController`
  /// （release 下同样抛，不是 assert），预览子树被 ErrorWidget 顶替 ——
  /// 表现就是「预览区黑屏，但工具栏还在」。
  CameraController? _cameraController;

  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;

  bool _isCameraReady = false;
  bool _isSimulatedMode = false;
  bool _isTorchOn = false;
  Timer? _simulatedTimer;

  /// 防止 [_initializeCamera] 并发重入（生命周期回调可能连续触发）
  bool _isInitializing = false;

  /// 相机是否已在失焦/后台期间被释放，回到前台时需要重建
  bool _needsCameraRestart = false;

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// 相机相关的提示语 / 错误原因，显示在界面上便于现场定位
  String? _cameraNotice;

  @override
  void initState() {
    super.initState();
    _pipeline = context.read<VisionPipeline>();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  // ==================== 相机生命周期 ====================

  /// 释放当前相机实例 —— **全项目唯一的释放入口**。
  ///
  /// 顺序很关键：先断开引用并同步状态，再 await 异步销毁。
  /// 这样在整个销毁期间 build 都不会拿到这个已死的 controller。
  Future<void> _releaseCamera() async {
    final old = _cameraController;
    _cameraController = null;
    if (old == null) return;

    _isCameraReady = false;
    _isTorchOn = false;
    if (mounted) {
      setState(() {});
    }

    try {
      if (old.value.isStreamingImages) {
        await old.stopImageStream();
      }
    } catch (e) {
      debugPrint('停止帧流失败: $e');
    }
    try {
      await old.dispose();
    } catch (e) {
      debugPrint('释放相机实例失败: $e');
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      // 先把上一实例彻底释放，避免与上一次未完成的 dispose 争抢摄像头
      await _releaseCamera();

      List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
      } catch (e) {
        _fallbackToSimulated('无法枚举摄像头：$e');
        return;
      }
      if (!mounted) return;

      _cameras = cameras;
      if (cameras.isEmpty) {
        _fallbackToSimulated('设备未上报任何摄像头');
        return;
      }

      final camera = cameras[_selectedCameraIndex % cameras.length];
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      // 初始化期间可能已退出页面或退到后台，此时这次创建的实例要直接销毁
      if (!mounted || _lifecycle != AppLifecycleState.resumed) {
        await controller.dispose();
        return;
      }

      _simulatedTimer?.cancel();
      _simulatedTimer = null;
      _cameraController = controller;
      setState(() {
        _isSimulatedMode = false;
        _isCameraReady = true;
        _cameraNotice = null;
      });

      // 帧流启动失败不应该丢掉已经可用的预览，单独降级提示
      try {
        await _startImageStream(controller);
      } catch (e) {
        debugPrint('启动帧流失败: $e');
        if (mounted) {
          setState(() => _cameraNotice = '预览正常，但视频帧流启动失败：$e');
        }
      }
    } catch (e) {
      debugPrint('相机初始化失败: $e');
      await _releaseCamera();
      if (!mounted) return;
      _fallbackToSimulated(_describeCameraError(e));
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _startImageStream(CameraController controller) async {
    if (!controller.supportsImageStreaming()) {
      if (mounted) {
        setState(() => _cameraNotice = '当前设备不支持视频帧流，仅显示预览画面');
      }
      return;
    }
    if (controller.value.isStreamingImages) return;
    await controller.startImageStream((CameraImage image) {
      if (!mounted) return;
      _pipeline.processCameraFrame(image);
    });
  }

  /// 降级到演示/模拟流
  void _startSimulatedStream({String? notice}) {
    // 重复调用必须先取消旧定时器，否则每调用一次就多一个常驻定时器
    _simulatedTimer?.cancel();
    _simulatedTimer = null;
    if (!mounted) return;

    setState(() {
      _isSimulatedMode = true;
      _isCameraReady = true;
      _cameraNotice = notice;
    });

    _simulatedTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      _pipeline.processCameraFrame(null);
    });
  }

  void _fallbackToSimulated(String why) {
    if (!mounted) return;
    _startSimulatedStream(notice: why);
  }

  String _describeCameraError(Object e) {
    if (e is CameraException) {
      switch (e.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'cameraPermission':
          return '相机权限被拒绝，请在系统设置中允许「跑胡子助手」使用相机';
        case 'CameraAccessRestricted':
          return '相机访问受限（可能被设备策略或家长控制禁用）';
        default:
          return '相机异常 [${e.code}] ${e.description ?? ''}'.trim();
      }
    }
    return '相机初始化失败：$e';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_needsCameraRestart) {
          _needsCameraRestart = false;
          _initializeCamera();
        }

      case AppLifecycleState.inactive:
        // 系统弹窗、下拉通知栏、权限提示、部分 ROM 的悬浮提醒都会触发 inactive。
        // 这里**绝不释放相机** —— 一次瞬时失焦就销毁 controller，会让预览永久黑屏。
        // 只登记「回前台时重建一次」，作为预览万一被系统暂停的自愈手段。
        if (_cameraController != null) {
          _needsCameraRestart = true;
        }

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // 真正退到后台（Android onStop）才释放摄像头资源
        _needsCameraRestart = true;
        _releaseCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _simulatedTimer?.cancel();
    _simulatedTimer = null;

    // 先断开引用，State 已销毁不会再 build；dispose 是异步的且此处无法 await
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  // ==================== 交互 ====================

  void _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || _isSimulatedMode || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setFlashMode(_isTorchOn ? FlashMode.off : FlashMode.torch);
      if (!mounted) return;
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  void _switchCamera() async {
    if (_cameras.length <= 1 || _isSimulatedMode) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = context.watch<VisionPipeline>();
    final isFrontCamera = _cameras.isNotEmpty &&
        _cameras[_selectedCameraIndex % _cameras.length].lensDirection ==
            CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 摄像头预览画面 / 模拟背景
          Positioned.fill(child: _buildPreview()),

          // 2. 视野区域划分参考线 (手牌区 / 桌面区)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ZoneGuidePainter()),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.tealAccent.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          '常德跑胡子 (${pipeline.config.minHuXi}胡起)',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white),
                        onPressed: _toggleTorch,
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RuleSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => pipeline.resetState(),
                      ),
                    ],
                  ),
                ),
                if (_cameraNotice != null) _buildCameraNotice(),
              ],
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

  /// 预览区。绝不把已释放的 controller 交给 CameraPreview。
  Widget _buildPreview() {
    if (_isSimulatedMode) {
      return _buildSimulatedBackdrop();
    }
    final controller = _cameraController;
    if (_isCameraReady && controller != null && controller.value.isInitialized) {
      return CameraPreview(controller);
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.tealAccent),
    );
  }

  Widget _buildSimulatedBackdrop() {
    return Container(
      color: const Color(0xFF1E2620), // 仿牌桌深绿台呢
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined,
                color: Colors.tealAccent.withValues(alpha: 0.5), size: 64),
            const SizedBox(height: 12),
            Text(
              '实物跑胡子连续视觉识别中\n(当前为演示/模拟分析模式)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _cameraNotice!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _initializeCamera,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('重试', style: TextStyle(color: Colors.white)),
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
    final handPainter = TextPainter(text: handText, textDirection: TextDirection.ltr)
      ..layout();
    handPainter.paint(canvas, Offset(16, handLineY + 6));

    const tableText = TextSpan(
      text: '▲ 桌面弃牌 / 焦点牌区',
      style: TextStyle(color: Colors.white38, fontSize: 12),
    );
    final tablePainter =
        TextPainter(text: tableText, textDirection: TextDirection.ltr)..layout();
    tablePainter.paint(canvas, Offset(16, handLineY - 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
