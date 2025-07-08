import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/plugin_selection_screen.dart';
import 'services/background_service.dart';
import 'core/utils/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 環境変数の読み込み
  await dotenv.load(fileName: ".env");
  
  // ロガーの初期化
  logger.init();
  
  // BluetoothをiOS/Android向けに初期化
  if (Platform.isAndroid) {
    FlutterBluePlus.setLogLevel(LogLevel.warning, color: true);
  } else if (Platform.isIOS) {
    FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);
  }
  
  // バックグラウンドサービスの初期化
  await BackgroundService.initialize();
  
  runApp(const MyApp());
}

/// メインアプリケーション
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: '研究実験アプリ',
        theme: AppTheme.darkTheme,
        home: const PluginSelectionScreen(), // プラグイン選択画面を最初の画面に
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}