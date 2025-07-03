import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../cloud_storage_interface.dart';
import '../../utils/logger_service.dart';

/// AWS S3 Storage の実装
class AWSStorage extends BaseCloudStorage {
  late final String _bucketName;
  late final String _region;
  late final String _accessKeyId;
  late final String _secretAccessKey;
  
  AWSStorage({
    String? bucketName,
    String? region,
    String? accessKeyId,
    String? secretAccessKey,
  }) {
    // 環境変数から読み込み（引数で指定されていない場合）
    _bucketName = bucketName ?? dotenv.env['AWS_S3_BUCKET'] ?? '';
    _region = region ?? dotenv.env['AWS_REGION'] ?? 'ap-northeast-1';
    _accessKeyId = accessKeyId ?? dotenv.env['AWS_ACCESS_KEY_ID'] ?? '';
    _secretAccessKey = secretAccessKey ?? dotenv.env['AWS_SECRET_ACCESS_KEY'] ?? '';
    
    if (_bucketName.isEmpty || _accessKeyId.isEmpty || _secretAccessKey.isEmpty) {
      throw Exception('AWS S3 credentials not configured');
    }
  }
  
  @override
  String get providerName => 'AWS S3';
  
  @override
  Future<void> initialize() async {
    logger.info('AWS S3 Storage initialized');
  }
  
  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    Map<String, String>? metadata,
  }) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$cleanPath';
      
      // AWS署名バージョン4の実装（簡略版）
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatDateTime(now);
      
      final headers = <String, String>{
        'Host': '$_bucketName.s3.$_region.amazonaws.com',
        'x-amz-date': amzDate,
        'Content-Type': _getContentType(path),
        'Content-Length': data.length.toString(),
      };
      
      // メタデータを追加
      if (metadata != null) {
        for (final entry in metadata.entries) {
          headers['x-amz-meta-${entry.key}'] = entry.value;
        }
      }
      
      // 署名を計算（簡略版 - 実際のプロダクションでは完全な署名v4実装が必要）
      final authHeader = _calculateAuthorizationHeader(
        method: 'PUT',
        path: '/$cleanPath',
        headers: headers,
        dateStamp: dateStamp,
        amzDate: amzDate,
      );
      headers['Authorization'] = authHeader;
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: data,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        logger.info('File uploaded successfully to S3: $path');
        return url;
      } else {
        throw Exception('S3 upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logger.error('Failed to upload file to S3', e);
      rethrow;
    }
  }
  
  @override
  Future<bool> exists(String path) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$cleanPath';
      
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      logger.error('Failed to check file existence in S3', e);
      return false;
    }
  }
  
  @override
  Future<Uint8List> downloadFile(String path) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$cleanPath';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('S3 download failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('Failed to download file from S3', e);
      rethrow;
    }
  }
  
  @override
  Future<void> deleteFile(String path) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$cleanPath';
      
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatDateTime(now);
      
      final headers = <String, String>{
        'Host': '$_bucketName.s3.$_region.amazonaws.com',
        'x-amz-date': amzDate,
      };
      
      final authHeader = _calculateAuthorizationHeader(
        method: 'DELETE',
        path: '/$cleanPath',
        headers: headers,
        dateStamp: dateStamp,
        amzDate: amzDate,
      );
      headers['Authorization'] = authHeader;
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode != 204) {
        throw Exception('S3 delete failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('Failed to delete file from S3', e);
      rethrow;
    }
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      // バケットの存在確認
      final url = 'https://$_bucketName.s3.$_region.amazonaws.com/';
      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200 || response.statusCode == 403;
    } catch (e) {
      logger.error('S3 connection test failed', e);
      return false;
    }
  }
  
  String _getContentType(String path) {
    if (path.endsWith('.json')) return 'application/json';
    if (path.endsWith('.csv')) return 'text/csv';
    if (path.endsWith('.parquet')) return 'application/octet-stream';
    return 'application/octet-stream';
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }
  
  String _formatDateTime(DateTime date) {
    final iso = date.toIso8601String();
    return '${iso.replaceAll('-', '').replaceAll(':', '').split('.')[0]}Z';
  }
  
  // 簡略版の署名計算（実際のプロダクションでは完全な実装が必要）
  String _calculateAuthorizationHeader({
    required String method,
    required String path,
    required Map<String, String> headers,
    required String dateStamp,
    required String amzDate,
  }) {
    // これは簡略版です。実際のAWS署名v4は複雑な計算が必要です
    // プロダクション環境では aws_s3_client パッケージの使用を推奨
    final credential = '$_accessKeyId/$dateStamp/$_region/s3/aws4_request';
    final signedHeaders = headers.keys.map((k) => k.toLowerCase()).toList()..sort();
    
    return 'AWS4-HMAC-SHA256 Credential=$credential, SignedHeaders=${signedHeaders.join(';')}, Signature=dummy_signature';
  }
}