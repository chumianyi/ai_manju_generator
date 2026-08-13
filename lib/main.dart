import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/ai_config.dart';
import 'screens/home_screen.dart';
import 'screens/config_screen.dart';
import 'services/storage_service.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AiManjuApp());
}

class AiManjuApp extends StatefulWidget {
  const AiManjuApp({super.key});

  @override
  State<AiManjuApp> createState() => _AiManjuAppState();
}

class _AiManjuAppState extends State<AiManjuApp> {
  AiConfig _config = AiConfig();
  bool _isLoading = true;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await StorageService.loadConfig();
    if (mounted) {
      setState(() {
        _config = config;
        _isLoading = false;
      });
    }
  }

  void _onConfigSaved(AiConfig config) {
    setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'AI 漫剧生成器',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(null),
      darkTheme: AppTheme.darkTheme(null),
      themeMode: _themeMode,
      home: HomeScreen(
        config: _config,
        onOpenConfig: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfigScreen(
                config: _config,
                onSave: _onConfigSaved,
              ),
            ),
          );
        },
      ),
    );
  }
}
