import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/gait_repository.dart';
import '../../domain/interfaces/gait_analyzer.dart';
import '../../data/repositories/gait_repository_impl.dart';
import '../../../../core/plugins/research_plugin.dart';
import '../../services/gait_data_processor.dart';

/// Provider for gait repository
final gaitRepositoryProvider = Provider<IGaitRepository>((ref) {
  return GaitRepositoryImpl();
});

/// Provider for gait analyzer
final gaitAnalyzerProvider = Provider<IGaitAnalyzer>((ref) {
  final repository = ref.watch(gaitRepositoryProvider);
  return repository.analyzer;
});

/// Provider for gait analysis configuration
final gaitConfigProvider = StateProvider<GaitAnalysisConfig>((ref) {
  return const GaitAnalysisConfig();
});

/// Provider for current SPM
final currentSpmProvider = StreamProvider<double>((ref) async* {
  final analyzer = ref.watch(gaitAnalyzerProvider);
  
  // Emit current SPM periodically
  await for (final _ in Stream.periodic(const Duration(milliseconds: 100))) {
    yield analyzer.currentSpm;
  }
});

/// Provider for step events
final stepEventProvider = StreamProvider<StepEvent>((ref) {
  final analyzer = ref.watch(gaitAnalyzerProvider);
  return analyzer.stepStream;
});

/// Provider for gait data processor
final gaitDataProcessorProvider = Provider<DataProcessor>((ref) {
  final config = ref.watch(gaitConfigProvider);
  
  return GaitDataProcessor(
    settings: {
      'totalDataSeconds': config.totalDataSeconds,
      'windowSizeSeconds': config.windowSizeSeconds,
      'slideIntervalSeconds': config.slideIntervalSeconds,
      'minFrequency': config.minFrequency,
      'maxFrequency': config.maxFrequency,
      'minSpm': config.minSpm,
      'maxSpm': config.maxSpm,
      'smoothingFactor': config.smoothingFactor,
      'minReliability': config.minReliability,
      'staticThreshold': config.staticThreshold,
      'useSingleAxisOnly': config.useSingleAxisOnly,
      'verticalAxis': config.verticalAxis,
    },
  );
});

/// Provider for saved sessions
final savedSessionsProvider = FutureProvider<List<SessionInfo>>((ref) async {
  final repository = ref.watch(gaitRepositoryProvider);
  return await repository.getSavedSessions();
});

/// State notifier for gait analysis session
class GaitSessionNotifier extends StateNotifier<GaitSession?> {
  final IGaitRepository _repository;
  final List<Map<String, dynamic>> _sessionData = [];
  
  GaitSessionNotifier(this._repository) : super(null);
  
  void startSession() {
    state = GaitSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
    );
    _sessionData.clear();
  }
  
  void addDataPoint(Map<String, dynamic> data) {
    if (state != null) {
      _sessionData.add({
        ...data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
  
  Future<void> endSession() async {
    if (state != null) {
      final endTime = DateTime.now();
      
      // Save session data
      await _repository.saveSession(
        sessionId: state!.id,
        startTime: state!.startTime,
        endTime: endTime,
        data: _sessionData,
      );
      
      state = null;
      _sessionData.clear();
    }
  }
  
  bool get isSessionActive => state != null;
}

/// Gait session model
class GaitSession {
  final String id;
  final DateTime startTime;
  
  const GaitSession({
    required this.id,
    required this.startTime,
  });
}

/// Provider for gait session management
final gaitSessionProvider = 
    StateNotifierProvider<GaitSessionNotifier, GaitSession?>((ref) {
  final repository = ref.watch(gaitRepositoryProvider);
  return GaitSessionNotifier(repository);
});