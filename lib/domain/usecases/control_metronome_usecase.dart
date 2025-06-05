import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';
import '../repositories/metronome_repository.dart';

/// メトロノーム制御のユースケース
class ControlMetronomeUseCase {
  final MetronomeRepository _metronomeRepository;

  ControlMetronomeUseCase({
    required MetronomeRepository metronomeRepository,
  }) : _metronomeRepository = metronomeRepository;

  /// メトロノームを開始
  Future<Result<void>> start({double? bpm}) async {
    if (!_metronomeRepository.isPlaying) {
      return await _metronomeRepository.start(bpm: bpm);
    }
    return Results.success(null);
  }

  /// メトロノームを停止
  Future<Result<void>> stop() async {
    if (_metronomeRepository.isPlaying) {
      return await _metronomeRepository.stop();
    }
    return Results.success(null);
  }

  /// テンポを変更
  Future<Result<void>> changeTempo(double bpm) async {
    if (bpm <= 0 || bpm > 300) {
      return Results.failure(
        const ValidationException(
          message: 'BPM must be between 1 and 300',
          code: 'INVALID_BPM',
        ),
      );
    }
    return await _metronomeRepository.changeTempo(bpm);
  }

  /// バイブレーション設定を変更
  Future<Result<void>> setVibration(bool enabled) async {
    return await _metronomeRepository.setVibration(enabled);
  }

  /// 現在の状態を取得
  MetronomeState getCurrentState() {
    return MetronomeState(
      isPlaying: _metronomeRepository.isPlaying,
      bpm: _metronomeRepository.currentBpm,
      vibrationEnabled: _metronomeRepository.vibrationEnabled,
    );
  }
}

