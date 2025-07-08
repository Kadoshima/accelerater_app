import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/experiment_condition_manager.dart';
import '../../services/experiment_flow_controller.dart';
import '../../models/nback_models.dart';
import 'dart:async';

/// 実験制御ダッシュボード
class ExperimentControlDashboard extends ConsumerStatefulWidget {
  const ExperimentControlDashboard({Key? key}) : super(key: key);
  
  @override
  ConsumerState<ExperimentControlDashboard> createState() => 
      _ExperimentControlDashboardState();
}

class _ExperimentControlDashboardState 
    extends ConsumerState<ExperimentControlDashboard> {
  late ExperimentConditionManager _conditionManager;
  late ExperimentFlowController _flowController;
  
  // 状態管理
  ExperimentPhase _currentPhase = ExperimentPhase.notStarted;
  Duration _phaseRemaining = Duration.zero;
  String _currentInstruction = '';
  ExperimentProgress? _experimentProgress;
  
  // パフォーマンスデータ（デモ用）
  double _currentSpm = 0.0;
  double _currentCv = 0.0;
  double _nbackAccuracy = 0.0;
  double _rmsePhi = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeExperiment();
  }
  
  void _initializeExperiment() {
    // 実験管理の初期化
    _conditionManager = ExperimentConditionManager();
    _conditionManager.initialize(participantNumber: 1); // TODO: 実際の被験者番号
    
    _flowController = ExperimentFlowController(
      conditionManager: _conditionManager,
      onPhaseChanged: _onPhaseChanged,
      onPhaseProgress: _onPhaseProgress,
      onBlockCompleted: _onBlockCompleted,
      onInstruction: _onInstruction,
    );
    
    _updateProgress();
  }
  
  void _onPhaseChanged(ExperimentPhase phase) {
    setState(() {
      _currentPhase = phase;
    });
  }
  
  void _onPhaseProgress(Duration remaining) {
    setState(() {
      _phaseRemaining = remaining;
    });
  }
  
  void _onBlockCompleted() {
    _updateProgress();
    // TODO: データ保存処理
  }
  
  void _onInstruction(String instruction) {
    setState(() {
      _currentInstruction = instruction;
    });
  }
  
  void _updateProgress() {
    setState(() {
      _experimentProgress = _conditionManager.getProgress();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('実験制御ダッシュボード'),
        actions: [
          // 緊急停止ボタン
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.red),
            iconSize: 32,
            onPressed: _showEmergencyStopDialog,
            tooltip: '緊急停止',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左側：実験制御パネル
            Expanded(
              flex: 3,
              child: _buildControlPanel(theme),
            ),
            const SizedBox(width: 16),
            // 右側：リアルタイムモニタリング
            Expanded(
              flex: 2,
              child: _buildMonitoringPanel(theme),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 実験進行状況
        _buildProgressCard(theme),
        const SizedBox(height: 16),
        
        // 現在の条件
        _buildCurrentConditionCard(theme),
        const SizedBox(height: 16),
        
        // フェーズ情報と制御
        _buildPhaseControlCard(theme),
        const SizedBox(height: 16),
        
        // 指示表示
        Expanded(
          child: _buildInstructionCard(theme),
        ),
      ],
    );
  }
  
  Widget _buildProgressCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '実験進行状況',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            if (_experimentProgress != null) ...[
              // 進行状況バー
              LinearProgressIndicator(
                value: _experimentProgress!.progressPercentage,
                minHeight: 20,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              
              // テキスト情報
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ブロック: ${_experimentProgress!.progressText}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    '${(_experimentProgress!.progressPercentage * 100).toInt()}%',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurrentConditionCard(ThemeData theme) {
    final condition = _experimentProgress?.currentCondition;
    
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '現在の実験条件',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            
            if (condition != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'テンポ制御: ${condition.tempoControl.displayName}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.psychology,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '認知負荷: ${condition.cognitiveLoad.displayName}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhaseControlCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '現在のフェーズ',
                  style: theme.textTheme.titleMedium,
                ),
                Chip(
                  label: Text(_currentPhase.displayName),
                  backgroundColor: _currentPhase.phaseColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: _currentPhase.phaseColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 残り時間
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '残り時間',
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  _formatDuration(_phaseRemaining),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _phaseRemaining.inSeconds <= 10 
                        ? Colors.red 
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 制御ボタン
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentPhase == ExperimentPhase.notStarted
                        ? _startExperiment
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('開始'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentPhase != ExperimentPhase.notStarted &&
                               _currentPhase != ExperimentPhase.completed
                        ? _pauseExperiment
                        : null,
                    icon: const Icon(Icons.pause),
                    label: const Text('一時停止'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _currentPhase != ExperimentPhase.notStarted &&
                               _currentPhase != ExperimentPhase.completed
                        ? () => _flowController.skipPhase()
                        : null,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('スキップ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInstructionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '現在の指示',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _currentInstruction.isEmpty 
                        ? '実験開始を待っています...' 
                        : _currentInstruction,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMonitoringPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // リアルタイムメトリクス
        _buildMetricsCard(theme),
        const SizedBox(height: 16),
        
        // パフォーマンスインジケーター
        _buildPerformanceCard(theme),
        const SizedBox(height: 16),
        
        // アラート
        _buildAlertsCard(theme),
      ],
    );
  }
  
  Widget _buildMetricsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'リアルタイムメトリクス',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            _buildMetricRow(
              'SPM',
              _currentSpm.toStringAsFixed(1),
              theme,
              icon: Icons.directions_walk,
            ),
            _buildMetricRow(
              'CV',
              _currentCv.toStringAsFixed(3),
              theme,
              icon: Icons.analytics,
            ),
            _buildMetricRow(
              'RMSE_φ',
              _rmsePhi.toStringAsFixed(3),
              theme,
              icon: Icons.timeline,
            ),
            _buildMetricRow(
              'N-back正答率',
              '${(_nbackAccuracy * 100).toInt()}%',
              theme,
              icon: Icons.check_circle,
              valueColor: _nbackAccuracy < 0.7 ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricRow(
    String label,
    String value,
    ThemeData theme, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'パフォーマンス指標',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // 歩行安定性インジケーター
            _buildPerformanceIndicator(
              '歩行安定性',
              _currentCv < 0.05 ? 1.0 : (_currentCv < 0.1 ? 0.7 : 0.4),
              theme,
            ),
            const SizedBox(height: 12),
            
            // 認知課題パフォーマンス
            _buildPerformanceIndicator(
              '認知課題',
              _nbackAccuracy,
              theme,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceIndicator(
    String label,
    double value,
    ThemeData theme,
  ) {
    final color = value > 0.8 
        ? Colors.green 
        : (value > 0.6 ? Colors.orange : Colors.red);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              '${(value * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
  
  Widget _buildAlertsCard(ThemeData theme) {
    // アラート条件のチェック
    final alerts = <String>[];
    
    if (_currentCv > 0.1) {
      alerts.add('歩行の変動が大きくなっています');
    }
    if (_nbackAccuracy < 0.7) {
      alerts.add('N-back正答率が低下しています');
    }
    if (_currentSpm > 0 && (_currentSpm < 80 || _currentSpm > 140)) {
      alerts.add('歩行速度が通常範囲外です');
    }
    
    return Card(
      color: alerts.isEmpty 
          ? theme.colorScheme.surface
          : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  alerts.isEmpty ? Icons.check_circle : Icons.warning,
                  color: alerts.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'システムアラート',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (alerts.isEmpty)
              Text(
                '正常に動作しています',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.green,
                ),
              )
            else
              ...alerts.map((alert) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_right,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alert,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
  
  void _startExperiment() {
    _flowController.startExperiment(totalBlocks: 6);
    
    // デモ用のデータ更新タイマー
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentPhase == ExperimentPhase.completed ||
          _currentPhase == ExperimentPhase.aborted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        // ダミーデータの更新
        _currentSpm = 95 + (DateTime.now().second % 20).toDouble();
        _currentCv = 0.03 + (DateTime.now().second % 10) * 0.01;
        _nbackAccuracy = 0.7 + (DateTime.now().second % 30) * 0.01;
        _rmsePhi = 0.02 + (DateTime.now().second % 15) * 0.005;
      });
    });
  }
  
  void _pauseExperiment() {
    // TODO: 一時停止処理
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('一時停止機能は実装予定です')),
    );
  }
  
  void _showEmergencyStopDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('緊急停止'),
        content: const Text('実験を緊急停止しますか？\n保存されていないデータは失われる可能性があります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              _flowController.abortExperiment();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('緊急停止'),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }
}