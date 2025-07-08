import '../interfaces/gait_analyzer.dart';

/// Repository interface for gait analysis
abstract class IGaitRepository {
  /// Get the current gait analyzer instance
  IGaitAnalyzer get analyzer;
  
  /// Create a new analyzer with configuration
  IGaitAnalyzer createAnalyzer(GaitAnalysisConfig config);
  
  /// Save gait analysis session data
  Future<void> saveSession({
    required String sessionId,
    required DateTime startTime,
    required DateTime endTime,
    required List<Map<String, dynamic>> data,
  });
  
  /// Load previous session data
  Future<List<Map<String, dynamic>>?> loadSession(String sessionId);
  
  /// Get list of saved sessions
  Future<List<SessionInfo>> getSavedSessions();
  
  /// Delete a session
  Future<void> deleteSession(String sessionId);
  
  /// Export session data to CSV
  Future<String> exportSessionToCsv(String sessionId);
}

/// Information about a saved session
class SessionInfo {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int dataPoints;
  final double? averageSpm;
  final int? totalSteps;
  
  const SessionInfo({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.dataPoints,
    this.averageSpm,
    this.totalSteps,
  });
}