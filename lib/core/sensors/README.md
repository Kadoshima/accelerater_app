# センサー抽象化レイヤー

## 概要
このディレクトリには、研究プラットフォーム全体で使用される汎用的なセンサー抽象化レイヤーが含まれています。

## アーキテクチャ

### インターフェース
- `ISensor<T>`: すべてのセンサーの基本インターフェース
- `ISensorManager`: 複数センサーの管理インターフェース
- `SensorData`: センサーデータの基底クラス

### 実装
- `BLESensorAdapter`: Bluetoothデバイスを汎用センサーとして扱うアダプター
- `PhoneAccelerometerSensor`: スマートフォン内蔵加速度センサー
- `PhoneGyroscopeSensor`: スマートフォン内蔵ジャイロセンサー
- `SensorManagerImpl`: センサーマネージャーのデフォルト実装

## 使用例

### 基本的な使用方法

```dart
// センサーマネージャーの作成
final factory = SensorFactory();
final manager = factory.createSensorManager();

// スマートフォンセンサーの登録
final accelerometer = factory.createPhoneAccelerometer();
manager.registerSensor(accelerometer);

// センサーの接続とデータ収集開始
await accelerometer.connect();
await accelerometer.startDataCollection();

// データストリームの購読
accelerometer.dataStream.listen((data) {
  print('Acceleration: x=${data.x}, y=${data.y}, z=${data.z}');
});
```

### BLEセンサーの使用

```dart
// BLEデバイスからセンサーを作成
final bleSensor = factory.createBLESensor(
  device: bluetoothDevice,
  bleService: bleService,
);

manager.registerSensor(bleSensor);
await bleSensor.connect();
```

### Riverpodでの使用

```dart
// プロバイダーを使用
final manager = ref.watch(sensorManagerProvider);
final sensors = ref.watch(availableSensorsProvider);

// センサーの自動検出
final detectedSensors = await ref.read(autoDetectSensorsProvider.future);
```

### 研究プラグインでの使用

```dart
class MyResearchPlugin extends ResearchPlugin {
  @override
  List<SensorType> get requiredSensors => [
    SensorType.accelerometer,
    SensorType.gyroscope,
  ];
  
  @override
  DataProcessor createDataProcessor() {
    return MyDataProcessor();
  }
}

// データプロセッサーでセンサーデータを処理
class MyDataProcessor extends DataProcessor {
  @override
  Stream<ProcessedData> process(Stream<SensorData> input) {
    return input.where((data) => data is AccelerometerData)
        .map((data) => processAccelerometer(data as AccelerometerData));
  }
}
```

## センサータイプ

現在サポートされているセンサータイプ：
- `accelerometer`: 加速度センサー
- `gyroscope`: ジャイロスコープ
- `magnetometer`: 磁力計
- `heartRate`: 心拍センサー
- `gps`: GPS
- `barometer`: 気圧計
- `temperature`: 温度センサー
- `proximity`: 近接センサー
- `light`: 光センサー
- `microphone`: マイク

## 拡張方法

### 新しいセンサータイプの追加

1. `SensorType` enumに新しいタイプを追加
2. `SensorData`を継承した新しいデータクラスを作成
3. `ISensor<T>`を実装した新しいセンサークラスを作成
4. `SensorFactory`に作成メソッドを追加

### カスタムセンサーの実装例

```dart
class CustomSensor extends ISensor<CustomSensorData> {
  // 実装...
}

class CustomSensorData extends SensorData {
  final double customValue;
  
  CustomSensorData({
    required DateTime timestamp,
    required this.customValue,
  }) : super(timestamp: timestamp, type: SensorType.custom);
}
```

## 注意事項

- センサーの接続・切断は非同期処理です
- データストリームは適切にdisposeしてください
- BLEセンサーは接続が不安定な場合があるため、エラーハンドリングを適切に行ってください
- スマートフォンセンサーのサンプリングレートはデバイスに依存します