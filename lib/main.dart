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
  int _currentIndex = 0;
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

    final pages = [
      HomeScreen(config: _config, onOpenConfig: () => setState(() => _currentIndex = 1)),
      ConfigScreen(config: _config, onSave: _onConfigSaved),
    ];

    return MaterialApp(
      title: 'AI 漫剧生成器',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(null),
      darkTheme: AppTheme.darkTheme(null),
      themeMode: _themeMode,
      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie),
              label: '漫剧',
            ),
            NavigationDestination(
              icon: Icon(Icons.api_outlined),
              selectedIcon: Icon(Icons.api),
              label: 'API',
            ),
          ],
        ),
      ),
    );
  }
}
