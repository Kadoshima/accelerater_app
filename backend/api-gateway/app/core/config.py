"""
Application configuration using Pydantic Settings
"""
from typing import List, Optional, Union
from functools import lru_cache

from pydantic import field_validator, PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings."""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )
    
    # Project Info
    PROJECT_NAME: str = "Research Platform API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"
    
    # Security
    SECRET_KEY: str
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Database
    DATABASE_URL: PostgresDsn
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 40
    DB_POOL_TIMEOUT: int = 30
    
    # Redis
    REDIS_URL: str
    REDIS_POOL_SIZE: int = 10
    REDIS_DECODE_RESPONSES: bool = True
    
    # Keycloak
    KEYCLOAK_SERVER_URL: str
    KEYCLOAK_REALM: str
    KEYCLOAK_CLIENT_ID: str
    KEYCLOAK_CLIENT_SECRET: str
    KEYCLOAK_ADMIN_USERNAME: Optional[str] = None
    KEYCLOAK_ADMIN_PASSWORD: Optional[str] = None
    
    # Domain
    DOMAIN_NAME: str = "os3-378-22222.vs.sakura.ne.jp"
    API_URL: str = "https://os3-378-22222.vs.sakura.ne.jp/api/v1"
    FRONTEND_URL: str = "https://os3-378-22222.vs.sakura.ne.jp"
    WEBSOCKET_URL: str = "wss://os3-378-22222.vs.sakura.ne.jp/ws"
    
    # CORS
    CORS_ORIGINS: List[str] = ["http://localhost:3000"]
    
    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> Union[List[str], str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)
    
    # Celery
    CELERY_BROKER_URL: Optional[str] = None
    CELERY_RESULT_BACKEND: Optional[str] = None
    CELERY_TASK_ALWAYS_EAGER: bool = False
    
    # Storage
    USE_S3: bool = True
    S3_ENDPOINT_URL: Optional[str] = None
    S3_ACCESS_KEY_ID: Optional[str] = None
    S3_SECRET_ACCESS_KEY: Optional[str] = None
    S3_BUCKET_NAME: str = "research-data"
    S3_REGION: str = "us-east-1"
    
    # File Upload
    MAX_UPLOAD_SIZE_MB: int = 1024
    ALLOWED_UPLOAD_EXTENSIONS: List[str] = [
        ".csv", ".json", ".txt", ".pdf", ".xlsx", ".xls",
        ".png", ".jpg", ".jpeg", ".gif", ".mp4", ".avi"
    ]
    
    # Data Processing
    DATA_RETENTION_DAYS: int = 365
    AUTO_ARCHIVE_DAYS: int = 90
    MAX_PROCESSING_WORKERS: int = 4
    
    # Email
    SMTP_HOST: Optional[str] = None
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM: str = "noreply@research.example.com"
    SMTP_TLS: bool = True
    
    # Monitoring
    ENABLE_METRICS: bool = True
    SENTRY_DSN: Optional[str] = None
    
    # Feature Flags
    ENABLE_REALTIME_ANALYSIS: bool = True
    ENABLE_ML_PIPELINE: bool = False
    ENABLE_MULTI_TENANT: bool = True
    ENABLE_AUDIT_LOG: bool = True
    
    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_DEFAULT: str = "100/minute"
    RATE_LIMIT_STORAGE_URL: Optional[str] = None
    
    # Session
    SESSION_TIMEOUT_MINUTES: int = 60
    SESSION_COOKIE_NAME: str = "research_session"
    SESSION_COOKIE_SECURE: bool = True
    SESSION_COOKIE_HTTPONLY: bool = True
    
    # Pagination
    DEFAULT_PAGE_SIZE: int = 50
    MAX_PAGE_SIZE: int = 200
    
    @property
    def celery_broker_url(self) -> str:
        """Get Celery broker URL, defaulting to Redis URL if not set."""
        return self.CELERY_BROKER_URL or self.REDIS_URL
    
    @property
    def celery_result_backend(self) -> str:
        """Get Celery result backend, defaulting to Redis URL if not set."""
        return self.CELERY_RESULT_BACKEND or self.REDIS_URL
    
    def get_db_url(self, is_async: bool = True) -> str:
        """Get database URL for sync or async connections."""
        if is_async:
            return str(self.DATABASE_URL).replace("postgresql://", "postgresql+asyncpg://")
        return str(self.DATABASE_URL)


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


# Global settings instance
settings = get_settings()