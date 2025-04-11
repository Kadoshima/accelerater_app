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

  // AudioSource
  AudioSource? _strongBeatSource;
  AudioSource? _weakBeatSource;

  // 高精度タイマー用変数
  Timer? _timer;
  DateTime? _lastBeatTime;
  int _beatCount = 0; // 拍カウント（強拍・弱拍の切り替えに使用）
  final int _beatsPerBar = 4; // 1小節あたりの拍数（4/4拍子）
  int _nextBeatScheduledAt = 0; // 次の拍がスケジュールされた時間（ミリ秒）

  bool _isPlaying = false;
  double _currentBpm = 100.0;
  bool _shouldVibrate = true; // バイブレーション機能を有効にするフラグ

  // シーケンシャル実行制御用
  bool _isProcessingBeat = false;
  final List<Future<void> Function()> _pendingOperations = [];

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

      // AudioSourceを事前に作成
      _strongBeatSource = MyCustomSource(_strongBeatWaveform!);
      _weakBeatSource = MyCustomSource(_weakBeatWaveform!);

      // 音声を事前にロード
      await _audioPlayer1.setAudioSource(_strongBeatSource!);
      await _audioPlayer2.setAudioSource(_weakBeatSource!);

      print("メトロノーム波形生成完了: "
          "強拍=${_strongBeatWaveform!.length}バイト, "
          "弱拍=${_weakBeatWaveform!.length}バイト");

      // ウォームアップ（一度再生してシステムを準備）
      await _audioPlayer1.setVolume(0); // 無音で
      await _audioPlayer1.play(); // 再生
      await _audioPlayer1.stop(); // 即停止
      await _audioPlayer1.setVolume(1.0); // 音量戻す
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
    _lastBeatTime = DateTime.now(); // 開始時刻を記録
    _nextBeatScheduledAt = 0; // スケジュールをリセット
    _isProcessingBeat = false; // 処理フラグをリセット
    _pendingOperations.clear(); // 保留中の操作をクリア

    // 波形データとソースの準備確認
    if (_strongBeatSource == null || _weakBeatSource == null) {
      print("警告: 音源が準備できていないため再初期化します");

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

      // AudioSourceを作成
      _strongBeatSource = MyCustomSource(_strongBeatWaveform!);
      _weakBeatSource = MyCustomSource(_weakBeatWaveform!);

      // 音声をプリロード
      await _audioPlayer1.setAudioSource(_strongBeatSource!);
      await _audioPlayer2.setAudioSource(_weakBeatSource!);
    }

    // タイマーで定期的な実行を開始
    _startHighPrecisionTimer();
    print("メトロノーム開始: $_currentBpm BPM");

    // 最初のクリックを即座に行う（常に強拍から開始）
    await _playStrongBeat();
  }

  /// メトロノームを停止する
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _lastBeatTime = null;

    // 保留中の操作をクリア
    _pendingOperations.clear();
    _isProcessingBeat = false;

    // 両方の音声を停止
    await _audioPlayer1.stop();
    await _audioPlayer2.stop();
    print("メトロノーム停止");
  }

  /// メトロノームのテンポ（BPM）を変更する
  Future<void> changeTempo(double newBpm) async {
    if (newBpm <= 0) return; // 不正なBPMは無視

    // 精度を確保するため、小数点以下第一位までに丸める（0.1単位）
    newBpm = (newBpm * 10).round() / 10;

    _currentBpm = newBpm;
    print("メトロノームテンポ変更: $_currentBpm BPM");

    if (_isPlaying) {
      // 再生中の場合、タイマーをリセットして精度を保つ
      _timer?.cancel();
      _lastBeatTime = DateTime.now(); // 現在時刻を基準にリセット
      _nextBeatScheduledAt = 0; // スケジュールをリセット
      _startHighPrecisionTimer();
    }
  }

  /// 高精度タイマーを開始する
  void _startHighPrecisionTimer() {
    // 高頻度でチェックするために10msごとにタイマーを実行
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      _checkAndPlayNextBeat();
    });
  }

  /// 次の拍を再生するタイミングかチェックし、適切なタイミングで再生
  void _checkAndPlayNextBeat() {
    if (_lastBeatTime == null || _isProcessingBeat) return;

    final now = DateTime.now();
    final intervalMilliseconds = (60000 / _currentBpm).round();

    // 前回の拍から経過したミリ秒
    final elapsedMillis = now.difference(_lastBeatTime!).inMilliseconds;

    // 次の拍の予定時刻（前回の拍からの経過時間がインターバル以上）
    if (elapsedMillis >= intervalMilliseconds &&
        _nextBeatScheduledAt <= now.millisecondsSinceEpoch) {
      // 余分な時間を計算（精度を高めるため）
      final overshoot = elapsedMillis - intervalMilliseconds;

      // 次の拍をスケジュール
      _nextBeatScheduledAt =
          now.millisecondsSinceEpoch + intervalMilliseconds - overshoot;

      // 拍カウントを増やす
      _beatCount = (_beatCount + 1) % _beatsPerBar;

      // 更新された最後の拍の時間
      _lastBeatTime = now;

      // 非同期で拍を再生（UI更新を妨げないように）
      _executeSequentially(() async {
        // 強拍（小節の頭）と弱拍で異なる音を鳴らす
        if (_beatCount == 0) {
          await _playStrongBeat(); // 1拍目は強拍
        } else {
          await _playWeakBeat(); // 2拍目以降は弱拍
        }
      });
    }
  }

  /// 関数を順番に実行するために使用するヘルパーメソッド
  Future<void> _executeSequentially(Future<void> Function() operation) async {
    if (_isProcessingBeat) {
      // 既に処理中の場合はキューに追加
      _pendingOperations.add(operation);
      return;
    }

    _isProcessingBeat = true;

    try {
      await operation();
    } finally {
      _isProcessingBeat = false;

      // キューに保留中の操作があれば実行
      if (_pendingOperations.isNotEmpty) {
        final nextOperation = _pendingOperations.removeAt(0);
        _executeSequentially(nextOperation);
      }
    }
  }

  /// 強拍のクリック音を再生する（小節の頭、アクセント）
  Future<void> _playStrongBeat() async {
    if (!_isPlaying) return;

    try {
      // バイブレーションと音を同時に実行
      if (_shouldVibrate) {
        HapticFeedback.heavyImpact();
      }

      // すでにAudioSourceが設定されているので直接再生
      await _audioPlayer1.seek(Duration.zero); // 位置をリセット
      await _audioPlayer1.play();
    } catch (e) {
      print("強拍音声再生エラー: $e");
    }
  }

  /// 弱拍のクリック音を再生する（小節の頭以外）
  Future<void> _playWeakBeat() async {
    if (!_isPlaying) return;

    try {
      // バイブレーションと音を同時に実行
      if (_shouldVibrate) {
        HapticFeedback.mediumImpact();
      }

      // すでにAudioSourceが設定されているので直接再生
      await _audioPlayer2.seek(Duration.zero); // 位置をリセット
      await _audioPlayer2.play();
    } catch (e) {
      print("弱拍音声再生エラー: $e");
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
