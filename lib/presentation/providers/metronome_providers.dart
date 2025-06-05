import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger_service.dart';
import '../../domain/repositories/metronome_repository.dart';
import '../../data/repositories/flutter_metronome_repository_impl.dart';
import '../../data/repositories/native_metronome_repository_impl.dart';

/// メトロノームタイプ
enum MetronomeType {
  flutter,
  native,
}

/// 使用するメトロノームタイプのプロバイダー
final metronomeTypeProvider = StateProvider<MetronomeType>((ref) => MetronomeType.native);

/// Flutterメトロノームリポジトリのプロバイダー
final flutterMetronomeRepositoryProvider = Provider<MetronomeRepository>((ref) {
  final repository = FlutterMetronomeRepositoryImpl();
  ref.onDispose(() {
    repository.dispose();
  });
  return repository;
});

/// ネイティブメトロノームリポジトリのプロバイダー
final nativeMetronomeRepositoryProvider = Provider<MetronomeRepository>((ref) {
  final repository = NativeMetronomeRepositoryImpl();
  ref.onDispose(() {
    repository.dispose();
  });
  return repository;
});

/// 現在のメトロノームリポジトリのプロバイダー
final metronomeRepositoryProvider = Provider<MetronomeRepository>((ref) {
  final type = ref.watch(metronomeTypeProvider);
  return type == MetronomeType.native
      ? ref.watch(nativeMetronomeRepositoryProvider)
      : ref.watch(flutterMetronomeRepositoryProvider);
});

/// 現在のBPMを管理するプロバイダー
final currentBpmProvider = StateProvider<double>((ref) => 120.0);

/// メトロノーム再生状態を管理するプロバイダー
final isPlayingProvider = StateProvider<bool>((ref) => false);

/// 振動の有効/無効を管理するプロバイダー
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);

/// メトロノームコントローラーのプロバイダー
final metronomeControllerProvider = Provider<MetronomeController>((ref) {
  final repository = ref.watch(metronomeRepositoryProvider);
  
  return MetronomeController(
    ref: ref,
    repository: repository,
  );
});

/// メトロノームコントローラー
class MetronomeController {
  final Ref _ref;
  final MetronomeRepository _repository;
  
  MetronomeController({
    required Ref ref,
    required MetronomeRepository repository,
  })  : _ref = ref,
        _repository = repository;
  
  Future<void> initialize() async {
    final result = await _repository.initialize();
    result.fold(
      (error) {
        logger.error('Failed to initialize metronome', error);
        // ネイティブが失敗したらFlutterにフォールバック
        final currentType = _ref.read(metronomeTypeProvider);
        if (currentType == MetronomeType.native) {
          _ref.read(metronomeTypeProvider.notifier).state = MetronomeType.flutter;
        }
      },
      (_) => {},
    );
  }
  
  Future<void> start() async {
    final bpm = _ref.read(currentBpmProvider);
    final vibrationEnabled = _ref.read(vibrationEnabledProvider);
    
    await _repository.setVibration(vibrationEnabled);
    final result = await _repository.start(bpm: bpm);
    
    result.fold(
      (error) {
        logger.error('Failed to start metronome', error);
        _ref.read(isPlayingProvider.notifier).state = false;
      },
      (_) {
        _ref.read(isPlayingProvider.notifier).state = true;
      },
    );
  }
  
  Future<void> stop() async {
    final result = await _repository.stop();
    
    result.fold(
      (error) {
        logger.error('Failed to stop metronome', error);
      },
      (_) {
        _ref.read(isPlayingProvider.notifier).state = false;
      },
    );
  }
  
  Future<void> setBpm(double bpm) async {
    _ref.read(currentBpmProvider.notifier).state = bpm;
    
    if (_ref.read(isPlayingProvider)) {
      final result = await _repository.changeTempo(bpm);
      result.fold(
        (error) => logger.error('Failed to set BPM', error),
        (_) => {},
      );
    }
  }
  
  Future<void> setVibration(bool enabled) async {
    _ref.read(vibrationEnabledProvider.notifier).state = enabled;
    
    if (_ref.read(isPlayingProvider)) {
      final result = await _repository.setVibration(enabled);
      result.fold(
        (error) => logger.error('Failed to set vibration', error),
        (_) => {},
      );
    }
  }
  
  Stream<void> get beatStream => _repository.beatStream;
}