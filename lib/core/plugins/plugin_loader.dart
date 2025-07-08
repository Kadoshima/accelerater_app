import 'package:flutter/foundation.dart';
import 'research_plugin.dart';

/// Manages loading and lifecycle of research plugins
class PluginLoader {
  static final PluginLoader _instance = PluginLoader._internal();
  factory PluginLoader() => _instance;
  PluginLoader._internal();
  
  final Map<String, ResearchPlugin> _plugins = {};
  final ValueNotifier<ResearchPlugin?> _activePlugin = ValueNotifier(null);
  
  /// Currently active plugin
  ValueNotifier<ResearchPlugin?> get activePlugin => _activePlugin;
  
  /// All registered plugins
  List<ResearchPlugin> get registeredPlugins => _plugins.values.toList();
  
  /// Register a new plugin
  Future<void> registerPlugin(ResearchPlugin plugin) async {
    if (_plugins.containsKey(plugin.id)) {
      throw PluginException('Plugin with ID ${plugin.id} is already registered');
    }
    
    // Validate plugin before registration
    final validation = plugin.validate();
    if (!validation.isValid) {
      throw PluginException(
        'Plugin validation failed: ${validation.errors.join(', ')}',
      );
    }
    
    // Initialize plugin
    await plugin.initialize();
    
    _plugins[plugin.id] = plugin;
    debugPrint('Plugin registered: ${plugin.name} (${plugin.id})');
  }
  
  /// Unregister a plugin
  Future<void> unregisterPlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginException('Plugin with ID $pluginId not found');
    }
    
    // If this is the active plugin, deactivate it first
    if (_activePlugin.value?.id == pluginId) {
      await deactivatePlugin();
    }
    
    await plugin.dispose();
    _plugins.remove(pluginId);
    debugPrint('Plugin unregistered: ${plugin.name} (${plugin.id})');
  }
  
  /// Activate a plugin
  Future<void> activatePlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginException('Plugin with ID $pluginId not found');
    }
    
    // Deactivate current plugin if any
    if (_activePlugin.value != null) {
      await deactivatePlugin();
    }
    
    // Validate plugin can be activated
    final validation = plugin.validate();
    if (!validation.isValid) {
      throw PluginException(
        'Cannot activate plugin: ${validation.errors.join(', ')}',
      );
    }
    
    _activePlugin.value = plugin;
    debugPrint('Plugin activated: ${plugin.name} (${plugin.id})');
  }
  
  /// Deactivate current plugin
  Future<void> deactivatePlugin() async {
    if (_activePlugin.value == null) return;
    
    final plugin = _activePlugin.value!;
    _activePlugin.value = null;
    debugPrint('Plugin deactivated: ${plugin.name} (${plugin.id})');
  }
  
  /// Get plugin by ID
  ResearchPlugin? getPlugin(String pluginId) => _plugins[pluginId];
  
  /// Check if a plugin is registered
  bool isPluginRegistered(String pluginId) => _plugins.containsKey(pluginId);
  
  /// Export settings of all plugins
  Map<String, Map<String, dynamic>> exportAllSettings() {
    final settings = <String, Map<String, dynamic>>{};
    for (final entry in _plugins.entries) {
      settings[entry.key] = entry.value.exportSettings();
    }
    return settings;
  }
  
  /// Import settings for all plugins
  void importAllSettings(Map<String, Map<String, dynamic>> settings) {
    for (final entry in settings.entries) {
      final plugin = _plugins[entry.key];
      if (plugin != null) {
        plugin.importSettings(entry.value);
      }
    }
  }
  
  /// Dispose of all plugins
  Future<void> dispose() async {
    // Deactivate current plugin
    await deactivatePlugin();
    
    // Dispose all plugins
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
    
    _plugins.clear();
  }
}

/// Exception thrown by plugin operations
class PluginException implements Exception {
  final String message;
  const PluginException(this.message);
  
  @override
  String toString() => 'PluginException: $message';
}