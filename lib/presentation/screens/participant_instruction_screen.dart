import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/experiment_flow_controller.dart';
import '../../models/nback_models.dart';
import '../widgets/nback_display_widget.dart';
import 'dart:async';

/// 被験者用指示画面
class ParticipantInstructionScreen extends ConsumerStatefulWidget {
  const ParticipantInstructionScreen({Key? key}) : super(key: key);
  
  @override
  ConsumerState<ParticipantInstructionScreen> createState() => 
      _ParticipantInstructionScreenState();
}

class _ParticipantInstructionScreenState 
    extends ConsumerState<ParticipantInstructionScreen>
    with SingleTickerProviderStateMixin {
  
  // アニメーション
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // パフォーマンスデータ
  double _nbackAccuracy = 0.0;
  final List<double> _accuracyHistory = [];
  Timer? _performanceUpdateTimer;
  
  // N-back表示用（デモ）
  int _currentDigit = 5;
  int _sequenceIndex = 0;
  
  // 警告表示
  bool _showAccuracyWarning = false;
  String _warningMessage = '';
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
    _startPerformanceMonitoring();
  }
  
  void _startPerformanceMonitoring() {
    // デモ用のパフォーマンスデータ更新
    _performanceUpdateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        setState(() {
          // ランダムな正答率を生成（デモ用）
          _nbackAccuracy = 0.6 + (DateTime.now().second % 40) * 0.01;
          _accuracyHistory.add(_nbackAccuracy);
          
          // 最新30件のみ保持
          if (_accuracyHistory.length > 30) {
            _accuracyHistory.removeAt(0);
          }
          
          // 警告チェック
          _checkPerformanceWarnings();
          
          // N-back数字を更新（デモ）
          _currentDigit = (DateTime.now().second % 9) + 1;
          _sequenceIndex++;
        });
      },
    );
  }
  
  void _checkPerformanceWarnings() {
    if (_nbackAccuracy < 0.7) {
      _showAccuracyWarning = true;
      _warningMessage = '正答率が低下しています。集中してください。';
    } else if (_nbackAccuracy > 0.9) {
      _showAccuracyWarning = true;
      _warningMessage = '素晴らしいパフォーマンスです！';
    } else {
      _showAccuracyWarning = false;
      _warningMessage = '';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 上部：指示表示エリア
                Expanded(
                  flex: 2,
                  child: _buildInstructionArea(theme),
                ),
                
                const SizedBox(height: 24),
                
                // 中央：タスク表示エリア
                Expanded(
                  flex: 3,
                  child: _buildTaskArea(theme, screenSize),
                ),
                
                const SizedBox(height: 24),
                
                // 下部：パフォーマンス表示
                Expanded(
                  flex: 1,
                  child: _buildPerformanceArea(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInstructionArea(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '実験フェーズ: チャレンジ',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'メトロノームのリズムに合わせて歩きながら、\n表示される数字を覚えてください',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // 現在のタスク情報
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '1-back課題実施中',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskArea(ThemeData theme, Size screenSize) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenSize.width > 600 ? 500 : double.infinity,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // N-back表示（簡易版）
            _buildSimpleNBackDisplay(theme),
            
            const SizedBox(height: 32),
            
            // 警告表示
            if (_showAccuracyWarning)
              _buildWarningBanner(theme),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSimpleNBackDisplay(ThemeData theme) {
    return Column(
      children: [
        // 数字表示
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Text(
                    _currentDigit.toString(),
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 簡易進行状況
        Text(
          '${_sequenceIndex + 1} / 30',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWarningBanner(ThemeData theme) {
    final isPositive = _nbackAccuracy > 0.9;
    final bannerColor = isPositive ? Colors.green : Colors.orange;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bannerColor,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPositive ? Icons.star : Icons.warning,
            color: bannerColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _warningMessage,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: bannerColor.shade800,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 正答率表示
          Expanded(
            child: _buildPerformanceMetric(
              'N-back正答率',
              '${(_nbackAccuracy * 100).toInt()}%',
              _nbackAccuracy,
              theme,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 1分間の平均
          Expanded(
            child: _buildPerformanceMetric(
              '1分間平均',
              '${(_calculateRollingAverage() * 100).toInt()}%',
              _calculateRollingAverage(),
              theme,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceMetric(
    String label,
    String value,
    double percentage,
    ThemeData theme,
  ) {
    final color = percentage > 0.8 
        ? Colors.green 
        : (percentage > 0.6 ? Colors.orange : Colors.red);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            // ミニグラフ
            _buildMiniSparkline(theme),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }
  
  Widget _buildMiniSparkline(ThemeData theme) {
    if (_accuracyHistory.length < 2) {
      return const SizedBox(width: 60, height: 30);
    }
    
    return Container(
      width: 60,
      height: 30,
      padding: const EdgeInsets.all(2),
      child: CustomPaint(
        painter: SparklinePainter(
          data: _accuracyHistory.length > 10 
              ? _accuracyHistory.sublist(_accuracyHistory.length - 10)
              : _accuracyHistory,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
  
  double _calculateRollingAverage() {
    if (_accuracyHistory.isEmpty) return 0.0;
    
    // 最新30件（約1分）の平均を計算
    final recentData = _accuracyHistory.length > 30
        ? _accuracyHistory.sublist(_accuracyHistory.length - 30)
        : _accuracyHistory;
    
    return recentData.reduce((a, b) => a + b) / recentData.length;
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _performanceUpdateTimer?.cancel();
    super.dispose();
  }
}

/// スパークライングラフの描画
class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  
  SparklinePainter({
    required this.data,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final xStep = size.width / (data.length - 1);
    
    // データの最小値と最大値を取得
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    
    // パスを描画
    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final normalizedValue = range > 0 
          ? (data[i] - minValue) / range 
          : 0.5;
      final y = size.height * (1 - normalizedValue);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}