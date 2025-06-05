import 'dart:async';
import '../../core/utils/result.dart';
import '../../core/utils/logger_service.dart';
import '../../core/errors/app_exceptions.dart';
import '../../domain/repositories/metronome_repository.dart';
import '../../services/native_metronome.dart';

/// ネイティブメトロノームリポジトリの実装
class NativeMetronomeRepositoryImpl implements MetronomeRepository {
  final NativeMetronome _nativeMetronome;
  final StreamController<MetronomeState> _stateController = StreamController<MetronomeState>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _statusSubscription;
  bool _vibrationEnabled = false;
  int _beatCount = 0;

  NativeMetronomeRepositoryImpl({
    NativeMetronome? nativeMetronome,
  }) : _nativeMetronome = nativeMetronome ?? NativeMetronome() {
    // ネイティブメトロノームの状態変更を監視
    _statusSubscription = _nativeMetronome.statusStream.listen((status) {
      _beatCount++;
      _updateState(lastBeatTime: DateTime.now(), beatCount: _beatCount);
    });
  }

  @override
  Future<Result<void>> initialize() async {
    return Results.tryAsync(() async {
      final success = await _nativeMetronome.initialize();
      if (!success) {
        throw Exception('Native metronome initialization failed');
      }
      logger.info('Native metronome initialized');
    }, onError: (error, stackTrace) {
      logger.error('Failed to initialize native metronome', error, stackTrace);
      return AppException(
        message: 'Failed to initialize native metronome',
        code: 'NATIVE_METRONOME_INIT_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> start({double? bpm}) async {
    return Results.tryAsync(() async {
      final success = await _nativeMetronome.start(bpm: bpm);
      if (!success) {
        throw Exception('Native metronome start failed');
      }
      _beatCount = 0;
      _updateState();
      logger.info('Native metronome started at ${bpm ?? currentBpm} BPM');
    }, onError: (error, stackTrace) {
      logger.error('Failed to start native metronome', error, stackTrace);
      return AppException(
        message: 'Failed to start native metronome',
        code: 'NATIVE_METRONOME_START_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> stop() async {
    return Results.tryAsync(() async {
      final success = await _nativeMetronome.stop();
      if (!success) {
        throw Exception('Native metronome stop failed');
      }
      _beatCount = 0;
      _updateState();
      logger.info('Native metronome stopped');
    }, onError: (error, stackTrace) {
      logger.error('Failed to stop native metronome', error, stackTrace);
      return AppException(
        message: 'Failed to stop native metronome',
        code: 'NATIVE_METRONOME_STOP_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> changeTempo(double bpm) async {
    return Results.tryAsync(() async {
      final success = await _nativeMetronome.changeTempo(bpm);
      if (!success) {
        throw Exception('Native metronome tempo change failed');
      }
      _updateState();
      logger.info('Native metronome tempo changed to $bpm BPM');
    }, onError: (error, stackTrace) {
      logger.error('Failed to change native metronome tempo', error, stackTrace);
      return AppException(
        message: 'Failed to change native metronome tempo',
        code: 'NATIVE_METRONOME_TEMPO_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> setVibration(bool enabled) async {
    return Results.tryAsync(() async {
      final success = await _nativeMetronome.setVibration(enabled);
      if (!success) {
        throw Exception('Native metronome vibration setting failed');
      }
      _vibrationEnabled = enabled;
      _updateState();
      logger.info('Native metronome vibration ${enabled ? "enabled" : "disabled"}');
    }, onError: (error, stackTrace) {
      logger.error('Failed to set native metronome vibration', error, stackTrace);
      return AppException(
        message: 'Failed to set native metronome vibration',
        code: 'NATIVE_METRONOME_VIBRATION_ERROR',
        originalError: error,
      );
    });
  }

  @override
  bool get isPlaying => _nativeMetronome.isPlaying;

  @override
  double get currentBpm => _nativeMetronome.currentBpm;

  @override
  bool get vibrationEnabled => _vibrationEnabled;

  @override
  Stream<void> get beatStream => _nativeMetronome.statusStream.map((_) {});

  @override
  Stream<MetronomeState> get stateStream => _stateController.stream;

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _nativeMetronome.dispose();
    _stateController.close();
  }

  void _updateState({DateTime? lastBeatTime, int? beatCount}) {
    _stateController.add(MetronomeState(
      isPlaying: isPlaying,
      bpm: currentBpm,
      vibrationEnabled: vibrationEnabled,
      lastBeatTime: lastBeatTime,
      beatCount: beatCount ?? _beatCount,
    ));
  }
}