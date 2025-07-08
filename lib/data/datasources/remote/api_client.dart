import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger_service.dart';

/// API通信のベースクライアント
class ApiClient {
  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  
  ApiClient({String? baseUrl}) {
    final apiUrl = baseUrl ?? 
      (kDebugMode ? ApiConstants.devApiUrl : ApiConstants.prodApiUrl);
    
    _dio = Dio(BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        ApiConstants.contentTypeHeader: ApiConstants.jsonContentType,
        ApiConstants.acceptHeader: ApiConstants.jsonContentType,
      },
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add auth token if available
          if (_accessToken != null) {
            options.headers[ApiConstants.authorizationHeader] = 'Bearer $_accessToken';
          }
          
          logger.debug('API Request: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          logger.debug('API Response: ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) async {
          logger.error('API Error: ${error.message}', error.error);
          
          // Handle 401 Unauthorized
          if (error.response?.statusCode == 401 && _refreshToken != null) {
            try {
              await _refreshAccessToken();
              // Retry the request
              final clonedRequest = await _dio.request(
                error.requestOptions.path,
                options: Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers
                    ..[ApiConstants.authorizationHeader] = 'Bearer $_accessToken',
                ),
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
              );
              handler.resolve(clonedRequest);
              return;
            } catch (e) {
              // Refresh failed, logout user
              _clearTokens();
            }
          }
          
          handler.next(error);
        },
      ),
    );
    
    // Logging interceptor (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (log) => logger.debug(log.toString()),
      ));
    }
  }
  
  Future<void> _refreshAccessToken() async {
    try {
      final response = await _dio.post(
        ApiConstants.refreshEndpoint,
        data: {'refresh_token': _refreshToken},
      );
      
      _accessToken = response.data['access_token'];
      _refreshToken = response.data['refresh_token'];
      
      // TODO: Save tokens securely
    } catch (e) {
      logger.error('Token refresh failed', e);
      rethrow;
    }
  }
  
  void _clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    // TODO: Clear tokens from secure storage
  }
  
  void setTokens(String accessToken, String refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    // TODO: Save tokens securely
  }
  
  // Public methods for API calls
  
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options);
  }
  
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
  }
  
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);
  }
  
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
  }
  
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
  }
  
  // WebSocket URL helper
  String getWebSocketUrl(String path) {
    final wsUrl = kDebugMode ? ApiConstants.devWebSocketUrl : ApiConstants.prodWebSocketUrl;
    return '$wsUrl$path';
  }
}