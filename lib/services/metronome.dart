import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// メトロノーム機能を提供するクラス（波形生成バージョン）
class Metronome {
  // 音声プレーヤー
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 波形データ
  Uint8List? _beatWaveform;

  // AudioSource
  AudioSource? _beatSource;

  // 高精度タイマー用変数
  Timer? _timer;
  DateTime? _lastBeatTime;
  int _beatCount = 0; // 拍カウント（将来的な拡張用）
  final int _beatsPerBar = 4; // 将来的な拡張用
  int _nextBeatScheduledAt = 0; // 次の拍がスケジュールされた時間（ミリ秒）

  bool _isPlaying = false;
  double _currentBpm = 100.0;

  // シーケンシャル実行制御用
  bool _isProcessingBeat = false;
  final List<Future<void> Function()> _pendingOperations = [];

  bool get isPlaying => _isPlaying;
  double get currentBpm => _currentBpm;

  /// メトロノームを初期化する
  Future<void> initialize() async {
    try {
      // 音声プレーヤーの音量を最大に設定
      await _audioPlayer.setVolume(1.0);

      // クリック音波形を生成
      _beatWaveform = _generateClickWaveform(
        frequency: 900, // 中間の周波数
        durationMs: 25,
        amplitude: 0.8,
      );

      // AudioSourceを事前に作成
      _beatSource = MyCustomSource(_beatWaveform!);

      // 音声を事前にロード
      await _audioPlayer.setAudioSource(_beatSource!);

      print("メトロノーム波形生成完了: ${_beatWaveform!.length}バイト");

      // ウォームアップ（一度再生してシステムを準備）
      await _audioPlayer.setVolume(0); // 無音で
      await _audioPlayer.play(); // 再生
      await _audioPlayer.stop(); // 即停止
      await _audioPlayer.setVolume(1.0); // 音量戻す
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
    if (_beatSource == null) {
      print("警告: 音源が準備できていないため再初期化します");

      // 波形を再生成
      _beatWaveform = _generateClickWaveform(
        frequency: 900,
        durationMs: 25,
        amplitude: 0.8,
      );

      // AudioSourceを作成
      _beatSource = MyCustomSource(_beatWaveform!);

      // 音声をプリロード
      await _audioPlayer.setAudioSource(_beatSource!);
    }

    // タイマーで定期的な実行を開始
    _startHighPrecisionTimer();
    print("メトロノーム開始: $_currentBpm BPM");

    // 最初のクリックを即座に行う
    await _playBeat();
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

    // 音声を停止
    await _audioPlayer.stop();
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
    // タイマー間隔を非常に短く設定して高い精度を実現
    const tickInterval = Duration(milliseconds: 1);

    // まず直前のタイマーをキャンセル
    _timer?.cancel();

    _timer = Timer.periodic(tickInterval, (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      // 次のビートのタイミングをチェックして再生
      _checkAndPlayNextBeat();
    });

    // 開始ログ
    print(
        '高精度タイマー開始 - 間隔: ${tickInterval.inMilliseconds}ms, BPM: $_currentBpm');
  }

  /// 次の拍を再生するタイミングかチェックし、適切なタイミングで再生
  void _checkAndPlayNextBeat() {
    if (_lastBeatTime == null) return; // 停止中または初期化中

    final now = DateTime.now();
    final double intervalMillisecondsDouble = 60000.0 / _currentBpm;
    final int intervalMilliseconds = intervalMillisecondsDouble.round();

    // 最初の拍の場合は、開始時刻を基準にする
    if (_beatCount == 0) {
      // 最初の拍は既に鳴らしているので、次の拍の時刻を計算
      final nextBeatTime =
          _lastBeatTime!.add(Duration(milliseconds: intervalMilliseconds));

      // 次の拍の時刻になったら再生
      if (now.isAfter(nextBeatTime)) {
        // 拍カウントを更新
        _beatCount++;

        // 基準時刻を更新（累積誤差を防ぐため、理論上の時刻を使用）
        _lastBeatTime =
            _lastBeatTime!.add(Duration(milliseconds: intervalMilliseconds));

        // ビートを再生
        _playBeat();
      }
    } else {
      // 2回目以降の拍の場合

      // 次の拍の理論上の時刻を計算（累積誤差を防ぐ）
      final nextBeatTime =
          _lastBeatTime!.add(Duration(milliseconds: intervalMilliseconds));

      // 現在時刻が次の拍の時刻を過ぎているかチェック
      if (now.isAfter(nextBeatTime)) {
        if (_isProcessingBeat) {
          // 既に処理中なら待機（多重再生防止）
          return;
        }

        _isProcessingBeat = true;

        // 拍カウントを更新
        _beatCount++;

        // 基準時刻を更新（累積誤差を防ぐため、理論上の時刻を使用）
        _lastBeatTime = nextBeatTime;

        // 非同期で拍を再生
        _playBeat().whenComplete(() {
          _isProcessingBeat = false; // 処理完了フラグを解除
        });
      }
    }
  }

  /// クリック音を再生する
  Future<void> _playBeat() async {
    if (!_isPlaying) return;

    try {
      // 音声再生 - 必ず位置をリセットしてから再生
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();

      // 音が確実に鳴るようにデバッグ出力を追加
      print("メトロノーム: ビート再生 - BPM: $_currentBpm");
    } catch (e) {
      print("音声再生エラー: $e");
      // エラー発生時もフラグを確実に解除
      _isProcessingBeat = false;
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
    _audioPlayer.dispose();
  }
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
