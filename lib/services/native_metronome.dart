import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// ネイティブコードを利用した高精度メトロノーム
class NativeMetronome {
  static const MethodChannel _channel =
      MethodChannel('com.example.native_metronome');

  bool _isPlaying = false;
  double _currentBpm = 100.0;
  bool _isInitialized = false; // 初期化状態を管理
  bool _isPluginAvailable = true; // プラグインが利用可能かを管理

  // ネイティブ側の状態変更を監視するためのストリーム
  final StreamController<Map<String, dynamic>> _statusStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get statusStream =>
      _statusStreamController.stream;

  NativeMetronome() {
    // ネイティブからの呼び出しをハンドリング
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onBeat':
          final Map<String, dynamic> args =
              Map<String, dynamic>.from(call.arguments);
          _statusStreamController.add(args);
          break;
      }
      return null;
    });
  }

  /// メトロノームを初期化する
  Future<void> initialize() async {
    if (_isInitialized) return; // 既に初期化済みならスキップ

    try {
      print('ネイティブメトロノーム初期化開始');
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      _isPluginAvailable = true;
      print('ネイティブメトロノーム初期化メソッド呼び出し完了');
    } catch (e) {
      print('ネイティブメトロノーム初期化例外: $e');
      // MissingPluginExceptionの場合は明示的に例外をスロー
      if (e.toString().contains('MissingPluginException')) {
        print('エラー: ネイティブプラグインが見つかりません。プラグインが正しく登録されているか確認してください。');
        _isPluginAvailable = false;
        throw Exception('ネイティブメトロノームが利用できません: $e');
      }
      _isPluginAvailable = false;
      throw Exception('ネイティブメトロノームの初期化に失敗しました: $e');
    }
  }

  /// 指定されたBPMでメトロノームを開始する
  Future<void> start({double? bpm}) async {
    if (_isPlaying) return;

    if (bpm != null) {
      _currentBpm = bpm;
    }

    if (!_isPluginAvailable) {
      print('警告: プラグインが利用できないため、操作をスキップします');
      // UI更新のために状態だけ変更
      _isPlaying = true;
      return;
    }

    try {
      print('ネイティブメトロノーム開始');
      final result = await _channel.invokeMethod('start', {
        'bpm': _currentBpm,
      });

      if (result == true) {
        _isPlaying = true;
        debugPrint('ネイティブメトロノーム開始: $_currentBpm BPM');
        print('ネイティブメトロノーム開始メソッド呼び出し完了');
      }
    } catch (e) {
      print('ネイティブメトロノーム開始例外: $e');
      // MissingPluginExceptionの場合は警告のみ出して状態更新
      if (e.toString().contains('MissingPluginException')) {
        print('警告: ネイティブプラグインが見つからないため、代替処理を行います');
        _isPluginAvailable = false;
        _isPlaying = true; // UI更新のために状態を更新
        return;
      }
      throw Exception('ネイティブメトロノームの開始に失敗しました: $e');
    }
  }

  /// メトロノームを停止する
  Future<void> stop() async {
    if (!_isPlaying) return;

    if (!_isPluginAvailable) {
      print('警告: プラグインが利用できないため、操作をスキップします');
      // UI更新のために状態だけ変更
      _isPlaying = false;
      return;
    }

    try {
      print('ネイティブメトロノーム停止');
      final result = await _channel.invokeMethod('stop');
      if (result == true) {
        _isPlaying = false;
        debugPrint('ネイティブメトロノーム停止');
        print('ネイティブメトロノーム停止メソッド呼び出し完了');
      }
    } catch (e) {
      print('ネイティブメトロノーム停止例外: $e');
      // MissingPluginExceptionの場合は警告のみ出して状態更新
      if (e.toString().contains('MissingPluginException')) {
        print('警告: ネイティブプラグインが見つからないため、ローカルのみ状態更新します');
        _isPluginAvailable = false;
        _isPlaying = false; // UI更新のために状態を更新
        return;
      }
      throw Exception('ネイティブメトロノームの停止に失敗しました: $e');
    }
  }

  /// メトロノームのテンポ（BPM）を変更する
  Future<void> changeTempo(double newBpm) async {
    if (newBpm <= 0) return;

    // 精度を確保するため、小数点以下第一位までに丸める（0.1単位）
    newBpm = (newBpm * 10).round() / 10;
    _currentBpm = newBpm;

    if (!_isPluginAvailable) {
      print('警告: プラグインが利用できないため、操作をスキップします');
      return;
    }

    if (_isPlaying) {
      try {
        print('ネイティブメトロノームテンポ変更: $newBpm BPM');
        await _channel.invokeMethod('setTempo', {
          'bpm': _currentBpm,
        });
        print('ネイティブメトロノームテンポ変更メソッド呼び出し完了');
      } catch (e) {
        print('ネイティブメトロノームテンポ変更例外: $e');
        // MissingPluginExceptionの場合は警告のみ出して継続
        if (e.toString().contains('MissingPluginException')) {
          print('警告: ネイティブプラグインが見つからないため、ローカルの設定のみ更新します');
          _isPluginAvailable = false;
          return;
        }
        throw Exception('ネイティブメトロノームのテンポ変更に失敗しました: $e');
      }
    }
  }

  /// リソースを解放する
  void dispose() {
    if (_isPlaying) {
      stop();
    }
    _statusStreamController.close();
  }

  // 現在の状態を取得するためのゲッター
  bool get isPlaying => _isPlaying;
  double get currentBpm => _currentBpm;
  bool get isPluginAvailable => _isPluginAvailable;
}
