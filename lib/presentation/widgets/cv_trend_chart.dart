import 'package:flutter/material.dart';
import 'dart:math' as math;

/// CV値のトレンドを表示するチャート
class CvTrendChart extends StatelessWidget {
  final List<double> cvValues;
  final double targetCv;
  final int maxDataPoints;
  final double height;

  const CvTrendChart({
    Key? key,
    required this.cvValues,
    this.targetCv = 0.05,
    this.maxDataPoints = 60,
    this.height = 150,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: cvValues.isEmpty
          ? Center(
              child: Text(
                'データ収集中...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            )
          : CustomPaint(
              painter: _CvChartPainter(
                cvValues: cvValues.length > maxDataPoints
                    ? cvValues.sublist(cvValues.length - maxDataPoints)
                    : cvValues,
                targetCv: targetCv,
                color: theme.colorScheme.primary,
                targetColor: theme.colorScheme.tertiary,
                gridColor: theme.colorScheme.outline.withOpacity(0.1),
                textStyle: theme.textTheme.bodySmall!,
              ),
            ),
    );
  }
}

class _CvChartPainter extends CustomPainter {
  final List<double> cvValues;
  final double targetCv;
  final Color color;
  final Color targetColor;
  final Color gridColor;
  final TextStyle textStyle;

  _CvChartPainter({
    required this.cvValues,
    required this.targetCv,
    required this.color,
    required this.targetColor,
    required this.gridColor,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cvValues.isEmpty) return;

    const padding = EdgeInsets.all(20);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    // Y軸の範囲を計算
    final maxCv = math.max(cvValues.reduce(math.max) * 1.2, targetCv * 1.5);
    const minCv = 0.0;

    // グリッドを描画
    _drawGrid(canvas, chartRect, minCv, maxCv);

    // 目標ラインを描画
    _drawTargetLine(canvas, chartRect, minCv, maxCv);

    // CV値の推移を描画
    _drawCvLine(canvas, chartRect, minCv, maxCv);

    // 軸ラベルを描画
    _drawLabels(canvas, chartRect, minCv, maxCv);
  }

  void _drawGrid(Canvas canvas, Rect chartRect, double minCv, double maxCv) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // 横線（CV値）
    for (int i = 0; i <= 5; i++) {
      final y = chartRect.bottom - (i / 5) * chartRect.height;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        paint,
      );
    }

    // 縦線（時間）
    for (int i = 0; i <= 6; i++) {
      final x = chartRect.left + (i / 6) * chartRect.width;
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        paint,
      );
    }
  }

  void _drawTargetLine(Canvas canvas, Rect chartRect, double minCv, double maxCv) {
    final paint = Paint()
      ..color = targetColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final targetY = chartRect.bottom - 
        ((targetCv - minCv) / (maxCv - minCv)) * chartRect.height;

    final path = Path();
    for (double i = 0; i < chartRect.width; i += 5) {
      path.moveTo(chartRect.left + i, targetY);
      path.lineTo(chartRect.left + i + 3, targetY);
    }
    canvas.drawPath(path, paint);

    // ラベル
    final textPainter = TextPainter(
      text: TextSpan(
        text: '目標: ${(targetCv * 100).toStringAsFixed(1)}%',
        style: textStyle.copyWith(color: targetColor),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(chartRect.right - textPainter.width - 5, targetY - 15),
    );
  }

  void _drawCvLine(Canvas canvas, Rect chartRect, double minCv, double maxCv) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final pointSpacing = chartRect.width / (cvValues.length - 1);

    for (int i = 0; i < cvValues.length; i++) {
      final x = chartRect.left + i * pointSpacing;
      final y = chartRect.bottom - 
          ((cvValues[i] - minCv) / (maxCv - minCv)) * chartRect.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 最新値を強調
    if (cvValues.isNotEmpty) {
      final lastX = chartRect.right;
      final lastY = chartRect.bottom - 
          ((cvValues.last - minCv) / (maxCv - minCv)) * chartRect.height;

      canvas.drawCircle(
        Offset(lastX, lastY),
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // 最新値のラベル
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(cvValues.last * 100).toStringAsFixed(1)}%',
          style: textStyle.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(lastX - textPainter.width / 2, lastY - 20),
      );
    }
  }

  void _drawLabels(Canvas canvas, Rect chartRect, double minCv, double maxCv) {
    // Y軸ラベル（CV値）
    for (int i = 0; i <= 5; i++) {
      final cv = minCv + (i / 5) * (maxCv - minCv);
      final y = chartRect.bottom - (i / 5) * chartRect.height;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(cv * 100).toStringAsFixed(0)}%',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartRect.left - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // X軸ラベル（時間）
    final timeLabels = ['60秒前', '50秒', '40秒', '30秒', '20秒', '10秒', '現在'];
    for (int i = 0; i < timeLabels.length; i++) {
      final x = chartRect.left + (i / 6) * chartRect.width;

      final textPainter = TextPainter(
        text: TextSpan(
          text: timeLabels[i],
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartRect.bottom + 5),
      );
    }

    // タイトル
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'CV値の推移',
        style: textStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(
      canvas,
      Offset((chartRect.left + chartRect.right) / 2 - titlePainter.width / 2, 5),
    );
  }

  @override
  bool shouldRepaint(_CvChartPainter oldDelegate) {
    return cvValues != oldDelegate.cvValues ||
        targetCv != oldDelegate.targetCv ||
        color != oldDelegate.color;
  }
}