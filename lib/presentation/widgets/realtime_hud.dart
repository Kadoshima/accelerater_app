import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/performance_monitor.dart';

/// リアルタイムHUD（ヘッドアップディスプレイ）
/// 実験中の主要メトリクスを表示
class RealtimeHUD extends StatefulWidget {
  final Stream<PerformanceUpdate> performanceStream;
  final Stream<Map<String, dynamic>>? gaitDataStream;
  final Stream<Map<String, dynamic>>? cognitiveDataStream;
  final bool compact;
  
  const RealtimeHUD({
    Key? key,
    required this.performanceStream,
    this.gaitDataStream,
    this.cognitiveDataStream,
    this.compact = false,
  }) : super(key: key);
  
  @override
  State<RealtimeHUD> createState() => _RealtimeHUDState();
}

class _RealtimeHUDState extends State<RealtimeHUD> {
  PerformanceUpdate? _lastPerformance;
  Map<String, dynamic>? _lastGaitData;
  Map<String, dynamic>? _lastCognitiveData;
  
  late StreamSubscription<PerformanceUpdate> _performanceSubscription;
  StreamSubscription<Map<String, dynamic>>? _gaitSubscription;
  StreamSubscription<Map<String, dynamic>>? _cognitiveSubscription;
  
  @override
  void initState() {
    super.initState();
    _performanceSubscription = widget.performanceStream.listen((update) {
      if (mounted) {
        setState(() {
          _lastPerformance = update;
        });
      }
    });
    
    if (widget.gaitDataStream != null) {
      _gaitSubscription = widget.gaitDataStream!.listen((data) {
        if (mounted) {
          setState(() {
            _lastGaitData = data;
          });
        }
      });
    }
    
    if (widget.cognitiveDataStream != null) {
      _cognitiveSubscription = widget.cognitiveDataStream!.listen((data) {
        if (mounted) {
          setState(() {
            _lastCognitiveData = data;
          });
        }
      });
    }
  }
  
  @override
  void dispose() {
    _performanceSubscription.cancel();
    _gaitSubscription?.cancel();
    _cognitiveSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactHUD();
    } else {
      return _buildFullHUD();
    }
  }
  
  Widget _buildCompactHUD() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactMetric(
            icon: Icons.directions_walk,
            value: _lastGaitData?['spm']?.toStringAsFixed(0) ?? '--',
            unit: 'SPM',
            color: Colors.blue,
          ),
          const SizedBox(width: 16),
          _buildCompactMetric(
            icon: Icons.psychology,
            value: _lastPerformance != null 
                ? '${(_lastPerformance!.nbackAccuracy * 100).toStringAsFixed(0)}%'
                : '--%',
            unit: '',
            color: Colors.green,
          ),
          const SizedBox(width: 16),
          _buildCompactMetric(
            icon: Icons.score,
            value: _lastPerformance?.overallScore.toStringAsFixed(0) ?? '--',
            unit: '',
            color: _getScoreColor(_lastPerformance?.overallScore ?? 0),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFullHUD() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'リアルタイムモニター',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // メトリクスグリッド
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildMetricCard(
                title: '歩行速度',
                value: _lastPerformance?.walkingSpeed.toStringAsFixed(2) ?? '--',
                unit: 'm/s',
                icon: Icons.speed,
                color: Colors.blue,
              ),
              _buildMetricCard(
                title: 'SPM',
                value: _lastGaitData?['spm']?.toStringAsFixed(0) ?? '--',
                unit: '',
                icon: Icons.directions_walk,
                color: Colors.teal,
              ),
              _buildMetricCard(
                title: '変動係数',
                value: _lastPerformance?.walkingCv.toStringAsFixed(3) ?? '--',
                unit: '',
                icon: Icons.show_chart,
                color: Colors.orange,
              ),
              _buildMetricCard(
                title: 'N-back精度',
                value: _lastPerformance != null 
                    ? '${(_lastPerformance!.nbackAccuracy * 100).toStringAsFixed(0)}%'
                    : '--%',
                unit: '',
                icon: Icons.psychology,
                color: Colors.green,
              ),
              _buildMetricCard(
                title: '反応時間',
                value: _lastPerformance?.nbackResponseTime.toString() ?? '--',
                unit: 'ms',
                icon: Icons.timer,
                color: Colors.purple,
              ),
              _buildMetricCard(
                title: '総合スコア',
                value: _lastPerformance?.overallScore.toStringAsFixed(0) ?? '--',
                unit: '/100',
                icon: Icons.score,
                color: _getScoreColor(_lastPerformance?.overallScore ?? 0),
              ),
            ],
          ),
          
          // 追加情報
          if (_lastGaitData != null || _lastCognitiveData != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (_lastGaitData?['stepCount'] != null)
                  _buildInfoItem(
                    label: 'ステップ数',
                    value: _lastGaitData!['stepCount'].toString(),
                  ),
                if (_lastGaitData?['confidence'] != null)
                  _buildInfoItem(
                    label: '信頼度',
                    value: '${(_lastGaitData!['confidence'] * 100).toStringAsFixed(0)}%',
                  ),
                if (_lastCognitiveData?['nLevel'] != null)
                  _buildInfoItem(
                    label: 'N-back',
                    value: '${_lastCognitiveData!['nLevel']}-back',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCompactMetric({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          '$value$unit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '$value$unit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
  
  Color _getStatusColor() {
    if (_lastPerformance == null) return Colors.grey;
    
    final score = _lastPerformance!.overallScore;
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
  
  String _getStatusText() {
    if (_lastPerformance == null) return '待機中';
    
    final score = _lastPerformance!.overallScore;
    if (score >= 70) return '良好';
    if (score >= 50) return '注意';
    return '警告';
  }
}

/// HUD設定
class HUDSettings {
  final bool showWalkingMetrics;
  final bool showCognitiveMetrics;
  final bool showOverallScore;
  final bool showAlerts;
  final double opacity;
  final HUDPosition position;
  
  const HUDSettings({
    this.showWalkingMetrics = true,
    this.showCognitiveMetrics = true,
    this.showOverallScore = true,
    this.showAlerts = true,
    this.opacity = 0.9,
    this.position = HUDPosition.topRight,
  });
}

enum HUDPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}