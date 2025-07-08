# 共通インフラ概要 – 研究プラットフォーム共有資産

## 1. システム全体アーキテクチャ

### 1.1 概要
本研究プラットフォームは、4つの研究プロジェクトで共有される統合的なシステムインフラストラクチャを提供します。モバイルアプリケーション、バックエンドサービス、データストレージ、分析環境を包括的に統合し、効率的な研究活動を支援します。

```mermaid
graph TB
    subgraph "Mobile Layer"
        APP[Flutter App<br/>研究プラットフォーム]
    end
    
    subgraph "Backend Layer - Sakura VPS"
        subgraph "Docker Container"
            API[API Gateway<br/>FastAPI]
            AUTH[認証サービス<br/>Keycloak]
            REALTIME[リアルタイムサービス<br/>WebSocket]
            WORKER[バックグラウンドワーカー<br/>Celery]
        end
    end
    
    subgraph "Data Layer"
        POSTGRES[(PostgreSQL<br/>主データベース)]
        TIMESCALE[(TimescaleDB<br/>時系列データ)]
        REDIS[(Redis<br/>キャッシュ/Queue)]
        S3[Object Storage<br/>大容量データ]
    end
    
    subgraph "Analysis Layer"
        JUPYTER[JupyterHub<br/>分析環境]
        AIRFLOW[Apache Airflow<br/>データパイプライン]
    end
    
    APP <--> API
    API <--> AUTH
    API <--> POSTGRES
    API <--> TIMESCALE
    API <--> REDIS
    REALTIME <--> REDIS
    WORKER <--> REDIS
    WORKER <--> S3
    POSTGRES <--> AIRFLOW
    TIMESCALE <--> JUPYTER
```

## 2. ハードウェア資産

### 2.1 サーバーインフラ
- **Sakura VPS**
  - CPU: 8コア以上
  - メモリ: 16GB以上
  - ストレージ: SSD 500GB以上
  - ネットワーク: 1Gbps共有回線
  - OS: Ubuntu 22.04 LTS

### 2.2 センサーデバイス
- **共通利用センサー**
  - M5Stack系デバイス（IMU搭載）
  - Polar H10心拍センサー
  - スマートフォン内蔵センサー（iOS/Android）
  - GPSモジュール

### 2.3 開発・テスト環境
- 開発用ワークステーション
- テスト用モバイルデバイス（iOS/Android各2台）
- Bluetoothデバッグツール

## 3. ソフトウェア資産

### 3.1 モバイルアプリケーション

#### アーキテクチャ
```yaml
Architecture: Clean Architecture
State Management: Riverpod
Language: Dart/Flutter
Min SDK: 
  - iOS: 12.0
  - Android: API 21 (5.0)
```

#### コア機能モジュール
1. **センサー抽象化レイヤー**
   - 統一的なセンサーインターフェース
   - マルチデバイス対応
   - リアルタイムデータストリーミング

2. **プラグインシステム**
   - 研究別機能の動的ロード
   - 共通UIコンポーネント
   - データ処理パイプライン

3. **データ管理**
   - ローカルキャッシュ（SQLite）
   - オフライン対応
   - 自動同期機能

### 3.2 バックエンドシステム

#### 技術スタック
```yaml
API Framework: FastAPI (Python 3.11+)
Authentication: Keycloak
Message Queue: Redis + Celery
WebSocket: Socket.io
Container: Docker + Docker Compose
Reverse Proxy: Nginx
Monitoring: Prometheus + Grafana
```

#### マイクロサービス構成
```
backend/
├── api-gateway/           # APIゲートウェイ
├── auth-service/         # 認証・認可
├── data-service/         # データ管理
├── realtime-service/     # リアルタイム通信
├── analysis-service/     # データ分析
├── notification-service/ # 通知サービス
└── file-service/        # ファイル管理
```

## 4. データベース設計

### 4.1 データベース選定

#### 主データベース: PostgreSQL 15
- **選定理由**
  - ACID準拠の信頼性
  - JSON/JSONB型によるスキーマ柔軟性
  - 豊富な拡張機能
  - 研究データの整合性保証

#### 時系列データ: TimescaleDB
- **選定理由**
  - PostgreSQLの拡張として動作
  - センサーデータの効率的な保存
  - 自動パーティショニング
  - 高速な時系列クエリ

#### キャッシュ/Queue: Redis
- **選定理由**
  - 高速なインメモリ操作
  - Pub/Sub機能
  - セッション管理
  - ジョブキュー

### 4.2 スキーマ設計

```sql
-- 研究プロジェクト管理
CREATE TABLE research_projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'active',
    config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 研究者アカウント
CREATE TABLE researchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    institution VARCHAR(255),
    role VARCHAR(50) DEFAULT 'researcher',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 研究プロジェクトメンバー
CREATE TABLE project_members (
    project_id UUID REFERENCES research_projects(id),
    researcher_id UUID REFERENCES researchers(id),
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (project_id, researcher_id)
);

-- 被験者情報（匿名化）
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES research_projects(id),
    participant_code VARCHAR(100) NOT NULL,
    demographics JSONB DEFAULT '{}', -- 暗号化して保存
    consent_status VARCHAR(50) DEFAULT 'pending',
    consent_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, participant_code)
);

-- 実験セッション
CREATE TABLE experiment_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES research_projects(id),
    participant_id UUID REFERENCES participants(id),
    protocol_id UUID,
    session_code VARCHAR(100) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'planned',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- センサーデバイス登録
CREATE TABLE sensor_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) UNIQUE NOT NULL,
    device_type VARCHAR(100) NOT NULL,
    device_name VARCHAR(255),
    capabilities JSONB DEFAULT '{}',
    calibration_data JSONB DEFAULT '{}',
    registered_at TIMESTAMPTZ DEFAULT NOW()
);

-- 実験プロトコル
CREATE TABLE experiment_protocols (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES research_projects(id),
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) DEFAULT '1.0.0',
    protocol_data JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- データファイル管理
CREATE TABLE data_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES experiment_sessions(id),
    file_type VARCHAR(50) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT,
    checksum VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- 時系列センサーデータ（TimescaleDB）
CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    session_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    sensor_type VARCHAR(50) NOT NULL,
    data JSONB NOT NULL,
    quality_score FLOAT,
    PRIMARY KEY (time, session_id, device_id, sensor_type)
);

-- TimescaleDBのハイパーテーブル化
SELECT create_hypertable('sensor_data', 'time');

-- データ処理ジョブ
CREATE TABLE processing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES experiment_sessions(id),
    job_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    parameters JSONB DEFAULT '{}',
    result JSONB,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- インデックス作成
CREATE INDEX idx_sessions_project ON experiment_sessions(project_id);
CREATE INDEX idx_sessions_participant ON experiment_sessions(participant_id);
CREATE INDEX idx_sessions_status ON experiment_sessions(status);
CREATE INDEX idx_sensor_data_session ON sensor_data(session_id);
CREATE INDEX idx_sensor_data_device ON sensor_data(device_id);
CREATE INDEX idx_jobs_session ON processing_jobs(session_id);
CREATE INDEX idx_jobs_status ON processing_jobs(status);
```

## 5. Docker構成

### 5.1 docker-compose.yml

```yaml
version: '3.9'

services:
  # リバースプロキシ
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - api
      - keycloak

  # APIゲートウェイ
  api:
    build: ./api-gateway
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/research_db
      - REDIS_URL=redis://redis:6379
      - KEYCLOAK_URL=http://keycloak:8080
    depends_on:
      - postgres
      - redis
      - keycloak
    volumes:
      - ./api-gateway:/app

  # 認証サービス
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    environment:
      - KEYCLOAK_ADMIN=admin
      - KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
      - KC_DB=postgres
      - KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db
      - KC_DB_USERNAME=keycloak
      - KC_DB_PASSWORD=${KEYCLOAK_DB_PASSWORD}
    command: start-dev
    depends_on:
      - postgres

  # PostgreSQL + TimescaleDB
  postgres:
    image: timescale/timescaledb:latest-pg15
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_MULTIPLE_DATABASES=research_db,keycloak_db
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db:/docker-entrypoint-initdb.d

  # Redis
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data

  # リアルタイムサービス
  realtime:
    build: ./realtime-service
    environment:
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - redis

  # バックグラウンドワーカー
  worker:
    build: ./worker
    environment:
      - CELERY_BROKER_URL=redis://redis:6379
      - DATABASE_URL=postgresql://user:pass@postgres:5432/research_db
    depends_on:
      - redis
      - postgres

  # モニタリング
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus

  grafana:
    image: grafana/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"

volumes:
  postgres_data:
  redis_data:
  prometheus_data:
  grafana_data:
```

## 6. API設計

### 6.1 RESTful API エンドポイント

```yaml
# 認証
POST   /api/v1/auth/login
POST   /api/v1/auth/logout
POST   /api/v1/auth/refresh
GET    /api/v1/auth/me

# 研究プロジェクト
GET    /api/v1/projects
POST   /api/v1/projects
GET    /api/v1/projects/{id}
PUT    /api/v1/projects/{id}
DELETE /api/v1/projects/{id}

# 被験者管理
GET    /api/v1/projects/{project_id}/participants
POST   /api/v1/projects/{project_id}/participants
GET    /api/v1/participants/{id}
PUT    /api/v1/participants/{id}

# 実験セッション
GET    /api/v1/sessions
POST   /api/v1/sessions
GET    /api/v1/sessions/{id}
PUT    /api/v1/sessions/{id}/start
PUT    /api/v1/sessions/{id}/stop
PUT    /api/v1/sessions/{id}/pause

# センサーデータ
POST   /api/v1/sessions/{session_id}/data
GET    /api/v1/sessions/{session_id}/data
GET    /api/v1/sessions/{session_id}/data/export

# プロトコル管理
GET    /api/v1/protocols
POST   /api/v1/protocols
GET    /api/v1/protocols/{id}
PUT    /api/v1/protocols/{id}

# データ処理
POST   /api/v1/jobs
GET    /api/v1/jobs/{id}
GET    /api/v1/jobs/{id}/result
```

### 6.2 WebSocket エンドポイント

```javascript
// リアルタイムデータストリーミング
ws://api.research.example.com/ws/session/{session_id}

// イベント例
{
  "type": "sensor_data",
  "timestamp": "2024-01-01T12:00:00Z",
  "device_id": "M5Stack-001",
  "sensor_type": "accelerometer",
  "data": {
    "x": 0.12,
    "y": -0.05,
    "z": 9.81
  }
}
```

## 7. セキュリティ設計

### 7.1 認証・認可
- **Keycloak**によるSSO（シングルサインオン）
- JWT トークンベース認証
- Role-Based Access Control (RBAC)
  - Admin: システム管理者
  - PI: 研究責任者
  - Researcher: 研究者
  - Assistant: 研究補助者

### 7.2 データ保護
- **暗号化**
  - 通信: TLS 1.3
  - 保存時: AES-256
  - 被験者情報: 追加暗号化レイヤー
- **アクセス制御**
  - プロジェクトベースの権限管理
  - 監査ログ
  - データマスキング

### 7.3 コンプライアンス
- GDPR準拠設計
- 個人情報保護法対応
- 研究倫理委員会要件への適合

## 8. バックアップ・災害復旧

### 8.1 バックアップ戦略
```yaml
Database:
  - 方式: pg_dump + WAL アーカイブ
  - 頻度: 
    - フルバックアップ: 週次
    - 差分バックアップ: 日次
    - WALアーカイブ: 継続的
  - 保存先: オブジェクトストレージ

Files:
  - 方式: rsync
  - 頻度: 日次
  - 保存先: 別リージョンのストレージ

Configuration:
  - 方式: Git
  - 頻度: 変更時
```

### 8.2 復旧目標
- RPO (Recovery Point Objective): 1時間
- RTO (Recovery Time Objective): 4時間

## 9. スケーラビリティ

### 9.1 水平スケーリング対応
- APIサーバー: ロードバランサー経由で複数インスタンス
- データベース: Read Replicaによる読み取り負荷分散
- キャッシュ: Redis Cluster

### 9.2 パフォーマンス最適化
- データベースインデックス最適化
- クエリ最適化
- CDNによる静的コンテンツ配信
- 非同期処理によるレスポンス改善

## 10. 運用・保守

### 10.1 モニタリング
- **Prometheus + Grafana**
  - システムメトリクス
  - アプリケーションメトリクス
  - カスタムダッシュボード

### 10.2 ログ管理
- **ELKスタック（オプション）**
  - Elasticsearch: ログ保存
  - Logstash: ログ収集
  - Kibana: ログ可視化

### 10.3 アラート
- CPU/メモリ使用率
- ディスク容量
- APIレスポンスタイム
- エラー率

## 11. 開発環境

### 11.1 ローカル開発
```bash
# 開発環境起動
docker-compose -f docker-compose.dev.yml up

# データベースマイグレーション
docker-compose exec api alembic upgrade head

# テスト実行
docker-compose exec api pytest
```

### 11.2 CI/CD
- GitHub Actions
- 自動テスト
- コードカバレッジ
- 自動デプロイ（ステージング環境）

## 12. ドキュメント

### 12.1 技術ドキュメント
- API仕様書（OpenAPI/Swagger）
- データベース設計書
- システム構成図
- 運用手順書

### 12.2 研究者向けドキュメント
- アプリ利用ガイド
- データフォーマット仕様
- プロトコル作成ガイド
- トラブルシューティング

## 13. コスト見積もり

### 13.1 初期費用
- Sakura VPS セットアップ: ¥10,000
- ドメイン取得: ¥3,000/年
- SSL証明書: Let's Encrypt（無料）

### 13.2 月額費用
- Sakura VPS (8コア/16GB): ¥15,000/月
- バックアップストレージ: ¥5,000/月
- 監視サービス（オプション）: ¥3,000/月
- **合計: 約¥23,000/月**

## 14. 今後の拡張計画

### 14.1 Phase 1（6ヶ月）
- 基本システムの構築
- 4研究プロジェクトの統合
- セキュリティ強化

### 14.2 Phase 2（12ヶ月）
- 機械学習パイプライン追加
- リアルタイム解析機能
- 多施設連携機能

### 14.3 Phase 3（18ヶ月）
- AI支援機能
- 自動レポート生成
- 国際展開対応