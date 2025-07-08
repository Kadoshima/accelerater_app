# Research Platform バックエンドドキュメント

## 概要

このディレクトリには、Research Platformのバックエンドシステムに関する技術ドキュメントが含まれています。
フロントエンド開発者およびシステム管理者向けの参照資料として活用してください。

## ドキュメント一覧

### 1. [共通インフラ概要](./INFRASTRUCTURE.md)
研究プラットフォーム全体のシステムアーキテクチャ、ハードウェア/ソフトウェア資産、Docker構成などを説明しています。

**主な内容:**
- システム全体アーキテクチャ図
- ハードウェア構成（Sakura VPS仕様）
- ソフトウェアスタック
- Docker Compose設定
- セキュリティ設計
- バックアップ戦略
- コスト見積もり

### 2. [API仕様書](./API_SPECIFICATION.md)
フロントエンド開発者向けのRESTful API仕様書です。

**主な内容:**
- 認証方法（JWT）
- エンドポイント一覧
- リクエスト/レスポンス形式
- WebSocket API
- エラーコード
- Flutterでの実装例

### 3. [データベーススキーマ](./DATABASE_SCHEMA.md)
PostgreSQL + TimescaleDBのテーブル設計とリレーションシップを詳述しています。

**主な内容:**
- ER図
- テーブル定義
- インデックス設計
- セキュリティ考慮事項
- パフォーマンス最適化

## クイックリファレンス

### API基本情報

```
開発環境: http://localhost/api/v1
本番環境: https://api.research.example.com/api/v1
```

### 主要エンドポイント

| メソッド | パス | 説明 |
|----------|------|------|
| POST | /auth/login | ログイン |
| GET | /projects | プロジェクト一覧 |
| POST | /sessions | セッション作成 |
| POST | /sessions/{id}/data | センサーデータ送信 |
| GET | /sessions/{id}/data/export | データエクスポート |

### データベース接続情報

```yaml
Host: postgres
Port: 5432
Database: research_db
Schema: research
```

### 主要テーブル

- `research_projects` - 研究プロジェクト
- `participants` - 被験者（暗号化）
- `experiment_sessions` - 実験セッション
- `sensor_data` - センサーデータ（時系列）
- `processing_jobs` - 処理ジョブ

## 開発者向け情報

### ローカル環境セットアップ

```bash
# リポジトリのクローン
git clone https://github.com/your-org/research-platform.git
cd research-platform/backend

# 環境変数の設定
cp .env.example .env
# .envファイルを編集

# Dockerコンテナの起動
docker-compose up -d

# ログの確認
docker-compose logs -f api
```

### APIテスト

```bash
# ヘルスチェック
curl http://localhost/health

# ログイン
curl -X POST http://localhost/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

### データベースアクセス

```bash
# PostgreSQLコンソール
docker-compose exec postgres psql -U postgres -d research_db

# データベースの状態確認
docker-compose exec postgres pg_isready
```

## トラブルシューティング

### よくある質問

**Q: APIに接続できない**
- Dockerコンテナが起動しているか確認: `docker-compose ps`
- ログを確認: `docker-compose logs api`

**Q: 認証エラーが発生する**
- トークンの有効期限を確認
- Keycloakサービスの状態を確認

**Q: データベースエラー**
- マイグレーションが完了しているか確認
- 接続情報が正しいか確認

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2024-01-01 | 初版作成 |

## お問い合わせ

技術的な質問や問題がある場合は、以下にご連絡ください：

- Slackチャンネル: #research-platform-dev
- メール: dev-team@research.example.com
- GitHub Issues: [リポジトリURL]/issues