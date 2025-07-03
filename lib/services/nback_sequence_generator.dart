import 'dart:math' as math;

/// N-back課題の数字列生成クラス
class NBackSequenceGenerator {
  final math.Random _random;
  
  NBackSequenceGenerator({int? seed}) : _random = math.Random(seed);
  
  /// N-back課題用の数字列を生成
  /// length: 数字列の長さ
  /// nLevel: N-backのレベル（0, 1, 2）
  /// minDigit: 最小数字（デフォルト: 1）
  /// maxDigit: 最大数字（デフォルト: 9）
  /// targetMatchRate: ターゲット一致率（デフォルト: 0.3 = 30%）
  List<int> generate({
    required int length,
    required int nLevel,
    int minDigit = 1,
    int maxDigit = 9,
    double targetMatchRate = 0.3,
  }) {
    if (length < 1) {
      throw ArgumentError('Length must be at least 1');
    }
    
    if (nLevel < 0 || nLevel > 2) {
      throw ArgumentError('nLevel must be 0, 1, or 2');
    }
    
    if (minDigit >= maxDigit) {
      throw ArgumentError('minDigit must be less than maxDigit');
    }
    
    if (targetMatchRate < 0 || targetMatchRate > 1) {
      throw ArgumentError('targetMatchRate must be between 0 and 1');
    }
    
    // N-backが0の場合は特別な処理
    if (nLevel == 0) {
      return _generateZeroBack(length, minDigit, maxDigit, targetMatchRate);
    }
    
    // 通常のN-back生成
    final sequence = <int>[];
    final targetMatches = (length * targetMatchRate).round();
    final matchPositions = _generateMatchPositions(length, nLevel, targetMatches);
    
    for (int i = 0; i < length; i++) {
      if (i < nLevel) {
        // 最初のn個はランダム
        sequence.add(_randomDigit(minDigit, maxDigit));
      } else if (matchPositions.contains(i)) {
        // マッチ位置：n個前と同じ数字
        sequence.add(sequence[i - nLevel]);
      } else {
        // 非マッチ位置：n個前と異なる数字
        int digit;
        do {
          digit = _randomDigit(minDigit, maxDigit);
        } while (digit == sequence[i - nLevel]);
        sequence.add(digit);
      }
    }
    
    return sequence;
  }
  
  /// 0-back用の数字列生成（特定のターゲット数字の検出）
  List<int> _generateZeroBack(
    int length,
    int minDigit,
    int maxDigit,
    double targetMatchRate,
  ) {
    // ターゲット数字をランダムに選択
    final targetDigit = _randomDigit(minDigit, maxDigit);
    final sequence = <int>[];
    final targetCount = (length * targetMatchRate).round();
    
    // ターゲット出現位置を決定
    final targetPositions = <int>{};
    while (targetPositions.length < targetCount) {
      targetPositions.add(_random.nextInt(length));
    }
    
    // 数字列を生成
    for (int i = 0; i < length; i++) {
      if (targetPositions.contains(i)) {
        sequence.add(targetDigit);
      } else {
        int digit;
        do {
          digit = _randomDigit(minDigit, maxDigit);
        } while (digit == targetDigit);
        sequence.add(digit);
      }
    }
    
    return sequence;
  }
  
  /// マッチ位置を生成
  Set<int> _generateMatchPositions(int length, int nLevel, int targetMatches) {
    final positions = <int>{};
    final availablePositions = <int>[];
    
    // n番目以降の位置のみ利用可能
    for (int i = nLevel; i < length; i++) {
      availablePositions.add(i);
    }
    
    // ターゲット数がavailable positionsより多い場合は調整
    final actualMatches = math.min(targetMatches, availablePositions.length);
    
    // ランダムに位置を選択
    availablePositions.shuffle(_random);
    for (int i = 0; i < actualMatches; i++) {
      positions.add(availablePositions[i]);
    }
    
    return positions;
  }
  
  /// ランダムな数字を生成
  int _randomDigit(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }
  
  /// 生成された数字列の正答を計算（検証用）
  List<bool> calculateCorrectAnswers(List<int> sequence, int nLevel) {
    final answers = <bool>[];
    
    if (nLevel == 0) {
      // 0-backの場合、最初の数字がターゲット
      final target = sequence.first;
      for (final digit in sequence) {
        answers.add(digit == target);
      }
    } else {
      // 通常のN-back
      for (int i = 0; i < sequence.length; i++) {
        if (i < nLevel) {
          // 最初のn個は常にfalse（比較対象がない）
          answers.add(false);
        } else {
          answers.add(sequence[i] == sequence[i - nLevel]);
        }
      }
    }
    
    return answers;
  }
  
  /// 数字列の統計情報を取得
  Map<String, dynamic> getSequenceStatistics(List<int> sequence, int nLevel) {
    final answers = calculateCorrectAnswers(sequence, nLevel);
    final matchCount = answers.where((a) => a).length;
    final matchRate = sequence.isEmpty ? 0.0 : matchCount / sequence.length;
    
    // 数字の分布
    final digitDistribution = <int, int>{};
    for (final digit in sequence) {
      digitDistribution[digit] = (digitDistribution[digit] ?? 0) + 1;
    }
    
    return {
      'length': sequence.length,
      'nLevel': nLevel,
      'matchCount': matchCount,
      'matchRate': matchRate,
      'digitDistribution': digitDistribution,
      'uniqueDigits': digitDistribution.keys.length,
    };
  }
  
  /// N-back応答が正しいかチェック
  static bool isCorrectResponse({
    required List<int> sequence,
    required int currentIndex,
    required int nLevel,
    required int? response,
  }) {
    if (currentIndex < 0 || currentIndex >= sequence.length) {
      throw RangeError('Current index out of range');
    }
    
    if (nLevel == 0) {
      // 0-back: 最初の数字と比較
      return response == sequence[0];
    }
    
    if (currentIndex < nLevel) {
      // n-back不可能な位置では応答なしが正解
      return response == null;
    }
    
    // n-back: n個前の数字と比較
    return response == sequence[currentIndex - nLevel];
  }
  
  /// 正答率を計算
  static double calculateAccuracy(List<({int stimulus, int? response, bool isCorrect})> responses) {
    if (responses.isEmpty) return 0.0;
    
    final correctCount = responses.where((r) => r.isCorrect).length;
    return correctCount / responses.length;
  }
  
  /// 反応時間の統計を計算
  static Map<String, double> calculateResponseTimeStats(List<int> responseTimes) {
    if (responseTimes.isEmpty) {
      return {'mean': 0, 'median': 0, 'min': 0, 'max': 0};
    }
    
    final sorted = List<int>.from(responseTimes)..sort();
    final mean = responseTimes.reduce((a, b) => a + b) / responseTimes.length;
    final median = sorted.length.isOdd
        ? sorted[sorted.length ~/ 2].toDouble()
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2.0;
    
    return {
      'mean': mean,
      'median': median,
      'min': sorted.first.toDouble(),
      'max': sorted.last.toDouble(),
    };
  }
}