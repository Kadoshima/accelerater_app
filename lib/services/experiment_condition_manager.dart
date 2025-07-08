import '../models/nback_models.dart';

/// 実験条件管理システム
/// 6条件（2×3）の実験デザインを管理
class ExperimentConditionManager {
  // 実験条件の組み合わせ
  static const List<ExperimentCondition> allConditions = [
    ExperimentCondition(
      id: 'adaptive_none',
      tempoControl: TempoControl.adaptive,
      cognitiveLoad: CognitiveLoad.none,
    ),
    ExperimentCondition(
      id: 'adaptive_0back',
      tempoControl: TempoControl.adaptive,
      cognitiveLoad: CognitiveLoad.nBack0,
    ),
    ExperimentCondition(
      id: 'adaptive_1back',
      tempoControl: TempoControl.adaptive,
      cognitiveLoad: CognitiveLoad.nBack1,
    ),
    ExperimentCondition(
      id: 'adaptive_2back',
      tempoControl: TempoControl.adaptive,
      cognitiveLoad: CognitiveLoad.nBack2,
    ),
    ExperimentCondition(
      id: 'fixed_none',
      tempoControl: TempoControl.fixed,
      cognitiveLoad: CognitiveLoad.none,
    ),
    ExperimentCondition(
      id: 'fixed_0back',
      tempoControl: TempoControl.fixed,
      cognitiveLoad: CognitiveLoad.nBack0,
    ),
    ExperimentCondition(
      id: 'fixed_1back',
      tempoControl: TempoControl.fixed,
      cognitiveLoad: CognitiveLoad.nBack1,
    ),
    ExperimentCondition(
      id: 'fixed_2back',
      tempoControl: TempoControl.fixed,
      cognitiveLoad: CognitiveLoad.nBack2,
    ),
  ];
  
  // 現在の条件インデックス
  int _currentConditionIndex = 0;
  
  // 条件の順序（ラテン方格法で決定）
  List<ExperimentCondition> _conditionOrder = [];
  
  
  /// 初期化
  void initialize({required int participantNumber}) {
    _conditionOrder = _generateConditionOrder(participantNumber);
    _currentConditionIndex = 0;
  }
  
  /// ラテン方格法による条件順序の生成
  List<ExperimentCondition> _generateConditionOrder(int participantNumber) {
    // 6条件なので、6×6のラテン方格を使用
    // 被験者番号に基づいて行を選択
    final row = participantNumber % 6;
    
    // 標準的な6×6ラテン方格
    final latinSquare = [
      [0, 1, 2, 3, 4, 5],
      [1, 2, 3, 4, 5, 0],
      [2, 3, 4, 5, 0, 1],
      [3, 4, 5, 0, 1, 2],
      [4, 5, 0, 1, 2, 3],
      [5, 0, 1, 2, 3, 4],
    ];
    
    // 選択された行の順序で条件を並べ替え
    final orderIndices = latinSquare[row];
    final orderedConditions = <ExperimentCondition>[];
    
    // 基本的な6条件（認知負荷なしとfixedは除外）を取得
    final primaryConditions = allConditions.where((c) => 
      c.cognitiveLoad != CognitiveLoad.none && 
      c.tempoControl == TempoControl.adaptive
    ).toList();
    
    for (final index in orderIndices.take(primaryConditions.length)) {
      orderedConditions.add(primaryConditions[index]);
    }
    
    return orderedConditions;
  }
  
  /// 現在の条件を取得
  ExperimentCondition getCurrentCondition() {
    if (_conditionOrder.isEmpty) {
      throw StateError('Condition manager not initialized');
    }
    return _conditionOrder[_currentConditionIndex];
  }
  
  /// 次の条件に進む
  bool moveToNextCondition() {
    if (_currentConditionIndex < _conditionOrder.length - 1) {
      _currentConditionIndex++;
      return true;
    }
    return false;
  }
  
  /// 前の条件に戻る
  bool moveToPreviousCondition() {
    if (_currentConditionIndex > 0) {
      _currentConditionIndex--;
      return true;
    }
    return false;
  }
  
  /// 特定の条件にジャンプ
  void jumpToCondition(int index) {
    if (index >= 0 && index < _conditionOrder.length) {
      _currentConditionIndex = index;
    }
  }
  
  /// 進行状況を取得
  ExperimentProgress getProgress() {
    return ExperimentProgress(
      currentIndex: _currentConditionIndex,
      totalConditions: _conditionOrder.length,
      completedConditions: _currentConditionIndex,
      currentCondition: getCurrentCondition(),
      allConditions: List.unmodifiable(_conditionOrder),
    );
  }
  
  /// 現在のブロックインデックスを取得
  int getCurrentBlockIndex() {
    return _currentConditionIndex;
  }
  
  /// 現在のブロックを完了
  void completeCurrentBlock() {
    moveToNextCondition();
  }
  
  /// リセット
  void reset() {
    _currentConditionIndex = 0;
  }
  
  /// 条件の説明文を生成
  static String getConditionDescription(ExperimentCondition condition) {
    final tempo = condition.tempoControl == TempoControl.adaptive 
        ? '適応的テンポ制御' 
        : '固定テンポ制御';
    
    final cognitive = switch (condition.cognitiveLoad) {
      CognitiveLoad.none => '認知負荷なし',
      CognitiveLoad.nBack0 => '0-back課題',
      CognitiveLoad.nBack1 => '1-back課題',
      CognitiveLoad.nBack2 => '2-back課題',
    };
    
    return '$tempo + $cognitive';
  }
  
  /// 条件の短縮名を生成
  static String getConditionShortName(ExperimentCondition condition) {
    final tempo = condition.tempoControl == TempoControl.adaptive ? 'A' : 'F';
    final cognitive = switch (condition.cognitiveLoad) {
      CognitiveLoad.none => 'N',
      CognitiveLoad.nBack0 => '0',
      CognitiveLoad.nBack1 => '1',
      CognitiveLoad.nBack2 => '2',
    };
    
    return '$tempo-$cognitive';
  }
  
  /// 休憩が必要かチェック
  bool isRestNeeded() {
    // 2条件ごとに休憩を推奨
    return _currentConditionIndex > 0 && _currentConditionIndex % 2 == 0;
  }
  
  /// 推奨休憩時間を取得（秒）
  int getRecommendedRestDuration() {
    if (_currentConditionIndex >= 4) {
      return 180; // 3分
    } else if (_currentConditionIndex >= 2) {
      return 120; // 2分
    }
    return 60; // 1分
  }
}

/// 実験条件
class ExperimentCondition {
  final String id;
  final TempoControl tempoControl;
  final CognitiveLoad cognitiveLoad;
  
  const ExperimentCondition({
    required this.id,
    required this.tempoControl,
    required this.cognitiveLoad,
  });
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExperimentCondition &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

/// 実験進行状況
class ExperimentProgress {
  final int currentIndex;
  final int totalConditions;
  final int completedConditions;
  final ExperimentCondition currentCondition;
  final List<ExperimentCondition> allConditions;
  
  ExperimentProgress({
    required this.currentIndex,
    required this.totalConditions,
    required this.completedConditions,
    required this.currentCondition,
    required this.allConditions,
  });
  
  double get progressPercentage => 
      totalConditions > 0 ? completedConditions / totalConditions : 0.0;
  
  bool get isCompleted => completedConditions >= totalConditions;
  
  String get progressText => 
      '${completedConditions + 1} / $totalConditions';
}