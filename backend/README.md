# Research Platform Backend

## 概要

このバックエンドシステムは、研究プラットフォームの中核となるサーバーサイドアプリケーションです。
Docker Composeを使用してマイクロサービスアーキテクチャで構築されています。

## アーキテクチャ

### 主要コンポーネント

1. **API Gateway (FastAPI)**
   - RESTful API エンドポイント
   - 認証・認可の統合
   - データ処理とビジネスロジック

2. **PostgreSQL + TimescaleDB**
   - 主要データストレージ
   - 時系列センサーデータの効率的な保存

3. **Redis**
   - キャッシュ
   - セッション管理
   - ジョブキュー（Celery）

4. **Keycloak**
   - 認証・認可サービス
   - シングルサインオン（SSO）
   - ユーザー管理

5. **Nginx**
   - リバースプロキシ
   - ロードバランシング
   - SSL終端

6. **MinIO**
   - S3互換オブジェクトストレージ
   - 大容量ファイルの保存

## セットアップ

### 前提条件

- Docker 20.10以上
- Docker Compose 2.0以上
- 8GB以上のRAM（推奨: 16GB）
- 50GB以上の空きディスク容量

### 初期セットアップ

1. **環境変数の設定**
   ```bash
   cp .env.example .env
   # .envファイルを編集して適切な値を設定
   ```

2. **必要なディレクトリの作成**
   ```bash
   mkdir -p nginx/ssl
   mkdir -p data/{postgres,redis,minio}
   ```

3. **SSL証明書の配置**（本番環境の場合）
   ```bash
   # Let's Encryptを使用する場合
   certbot certonly --standalone -d your-domain.com
   cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/cert.pem
   cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/key.pem
   ```

### 起動方法

#### 開発環境
```bash
# すべてのサービスを起動
docker-compose up -d

# ログの確認
docker-compose logs -f

# 特定のサービスのログ
docker-compose logs -f api
```

#### 本番環境
```bash
# 本番用の設定で起動
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 初期データの投入

```bash
# データベースマイグレーション
docker-compose exec api alembic upgrade head

# 初期管理者ユーザーの作成
docker-compose exec api python scripts/create_admin.py

# サンプルデータの投入（開発環境のみ）
docker-compose exec api python scripts/seed_data.py
```

## 開発

### APIの開発

1. **新しいエンドポイントの追加**
   ```python
   # api-gateway/app/api/v1/endpoints/your_endpoint.py
   from fastapi import APIRouter, Depends
   
   router = APIRouter()
   
   @router.get("/your-endpoint")
   async def your_endpoint():
       return {"message": "Hello"}
   ```

2. **データベースマイグレーション**
   ```bash
   # 新しいマイグレーションの作成
   docker-compose exec api alembic revision --autogenerate -m "Your migration message"
   
   # マイグレーションの適用
   docker-compose exec api alembic upgrade head
   ```

3. **テストの実行**
   ```bash
   # すべてのテスト
   docker-compose exec api pytest
   
   # カバレッジレポート付き
   docker-compose exec api pytest --cov=app --cov-report=html
   ```

### デバッグ

```bash
# APIコンテナに接続
docker-compose exec api bash

# PostgreSQLに接続
docker-compose exec postgres psql -U postgres -d research_db

# Redisに接続
docker-compose exec redis redis-cli -a $REDIS_PASSWORD
```

## API仕様

### 認証

すべてのAPIリクエストにはJWTトークンが必要です：

```bash
# トークンの取得
curl -X POST http://localhost/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# APIリクエストの例
curl -X GET http://localhost/api/v1/projects \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 主要エンドポイント

- `GET /api/v1/projects` - プロジェクト一覧
- `POST /api/v1/projects` - プロジェクト作成
- `GET /api/v1/sessions` - セッション一覧
- `POST /api/v1/sessions/{id}/data` - センサーデータ送信
- `GET /api/v1/sessions/{id}/data/export` - データエクスポート

詳細なAPI仕様は `/docs` エンドポイントで確認できます。

## モニタリング

### Prometheus + Grafana

1. **アクセス方法**
   - Grafana: http://localhost:3000
   - Prometheus: http://localhost:9090

2. **ダッシュボードの設定**
   - Grafanaにログイン（admin/設定したパスワード）
   - Prometheusをデータソースとして追加
   - 事前定義されたダッシュボードをインポート

### ログの確認

```bash
# リアルタイムログ
docker-compose logs -f

# 過去のログ（行数指定）
docker-compose logs --tail=100 api

# タイムスタンプ付き
docker-compose logs -t api
```

## バックアップとリストア

### バックアップ

```bash
# 自動バックアップスクリプト
./scripts/backup.sh

# 手動バックアップ
docker-compose exec postgres pg_dump -U postgres research_db > backup_$(date +%Y%m%d_%H%M%S).sql
```

### リストア

```bash
# バックアップからのリストア
docker-compose exec -T postgres psql -U postgres research_db < backup_20240101_120000.sql
```

## トラブルシューティング

### よくある問題

1. **コンテナが起動しない**
   ```bash
   # コンテナの状態確認
   docker-compose ps
   
   # エラーログの確認
   docker-compose logs service_name
   ```

2. **データベース接続エラー**
   ```bash
   # PostgreSQLの状態確認
   docker-compose exec postgres pg_isready
   
   # 接続テスト
   docker-compose exec api python -c "from app.core.database import test_connection; test_connection()"
   ```

3. **メモリ不足**
   ```bash
   # リソース使用状況
   docker stats
   
   # 不要なコンテナの削除
   docker system prune -a
   ```

## セキュリティ

### ベストプラクティス

1. **環境変数の管理**
   - 本番環境では環境変数を安全に管理（AWS Secrets Manager等）
   - `.env`ファイルをGitにコミットしない

2. **ネットワークセキュリティ**
   - 必要なポートのみを公開
   - ファイアウォールの適切な設定

3. **定期的なアップデート**
   ```bash
   # イメージの更新
   docker-compose pull
   docker-compose up -d
   ```

## ライセンス

[プロジェクトのライセンスを記載]