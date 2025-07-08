import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dual_task_experiment_screen.dart';

/// 二重課題プロトコルメニュー画面
class DualTaskMenuScreen extends ConsumerStatefulWidget {
  const DualTaskMenuScreen({Key? key}) : super(key: key);
  
  @override
  ConsumerState<DualTaskMenuScreen> createState() => _DualTaskMenuScreenState();
}

class _DualTaskMenuScreenState extends ConsumerState<DualTaskMenuScreen> {
  final _participantNumberController = TextEditingController();
  bool _isValidParticipant = false;
  
  @override
  void initState() {
    super.initState();
    _participantNumberController.addListener(_validateParticipant);
  }
  
  void _validateParticipant() {
    final text = _participantNumberController.text;
    setState(() {
      _isValidParticipant = text.isNotEmpty && 
          int.tryParse(text) != null &&
          int.parse(text) > 0;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('二重課題プロトコル'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ロゴ/アイコン
                Icon(
                  Icons.psychology_alt,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 32),
                
                // タイトル
                Text(
                  '可変難度・二重課題プロトコル',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // 説明
                Text(
                  '適応的リズム歩行支援と認知負荷の影響を評価する実験システム',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                // 被験者番号入力
                TextField(
                  controller: _participantNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '被験者番号',
                    hintText: '1-999',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 32),
                
                // 実験開始ボタン
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isValidParticipant ? _startExperiment : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('実験を開始'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // その他のオプション
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _showInstructions,
                      icon: const Icon(Icons.help_outline),
                      label: const Text('実験手順'),
                    ),
                    TextButton.icon(
                      onPressed: _showSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text('設定'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // 実験条件の概要
                Card(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '実験条件',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildConditionRow('テンポ制御:', '適応的 / 固定'),
                        _buildConditionRow('認知負荷:', '0-back / 1-back / 2-back'),
                        _buildConditionRow('総条件数:', '6条件'),
                        _buildConditionRow('実験時間:', '約90分'),
                      ],
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
  
  Widget _buildConditionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  void _startExperiment() {
    final participantNumber = int.parse(_participantNumberController.text);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DualTaskExperimentScreen(
          participantNumber: participantNumber,
        ),
      ),
    );
  }
  
  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('実験手順'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. センサーを装着'),
              Text('2. キャリブレーション実施'),
              Text('3. 練習セッション（10分）'),
              Text('4. 本実験（6条件×6分）'),
              Text('5. 条件間休憩（3分）'),
              SizedBox(height: 16),
              Text('各条件では：'),
              Text('• ベースライン歩行（1分）'),
              Text('• リズム同期（2分）'),
              Text('• チャレンジフェーズ（2分）'),
              Text('• 安定観察（30秒）'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
  
  void _showSettings() {
    // TODO: 設定画面の実装
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('設定画面は実装予定です'),
      ),
    );
  }
  
  @override
  void dispose() {
    _participantNumberController.dispose();
    super.dispose();
  }
}