/// アプリケーション全体の定数を定義
class AppConstants {
  AppConstants._();

  // アプリ情報
  static const String appName = 'HealthCore M5 Demo';
  static const String appVersion = '1.0.0';

  // 歩行解析パラメータ
  static const double defaultSamplingRate = 60.0; // Hz
  static const int defaultWindowSizeSeconds = 10;
  static const int defaultSlideIntervalSeconds = 1;
  static const double minFrequency = 1.0; // Hz (60 SPM)
  static const double maxFrequency = 3.5; // Hz (210 SPM)
  static const double minStdDev = 0.05; // 静止判定しきい値
  static const double minSNR = 2.0; // 最小信号対雑音比
  static const double defaultSmoothingFactor = 0.3;
  static const double spmCorrectionFactor = 0.93; // 7%削減係数

  // メトロノーム設定
  static const double defaultBpm = 120.0;
  static const double minBpm = 40.0;
  static const double maxBpm = 200.0;
  static const double clickFrequency = 900.0; // Hz
  static const double clickDuration = 0.025; // 秒
  static const double clickAmplitude = 0.3;

  // 実験フェーズ
  static const Duration baselineDuration = Duration(minutes: 2);
  static const Duration adaptationDuration = Duration(minutes: 3);
  static const Duration inductionDuration = Duration(minutes: 5);
  static const int stableThresholdSeconds = 30;
  static const double bpmIncrementStep = 5.0;

  // ファイル保存
  static const String dataFolderName = 'accelerometer_data';
  static const String experimentFolderName = 'experiments';
  
  // Azure Storage（環境変数から読み込むため、ここではキー名のみ）
  static const String azureStorageAccountKey = 'AZURE_STORAGE_ACCOUNT';
  static const String azureSasTokenKey = 'AZURE_SAS_TOKEN';
  static const String azureContainerNameKey = 'AZURE_CONTAINER_NAME';
}