# Sakura VPS デプロイメントガイド

## 1. サーバー初期設定

### 1.1 VPSの準備

```bash
# SSHでVPSに接続
ssh root@your-vps-ip

# システムの更新
apt update && apt upgrade -y

# 必要なパッケージのインストール
apt install -y \
    curl \
    git \
    vim \
    htop \
    ufw \
    fail2ban \
    nginx \
    certbot \
    python3-certbot-nginx
```

### 1.2 ユーザー設定

```bash
# 新しいユーザーの作成
adduser research
usermod -aG sudo research

# SSHキーの設定
su - research
mkdir ~/.ssh
chmod 700 ~/.ssh
# ローカルマシンから公開鍵をコピー
echo "your-public-key" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 1.3 ファイアウォール設定

```bash
# UFWの設定
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 3000  # Grafana
sudo ufw allow 9090  # Prometheus (内部アクセスのみ推奨)
sudo ufw enable
```

## 2. Docker環境のセットアップ

### 2.1 Dockerのインストール

```bash
# Docker公式インストールスクリプト
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# ユーザーをdockerグループに追加
sudo usermod -aG docker research

# Docker Composeのインストール
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2.2 スワップファイルの作成（メモリが少ない場合）

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永続化
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 3. アプリケーションのデプロイ

### 3.1 リポジトリのクローン

```bash
cd /home/research
git clone https://github.com/your-org/research-platform.git
cd research-platform/backend
```

### 3.2 環境変数の設定

```bash
# 環境変数ファイルの作成
cp .env.example .env

# セキュアなパスワードの生成
openssl rand -base64 32  # 各パスワード用に実行

# .envファイルの編集
vim .env
```

### 3.3 SSL証明書の取得

```bash
# Let's Encryptを使用
sudo certbot certonly --standalone -d os3-378-22222.vs.sakura.ne.jp

# 証明書をコピー
sudo cp /etc/letsencrypt/live/os3-378-22222.vs.sakura.ne.jp/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/os3-378-22222.vs.sakura.ne.jp/privkey.pem nginx/ssl/key.pem
sudo chown research:research nginx/ssl/*
```

### 3.4 本番用設定ファイルの作成

```bash
# docker-compose.prod.yml
cat > docker-compose.prod.yml << 'EOF'
version: '3.9'

services:
  nginx:
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.prod.conf:/etc/nginx/nginx.conf:ro

  api:
    restart: always
    environment:
      ENVIRONMENT: production
      LOG_LEVEL: WARNING
    command: gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

  postgres:
    restart: always
    volumes:
      - /data/postgres:/var/lib/postgresql/data

  redis:
    restart: always
    volumes:
      - /data/redis:/data

  celery_worker:
    restart: always
    deploy:
      replicas: 2

  minio:
    restart: always
    volumes:
      - /data/minio:/data
EOF
```

### 3.5 アプリケーションの起動

```bash
# イメージのビルド
docker-compose build

# サービスの起動
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# ログの確認
docker-compose logs -f
```

## 4. 初期設定

### 4.1 データベースの初期化

```bash
# マイグレーションの実行
docker-compose exec api alembic upgrade head

# 管理者ユーザーの作成
docker-compose exec api python scripts/create_admin.py
```

### 4.2 Keycloakの設定

1. ブラウザで `https://os3-378-22222.vs.sakura.ne.jp/auth` にアクセス
2. 管理者アカウントでログイン
3. レルムの作成とクライアントの設定

### 4.3 MinIOの設定

```bash
# MinIOクライアントのインストール
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# エイリアスの設定
mc alias set research http://localhost:9000 minioadmin your-minio-password

# バケットの作成
mc mb research/research-data
mc mb research/research-backups
```

## 5. 監視とメンテナンス

### 5.1 自動バックアップの設定

```bash
# バックアップスクリプトの作成
cat > /home/research/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/data/backups"
mkdir -p $BACKUP_DIR

# PostgreSQLバックアップ
docker-compose exec -T postgres pg_dump -U postgres research_db | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# MinIOデータの同期
mc mirror research/research-data $BACKUP_DIR/minio_$DATE/

# 古いバックアップの削除（30日以上）
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
EOF

chmod +x /home/research/backup.sh

# Cronジョブの設定
crontab -e
# 毎日午前2時にバックアップ
0 2 * * * /home/research/backup.sh
```

### 5.2 ログローテーション

```bash
# Dockerログの設定
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

### 5.3 監視設定

```bash
# Prometheusアラートルールの設定
cat > prometheus/alerts.yml << 'EOF'
groups:
  - name: research_platform
    rules:
      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total[5m]) > 0.8
        for: 5m
        annotations:
          summary: "High CPU usage detected"
      
      - alert: LowDiskSpace
        expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes < 0.1
        for: 5m
        annotations:
          summary: "Low disk space"
EOF
```

## 6. セキュリティ強化

### 6.1 SSH設定の強化

```bash
# /etc/ssh/sshd_config の編集
sudo vim /etc/ssh/sshd_config

# 以下の設定を適用
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers research

# SSH再起動
sudo systemctl restart sshd
```

### 6.2 Fail2banの設定

```bash
# Jail設定
sudo vim /etc/fail2ban/jail.local

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

# Fail2ban再起動
sudo systemctl restart fail2ban
```

### 6.3 定期的なセキュリティアップデート

```bash
# 自動アップデートの設定
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

## 7. トラブルシューティング

### 7.1 サービスが起動しない場合

```bash
# Docker関連の問題
docker-compose down
docker system prune -a
docker-compose up -d

# ディスク容量の確認
df -h
du -sh /var/lib/docker/*
```

### 7.2 パフォーマンスの問題

```bash
# リソース使用状況の確認
docker stats
htop

# PostgreSQLのチューニング
docker-compose exec postgres psql -U postgres -c "SHOW shared_buffers;"
docker-compose exec postgres psql -U postgres -c "SHOW effective_cache_size;"
```

### 7.3 復旧手順

```bash
# バックアップからの復旧
docker-compose down
docker-compose up -d postgres
gunzip < /data/backups/db_20240101_020000.sql.gz | docker-compose exec -T postgres psql -U postgres research_db
docker-compose up -d
```

## 8. アップデート手順

```bash
# コードの更新
cd /home/research/research-platform
git pull origin main

# イメージの再ビルド
docker-compose build

# ローリングアップデート
docker-compose up -d --no-deps --build api
docker-compose up -d --no-deps --build celery_worker

# データベースマイグレーション
docker-compose exec api alembic upgrade head
```

## 9. 災害復旧計画

### 9.1 バックアップの外部保存

```bash
# S3互換ストレージへの同期
mc mirror /data/backups s3/research-backups/
```

### 9.2 復旧時間目標（RTO）達成のための準備

- データベースのレプリケーション設定
- 定期的な復旧訓練の実施
- 復旧手順書の整備

## 10. 連絡先とサポート

- システム管理者: admin@research.example.com
- 緊急連絡先: +81-XX-XXXX-XXXX
- ドキュメント: https://docs.research.example.com