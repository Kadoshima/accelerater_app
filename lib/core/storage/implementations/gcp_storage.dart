import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../cloud_storage_interface.dart';
import '../../utils/logger_service.dart';

/// Google Cloud Storage の実装
class GCPStorage extends BaseCloudStorage {
  late final String _bucketName;
  late final String _projectId;
  late final String _accessToken;
  
  GCPStorage({
    String? bucketName,
    String? projectId,
    String? accessToken,
  }) {
    // 環境変数から読み込み（引数で指定されていない場合）
    _bucketName = bucketName ?? dotenv.env['GCP_BUCKET_NAME'] ?? '';
    _projectId = projectId ?? dotenv.env['GCP_PROJECT_ID'] ?? '';
    _accessToken = accessToken ?? dotenv.env['GCP_ACCESS_TOKEN'] ?? '';
    
    if (_bucketName.isEmpty || _projectId.isEmpty) {
      throw Exception('GCP Storage credentials not configured');
    }
  }
  
  @override
  String get providerName => 'Google Cloud Storage';
  
  @override
  Future<void> initialize() async {
    // TODO: OAuth2認証フローの実装が必要
    logger.info('GCP Storage initialized');
  }
  
  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    Map<String, String>? metadata,
  }) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://storage.googleapis.com/upload/storage/v1/b/$_bucketName/o?uploadType=media&name=$cleanPath';
      
      final headers = <String, String>{
        'Content-Type': _getContentType(path),
        'Content-Length': data.length.toString(),
      };
      
      // アクセストークンが設定されている場合は使用
      if (_accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      
      // メタデータを設定
      if (metadata != null && metadata.isNotEmpty) {
        // GCSではメタデータは別のAPIで設定する必要がある
        // ここでは簡略化のため省略
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: data,
      );
      
      if (response.statusCode == 200) {
        logger.info('File uploaded successfully to GCS: $path');
        return 'https://storage.googleapis.com/$_bucketName/$cleanPath';
      } else {
        throw Exception('GCS upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logger.error('Failed to upload file to GCS', e);
      rethrow;
    }
  }
  
  @override
  Future<bool> exists(String path) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://storage.googleapis.com/storage/v1/b/$_bucketName/o/$cleanPath';
      
      final headers = <String, String>{};
      if (_accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      logger.error('Failed to check file existence in GCS', e);
      return false;
    }
  }
  
  @override
  Future<Uint8List> downloadFile(String path) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://storage.googleapis.com/$_bucketName/$cleanPath';
      
      final headers = <String, String>{};
      if (_accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('GCS download failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('Failed to download file from GCS', e);
      rethrow;
    }
  }
  
  @override
  Future<void> deleteFile(String path) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://storage.googleapis.com/storage/v1/b/$_bucketName/o/$cleanPath';
      
      final headers = <String, String>{};
      if (_accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode != 204 && response.statusCode != 404) {
        throw Exception('GCS delete failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('Failed to delete file from GCS', e);
      rethrow;
    }
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      // バケットのメタデータを取得してテスト
      final url = 'https://storage.googleapis.com/storage/v1/b/$_bucketName';
      
      final headers = <String, String>{};
      if (_accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      logger.error('GCS connection test failed', e);
      return false;
    }
  }
  
  String _getContentType(String path) {
    if (path.endsWith('.json')) return 'application/json';
    if (path.endsWith('.csv')) return 'text/csv';
    if (path.endsWith('.parquet')) return 'application/octet-stream';
    return 'application/octet-stream';
  }
}