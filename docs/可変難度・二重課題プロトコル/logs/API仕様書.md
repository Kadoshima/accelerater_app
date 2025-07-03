# API仕様書 - 可変難度・二重課題プロトコル

## 1. AdaptiveTempoService

### 概要
最小二乗線形予測を用いた適応的テンポ制御サービス

### メソッド

#### initialize
```dart
void initialize(double initialBpm)
```
- **説明**: サービスを初期化
- **パラメータ**:
  - `initialBpm`: 初期BPM値（60-200）
- **使用例**:
```dart
final tempoService = AdaptiveTempoService();
tempoService.initialize(100.0);
```

#### updateBpm
```dart
double updateBpm({
  required DateTime clickTime,
  required DateTime heelStrikeTime,
})
```
- **説明**: 位相誤差に基づいてBPMを更新
- **パラメータ**:
  - `clickTime`: メトロノームクリック時刻
  - `heelStrikeTime`: かかと接地時刻
- **戻り値**: 更新後のBPM
- **使用例**:
```dart
final newBpm = tempoService.updateBpm(
  clickTime: DateTime.now(),
  heelStrikeTime: DateTime.now().subtract(Duration(milliseconds: 50)),
);
```

---

## 2. PhaseErrorEngine

### 概要
位相誤差の計算とRMSE評価を行うエンジン

### メソッド

#### initialize
```dart
void initialize(double targetSpm)
```
- **説明**: エンジンを初期化
- **パラメータ**:
  - `targetSpm`: 目標SPM（steps per minute）

#### recordPhaseError
```dart
void recordPhaseError({
  required DateTime clickTime,
  required DateTime heelStrikeTime,
  required double currentSpm,
})
```
- **説明**: 位相誤差を記録
- **パラメータ**:
  - `clickTime`: メトロノームクリック時刻
  - `heelStrikeTime`: かかと接地時刻
  - `currentSpm`: 現在のSPM

#### getStatistics
```dart
Map<String, dynamic> getStatistics()
```
- **戻り値**:
```dart
{
  'rmsePhi': 0.045,           // RMSE値
  'convergenceTime': 15.5,    // 収束時間（秒）
  'meanError': 0.02,          // 平均誤差
  'stdError': 0.03,           // 標準偏差
  'dataPoints': 150,          // データ点数
  'targetSpm': 100.0,         // 目標SPM
  'isConverged': true,        // 収束状態
}
```

---

## 3. AudioConflictResolver

### 概要
音声イベントの衝突を検出し、自動的に調整

### メソッド

#### scheduleNBackAudio
```dart
DateTime scheduleNBackAudio({
  required DateTime originalTime,
  required int duration,
})
```
- **説明**: N-back音声の再生時刻をスケジュール
- **パラメータ**:
  - `originalTime`: 元の予定時刻
  - `duration`: 音声の長さ（ミリ秒）
- **戻り値**: 調整後の再生時刻
- **使用例**:
```dart
final adjustedTime = resolver.scheduleNBackAudio(
  originalTime: DateTime.now().add(Duration(seconds: 2)),
  duration: 500, // 500ms
);
```

#### getConflictStatistics
```dart
Map<String, dynamic> getConflictStatistics()
```
- **戻り値**:
```dart
{
  'totalConflicts': 15,
  'metronomeConflicts': 10,
  'nBackOverlaps': 5,
  'averageShiftMs': 85.5,
  'recentConflicts': [...],
}
```

---

## 4. ExtendedDataRecorder

### 概要
拡張メトリクスを含むデータ記録サービス

### メソッド

#### recordExtendedMetrics
```dart
void recordExtendedMetrics({
  required double currentSpm,
  required double currentCv,
  required double phaseCorrection,
  required double tempoAdjustment,
  Map<String, dynamic>? additionalData,
})
```
- **説明**: 拡張メトリクスを記録
- **パラメータ**:
  - `currentSpm`: 現在のSPM
  - `currentCv`: 現在の変動係数
  - `phaseCorrection`: 位相補正値
  - `tempoAdjustment`: テンポ調整値
  - `additionalData`: 追加データ（オプション）

#### updateCondition
```dart
void updateCondition(String condition, bool isAdaptive)
```
- **説明**: 実験条件を更新
- **パラメータ**:
  - `condition`: 条件名（'baseline', 'fixed', 'adaptive'など）
  - `isAdaptive`: 適応モードかどうか

---

## 5. NBackSequenceGenerator

### 概要
N-back課題用の数字列を生成

### メソッド

#### generate
```dart
List<int> generate({
  required int length,
  required int nLevel,
  int minDigit = 1,
  int maxDigit = 9,
  double targetMatchRate = 0.3,
})
```
- **説明**: N-back用の数字列を生成
- **パラメータ**:
  - `length`: 数字列の長さ
  - `nLevel`: N-backレベル（0, 1, 2）
  - `minDigit`: 最小数字（デフォルト: 1）
  - `maxDigit`: 最大数字（デフォルト: 9）
  - `targetMatchRate`: ターゲット一致率（デフォルト: 30%）
- **戻り値**: 生成された数字列
- **使用例**:
```dart
final sequence = generator.generate(
  length: 30,
  nLevel: 2,
  targetMatchRate: 0.3,
);
// [5, 3, 5, 8, 3, 2, 8, ...] (2-back: 3番目の5は1番目と一致)
```

---

## 6. TTSService

### 概要
Text-to-Speechサービスのラッパー

### メソッド

#### initialize
```dart
Future<void> initialize({
  String language = 'ja-JP',
  double speechRate = 1.0,
  double volume = 1.0,
  double pitch = 1.0,
})
```
- **説明**: TTSエンジンを初期化
- **パラメータ**:
  - `language`: 言語コード（'ja-JP', 'en-US'）
  - `speechRate`: 読み上げ速度（0.1-2.0）
  - `volume`: 音量（0.0-1.0）
  - `pitch`: ピッチ（0.5-2.0）

#### speakDigit
```dart
Future<void> speakDigit(int digit, {DateTime? scheduledTime})
```
- **説明**: 数字を読み上げ
- **パラメータ**:
  - `digit`: 読み上げる数字（0-9）
  - `scheduledTime`: スケジュール時刻（オプション）

---

## 7. NBackResponseCollector

### 概要
N-back課題の応答を収集

### メソッド

#### startCollecting
```dart
void startCollecting({
  required int sequenceIndex,
  required int presentedDigit,
})
```
- **説明**: 応答収集を開始
- **パラメータ**:
  - `sequenceIndex`: 数字列のインデックス
  - `presentedDigit`: 提示された数字

#### handleButtonInput
```dart
void handleButtonInput(int digit)
```
- **説明**: ボタン入力を処理
- **パラメータ**:
  - `digit`: 入力された数字

### ストリーム

#### inputStream
```dart
Stream<NBackUserInput> get inputStream
```
- **説明**: ユーザー入力のストリーム
- **使用例**:
```dart
collector.inputStream.listen((input) {
  print('User input: ${input.inputDigit}');
  print('Reaction time: ${input.reactionTimeMs}ms');
});
```

---

## 8. ExperimentConditionManager

### 概要
実験条件の管理とラテン方格法による順序決定

### メソッド

#### initialize
```dart
void initialize({required int participantNumber})
```
- **説明**: 被験者番号に基づいて条件順序を決定
- **パラメータ**:
  - `participantNumber`: 被験者番号

#### getCurrentCondition
```dart
ExperimentCondition getCurrentCondition()
```
- **戻り値**: 現在の実験条件
```dart
ExperimentCondition {
  id: 'adaptive_1back',
  tempoControl: TempoControl.adaptive,
  cognitiveLoad: CognitiveLoad.nBack1,
}
```

#### moveToNextCondition
```dart
bool moveToNextCondition()
```
- **説明**: 次の条件に進む
- **戻り値**: 成功した場合true

---

## 9. ExperimentFlowController

### 概要
6分構成の実験ブロックを管理

### メソッド

#### startExperiment
```dart
void startExperiment({required int totalBlocks})
```
- **説明**: 実験を開始
- **パラメータ**:
  - `totalBlocks`: 総ブロック数

### コールバック

```dart
ExperimentFlowController(
  conditionManager: conditionManager,
  onPhaseChanged: (phase) {
    print('Phase changed to: ${phase.displayName}');
  },
  onPhaseProgress: (remaining) {
    print('Time remaining: ${remaining.inSeconds}s');
  },
  onBlockCompleted: () {
    print('Block completed');
  },
  onInstruction: (instruction) {
    print('Instruction: $instruction');
  },
)
```

---

## 10. DataSynchronizationService

### 概要
異なるサンプリングレートのデータを同期

### メソッド

#### recordIMUData
```dart
void recordIMUData({
  required String sensorId,
  required IMUData data,
})
```
- **説明**: IMUデータを記録（100Hz）

#### recordHeartRateData
```dart
void recordHeartRateData({
  required HeartRateData data,
})
```
- **説明**: 心拍データを記録（3秒間隔）

#### getDataInTimeRange
```dart
List<SynchronizedDataPoint> getDataInTimeRange({
  required DateTime start,
  required DateTime end,
  DataType? dataType,
})
```
- **説明**: 時間範囲内のデータを取得
- **パラメータ**:
  - `start`: 開始時刻
  - `end`: 終了時刻
  - `dataType`: データタイプ（オプション）

---

## エラーハンドリング

### 共通エラー
- `StateError`: 初期化前のメソッド呼び出し
- `ArgumentError`: 無効なパラメータ
- `RangeError`: 範囲外の値

### エラー処理例
```dart
try {
  final newBpm = tempoService.updateBpm(
    clickTime: clickTime,
    heelStrikeTime: heelStrikeTime,
  );
} catch (e) {
  if (e is StateError) {
    // サービスが初期化されていない
    tempoService.initialize(100.0);
  }
}
```

---

## 使用例：統合シナリオ

```dart
// 1. サービスの初期化
final tempoService = AdaptiveTempoService();
final phaseEngine = PhaseErrorEngine();
final audioResolver = AudioConflictResolver();
final dataRecorder = ExtendedDataRecorder();

tempoService.initialize(100.0);
phaseEngine.initialize(100.0);
audioResolver.initialize(100.0);

// 2. 実験開始
await dataRecorder.startRecording(
  sessionId: 'session_001',
  subjectId: 'subject_001',
  experimentMetadata: {
    'condition': 'adaptive_1back',
    'isAdaptive': true,
    'targetSpm': 100.0,
  },
);

// 3. リアルタイムデータ処理
void onHeelStrike(DateTime heelStrikeTime) {
  final clickTime = getNextMetronomeClick();
  
  // 位相誤差を記録
  phaseEngine.recordPhaseError(
    clickTime: clickTime,
    heelStrikeTime: heelStrikeTime,
    currentSpm: currentSpm,
  );
  
  // BPMを更新
  final newBpm = tempoService.updateBpm(
    clickTime: clickTime,
    heelStrikeTime: heelStrikeTime,
  );
  
  // メトロノームBPMを更新
  updateMetronomeBpm(newBpm);
}

// 4. N-back音声のスケジューリング
final adjustedTime = audioResolver.scheduleNBackAudio(
  originalTime: DateTime.now().add(Duration(seconds: 2)),
  duration: 500,
);

// 5. 実験終了
await dataRecorder.stopRecording();
```