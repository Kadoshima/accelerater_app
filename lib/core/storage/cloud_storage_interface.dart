import 'dart:typed_data';

/// クラウドストレージの抽象インターフェース
abstract class CloudStorageInterface {
  /// ストレージの初期化
  Future<void> initialize();
  
  /// ファイルのアップロード
  /// [path] - ストレージ内のパス
  /// [data] - アップロードするデータ
  /// [metadata] - メタデータ（オプション）
  /// 戻り値: アップロードされたファイルのURL
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    Map<String, String>? metadata,
  });
  
  /// テキストデータのアップロード（便利メソッド）
  Future<String> uploadText({
    required String path,
    required String content,
    Map<String, String>? metadata,
  });
  
  /// ファイルの存在確認
  Future<bool> exists(String path);
  
  /// ファイルのダウンロード
  Future<Uint8List> downloadFile(String path);
  
  /// ファイルの削除
  Future<void> deleteFile(String path);
  
  /// 接続テスト
  Future<bool> testConnection();
  
  /// ストレージプロバイダー名
  String get providerName;
}

/// CloudStorageInterfaceのベース実装
abstract class BaseCloudStorage implements CloudStorageInterface {
  @override
  Future<String> uploadText({
    required String path,
    required String content,
    Map<String, String>? metadata,
  }) {
    final data = Uint8List.fromList(content.codeUnits);
    return uploadFile(path: path, data: data, metadata: metadata);
  }
}

/// クラウドストレージの設定
class CloudStorageConfig {
  final String type; // 'azure', 'aws', 'gcp'
  final Map<String, String> credentials;
  final String? defaultContainer;
  final String? region;
  
  const CloudStorageConfig({
    required this.type,
    required this.credentials,
    this.defaultContainer,
    this.region,
  });
}

/// アップロード結果
class UploadResult {
  final String url;
  final String path;
  final DateTime timestamp;
  final int size;
  final Map<String, String>? metadata;
  
  const UploadResult({
    required this.url,
    required this.path,
    required this.timestamp,
    required this.size,
    this.metadata,
  });
}