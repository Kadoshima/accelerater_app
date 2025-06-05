import 'dart:async';
import '../../core/utils/result.dart';
import '../../core/utils/logger_service.dart';
import '../../core/errors/app_exceptions.dart';
import '../../domain/repositories/metronome_repository.dart';
import '../../services/metronome.dart';

/// Flutter（Dart）メトロノームリポジトリの実装
class FlutterMetronomeRepositoryImpl implements MetronomeRepository {
  final Metronome _metronome;
  final StreamController<MetronomeState> _stateController = StreamController<MetronomeState>.broadcast();
  bool _vibrationEnabled = false;

  FlutterMetronomeRepositoryImpl({
    Metronome? metronome,
  }) : _metronome = metronome ?? Metronome();

  @override
  Future<Result<void>> initialize() async {
    return Results.tryAsync(() async {
      await _metronome.initialize();
      logger.info('Flutter metronome initialized');
    }, onError: (error, stackTrace) {
      logger.error('Failed to initialize Flutter metronome', error, stackTrace);
      return AppException(
        message: 'Failed to initialize metronome',
        code: 'METRONOME_INIT_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> start({double? bpm}) async {
    return Results.tryAsync(() async {
      await _metronome.start(bpm: bpm);
      _updateState();
      logger.info('Flutter metronome started at ${bpm ?? currentBpm} BPM');
    }, onError: (error, stackTrace) {
      logger.error('Failed to start Flutter metronome', error, stackTrace);
      return AppException(
        message: 'Failed to start metronome',
        code: 'METRONOME_START_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> stop() async {
    return Results.tryAsync(() async {
      await _metronome.stop();
      _updateState();
      logger.info('Flutter metronome stopped');
    }, onError: (error, stackTrace) {
      logger.error('Failed to stop Flutter metronome', error, stackTrace);
      return AppException(
        message: 'Failed to stop metronome',
        code: 'METRONOME_STOP_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> changeTempo(double bpm) async {
    return Results.tryAsync(() async {
      await _metronome.changeTempo(bpm);
      _updateState();
      logger.info('Flutter metronome tempo changed to $bpm BPM');
    }, onError: (error, stackTrace) {
      logger.error('Failed to change Flutter metronome tempo', error, stackTrace);
      return AppException(
        message: 'Failed to change metronome tempo',
        code: 'METRONOME_TEMPO_ERROR',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> setVibration(bool enabled) async {
    return Results.tryAsync(() async {
      _metronome.setVibration(enabled);
      _vibrationEnabled = enabled;
      _updateState();
      logger.info('Flutter metronome vibration ${enabled ? "enabled" : "disabled"}');
    }, onError: (error, stackTrace) {
      logger.error('Failed to set Flutter metronome vibration', error, stackTrace);
      return AppException(
        message: 'Failed to set metronome vibration',
        code: 'METRONOME_VIBRATION_ERROR',
        originalError: error,
      );
    });
  }

  @override
  bool get isPlaying => _metronome.isPlaying;

  @override
  double get currentBpm => _metronome.currentBpm;

  @override
  bool get vibrationEnabled => _vibrationEnabled;

  @override
  Stream<void> get beatStream {
    // TODO: Implement beat stream for Flutter metronome
    return Stream<void>.periodic(
      Duration(milliseconds: (60000 / currentBpm).round()),
    );
  }

  @override
  Stream<MetronomeState> get stateStream => _stateController.stream;

  @override
  void dispose() {
    _metronome.dispose();
    _stateController.close();
  }

  void _updateState() {
    _stateController.add(MetronomeState(
      isPlaying: isPlaying,
      bpm: currentBpm,
      vibrationEnabled: vibrationEnabled,
    ));
  }
}