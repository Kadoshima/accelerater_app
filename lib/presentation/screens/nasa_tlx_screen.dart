import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// NASA-TLX（Task Load Index）入力画面
class NasaTlxScreen extends ConsumerStatefulWidget {
  final String conditionId;
  final Function(Map<String, double>)? onComplete;
  
  const NasaTlxScreen({
    Key? key,
    required this.conditionId,
    this.onComplete,
  }) : super(key: key);
  
  @override
  ConsumerState<NasaTlxScreen> createState() => _NasaTlxScreenState();
}

class _NasaTlxScreenState extends ConsumerState<NasaTlxScreen> {
  // NASA-TLXの6つの評価項目
  final Map<String, double> _ratings = {
    'mental_demand': 50.0,     // 精神的要求
    'physical_demand': 50.0,   // 身体的要求
    'temporal_demand': 50.0,   // 時間的圧迫感
    'performance': 50.0,       // 作業成績
    'effort': 50.0,           // 努力
    'frustration': 50.0,      // フラストレーション
  };
  
  // 項目の説明
  final Map<String, Map<String, String>> _itemDescriptions = {
    'mental_demand': {
      'title': '精神的要求',
      'subtitle': 'Mental Demand',
      'low': '低い',
      'high': '高い',
      'description': 'どの程度の精神的・知覚的活動（考える、決める、計算する、記憶する、見る、探すなど）が必要でしたか？',
    },
    'physical_demand': {
      'title': '身体的要求',
      'subtitle': 'Physical Demand',
      'low': '低い',
      'high': '高い',
      'description': 'どの程度の身体的活動（押す、引く、回す、制御する、動き回るなど）が必要でしたか？',
    },
    'temporal_demand': {
      'title': '時間的圧迫感',
      'subtitle': 'Temporal Demand',
      'low': '低い',
      'high': '高い',
      'description': '仕事のペースや課題が発生する頻度のために、どの程度の時間的圧迫感を感じましたか？',
    },
    'performance': {
      'title': '作業成績',
      'subtitle': 'Performance',
      'low': '良い',
      'high': '悪い',
      'description': '作業の目標を達成することにおいて、どの程度成功したと思いますか？',
    },
    'effort': {
      'title': '努力',
      'subtitle': 'Effort',
      'low': '低い',
      'high': '高い',
      'description': '作業成績のレベルを達成・維持するために、どの程度一生懸命に作業しなければなりませんでしたか？',
    },
    'frustration': {
      'title': 'フラストレーション',
      'subtitle': 'Frustration',
      'low': '低い',
      'high': '高い',
      'description': '作業中、どの程度イライラ、ストレス、悩み、苛立ちを感じましたか？',
    },
  };
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('作業負荷評価'),
        actions: [
          TextButton(
            onPressed: _isAllRated() ? _submitRatings : null,
            child: Text(
              '完了',
              style: TextStyle(
                color: _isAllRated() 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー情報
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NASA-TLX評価',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '条件: ${widget.conditionId}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '各項目について、あなたの主観的な評価をスライダーで選択してください。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 評価項目
            ..._ratings.keys.map((key) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildRatingItem(key, theme),
            )),
            
            const SizedBox(height: 32),
            
            // 送信ボタン
            Center(
              child: ElevatedButton.icon(
                onPressed: _isAllRated() ? _submitRatings : null,
                icon: const Icon(Icons.check),
                label: const Text('評価を送信'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRatingItem(String key, ThemeData theme) {
    final description = _itemDescriptions[key]!;
    final value = _ratings[key]!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description['title']!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description['subtitle']!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 現在の値
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value.toInt().toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 説明
            Text(
              description['description']!,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            
            // スライダー
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (newValue) {
                      setState(() {
                        _ratings[key] = newValue;
                      });
                    },
                  ),
                ),
                // ラベル
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        description['low']!,
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        description['high']!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // スケール表示
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final scaleValue = index * 25;
                return Text(
                  scaleValue.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
  
  bool _isAllRated() {
    // すべての項目が初期値（50）から変更されているかチェック
    return _ratings.values.any((value) => value != 50.0);
  }
  
  void _submitRatings() {
    // 評価結果をコールバックで返す
    widget.onComplete?.call(Map.from(_ratings));
    
    // 完了メッセージ
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('評価を送信しました'),
        backgroundColor: Colors.green,
      ),
    );
    
    // 画面を閉じる
    Navigator.of(context).pop();
  }
}