import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';

/// Calculate basic statistics from walking SPM data and save them locally.
/// Returns the path to the created summary file.
Future<String> saveSpmAnalysis({
  required List<Map<String, dynamic>> timeSeriesData,
  required String subjectId,
  String filePrefix = 'analysis',
}) async {
  final spmValues = timeSeriesData
      .map<double>((e) => (e['currentSPM'] as double? ?? 0))
      .where((v) => v > 0)
      .toList();

  double mean = 0;
  double stdDev = 0;
  double cv = 0;

  if (spmValues.isNotEmpty) {
    mean = spmValues.reduce((a, b) => a + b) / spmValues.length;
    double sumSq = 0;
    for (final v in spmValues) {
      sumSq += math.pow(v - mean, 2) as double;
    }
    stdDev = math.sqrt(sumSq / spmValues.length);
    if (mean != 0) {
      cv = stdDev / mean;
    }
  }

  final analysis = {
    'subjectId': subjectId.isEmpty ? 'unknown' : subjectId,
    'timestamp': DateTime.now().toIso8601String(),
    'meanSPM': mean,
    'stdDevSPM': stdDev,
    'coefficientOfVariation': cv,
  };

  final directory = await getApplicationDocumentsDirectory();
  final folderPath = '${directory.path}/analysis_results';
  final folder = Directory(folderPath);
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final fileName = '${filePrefix}_summary.json';
  final filePath = '$folderPath/$fileName';
  final file = File(filePath);
  await file.writeAsString(jsonEncode(analysis));

  return filePath;
}
