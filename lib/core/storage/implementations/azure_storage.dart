import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../cloud_storage_interface.dart';
import '../../utils/logger_service.dart';

/// Azure Blob Storage の実装
class AzureStorage extends BaseCloudStorage {
  late final String _accountName;
  late final String _sasToken;
  late final String _containerName;
  
  AzureStorage({
    String? accountName,
    String? sasToken,
    String? containerName,
  }) {
    // 環境変数から読み込み（引数で指定されていない場合）
    _accountName = accountName ?? dotenv.env['AZURE_STORAGE_ACCOUNT'] ?? '';
    _sasToken = sasToken ?? dotenv.env['AZURE_SAS_TOKEN'] ?? '';
    _containerName = containerName ?? dotenv.env['AZURE_CONTAINER_NAME'] ?? '';
    
    if (_accountName.isEmpty || _sasToken.isEmpty || _containerName.isEmpty) {
      throw Exception('Azure Storage credentials not configured');
    }
  }
  
  @override
  String get providerName => 'Azure Blob Storage';
  
  @override
  Future<void> initialize() async {
    // Azure Blob Storageは特別な初期化は不要
    logger.info('Azure Storage initialized');
  }
  
  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    Map<String, String>? metadata,
  }) async {
    try {
      final url = _buildUrl(path);
      
      final headers = <String, String>{
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': _getContentType(path),
      };
      
      // メタデータを追加
      if (metadata != null) {
        for (final entry in metadata.entries) {
          headers['x-ms-meta-${entry.key}'] = entry.value;
        }
      }
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: data,
      );
      
      if (response.statusCode == 201) {
        logger.info('File uploaded successfully: $path');
        return url.split('?').first; // SASトークンを除いたURL
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logger.error('Failed to upload file to Azure', e);
      rethrow;
    }
  }
  
  @override
  Future<bool> exists(String path) async {
    try {
      final url = _buildUrl(path);
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      logger.error('Failed to check file existence', e);
      return false;
    }
  }
  
  @override
  Future<Uint8List> downloadFile(String path) async {
    try {
      final url = _buildUrl(path);
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('Failed to download file from Azure', e);
      rethrow;
    }
  }
  
  @override
  Future<void> deleteFile(String path) async {
    try {
      final url = _buildUrl(path);
      final response = await http.delete(Uri.parse(url));
      
      if (response.statusCode != 202) {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('Failed to delete file from Azure', e);
      rethrow;
    }
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      // コンテナのプロパティを取得してテスト
      final url = 'https://$_accountName.blob.core.windows.net/$_containerName?restype=container&$_sasToken';
      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      logger.error('Connection test failed', e);
      return false;
    }
  }
  
  String _buildUrl(String path) {
    // パスの先頭のスラッシュを削除
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return 'https://$_accountName.blob.core.windows.net/$_containerName/$cleanPath?$_sasToken';
  }
  
  String _getContentType(String path) {
    if (path.endsWith('.json')) return 'application/json';
    if (path.endsWith('.csv')) return 'text/csv';
    if (path.endsWith('.parquet')) return 'application/octet-stream';
    return 'application/octet-stream';
  }
}