import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/repositories/gait_repository.dart';
import '../../domain/interfaces/gait_analyzer.dart';
import '../../services/legacy_gait_analyzer_adapter.dart';

/// Implementation of gait repository
class GaitRepositoryImpl implements IGaitRepository {
  IGaitAnalyzer? _currentAnalyzer;
  
  @override
  IGaitAnalyzer get analyzer {
    _currentAnalyzer ??= createAnalyzer(const GaitAnalysisConfig());
    return _currentAnalyzer!;
  }
  
  @override
  IGaitAnalyzer createAnalyzer(GaitAnalysisConfig config) {
    // Dispose previous analyzer if exists
    _currentAnalyzer?.dispose();
    
    // Create new analyzer with legacy adapter
    _currentAnalyzer = LegacyGaitAnalyzerAdapter(config: config);
    return _currentAnalyzer!;
  }
  
  @override
  Future<void> saveSession({
    required String sessionId,
    required DateTime startTime,
    required DateTime endTime,
    required List<Map<String, dynamic>> data,
  }) async {
    final directory = await _getSessionDirectory();
    final file = File('${directory.path}/$sessionId.json');
    
    final sessionData = {
      'id': sessionId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'dataPoints': data.length,
      'data': data,
    };
    
    await file.writeAsString(jsonEncode(sessionData));
  }
  
  @override
  Future<List<Map<String, dynamic>>?> loadSession(String sessionId) async {
    try {
      final directory = await _getSessionDirectory();
      final file = File('${directory.path}/$sessionId.json');
      
      if (!await file.exists()) {
        return null;
      }
      
      final content = await file.readAsString();
      final sessionData = jsonDecode(content) as Map<String, dynamic>;
      
      return (sessionData['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading session: $e');
      return null;
    }
  }
  
  @override
  Future<List<SessionInfo>> getSavedSessions() async {
    final directory = await _getSessionDirectory();
    final files = await directory.list().toList();
    final sessions = <SessionInfo>[];
    
    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          
          // Calculate average SPM and total steps from data
          double? avgSpm;
          int? totalSteps;
          
          if (data['data'] != null) {
            final dataList = (data['data'] as List<dynamic>);
            if (dataList.isNotEmpty) {
              double spmSum = 0;
              int spmCount = 0;
              
              for (final point in dataList) {
                if (point['spm'] != null) {
                  spmSum += point['spm'];
                  spmCount++;
                }
                if (point['stepCount'] != null && totalSteps == null) {
                  totalSteps = point['stepCount'];
                }
              }
              
              if (spmCount > 0) {
                avgSpm = spmSum / spmCount;
              }
            }
          }
          
          sessions.add(SessionInfo(
            id: data['id'],
            startTime: DateTime.parse(data['startTime']),
            endTime: DateTime.parse(data['endTime']),
            dataPoints: data['dataPoints'] ?? 0,
            averageSpm: avgSpm,
            totalSteps: totalSteps,
          ));
        } catch (e) {
          print('Error parsing session file: $e');
        }
      }
    }
    
    // Sort by start time (newest first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    
    return sessions;
  }
  
  @override
  Future<void> deleteSession(String sessionId) async {
    final directory = await _getSessionDirectory();
    final file = File('${directory.path}/$sessionId.json');
    
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  @override
  Future<String> exportSessionToCsv(String sessionId) async {
    final data = await loadSession(sessionId);
    if (data == null || data.isEmpty) {
      throw Exception('Session not found or empty');
    }
    
    // Create CSV header
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,SPM,Confidence,Step Count,Type');
    
    // Add data rows
    for (final point in data) {
      buffer.writeln(
        '${point['timestamp'] ?? ''},'
        '${point['spm'] ?? ''},'
        '${point['confidence'] ?? ''},'
        '${point['stepCount'] ?? ''},'
        '${point['type'] ?? ''}',
      );
    }
    
    // Save to file
    final directory = await _getSessionDirectory();
    final csvFile = File('${directory.path}/$sessionId.csv');
    await csvFile.writeAsString(buffer.toString());
    
    return csvFile.path;
  }
  
  Future<Directory> _getSessionDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/gait_sessions');
    
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    
    return sessionDir;
  }
  
  void dispose() {
    _currentAnalyzer?.dispose();
  }
}