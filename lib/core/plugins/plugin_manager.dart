import 'package:flutter/foundation.dart';
import 'dart:async';
import 'research_plugin.dart';
import '../sensors/interfaces/sensor_interface.dart';
import '../../plugins/gait_analysis/gait_analysis_plugin.dart';

/// プラグインの状態
enum PluginState {
  uninitialized,
  initializing,
  ready,
  running,
  stopped,
  error,
}

/// プラグイン情報
class PluginInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final PluginState state;
  final String? errorMessage;
  final DateTime? lastActiveTime;
  
  PluginInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.state,
    this.errorMessage,
    this.lastActiveTime,
  });
  
  PluginInfo copyWith({
    PluginState? state,
    String? errorMessage,
    DateTime? lastActiveTime,
  }) {
    return PluginInfo(
      id: id,
      name: name,
      description: description,
      version: version,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
    );
  }
}

/// プラグインマネージャー
/// すべてのプラグインの登録、初期化、実行を管理
class PluginManager with ChangeNotifier {
  static PluginManager? _instance;
  
  // シングルトンインスタンス
  static PluginManager get instance {
    _instance ??= PluginManager._();
    return _instance!;
  }
  
  PluginManager._();
  
  // 登録されたプラグイン
  final Map<String, ResearchPlugin> _plugins = {};
  final Map<String, PluginInfo> _pluginInfos = {};
  
  // 現在アクティブなプラグイン
  String? _activePluginId;
  
  // センサーマネージャーへの参照
  ISensorManager? _sensorManager;
  
  // イベントストリーム
  final _pluginEventController = StreamController<PluginEvent>.broadcast();
  Stream<PluginEvent> get pluginEvents => _pluginEventController.stream;
  
  /// プラグインを登録
  void registerPlugin(ResearchPlugin plugin) {
    final id = plugin.id;
    _plugins[id] = plugin;
    _pluginInfos[id] = PluginInfo(
      id: id,
      name: plugin.name,
      description: plugin.description,
      version: plugin.version,
      state: PluginState.uninitialized,
    );
    
    _pluginEventController.add(PluginEvent(
      type: PluginEventType.registered,
      pluginId: id,
      timestamp: DateTime.now(),
    ));
    
    notifyListeners();
  }
  
  /// ビルトインプラグインを登録
  void registerBuiltinPlugins() {
    // 歩行解析プラグインを登録
    registerPlugin(GaitAnalysisPlugin());
    
    // 今後、他のプラグインもここに追加
  }
  
  /// プラグインを初期化
  Future<void> initializePlugin(String pluginId, {Map<String, dynamic>? config}) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginException('Plugin not found: $pluginId');
    }
    
    _updatePluginState(pluginId, PluginState.initializing);
    
    try {
      // 必要な権限をチェック
      await _checkPermissions(plugin);
      
      // 必要なセンサーをチェック
      await _checkSensors(plugin);
      
      // プラグインを初期化
      await plugin.initialize();
      
      _updatePluginState(pluginId, PluginState.ready);
      
      _pluginEventController.add(PluginEvent(
        type: PluginEventType.initialized,
        pluginId: pluginId,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      _updatePluginState(
        pluginId, 
        PluginState.error,
        errorMessage: e.toString(),
      );
      
      _pluginEventController.add(PluginEvent(
        type: PluginEventType.error,
        pluginId: pluginId,
        timestamp: DateTime.now(),
        error: e.toString(),
      ));
      
      rethrow;
    }
  }
  
  /// プラグインを開始
  Future<void> startPlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginException('Plugin not found: $pluginId');
    }
    
    final info = _pluginInfos[pluginId];
    if (info?.state != PluginState.ready && info?.state != PluginState.stopped) {
      throw PluginException('Plugin is not ready: $pluginId');
    }
    
    // 既存のアクティブプラグインを停止
    if (_activePluginId != null && _activePluginId != pluginId) {
      await stopPlugin(_activePluginId!);
    }
    
    try {
      await plugin.initialize();
      _activePluginId = pluginId;
      _updatePluginState(
        pluginId, 
        PluginState.running,
        lastActiveTime: DateTime.now(),
      );
      
      _pluginEventController.add(PluginEvent(
        type: PluginEventType.started,
        pluginId: pluginId,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      _updatePluginState(
        pluginId,
        PluginState.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
  
  /// プラグインを停止
  Future<void> stopPlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginException('Plugin not found: $pluginId');
    }
    
    try {
      await plugin.dispose();
      
      if (_activePluginId == pluginId) {
        _activePluginId = null;
      }
      
      _updatePluginState(pluginId, PluginState.stopped);
      
      _pluginEventController.add(PluginEvent(
        type: PluginEventType.stopped,
        pluginId: pluginId,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      _updatePluginState(
        pluginId,
        PluginState.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
  
  /// プラグインを破棄
  Future<void> disposePlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;
    
    // 実行中の場合は停止
    final info = _pluginInfos[pluginId];
    if (info?.state == PluginState.running) {
      await stopPlugin(pluginId);
    }
    
    await plugin.dispose();
    _plugins.remove(pluginId);
    _pluginInfos.remove(pluginId);
    
    _pluginEventController.add(PluginEvent(
      type: PluginEventType.disposed,
      pluginId: pluginId,
      timestamp: DateTime.now(),
    ));
    
    notifyListeners();
  }
  
  /// すべてのプラグインを破棄
  Future<void> disposeAll() async {
    final pluginIds = _plugins.keys.toList();
    for (final id in pluginIds) {
      await disposePlugin(id);
    }
    _pluginEventController.close();
  }
  
  /// センサーマネージャーを設定
  void setSensorManager(ISensorManager sensorManager) {
    _sensorManager = sensorManager;
  }
  
  /// センサーデータをアクティブなプラグインに転送
  void handleSensorData(SensorData data) {
    if (_activePluginId == null) return;
    
    final plugin = _plugins[_activePluginId];
    // TODO: Implement sensor data handling in ResearchPlugin interface
    // plugin?.handleSensorData(data);
  }
  
  // Getters
  
  /// 登録されているプラグインのリスト
  List<PluginInfo> get plugins => _pluginInfos.values.toList();
  
  /// アクティブなプラグインID
  String? get activePluginId => _activePluginId;
  
  /// アクティブなプラグイン
  ResearchPlugin? get activePlugin => 
      _activePluginId != null ? _plugins[_activePluginId] : null;
  
  /// プラグインを取得
  ResearchPlugin? getPlugin(String pluginId) => _plugins[pluginId];
  
  /// プラグイン情報を取得
  PluginInfo? getPluginInfo(String pluginId) => _pluginInfos[pluginId];
  
  // Private methods
  
  void _updatePluginState(
    String pluginId, 
    PluginState state, {
    String? errorMessage,
    DateTime? lastActiveTime,
  }) {
    final info = _pluginInfos[pluginId];
    if (info != null) {
      _pluginInfos[pluginId] = info.copyWith(
        state: state,
        errorMessage: errorMessage,
        lastActiveTime: lastActiveTime,
      );
      notifyListeners();
    }
  }
  
  Future<void> _checkPermissions(ResearchPlugin plugin) async {
    // TODO: 権限チェックの実装
    // 各プラットフォームの権限APIを使用
  }
  
  Future<void> _checkSensors(ResearchPlugin plugin) async {
    if (_sensorManager == null) return;
    
    final requiredSensors = plugin.requiredSensors;
    if (requiredSensors.isEmpty) return;
    
    // センサーの利用可能性をチェック
    for (final sensorType in requiredSensors) {
      final sensors = _sensorManager!.getSensorsByType(sensorType);
      
      // センサーが見つからない場合、利用可能性を確認
      if (sensors.isEmpty) {
        // iPhoneの加速度センサーが利用できるか確認
        bool sensorAvailable = false;
        for (final sensor in _sensorManager!.allSensors) {
          if (sensor.type == sensorType && await sensor.isAvailable()) {
            sensorAvailable = true;
            break;
          }
        }
        
        if (!sensorAvailable) {
          throw PluginException(
            'Required sensor not available: ${sensorType.name}',
          );
        }
      }
    }
  }
}

/// プラグインイベント
class PluginEvent {
  final PluginEventType type;
  final String pluginId;
  final DateTime timestamp;
  final String? error;
  final Map<String, dynamic>? data;
  
  PluginEvent({
    required this.type,
    required this.pluginId,
    required this.timestamp,
    this.error,
    this.data,
  });
}

/// プラグインイベントタイプ
enum PluginEventType {
  registered,
  initialized,
  started,
  stopped,
  disposed,
  error,
  dataReceived,
}

/// プラグイン例外
class PluginException implements Exception {
  final String message;
  
  PluginException(this.message);
  
  @override
  String toString() => 'PluginException: $message';
}