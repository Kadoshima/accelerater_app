import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart'; // for rootBundle

/// メトロノーム機能を提供するクラス
class Metronome {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Uint8List? _clickSoundBytes;
  Timer? _timer;

  bool _isPlaying = false;
  double _currentBpm = 100.0;

  bool get isPlaying => _isPlaying;
  double get currentBpm => _currentBpm;

  /// メトロノームを初期化する
  Future<void> initialize() async {
    try {
      // アセットからクリック音を読み込む
      final byteData = await rootBundle.load(
          'assets/sounds/metronome_click.wav'); // Correct path to your sound file
      _clickSoundBytes = byteData.buffer.asUint8List();
      print("メトロノームクリック音ロード完了");
    } catch (e) {
      print("メトロノームクリック音のロードエラー: $e");
      // エラーが発生した場合でも処理を続行する（音なしで動くように）
    }
  }

  /// 指定されたBPMでメトロノームを開始する
  Future<void> start({double? bpm}) async {
    if (_isPlaying) return;
    if (bpm != null) {
      _currentBpm = bpm;
    }
    if (_currentBpm <= 0) return; // BPMが不正なら開始しない

    _isPlaying = true;
    _startTimer();
    print("メトロノーム開始: $_currentBpm BPM");
    // 最初のクリックを即座に行う
    _playClickSound();
  }

  /// メトロノームを停止する
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    // 再生中の音があれば止める（必要な場合）
    // await _audioPlayer.stop();
    print("メトロノーム停止");
  }

  /// メトロノームのテンポ（BPM）を変更する
  Future<void> changeTempo(double newBpm) async {
    if (newBpm <= 0) return; // 不正なBPMは無視
    _currentBpm = newBpm;
    print("メトロノームテンポ変更: $_currentBpm BPM");
    if (_isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// タイマーを開始または再開する
  void _startTimer() {
    final intervalMilliseconds = (60000 / _currentBpm).round();
    _timer =
        Timer.periodic(Duration(milliseconds: intervalMilliseconds), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      _playClickSound();
    });
  }

  /// クリック音を再生する
  Future<void> _playClickSound() async {
    if (_clickSoundBytes != null) {
      try {
        await _audioPlayer.play(BytesSource(_clickSoundBytes!));
        // print("クリック音再生"); // デバッグ用
      } catch (e) {
        print("クリック音再生エラー: $e");
      }
    } else {
      // print("クリック音データがありません"); // デバッグ用
      // 音声ファイルがない場合、触覚フィードバックで代用
      HapticFeedback.lightImpact();
    }
  }

  /// リソースを解放する
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
  }
}
