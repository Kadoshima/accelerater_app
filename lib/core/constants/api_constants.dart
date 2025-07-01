/// API関連の定数定義
class ApiConstants {
  ApiConstants._();
  
  // Development environment
  static const String devBaseUrl = 'http://localhost';
  static const String devApiUrl = '$devBaseUrl/api/v1';
  static const String devWebSocketUrl = 'ws://localhost/ws';
  
  // Production environment (Sakura VPS)
  static const String prodDomain = 'os3-378-22222.vs.sakura.ne.jp';
  static const String prodBaseUrl = 'https://$prodDomain';
  static const String prodApiUrl = '$prodBaseUrl/api/v1';
  static const String prodWebSocketUrl = 'wss://$prodDomain/ws';
  
  // API endpoints
  static const String authEndpoint = '/auth';
  static const String loginEndpoint = '$authEndpoint/login';
  static const String refreshEndpoint = '$authEndpoint/refresh';
  static const String logoutEndpoint = '$authEndpoint/logout';
  
  static const String projectsEndpoint = '/projects';
  static const String participantsEndpoint = '/participants';
  static const String sessionsEndpoint = '/sessions';
  static const String devicesEndpoint = '/devices';
  static const String protocolsEndpoint = '/protocols';
  static const String jobsEndpoint = '/jobs';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);
  
  // Headers
  static const String authorizationHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';
  static const String acceptHeader = 'Accept';
  
  // Content types
  static const String jsonContentType = 'application/json';
  static const String multipartContentType = 'multipart/form-data';
  
  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 200;
  
  // Rate limiting
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}