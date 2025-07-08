import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugins/plugin_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/common/app_card.dart';
import '../providers/plugin_providers.dart';

/// プラグイン選択画面
class PluginSelectionScreen extends ConsumerStatefulWidget {
  const PluginSelectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PluginSelectionScreen> createState() => _PluginSelectionScreenState();
}

class _PluginSelectionScreenState extends ConsumerState<PluginSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final plugins = ref.watch(pluginsProvider);
    final activePluginId = ref.watch(activePluginIdProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('実験を選択'),
        backgroundColor: AppColors.surface,
        centerTitle: true,
        elevation: 0,
      ),
      body: plugins.isEmpty
          ? const Center(
              child: Text(
                '利用可能な実験がありません',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: plugins.length,
              itemBuilder: (context, index) {
                final plugin = plugins[index];
                return _buildPluginCard(plugin, activePluginId == plugin.id);
              },
            ),
    );
  }
  
  Widget _buildPluginCard(PluginInfo plugin, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: InkWell(
          onTap: () => _selectPlugin(plugin),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plugin.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusBadge(plugin.state, isActive),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  plugin.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      'バージョン: ${plugin.version}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (plugin.lastActiveTime != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        '最終使用: ${_formatDateTime(plugin.lastActiveTime!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (plugin.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            plugin.errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusBadge(PluginState state, bool isActive) {
    Color color;
    String text;
    IconData icon;
    
    if (isActive) {
      color = AppColors.success;
      text = 'アクティブ';
      icon = Icons.play_circle_filled;
    } else {
      switch (state) {
        case PluginState.uninitialized:
          color = AppColors.textTertiary;
          text = '未初期化';
          icon = Icons.stop_circle_outlined;
          break;
        case PluginState.initializing:
          color = AppColors.warning;
          text = '初期化中';
          icon = Icons.hourglass_empty;
          break;
        case PluginState.ready:
          color = AppColors.primary;
          text = '準備完了';
          icon = Icons.check_circle_outline;
          break;
        case PluginState.running:
          color = AppColors.success;
          text = '実行中';
          icon = Icons.play_circle_filled;
          break;
        case PluginState.stopped:
          color = AppColors.textSecondary;
          text = '停止中';
          icon = Icons.pause_circle_filled;
          break;
        case PluginState.error:
          color = AppColors.error;
          text = 'エラー';
          icon = Icons.error_outline;
          break;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _selectPlugin(PluginInfo plugin) async {
    final manager = ref.read(pluginManagerProvider);
    
    try {
      // 未初期化の場合は初期化
      if (plugin.state == PluginState.uninitialized) {
        await manager.initializePlugin(plugin.id);
      }
      
      // プラグインを開始
      if (plugin.state == PluginState.ready || plugin.state == PluginState.stopped) {
        await manager.startPlugin(plugin.id);
        
        // プラグインの画面に遷移
        if (mounted) {
          final activePlugin = manager.getPlugin(plugin.id);
          if (activePlugin != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => activePlugin.buildExperimentScreen(context),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }
}