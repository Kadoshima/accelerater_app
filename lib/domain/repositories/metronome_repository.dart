import 'dart:async';
import '../../core/utils/result.dart';

/// メトロノーム管理リポジトリのインターフェース
abstract class MetronomeRepository {
  /// メトロノームを初期化
  Future<Result<void>> initialize();

  /// メトロノームを開始
  Future<Result<void>> start({double? bpm});

  /// メトロノームを停止
  Future<Result<void>> stop();

  /// テンポを変更
  Future<Result<void>> changeTempo(double bpm);

  /// バイブレーション設定を変更
  Future<Result<void>> setVibration(bool enabled);

  /// 現在の再生状態を取得
  bool get isPlaying;

  /// 現在のBPMを取得
  double get currentBpm;

  /// バイブレーション設定を取得
  bool get vibrationEnabled;

  /// ビートイベントのストリーム
  Stream<void> get beatStream;

  /// メトロノームの状態ストリーム
  Stream<MetronomeState> get stateStream;

  /// リソースを解放
  void dispose();
}

/// メトロノームの状態
class MetronomeState {
  final bool isPlaying;
  final double bpm;
  final bool vibrationEnabled;
  final DateTime? lastBeatTime;
  final int beatCount;

  const MetronomeState({
    required this.isPlaying,
    required this.bpm,
    required this.vibrationEnabled,
    this.lastBeatTime,
    this.beatCount = 0,
  });

  MetronomeState copyWith({
    bool? isPlaying,
    double? bpm,
    bool? vibrationEnabled,
    DateTime? lastBeatTime,
    int? beatCount,
  }) {
    return MetronomeState(
      isPlaying: isPlaying ?? this.isPlaying,
      bpm: bpm ?? this.bpm,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      lastBeatTime: lastBeatTime ?? this.lastBeatTime,
      beatCount: beatCount ?? this.beatCount,
    );
  }
}