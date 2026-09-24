import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'vision/vision_pipeline.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏方向，方便单手持握或支架固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 加载持久化的跑胡子规则
  final initialConfig = await SettingsService.loadConfig();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => VisionPipeline(config: initialConfig),
        ),
      ],
      child: const PaoHelpApp(),
    ),
  );
}

class PaoHelpApp extends StatelessWidget {
  const PaoHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '跑胡子助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF141916),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2620),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
