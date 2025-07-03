import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugins/plugin_manager.dart';
import '../../core/plugins/research_plugin.dart';
import '../providers/sensor_providers.dart';

/// プラグインマネージャーのプロバイダー
final pluginManagerProvider = ChangeNotifierProvider<PluginManager>((ref) {
  final manager = PluginManager.instance;
  
  // センサーマネージャーを設定
  final sensorManager = ref.watch(sensorManagerProvider);
  manager.setSensorManager(sensorManager);
  
  // ビルトインプラグインを登録
  manager.registerBuiltinPlugins();
  
  ref.onDispose(() async {
    await manager.disposeAll();
  });
  
  return manager;
});

/// 登録されているプラグインのリスト
final pluginsProvider = Provider<List<PluginInfo>>((ref) {
  final manager = ref.watch(pluginManagerProvider);
  return manager.plugins;
});

/// アクティブなプラグインID
final activePluginIdProvider = Provider<String?>((ref) {
  final manager = ref.watch(pluginManagerProvider);
  return manager.activePluginId;
});

/// アクティブなプラグイン
final activePluginProvider = Provider<ResearchPlugin?>((ref) {
  final manager = ref.watch(pluginManagerProvider);
  return manager.activePlugin;
});

/// プラグインの状態
final pluginStateProvider = Provider.family<PluginState?, String>((ref, pluginId) {
  final manager = ref.watch(pluginManagerProvider);
  return manager.getPluginInfo(pluginId)?.state;
});

/// プラグインイベントストリーム
final pluginEventsProvider = StreamProvider<PluginEvent>((ref) {
  final manager = ref.watch(pluginManagerProvider);
  return manager.pluginEvents;
});

/// プラグインの初期化
final initializePluginProvider = Provider.family<
  Future<void> Function(Map<String, dynamic>?), 
  String
>((ref, pluginId) {
  final manager = ref.watch(pluginManagerProvider);
  return (config) => manager.initializePlugin(pluginId, config: config);
});

/// プラグインの開始
final startPluginProvider = Provider.family<
  Future<void> Function(), 
  String
>((ref, pluginId) {
  final manager = ref.watch(pluginManagerProvider);
  return () => manager.startPlugin(pluginId);
});

/// プラグインの停止
final stopPluginProvider = Provider.family<
  Future<void> Function(), 
  String
>((ref, pluginId) {
  final manager = ref.watch(pluginManagerProvider);
  return () => manager.stopPlugin(pluginId);
});

/// プラグインのデータストリーム
/// TODO: データストリーム機能は将来の実装で追加予定
final pluginDataStreamProvider = StreamProvider.family<
  Map<String, dynamic>, 
  String
>((ref, pluginId) {
  // 現在は空のストリームを返す
  // 将来的にプラグインごとのデータストリーム実装を追加
  return Stream<Map<String, dynamic>>.empty();
});

/// プラグイン設定の検証
final validatePluginConfigProvider = Provider.family<
  bool Function(Map<String, dynamic>), 
  String
>((ref, pluginId) {
  final manager = ref.watch(pluginManagerProvider);
  final plugin = manager.getPlugin(pluginId);
  
  // プラグインの validate() メソッドを使用して基本的な検証を行う
  return (config) {
    if (plugin == null) return false;
    
    // プラグインに設定を適用してから検証
    plugin.importSettings(config);
    final result = plugin.validate();
    return result.isValid;
  };
});