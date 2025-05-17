import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

// サービス関連の定数
const String notificationChannelId = 'gait_analysis_channel';
const String notificationId = 'gait_analysis_notification';

class BackgroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isRunning = false;

  // バックグラウンドサービスの初期化
  static Future<void> initialize() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Android用の通知チャンネル設定
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        notificationChannelId,
        '歩行リズム測定サービス',
        description: 'アプリがバックグラウンドで実験データを収集しています',
        importance: Importance.high,
      );

      // Android用通知チャンネル登録
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // サービスの設定
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: '歩行リズム測定アプリ',
        initialNotificationContent: 'バックグラウンドで実験データを収集しています',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // iOSバックグラウンド処理
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // サービス開始時のエントリーポイント
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // 実験データ記録用のリスト
    List<Map<String, dynamic>> experimentData = [];
    DateTime? experimentStartTime;
    String experimentFileName = '';
    String subjectId = '';
    double targetBpm = 0.0;

    // 定期的なデータ処理
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      // 実験が実行中の場合、データを処理
      final prefs = await SharedPreferences.getInstance();
      final isExperimentRunning =
          prefs.getBool('is_experiment_running') ?? false;

      if (isExperimentRunning) {
        // 初回実行時に実験情報を取得
        if (experimentStartTime == null) {
          experimentFileName =
              prefs.getString('experiment_file_name') ?? 'unknown_experiment';
          subjectId = prefs.getString('subject_id') ?? 'unknown';
          targetBpm = prefs.getDouble('target_bpm') ?? 100.0;
          experimentStartTime = DateTime.now();

          print('バックグラウンドサービス: 実験データ収集を開始します - $experimentFileName');
        }

        // センサーデータを取得して記録（ここでは仮データ）
        // 実際のアプリでは、Bluetoothの接続状態を確認し、
        // センサーからのデータ取得をバックグラウンドで継続する必要があります
        final now = DateTime.now();
        experimentData.add({
          'timestamp': now.millisecondsSinceEpoch,
          'targetBPM': targetBpm,
          'elapsedSeconds': now.difference(experimentStartTime!).inSeconds,
        });

        // 定期的に保存（例：30秒ごと）
        if (experimentData.length % 30 == 0) {
          // ここでデータ保存処理
          print('バックグラウンドサービス: ${experimentData.length}件のデータを保存します');

          // LocalStorageへの保存処理をここに実装
        }

        // UIに状態を通知
        service.invoke('update', {
          'isRunning': true,
          'timestamp': now.toIso8601String(),
          'dataCount': experimentData.length,
        });
      } else if (experimentData.isNotEmpty) {
        // 実験が終了した場合、残っているデータを保存
        print('バックグラウンドサービス: 実験が終了しました。残りのデータを保存します');

        // LocalStorageへの保存処理をここに実装

        // データをリセット
        experimentData.clear();
        experimentStartTime = null;
        experimentFileName = '';
        subjectId = '';
      }
    });

    // サービスの状態を更新
    _isRunning = true;
  }

  // サービスの起動
  static Future<void> startService() async {
    await _service.startService();
    _isRunning = true;
  }

  // サービスの停止
  static Future<void> stopService() async {
    _service.invoke('stopService');
    _isRunning = false;
  }

  // サービスが実行中かどうか
  static bool get isRunning => _isRunning;

  // サービスインスタンスを取得
  static FlutterBackgroundService get service => _service;
}
