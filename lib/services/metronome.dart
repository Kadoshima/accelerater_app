import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// メトロノーム機能を提供するクラス（波形生成バージョン）
class Metronome {
  // 音声プレーヤー
  final AudioPlayer _audioPlayer1 = AudioPlayer();
  final AudioPlayer _audioPlayer2 = AudioPlayer();

  // 波形データ
  Uint8List? _strongBeatWaveform;
  Uint8List? _weakBeatWaveform;

  Timer? _timer;
  int _beatCount = 0; // 拍カウント（強拍・弱拍の切り替えに使用）
  final int _beatsPerBar = 4; // 1小節あたりの拍数（4/4拍子）

  bool _isPlaying = false;
  double _currentBpm = 100.0;
  bool _shouldVibrate = true; // バイブレーション機能を有効にするフラグ

  bool get isPlaying => _isPlaying;
  double get currentBpm => _currentBpm;

  /// メトロノームを初期化する
  Future<void> initialize() async {
    try {
      // 両方の音声プレーヤーで音量を最大に設定
      await _audioPlayer1.setVolume(1.0);
      await _audioPlayer2.setVolume(0.7); // 弱拍は少し小さい音量

      // 強拍用のクリック音波形を生成
      _strongBeatWaveform = _generateClickWaveform(
        frequency: 1000, // 1000Hz（高めの音）
        durationMs: 30,
        amplitude: 0.8,
      );

      // 弱拍用のクリック音波形を生成（周波数を変えて音色を変える）
      _weakBeatWaveform = _generateClickWaveform(
        frequency: 800, // 800Hz（少し低め）
        durationMs: 20, // 短め
        amplitude: 0.6, // 小さめ
      );

      print("メトロノーム波形生成完了: "
          "強拍=${_strongBeatWaveform!.length}バイト, "
          "弱拍=${_weakBeatWaveform!.length}バイト");

      // テスト再生
      await _playStrongBeat(isTest: true);
    } catch (e) {
      print("メトロノーム初期化エラー: $e");
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
    _beatCount = 0; // カウントをリセット

    // 波形データの準備確認
    if (_strongBeatWaveform == null) {
      print("警告: 波形データがないままメトロノームを開始しています");
      // 波形を再生成
      _strongBeatWaveform = _generateClickWaveform(
        frequency: 1000,
        durationMs: 30,
        amplitude: 0.8,
      );

      _weakBeatWaveform = _generateClickWaveform(
        frequency: 800,
        durationMs: 20,
        amplitude: 0.6,
      );

      print("メトロノーム起動時に波形を再生成しました");
    }

    _startTimer();
    print("メトロノーム開始: $_currentBpm BPM");

    // 最初のクリックを即座に行う（常に強拍から開始）
    _playStrongBeat();
  }

  /// メトロノームを停止する
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    // 両方の音声を停止
    await _audioPlayer1.stop();
    await _audioPlayer2.stop();
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

      // 拍カウントを増やす
      _beatCount = (_beatCount + 1) % _beatsPerBar;

      // 強拍（小節の頭）と弱拍で異なる音を鳴らす
      if (_beatCount == 0) {
        _playStrongBeat(); // 1拍目は強拍
      } else {
        _playWeakBeat(); // 2拍目以降は弱拍
      }
    });
  }

  /// 強拍のクリック音を再生する（小節の頭、アクセント）
  Future<void> _playStrongBeat({bool isTest = false}) async {
    // 先にバイブレーションを起動（音より100ms早く）
    if (_shouldVibrate) {
      HapticFeedback.heavyImpact();
    }

    // 音声の遅延（バイブレーションより後に音を鳴らす）
    await Future.delayed(const Duration(milliseconds: 0));

    if (_strongBeatWaveform != null) {
      try {
        // 現在再生中の場合は一度停止
        await _audioPlayer1.stop();

        // 波形データをメモリ上で再生
        final audioSource = MyCustomSource(_strongBeatWaveform!);
        await _audioPlayer1.setAudioSource(audioSource);
        await _audioPlayer1.play();

        if (isTest) {
          print("強拍テスト音声再生: 成功");
        }
      } catch (e) {
        print("強拍音声再生エラー: $e");
      }
    } else {
      print("強拍音声データがありません - 触覚フィードバックのみ使用");
    }
  }

  /// 弱拍のクリック音を再生する（小節の頭以外）
  Future<void> _playWeakBeat() async {
    // 先にバイブレーションを起動（音より100ms早く）
    if (_shouldVibrate) {
      HapticFeedback.mediumImpact();
    }

    // 音声の遅延（バイブレーションより後に音を鳴らす）
    await Future.delayed(const Duration(milliseconds: 100));

    if (_weakBeatWaveform != null) {
      try {
        // 現在再生中の場合は一度停止
        await _audioPlayer2.stop();

        // 波形データをメモリ上で再生
        final audioSource = MyCustomSource(_weakBeatWaveform!);
        await _audioPlayer2.setAudioSource(audioSource);
        await _audioPlayer2.play();
      } catch (e) {
        print("弱拍音声再生エラー: $e");
      }
    } else {
      print("弱拍音声データがありません - 軽い触覚フィードバックのみ使用");
    }
  }

  /// メトロノーム音のWAV形式波形データを生成する
  Uint8List _generateClickWaveform({
    required double frequency,
    required int durationMs,
    required double amplitude,
    int sampleRate = 44100,
  }) {
    // ヘッダーサイズと波形データサイズの計算
    final int headerSize = 44; // WAVヘッダーのサイズ（44バイト）
    final int numSamples = (sampleRate * durationMs ~/ 1000);
    final int dataSize = numSamples * 2; // 16ビット（2バイト）サンプル
    final int fileSize = headerSize + dataSize;

    // バッファを作成
    final ByteData buffer = ByteData(fileSize);

    // WAVヘッダーを書き込む
    // "RIFF" チャンク
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, fileSize - 8, Endian.little); // ファイルサイズ - 8

    // "WAVE" フォーマット
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // "fmt " サブチャンク
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // fmt チャンクサイズ: 16
    buffer.setUint16(20, 1, Endian.little); // フォーマットタイプ: 1 (PCM)
    buffer.setUint16(22, 1, Endian.little); // チャンネル数: 1 (モノラル)
    buffer.setUint32(24, sampleRate, Endian.little); // サンプリングレート
    buffer.setUint32(
        28, sampleRate * 2, Endian.little); // バイトレート = サンプリングレート * ブロックサイズ
    buffer.setUint16(32, 2, Endian.little); // ブロックサイズ = チャンネル数 * ビット深度 / 8
    buffer.setUint16(34, 16, Endian.little); // ビット深度: 16

    // "data" サブチャンク
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little); // 波形データサイズ

    // 波形データを生成（短いクリック音）
    double decay = exp(-5.0 / numSamples); // 減衰係数
    double currentAmplitude = amplitude;

    for (int i = 0; i < numSamples; i++) {
      // サイン波（単純な音）を生成し、経時的に減衰させる
      final double t = i / sampleRate;
      double sample = sin(2 * pi * frequency * t) * currentAmplitude;

      // 16ビット整数に変換 (-32768 ~ 32767)
      final int sampleInt = (sample * 32767).toInt().clamp(-32768, 32767);

      // バッファに書き込む
      buffer.setInt16(headerSize + i * 2, sampleInt, Endian.little);

      // 減衰を適用
      currentAmplitude *= decay;
    }

    return buffer.buffer.asUint8List();
  }

  /// リソースを解放する
  void dispose() {
    _timer?.cancel();
    _audioPlayer1.dispose();
    _audioPlayer2.dispose();
  }

  // バイブレーション機能の有効/無効を切り替える
  void setVibration(bool enabled) {
    _shouldVibrate = enabled;
    print('バイブレーション機能: ${enabled ? '有効' : '無効'}');
  }

  // バイブレーション機能が有効かどうかを取得
  bool get vibrationEnabled => _shouldVibrate;
}

/// just_audioで使用するためのカスタムオーディオソース
class MyCustomSource extends StreamAudioSource {
  final Uint8List _buffer;

  MyCustomSource(this._buffer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // 要求された範囲（または全体）を取得
    start = start ?? 0;
    end = end ?? _buffer.length;

    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
