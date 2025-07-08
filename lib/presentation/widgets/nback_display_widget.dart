import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/nback_models.dart';

/// N-back課題表示ウィジェット
class NBackDisplayWidget extends ConsumerStatefulWidget {
  final NBackConfig config;
  final int currentDigit;
  final int? currentIndex;
  final int totalDigits;
  final bool showFeedback;
  final bool? isCorrect;
  final Function(int)? onDigitInput;
  
  const NBackDisplayWidget({
    Key? key,
    required this.config,
    required this.currentDigit,
    this.currentIndex,
    required this.totalDigits,
    this.showFeedback = false,
    this.isCorrect,
    this.onDigitInput,
  }) : super(key: key);
  
  @override
  ConsumerState<NBackDisplayWidget> createState() => _NBackDisplayWidgetState();
}

class _NBackDisplayWidgetState extends ConsumerState<NBackDisplayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
  }
  
  @override
  void didUpdateWidget(NBackDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDigit != widget.currentDigit) {
      _animationController.forward(from: 0);
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(
          minWidth: 300,
          minHeight: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // タスク情報
            _buildTaskInfo(theme),
            const SizedBox(height: 32),
            
            // 数字表示エリア
            _buildDigitDisplay(theme),
            const SizedBox(height: 32),
            
            // フィードバック表示
            if (widget.showFeedback) _buildFeedback(theme),
            const SizedBox(height: 24),
            
            // 進行状況バー
            _buildProgressBar(theme),
            const SizedBox(height: 32),
            
            // 入力ボタングリッド
            if (widget.onDigitInput != null) _buildInputGrid(theme),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTaskInfo(ThemeData theme) {
    String taskName;
    String instruction;
    
    switch (widget.config.nLevel) {
      case 0:
        taskName = '0-back Task';
        instruction = '最初の数字と同じ数字が表示されたらボタンを押してください';
        break;
      case 1:
        taskName = '1-back Task';
        instruction = '1つ前と同じ数字が表示されたらボタンを押してください';
        break;
      case 2:
        taskName = '2-back Task';
        instruction = '2つ前と同じ数字が表示されたらボタンを押してください';
        break;
      default:
        taskName = 'N-back Task';
        instruction = '';
    }
    
    return Column(
      children: [
        Text(
          taskName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          instruction,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildDigitDisplay(ThemeData theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.currentDigit.toString(),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFeedback(ThemeData theme) {
    if (widget.isCorrect == null) return const SizedBox.shrink();
    
    final isCorrect = widget.isCorrect!;
    final color = isCorrect ? Colors.green : Colors.red;
    final icon = isCorrect ? Icons.check_circle : Icons.cancel;
    final text = isCorrect ? '正解！' : '不正解';
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressBar(ThemeData theme) {
    final progress = widget.currentIndex != null && widget.totalDigits > 0
        ? (widget.currentIndex! + 1) / widget.totalDigits
        : 0.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '進行状況',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              '${widget.currentIndex != null ? widget.currentIndex! + 1 : 0} / ${widget.totalDigits}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInputGrid(ThemeData theme) {
    return Column(
      children: [
        Text(
          'あなたの回答：',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final digit = index + 1;
            return _DigitButton(
              digit: digit,
              onPressed: () => widget.onDigitInput?.call(digit),
            );
          },
        ),
      ],
    );
  }
}

/// 数字入力ボタン
class _DigitButton extends StatelessWidget {
  final int digit;
  final VoidCallback onPressed;
  
  const _DigitButton({
    Key? key,
    required this.digit,
    required this.onPressed,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              digit.toString(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}