import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../models/experiment_models.dart';
import '../services/experiment_controller.dart';
import '../utils/responsive_helper.dart';

class TabletDashboard extends StatefulWidget {
  final ExperimentSession session;
  final ExperimentController controller;
  final List<FlSpot> spmSpots;
  final List<FlSpot> targetSpots;
  final double minY;
  final double maxY;
  final double maxX;

  const TabletDashboard({
    Key? key,
    required this.session,
    required this.controller,
    required this.spmSpots,
    required this.targetSpots,
    required this.minY,
    required this.maxY,
    required this.maxX,
  }) : super(key: key);

  @override
  State<TabletDashboard> createState() => _TabletDashboardState();
}

class _TabletDashboardState extends State<TabletDashboard> {
  // モック心拍数データ
  double mockHeartRate = 75.0;
  List<FlSpot> heartRateSpots = [];
  
  @override
  void initState() {
    super.initState();
    _generateMockHeartRate();
  }

  void _generateMockHeartRate() {
    // 歩行ピッチに連動した心拍数を生成
    final currentSpm = widget.controller.getCurrentSpm();
    final baseHR = 70.0;
    final variation = (currentSpm - 100) * 0.3; // SPMに応じて変動
    mockHeartRate = baseHR + variation + (math.Random().nextDouble() * 10 - 5);
    mockHeartRate = mockHeartRate.clamp(60, 150);
  }

  String _getAIAdvice() {
    final currentSpm = widget.controller.getCurrentSpm();
    final targetSpm = widget.session.targetSpm;
    final isStable = widget.controller.isStable();
    final phase = widget.session.currentPhase;

    // フェーズに応じたアドバイス
    if (phase == AdvancedExperimentPhase.preparation) {
      return "リラックスして自然な歩行を心がけてください。深呼吸をして準備を整えましょう。";
    }

    if (phase == AdvancedExperimentPhase.baseline) {
      return "普段通りの歩行ペースを維持してください。無理のない自然な動きが大切です。";
    }

    // 目標との差分に基づくアドバイス
    if (targetSpm > 0) {
      final difference = (currentSpm - targetSpm).abs();
      if (difference < 5) {
        return isStable 
          ? "素晴らしい！目標ペースを安定して維持できています。この調子で続けましょう。" 
          : "良いペースです。もう少しで安定します。リズムを意識して歩きましょう。";
      } else if (currentSpm < targetSpm) {
        return "少しペースが遅めです。足の回転を意識して、軽やかに歩いてみましょう。腕の振りも活用すると良いでしょう。";
      } else {
        return "ペースが速すぎます。呼吸を整えて、リラックスして歩きましょう。メトロノームの音に合わせてみてください。";
      }
    }

    return "自分のペースで歩行を続けてください。姿勢を正しく保ち、前を向いて歩きましょう。";
  }

  @override
  Widget build(BuildContext context) {
    final phaseInfo = widget.session.getPhaseInfo();
    final currentSpm = widget.controller.getCurrentSpm();
    final isStable = widget.controller.isStable();
    final stableSeconds = widget.controller.getStableSeconds();
    final remainingSeconds = widget.session.getRemainingSeconds();
    final progress = widget.session.getPhaseProgress();

    _generateMockHeartRate(); // 心拍数を更新

    return Container(
      color: Colors.grey[100],
      child: Row(
        children: [
          // 左側：メトリクスと詳細情報
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // 上段：主要メトリクス
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      // 歩行ピッチカード
                      Expanded(
                        child: _buildMetricCard(
                          title: '歩行ピッチ',
                          value: currentSpm.toStringAsFixed(1),
                          unit: 'SPM',
                          icon: Icons.directions_walk,
                          color: Colors.blue,
                          subtitle: widget.session.targetSpm > 0 
                            ? '目標: ${widget.session.targetSpm.toStringAsFixed(1)} SPM'
                            : 'フリーウォーキング',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 心拍数カード
                      Expanded(
                        child: _buildMetricCard(
                          title: '心拍数',
                          value: mockHeartRate.toStringAsFixed(0),
                          unit: 'BPM',
                          icon: Icons.favorite,
                          color: Colors.red,
                          subtitle: _getHeartRateZone(mockHeartRate),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 中段：歩行詳細
                Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '歩行詳細',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildPhaseIndicator(phaseInfo, remainingSeconds),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              children: [
                                // 左側：数値データ
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildDetailRow('安定性', isStable ? '安定' : '調整中', 
                                        isStable ? Colors.green : Colors.orange),
                                      _buildDetailRow('安定時間', '$stableSeconds秒', Colors.blue),
                                      _buildDetailRow('ベースライン', 
                                        widget.session.baselineSpm > 0 
                                          ? '${widget.session.baselineSpm.toStringAsFixed(1)} SPM' 
                                          : '計測中', 
                                        Colors.purple),
                                      _buildDetailRow('追従率', 
                                        widget.session.followRate > 0 
                                          ? '${widget.session.followRate.toStringAsFixed(1)}%' 
                                          : 'N/A', 
                                        _getFollowRateColor(widget.session.followRate)),
                                    ],
                                  ),
                                ),
                                // 右側：進捗バー
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('フェーズ進捗', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            height: 120,
                                            width: 120,
                                            child: CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 12,
                                              backgroundColor: Colors.grey[300],
                                              color: phaseInfo.color,
                                            ),
                                          ),
                                          Text(
                                            '${(progress * 100).toInt()}%',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 下段：AIアドバイス
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.all(8),
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'AIアドバイス',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Center(
                              child: Text(
                                _getAIAdvice(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue[900],
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 右側：グラフ
          Expanded(
            flex: 4,
            child: Card(
              elevation: 2,
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '歩行ピッチ推移',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildChart(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator(dynamic phaseInfo, int remainingSeconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: phaseInfo.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(phaseInfo.icon, size: 16, color: phaseInfo.color),
          const SizedBox(width: 4),
          Text(
            '${phaseInfo.name} (${_formatDuration(Duration(seconds: remainingSeconds))})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: phaseInfo.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: widget.maxX,
        minY: widget.minY,
        maxY: widget.maxY,
        lineBarsData: [
          // 実測値
          LineChartBarData(
            spots: widget.spmSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
          // 目標値
          if (widget.targetSpots.isNotEmpty)
            LineChartBarData(
              spots: widget.targetSpots,
              isCurved: false,
              color: Colors.orange,
              barWidth: 2,
              isStrokeCapRound: true,
              dashArray: [5, 5],
              dotData: FlDotData(show: false),
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}分',
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  String _getHeartRateZone(double hr) {
    if (hr < 90) return 'リラックス';
    if (hr < 110) return '軽度運動';
    if (hr < 130) return '中強度運動';
    return '高強度運動';
  }

  Color _getFollowRateColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}