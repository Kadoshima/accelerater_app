# Research Platform API仕様書

## 概要

本ドキュメントは、Research Platform のバックエンドAPIの詳細仕様を定義します。
フロントエンド開発者向けに、エンドポイント、リクエスト/レスポンス形式、認証方法などを記載しています。

## ベースURL

```
開発環境: http://localhost/api/v1
本番環境: https://os3-378-22222.vs.sakura.ne.jp/api/v1
```

## 認証

### 認証方式

本APIは、JWT (JSON Web Token) ベースの認証を使用します。

### トークンの取得

```http
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

**レスポンス:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800
}
```

### APIリクエストでの認証

すべてのAPIリクエストには、`Authorization`ヘッダーにBearerトークンを含める必要があります：

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### トークンの更新

```http
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

## 共通仕様

### レスポンス形式

すべてのAPIレスポンスは以下の形式に従います：

**成功時:**
```json
{
  "status": "success",
  "data": {
    // レスポンスデータ
  },
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

**エラー時:**
```json
{
  "status": "error",
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ",
    "details": {}
  },
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

### ページネーション

リスト系のエンドポイントは、以下のパラメータでページネーションをサポートします：

- `page`: ページ番号（デフォルト: 1）
- `per_page`: 1ページあたりの件数（デフォルト: 50、最大: 200）
- `sort`: ソート項目
- `order`: ソート順（asc/desc）

**レスポンス例:**
```json
{
  "status": "success",
  "data": {
    "items": [...],
    "pagination": {
      "page": 1,
      "per_page": 50,
      "total": 150,
      "pages": 3
    }
  }
}
```

### エラーコード

| コード | 説明 |
|--------|------|
| `AUTH_REQUIRED` | 認証が必要です |
| `INVALID_TOKEN` | 無効なトークンです |
| `PERMISSION_DENIED` | 権限がありません |
| `NOT_FOUND` | リソースが見つかりません |
| `VALIDATION_ERROR` | 入力値が不正です |
| `INTERNAL_ERROR` | サーバーエラー |

## APIエンドポイント

### 1. 研究プロジェクト管理

#### プロジェクト一覧取得
```http
GET /projects
```

**クエリパラメータ:**
- `status`: フィルタリング（active/completed/paused/archived）
- `search`: 検索文字列

**レスポンス:**
```json
{
  "status": "success",
  "data": {
    "items": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "code": "GAIT-2024-001",
        "name": "歩行解析研究プロジェクト",
        "description": "加速度センサーを用いた歩行パターン解析",
        "status": "active",
        "start_date": "2024-01-01",
        "end_date": null,
        "created_at": "2024-01-01T09:00:00Z",
        "updated_at": "2024-01-01T09:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "per_page": 50,
      "total": 1,
      "pages": 1
    }
  }
}
```

#### プロジェクト詳細取得
```http
GET /projects/{project_id}
```

#### プロジェクト作成
```http
POST /projects
Content-Type: application/json

{
  "code": "GAIT-2024-002",
  "name": "新規歩行解析研究",
  "description": "説明文",
  "start_date": "2024-02-01",
  "end_date": "2024-12-31",
  "ethics_approval_number": "2024-001"
}
```

#### プロジェクト更新
```http
PUT /projects/{project_id}
Content-Type: application/json

{
  "name": "更新された名前",
  "status": "paused"
}
```

### 2. 被験者管理

#### 被験者一覧取得
```http
GET /projects/{project_id}/participants
```

#### 被験者登録
```http
POST /projects/{project_id}/participants
Content-Type: application/json

{
  "participant_code": "P001",
  "consent_status": "obtained",
  "consent_date": "2024-01-15",
  "demographics": {
    "age_group": "20-29",
    "gender": "female"
  }
}
```

**注意:** `demographics`フィールドは暗号化されて保存されます。

### 3. 実験セッション管理

#### セッション一覧取得
```http
GET /sessions
```

**クエリパラメータ:**
- `project_id`: プロジェクトIDでフィルタ
- `participant_id`: 被験者IDでフィルタ
- `status`: ステータスでフィルタ
- `date_from`: 開始日（YYYY-MM-DD）
- `date_to`: 終了日（YYYY-MM-DD）

#### セッション作成
```http
POST /sessions
Content-Type: application/json

{
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "participant_id": "660e8400-e29b-41d4-a716-446655440001",
  "protocol_id": "770e8400-e29b-41d4-a716-446655440002",
  "session_code": "S-2024-001",
  "scheduled_time": "2024-02-01T10:00:00Z"
}
```

#### セッション開始
```http
PUT /sessions/{session_id}/start
```

#### セッション終了
```http
PUT /sessions/{session_id}/stop
```

### 4. センサーデータ送信

#### リアルタイムデータ送信
```http
POST /sessions/{session_id}/data
Content-Type: application/json

{
  "device_id": "M5Stack-001",
  "timestamp": "2024-01-01T10:00:00.123Z",
  "data": [
    {
      "sensor_type": "accelerometer",
      "channels": {
        "x": 0.12,
        "y": -0.05,
        "z": 9.81
      }
    },
    {
      "sensor_type": "gyroscope",
      "channels": {
        "x": 0.01,
        "y": 0.02,
        "z": -0.01
      }
    }
  ]
}
```

#### バッチデータ送信
```http
POST /sessions/{session_id}/data/batch
Content-Type: application/json

{
  "device_id": "M5Stack-001",
  "data": [
    {
      "timestamp": "2024-01-01T10:00:00.123Z",
      "sensor_type": "accelerometer",
      "channels": {
        "x": 0.12,
        "y": -0.05,
        "z": 9.81
      }
    },
    // ... 複数のデータポイント
  ]
}
```

### 5. データエクスポート

#### セッションデータエクスポート
```http
GET /sessions/{session_id}/data/export
```

**クエリパラメータ:**
- `format`: エクスポート形式（csv/json/mat）
- `start_time`: 開始時刻
- `end_time`: 終了時刻
- `sensors`: センサータイプ（カンマ区切り）

**レスポンス:**
```json
{
  "status": "success",
  "data": {
    "export_url": "https://storage.example.com/exports/session_data_20240101.csv",
    "expires_at": "2024-01-02T10:00:00Z"
  }
}
```

### 6. 実験プロトコル管理

#### プロトコル一覧取得
```http
GET /protocols
```

#### プロトコル作成
```http
POST /protocols
Content-Type: application/json

{
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "標準歩行解析プロトコル",
  "version": "1.0.0",
  "protocol_data": {
    "phases": [
      {
        "id": "rest",
        "name": "安静期",
        "duration_seconds": 60,
        "instructions": "椅子に座って安静にしてください"
      },
      {
        "id": "walking",
        "name": "歩行期",
        "duration_seconds": 300,
        "instructions": "通常の速度で歩いてください"
      }
    ],
    "required_sensors": ["accelerometer", "gyroscope"],
    "sampling_rate": 100
  }
}
```

### 7. デバイス管理

#### デバイス登録
```http
POST /devices
Content-Type: application/json

{
  "device_id": "M5Stack-002",
  "device_type": "m5stack",
  "device_name": "M5Stack Gray #2",
  "capabilities": {
    "sensors": ["accelerometer", "gyroscope", "magnetometer"],
    "sampling_rates": [50, 100, 200],
    "battery": true
  }
}
```

#### デバイス一覧取得
```http
GET /devices
```

### 8. 分析ジョブ

#### ジョブ作成
```http
POST /jobs
Content-Type: application/json

{
  "session_id": "880e8400-e29b-41d4-a716-446655440003",
  "job_type": "gait_analysis",
  "parameters": {
    "window_size": 3,
    "overlap": 0.5,
    "min_spm": 40,
    "max_spm": 180
  }
}
```

#### ジョブステータス確認
```http
GET /jobs/{job_id}
```

**レスポンス:**
```json
{
  "status": "success",
  "data": {
    "id": "990e8400-e29b-41d4-a716-446655440004",
    "job_type": "gait_analysis",
    "status": "completed",
    "progress": 100,
    "result": {
      "average_spm": 112.5,
      "cadence_variability": 0.05,
      "step_count": 450
    },
    "created_at": "2024-01-01T10:00:00Z",
    "completed_at": "2024-01-01T10:05:00Z"
  }
}
```

## WebSocket API

### 接続

```javascript
const ws = new WebSocket('wss://os3-378-22222.vs.sakura.ne.jp/ws/session/{session_id}');

// 認証
ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'auth',
    token: 'your-jwt-token'
  }));
};
```

### メッセージ形式

**センサーデータ送信:**
```json
{
  "type": "sensor_data",
  "timestamp": "2024-01-01T10:00:00.123Z",
  "device_id": "M5Stack-001",
  "sensor_type": "accelerometer",
  "data": {
    "x": 0.12,
    "y": -0.05,
    "z": 9.81
  }
}
```

**イベント通知:**
```json
{
  "type": "event",
  "event_type": "phase_change",
  "data": {
    "from_phase": "rest",
    "to_phase": "walking"
  }
}
```

## 使用例（Flutter）

### APIクライアントの実装例

```dart
import 'package:dio/dio.dart';

class ResearchApiClient {
  final Dio _dio;
  final String baseUrl;
  String? _accessToken;
  
  ResearchApiClient({required this.baseUrl}) 
    : _dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      )) {
    _dio.interceptors.add(AuthInterceptor(this));
  }
  
  // ログイン
  Future<void> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    
    _accessToken = response.data['access_token'];
    // トークンを安全に保存
  }
  
  // プロジェクト一覧取得
  Future<List<Project>> getProjects() async {
    final response = await _dio.get('/projects');
    return (response.data['data']['items'] as List)
        .map((json) => Project.fromJson(json))
        .toList();
  }
  
  // センサーデータ送信
  Future<void> sendSensorData(
    String sessionId,
    String deviceId,
    SensorData data,
  ) async {
    await _dio.post('/sessions/$sessionId/data', data: {
      'device_id': deviceId,
      'timestamp': data.timestamp.toIso8601String(),
      'data': [
        {
          'sensor_type': data.sensorType,
          'channels': data.channels,
        }
      ],
    });
  }
}

// 認証インターセプター
class AuthInterceptor extends Interceptor {
  final ResearchApiClient client;
  
  AuthInterceptor(this.client);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (client._accessToken != null) {
      options.headers['Authorization'] = 'Bearer ${client._accessToken}';
    }
    handler.next(options);
  }
}
```

## エラーハンドリング

### 一般的なエラーレスポンス

```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "入力値が不正です",
    "details": {
      "fields": {
        "email": ["有効なメールアドレスを入力してください"],
        "password": ["パスワードは8文字以上である必要があります"]
      }
    }
  }
}
```

### Flutterでのエラーハンドリング例

```dart
try {
  await apiClient.sendSensorData(sessionId, deviceId, data);
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    // 認証エラー - 再ログインを促す
  } else if (e.response?.statusCode == 422) {
    // バリデーションエラー
    final errors = e.response?.data['error']['details']['fields'];
    // エラーメッセージを表示
  } else {
    // その他のエラー
  }
}
```

## レート制限

APIには以下のレート制限が適用されます：

- 認証エンドポイント: 5リクエスト/分
- 通常のAPIエンドポイント: 100リクエスト/分
- データ送信エンドポイント: 1000リクエスト/分

レート制限に達した場合、`429 Too Many Requests`エラーが返されます。

## 変更履歴

| バージョン | 日付 | 変更内容 |
|------------|------|----------|
| 1.0.0 | 2024-01-01 | 初版リリース |