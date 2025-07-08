import 'package:flutter/material.dart';
import 'dart:async';

/// 休憩画面
class RestScreen extends StatefulWidget {
  final Duration restDuration;
  final VoidCallback? onRestComplete;
  final int completedBlocks;
  final int totalBlocks;
  
  const RestScreen({
    Key? key,
    required this.restDuration,
    this.onRestComplete,
    required this.completedBlocks,
    required this.totalBlocks,
  }) : super(key: key);
  
  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _breathAnimation;
  Timer? _timer;
  late Duration _remainingTime;
  
  @override
  void initState() {
    super.initState();
    _remainingTime = widget.restDuration;
    
    // 呼吸アニメーション
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _breathAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // カウントダウンタイマー
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime = Duration(
          seconds: _remainingTime.inSeconds - 1,
        );
        
        if (_remainingTime.inSeconds <= 0) {
          timer.cancel();
          widget.onRestComplete?.call();
        }
      });
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // タイトル
                Text(
                  '休憩時間',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                
                // 呼吸サークル
                AnimatedBuilder(
                  animation: _breathAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _breathAnimation.value,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.3),
                              theme.colorScheme.primary.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withOpacity(0.2),
                            ),
                            child: Center(
                              child: Text(
                                _formatTime(_remainingTime),
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                
                // 呼吸ガイド
                Text(
                  _getBreathingGuide(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 64),
                
                // 進行状況
                _buildProgressInfo(theme),
                const SizedBox(height: 32),
                
                // ヒント
                _buildRestTips(theme),
                
                const Spacer(),
                
                // スキップボタン（残り時間が少ない場合のみ）
                if (_remainingTime.inSeconds <= 30)
                  TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      widget.onRestComplete?.call();
                    },
                    child: Text(
                      '休憩を終了',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProgressInfo(ThemeData theme) {
    final progress = widget.completedBlocks / widget.totalBlocks;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '実験進行状況',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          
          // プログレスバー
          Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 20,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            '${widget.completedBlocks} / ${widget.totalBlocks} ブロック完了',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRestTips(ThemeData theme) {
    final tips = [
      '深呼吸をして、リラックスしましょう',
      '水分補給をお忘れなく',
      'ストレッチで筋肉をほぐしましょう',
      '次のブロックに向けて集中力を整えましょう',
    ];
    
    final currentTip = tips[widget.completedBlocks % tips.length];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentTip,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String _getBreathingGuide() {
    final phase = (_animationController.value * 2).floor();
    return phase == 0 ? '息を吸って...' : '息を吐いて...';
  }
}