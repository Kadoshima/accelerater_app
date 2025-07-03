import 'package:flutter/material.dart';

/// NASA-TLX（Task Load Index）評価画面
class NasaTlxEvaluation extends StatefulWidget {
  final Function(NasaTlxResult) onComplete;
  
  const NasaTlxEvaluation({
    Key? key,
    required this.onComplete,
  }) : super(key: key);
  
  @override
  State<NasaTlxEvaluation> createState() => _NasaTlxEvaluationState();
}

class _NasaTlxEvaluationState extends State<NasaTlxEvaluation> {
  final Map<NasaTlxDimension, double> _scores = {
    NasaTlxDimension.mentalDemand: 50,
    NasaTlxDimension.physicalDemand: 50,
    NasaTlxDimension.temporalDemand: 50,
    NasaTlxDimension.performance: 50,
    NasaTlxDimension.effort: 50,
    NasaTlxDimension.frustration: 50,
  };
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NASA-TLX 評価'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '実験タスクの負荷を評価してください',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '各項目について、0（非常に低い）から100（非常に高い）の範囲で評価してください。',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ...NasaTlxDimension.values.map((dimension) => 
                    _buildDimensionSlider(dimension)
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '総合スコア:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _calculateOverallScore().toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitEvaluation,
                      child: const Text('評価を送信'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDimensionSlider(NasaTlxDimension dimension) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dimension.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dimension.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 50,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _scores[dimension]!.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('低い'),
              Expanded(
                child: Slider(
                  value: _scores[dimension]!,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _scores[dimension] = value;
                    });
                  },
                ),
              ),
              const Text('高い'),
            ],
          ),
        ],
      ),
    );
  }
  
  double _calculateOverallScore() {
    final sum = _scores.values.reduce((a, b) => a + b);
    return sum / _scores.length;
  }
  
  void _submitEvaluation() {
    final result = NasaTlxResult(
      timestamp: DateTime.now(),
      scores: Map.from(_scores),
      overallScore: _calculateOverallScore(),
    );
    
    widget.onComplete(result);
  }
}

/// NASA-TLXの評価次元
enum NasaTlxDimension {
  mentalDemand,
  physicalDemand,
  temporalDemand,
  performance,
  effort,
  frustration,
}

extension NasaTlxDimensionExt on NasaTlxDimension {
  String get title {
    switch (this) {
      case NasaTlxDimension.mentalDemand:
        return '精神的要求';
      case NasaTlxDimension.physicalDemand:
        return '身体的要求';
      case NasaTlxDimension.temporalDemand:
        return '時間的圧迫感';
      case NasaTlxDimension.performance:
        return 'タスク達成度';
      case NasaTlxDimension.effort:
        return '努力';
      case NasaTlxDimension.frustration:
        return 'フラストレーション';
    }
  }
  
  String get description {
    switch (this) {
      case NasaTlxDimension.mentalDemand:
        return '知覚、記憶、計算など、どの程度精神的・知的活動が必要でしたか？';
      case NasaTlxDimension.physicalDemand:
        return 'どの程度の身体的活動が必要でしたか？';
      case NasaTlxDimension.temporalDemand:
        return '時間的なプレッシャーをどの程度感じましたか？';
      case NasaTlxDimension.performance:
        return 'タスクの目標をどの程度達成できたと思いますか？';
      case NasaTlxDimension.effort:
        return 'タスクを遂行するためにどの程度努力しましたか？';
      case NasaTlxDimension.frustration:
        return 'タスク中にどの程度イライラ、ストレス、不快感を感じましたか？';
    }
  }
}

/// NASA-TLX評価結果
class NasaTlxResult {
  final DateTime timestamp;
  final Map<NasaTlxDimension, double> scores;
  final double overallScore;
  
  NasaTlxResult({
    required this.timestamp,
    required this.scores,
    required this.overallScore,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'mentalDemand': scores[NasaTlxDimension.mentalDemand],
      'physicalDemand': scores[NasaTlxDimension.physicalDemand],
      'temporalDemand': scores[NasaTlxDimension.temporalDemand],
      'performance': scores[NasaTlxDimension.performance],
      'effort': scores[NasaTlxDimension.effort],
      'frustration': scores[NasaTlxDimension.frustration],
      'overallScore': overallScore,
    };
  }
}