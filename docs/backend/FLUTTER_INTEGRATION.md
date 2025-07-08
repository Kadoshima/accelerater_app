# Flutter アプリケーション統合ガイド

## 概要

このドキュメントでは、FlutterアプリケーションからResearch Platform バックエンドAPIへの接続方法について説明します。

## 接続情報

### エンドポイント

| 環境 | URL |
|------|-----|
| 開発環境 | `http://localhost/api/v1` |
| 本番環境 | `https://os3-378-22222.vs.sakura.ne.jp/api/v1` |
| WebSocket（開発） | `ws://localhost/ws` |
| WebSocket（本番） | `wss://os3-378-22222.vs.sakura.ne.jp/ws` |

## 実装例

### 1. API定数の定義

```dart
// lib/core/constants/api_constants.dart
class ApiConstants {
  // Production environment (Sakura VPS)
  static const String prodDomain = 'os3-378-22222.vs.sakura.ne.jp';
  static const String prodBaseUrl = 'https://$prodDomain';
  static const String prodApiUrl = '$prodBaseUrl/api/v1';
  static const String prodWebSocketUrl = 'wss://$prodDomain/ws';
}
```

### 2. APIクライアントの実装

```dart
// lib/data/datasources/remote/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;
  
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.prodApiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }
}
```

### 3. 認証の実装

```dart
// ログイン
Future<void> login(String email, String password) async {
  try {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    
    final accessToken = response.data['access_token'];
    final refreshToken = response.data['refresh_token'];
    
    // トークンを安全に保存
    await secureStorage.write(key: 'access_token', value: accessToken);
    await secureStorage.write(key: 'refresh_token', value: refreshToken);
    
  } catch (e) {
    // エラーハンドリング
  }
}
```

### 4. センサーデータの送信

```dart
// リアルタイムデータ送信
Future<void> sendSensorData(
  String sessionId,
  AccelerometerData data,
) async {
  await _dio.post('/sessions/$sessionId/data', data: {
    'device_id': deviceId,
    'timestamp': DateTime.now().toIso8601String(),
    'data': [
      {
        'sensor_type': 'accelerometer',
        'channels': {
          'x': data.x,
          'y': data.y,
          'z': data.z,
        }
      }
    ],
  });
}
```

### 5. WebSocket接続

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  
  void connect(String sessionId) {
    final url = '${ApiConstants.prodWebSocketUrl}/session/$sessionId';
    _channel = WebSocketChannel.connect(Uri.parse(url));
    
    // 認証
    _channel!.sink.add(jsonEncode({
      'type': 'auth',
      'token': accessToken,
    }));
    
    // データ受信
    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      // データ処理
    });
  }
  
  void sendData(SensorData data) {
    _channel?.sink.add(jsonEncode({
      'type': 'sensor_data',
      'timestamp': data.timestamp.toIso8601String(),
      'device_id': data.deviceId,
      'sensor_type': data.sensorType,
      'data': data.values,
    }));
  }
}
```

## セキュリティ考慮事項

### 1. トークンの安全な保存

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  static const _storage = FlutterSecureStorage();
  
  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }
  
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }
}
```

### 2. SSL証明書のピンニング（オプション）

```dart
import 'package:dio_certificate_pinning/dio_certificate_pinning.dart';

void setupCertificatePinning(Dio dio) {
  dio.interceptors.add(
    CertificatePinningInterceptor(
      allowedSHAFingerprints: ['SHA256:XXXXX'],
      timeout: 30,
    ),
  );
}
```

## エラーハンドリング

```dart
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  
  ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });
}

// 使用例
try {
  await apiClient.post('/sessions', data: sessionData);
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    // 認証エラー
    throw ApiException(
      message: '認証が必要です',
      statusCode: 401,
      errorCode: 'AUTH_REQUIRED',
    );
  } else if (e.response?.statusCode == 422) {
    // バリデーションエラー
    final errors = e.response?.data['error']['details'];
    throw ApiException(
      message: 'バリデーションエラー',
      statusCode: 422,
      errorCode: 'VALIDATION_ERROR',
    );
  }
  // その他のエラー
  throw ApiException(message: e.message ?? '不明なエラー');
}
```

## デバッグとテスト

### 1. APIリクエストのログ出力

```dart
if (kDebugMode) {
  _dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    error: true,
  ));
}
```

### 2. モックサーバーでのテスト

```dart
// テスト環境での設定
class TestApiClient extends ApiClient {
  TestApiClient() : super(baseUrl: 'http://localhost:8081');
}
```

## トラブルシューティング

### 接続できない場合

1. **ネットワーク権限の確認**
   ```xml
   <!-- Android: AndroidManifest.xml -->
   <uses-permission android:name="android.permission.INTERNET" />
   ```

2. **iOS ATSの設定**（開発環境のみ）
   ```xml
   <!-- iOS: Info.plist -->
   <key>NSAppTransportSecurity</key>
   <dict>
     <key>NSAllowsLocalNetworking</key>
     <true/>
   </dict>
   ```

3. **プロキシ設定**
   ```dart
   (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
     client.findProxy = (uri) {
       return 'PROXY localhost:8888';
     };
   };
   ```

### SSL証明書エラー

本番環境で自己署名証明書を使用している場合：

```dart
// 開発環境でのみ使用（本番環境では使用しないこと）
(_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
  client.badCertificateCallback = (cert, host, port) => true;
  return client;
};
```

## パフォーマンス最適化

### 1. コネクションプーリング

```dart
final dio = Dio()
  ..options.connectTimeout = const Duration(seconds: 10)
  ..options.receiveTimeout = const Duration(seconds: 30)
  ..httpClientAdapter = Http2Adapter(
    ConnectionManager(
      idleTimeout: const Duration(seconds: 15),
      onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
    ),
  );
```

### 2. リクエストのバッチ処理

```dart
// 複数のセンサーデータをまとめて送信
Future<void> sendBatchData(List<SensorData> dataList) async {
  final batchData = dataList.map((data) => {
    'timestamp': data.timestamp.toIso8601String(),
    'sensor_type': data.sensorType,
    'channels': data.channels,
  }).toList();
  
  await _dio.post('/sessions/$sessionId/data/batch', data: {
    'device_id': deviceId,
    'data': batchData,
  });
}
```

## 参考リンク

- [Dio パッケージドキュメント](https://pub.dev/packages/dio)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [WebSocket Channel](https://pub.dev/packages/web_socket_channel)