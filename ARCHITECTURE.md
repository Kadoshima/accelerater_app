# アプリケーションアーキテクチャガイド

## 概要

本アプリケーションは、Robert C. Martin（Uncle Bob）が提唱するClean Architectureの原則に基づいて設計されています。この設計により、テスタビリティ、保守性、拡張性が向上し、ビジネスロジックが外部フレームワークから独立した状態を保つことができます。

## アーキテクチャの原則

### 1. 依存性の逆転原則（DIP）
- 上位層は下位層に依存しない
- 両方とも抽象（インターフェース）に依存する
- Domain層は最も内側にあり、他の層に依存しない

### 2. 単一責任の原則（SRP）
- 各クラスは単一の責任を持つ
- 変更の理由は1つだけであるべき

### 3. インターフェース分離の原則（ISP）
- クライアントが使用しないメソッドへの依存を強制しない
- 小さく、特定の目的を持つインターフェースを作成

## レイヤー構造

```
┌─────────────────────────────────────────────────┐
│              Presentation Layer                  │
│  (UI Components, State Management, Providers)    │
├─────────────────────────────────────────────────┤
│                Domain Layer                      │
│    (Entities, Use Cases, Repositories)          │
├─────────────────────────────────────────────────┤
│                 Data Layer                       │
│  (Repository Impl, Data Sources, Models)        │
├─────────────────────────────────────────────────┤
│                 Core Layer                       │
│    (Constants, Errors, Utils, Theme)            │
└─────────────────────────────────────────────────┘
```

## 各レイヤーの詳細

### Domain層（ビジネスロジック）

最も重要な層で、アプリケーションのビジネスルールを含みます。

#### Entities
```dart
// domain/entities/bluetooth_device.dart
@freezed
class BluetoothDevice with _$BluetoothDevice {
  const factory BluetoothDevice({
    required String id,
    required String name,
    required DeviceType type,
    @Default(false) bool isConnected,
    @Default(null) int? rssi,
  }) = _BluetoothDevice;
}
```

**特徴:**
- Freezedを使用したイミュータブルなデータクラス
- ビジネスルールのカプセル化
- 外部依存なし

#### Repositories（インターフェース）
```dart
// domain/repositories/bluetooth_repository.dart
abstract class BluetoothRepository {
  Stream<List<BluetoothDevice>> scanDevices();
  Future<Result<Unit>> connectDevice(String deviceId);
  Future<Result<Unit>> disconnectDevice(String deviceId);
  Stream<HeartRateData> getHeartRateStream(String deviceId);
  Stream<M5SensorData> getSensorDataStream(String deviceId);
}
```

**特徴:**
- 抽象クラスとして定義（実装はData層）
- Result型でエラーハンドリング
- Streamでリアルタイムデータ

#### Use Cases
```dart
// domain/usecases/bluetooth/connect_device_usecase.dart
class ConnectDeviceUseCase {
  final BluetoothRepository _repository;
  
  ConnectDeviceUseCase(this._repository);
  
  Future<Result<Unit>> call(String deviceId) async {
    // ビジネスロジックの検証
    if (deviceId.isEmpty) {
      return Left(ValidationException('Device ID cannot be empty'));
    }
    
    // リポジトリへの委譲
    return await _repository.connectDevice(deviceId);
  }
}
```

**特徴:**
- 単一の責任（1つのユースケース = 1つのアクション）
- ビジネスルールの実装
- リポジトリインターフェースへの依存

### Data層（データアクセス）

外部データソースとの通信を担当します。

#### Repository実装
```dart
// data/repositories/bluetooth_repository_impl.dart
class BluetoothRepositoryImpl implements BluetoothRepository {
  final FlutterBluePlus _flutterBlue;
  
  @override
  Stream<List<BluetoothDevice>> scanDevices() {
    return _flutterBlue.scanResults.map((results) {
      return results.map((result) => BluetoothDevice(
        id: result.device.id.toString(),
        name: result.device.name.isEmpty ? 'Unknown' : result.device.name,
        type: _determineDeviceType(result),
        rssi: result.rssi,
      )).toList();
    });
  }
  
  // 他のメソッドの実装...
}
```

**特徴:**
- Domain層のインターフェースを実装
- 外部ライブラリ（FlutterBluePlus）への依存
- データ変換（外部データ → ドメインエンティティ）

#### Models
```dart
// data/models/sensor_data.dart
class M5SensorData {
  final String device;
  final int timestamp;
  final String type;
  final Map<String, dynamic> data;
  
  // JSONシリアライゼーション
  factory M5SensorData.fromJson(Map<String, dynamic> json) {
    return M5SensorData(
      device: json['device'] as String,
      timestamp: json['timestamp'] as int,
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}
```

### Presentation層（UI/状態管理）

ユーザーインターフェースと状態管理を担当します。

#### Providers（依存性注入）
```dart
// presentation/providers/service_providers.dart
final bluetoothRepositoryProvider = Provider<BluetoothRepository>((ref) {
  return BluetoothRepositoryImpl();
});

// presentation/providers/usecase_providers.dart
final connectDeviceUseCaseProvider = Provider<ConnectDeviceUseCase>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return ConnectDeviceUseCase(repository);
});
```

#### State Management
```dart
// presentation/providers/bluetooth_providers.dart
final bluetoothScanProvider = StreamProvider<List<BluetoothDevice>>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.scanDevices();
});

final deviceConnectionProvider = 
    StateNotifierProvider<DeviceConnectionNotifier, ConnectionState>((ref) {
  final connectDevice = ref.watch(connectDeviceUseCaseProvider);
  return DeviceConnectionNotifier(connectDevice);
});
```

#### UI Components
```dart
// presentation/screens/device_connection_screen.dart
class DeviceConnectionScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanResults = ref.watch(bluetoothScanProvider);
    
    return scanResults.when(
      data: (devices) => ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.name),
            subtitle: Text('RSSI: ${device.rssi}'),
            onTap: () => _connectToDevice(ref, device.id),
          );
        },
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Core層（共通機能）

すべての層から使用される共通機能を提供します。

#### エラーハンドリング
```dart
// core/utils/result.dart
typedef Result<T> = Either<AppException, T>;

// core/errors/app_exceptions.dart
abstract class AppException implements Exception {
  final String message;
  final String? code;
  
  AppException(this.message, [this.code]);
}

class BluetoothException extends AppException {
  BluetoothException(String message, [String? code]) : super(message, code);
}
```

#### ログサービス
```dart
// core/utils/logger_service.dart
class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );
  
  static void d(String message) => _logger.d(message);
  static void i(String message) => _logger.i(message);
  static void w(String message) => _logger.w(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
```

## データフロー

### 1. ユーザーアクション → ビジネスロジック実行

```
User Tap → UI Widget → Provider → UseCase → Repository → Data Source
                ↓                      ↓           ↓           ↓
            State Update ← Result ← Business ← Domain ← External API
                                    Logic      Entity
```

### 2. リアルタイムデータストリーム

```
BLE Device → Data Source → Repository → Stream → Provider → UI Update
    ↓             ↓            ↓          ↓         ↓           ↓
Sensor Data → Parse → Domain Entity → Transform → State → Widget Rebuild
```

## ベストプラクティス

### 1. 依存性の方向
- Presentation → Domain ← Data
- Domain層は他の層に依存しない
- Data層はDomain層のインターフェースを実装

### 2. エラーハンドリング
```dart
// ユースケースでのエラーハンドリング
Future<Result<Unit>> execute(String param) async {
  try {
    // 入力検証
    if (!isValid(param)) {
      return Left(ValidationException('Invalid parameter'));
    }
    
    // ビジネスロジック実行
    final result = await repository.doSomething(param);
    
    return result;
  } catch (e) {
    return Left(UnknownException(e.toString()));
  }
}
```

### 3. テスタビリティ
```dart
// モックを使用したユースケースのテスト
class MockBluetoothRepository extends Mock implements BluetoothRepository {}

void main() {
  late ConnectDeviceUseCase useCase;
  late MockBluetoothRepository mockRepository;
  
  setUp(() {
    mockRepository = MockBluetoothRepository();
    useCase = ConnectDeviceUseCase(mockRepository);
  });
  
  test('should return error when device ID is empty', () async {
    // Given
    const deviceId = '';
    
    // When
    final result = await useCase(deviceId);
    
    // Then
    expect(result.isLeft(), true);
    expect(result.getLeft(), isA<ValidationException>());
  });
}
```

### 4. 状態管理のパターン
```dart
// StateNotifierを使用した複雑な状態管理
class ExperimentStateNotifier extends StateNotifier<ExperimentState> {
  final StartExperimentUseCase _startExperiment;
  final StopExperimentUseCase _stopExperiment;
  
  ExperimentStateNotifier(
    this._startExperiment,
    this._stopExperiment,
  ) : super(ExperimentState.initial());
  
  Future<void> startExperiment(ExperimentCondition condition) async {
    state = state.copyWith(isLoading: true);
    
    final result = await _startExperiment(condition);
    
    result.fold(
      (error) => state = state.copyWith(
        isLoading: false,
        error: error.message,
      ),
      (session) => state = state.copyWith(
        isLoading: false,
        currentSession: session,
        isRunning: true,
      ),
    );
  }
}
```

## フォルダ構造

```
lib/
├── core/                      # 共通機能
│   ├── constants/            # アプリ定数
│   ├── errors/               # 例外定義
│   ├── theme/                # UIテーマ
│   └── utils/                # ユーティリティ
├── data/                      # データ層
│   ├── datasources/          # 外部データソース
│   ├── models/               # データモデル
│   └── repositories/         # リポジトリ実装
├── domain/                    # ドメイン層
│   ├── entities/             # エンティティ
│   ├── repositories/         # リポジトリインターフェース
│   └── usecases/             # ユースケース
├── presentation/              # プレゼンテーション層
│   ├── providers/            # Riverpodプロバイダー
│   ├── screens/              # 画面
│   └── widgets/              # ウィジェット
├── services/                  # ビジネスサービス
└── main.dart                  # エントリーポイント
```

## 移行ガイド

既存のコードをClean Architectureに移行する際の手順：

1. **エンティティの抽出**: ビジネスモデルを特定し、Domain層に移動
2. **ユースケースの作成**: ビジネスロジックをユースケースに分離
3. **リポジトリの定義**: データアクセスのインターフェースを作成
4. **実装の分離**: 具体的な実装をData層に移動
5. **DIの設定**: Riverpodプロバイダーで依存性を注入
6. **UIの更新**: プロバイダーを使用してUIを更新

## まとめ

Clean Architectureの採用により、以下のメリットが得られます：

- **テスタビリティ**: 各層が独立しているため、単体テストが容易
- **保守性**: 明確な責任分離により、変更の影響範囲が限定的
- **拡張性**: 新機能の追加が既存コードに影響を与えにくい
- **チーム開発**: 明確な構造により、複数人での開発が効率的

この設計により、長期的な開発とメンテナンスが大幅に改善されます。