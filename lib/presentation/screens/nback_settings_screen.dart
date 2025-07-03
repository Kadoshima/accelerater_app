import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/nback_models.dart';

/// N-back設定画面
class NBackSettingsScreen extends ConsumerStatefulWidget {
  const NBackSettingsScreen({Key? key}) : super(key: key);
  
  @override
  ConsumerState<NBackSettingsScreen> createState() => _NBackSettingsScreenState();
}

class _NBackSettingsScreenState extends ConsumerState<NBackSettingsScreen> {
  // 設定値
  int _nLevel = 1;
  int _sequenceLength = 30;
  double _intervalSeconds = 2.0;
  String _language = 'ja-JP';
  double _speechRate = 1.0;
  bool _enableVoiceInput = false;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('N-back課題設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'デフォルトに戻す',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本設定セクション
            _buildSectionTitle('基本設定', theme),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildNLevelSelector(theme),
                    const Divider(height: 32),
                    _buildSequenceLengthSlider(theme),
                    const Divider(height: 32),
                    _buildIntervalSlider(theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 音声設定セクション
            _buildSectionTitle('音声設定', theme),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildLanguageSelector(theme),
                    const Divider(height: 32),
                    _buildSpeechRateSlider(theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 入力設定セクション
            _buildSectionTitle('入力設定', theme),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildVoiceInputSwitch(theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // 開始ボタン
            Center(
              child: ElevatedButton.icon(
                onPressed: _startNBackTask,
                icon: const Icon(Icons.play_arrow),
                label: const Text('N-back課題を開始'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
  
  Widget _buildNLevelSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'N-backレベル',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          _getNLevelDescription(_nLevel),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('0-back'),
              icon: Icon(Icons.looks_one),
            ),
            ButtonSegment(
              value: 1,
              label: Text('1-back'),
              icon: Icon(Icons.looks_two),
            ),
            ButtonSegment(
              value: 2,
              label: Text('2-back'),
              icon: Icon(Icons.looks_3),
            ),
          ],
          selected: {_nLevel},
          onSelectionChanged: (Set<int> selection) {
            setState(() {
              _nLevel = selection.first;
            });
          },
        ),
      ],
    );
  }
  
  String _getNLevelDescription(int level) {
    switch (level) {
      case 0:
        return '最初に表示された数字と同じ数字を見つける課題です（最も簡単）';
      case 1:
        return '1つ前に表示された数字と同じ数字を見つける課題です（標準的な難易度）';
      case 2:
        return '2つ前に表示された数字と同じ数字を見つける課題です（高難度）';
      default:
        return '';
    }
  }
  
  Widget _buildSequenceLengthSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '数字列の長さ',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '$_sequenceLength 個',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '課題の総時間: ${(_sequenceLength * _intervalSeconds).toStringAsFixed(0)}秒',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _sequenceLength.toDouble(),
          min: 10,
          max: 60,
          divisions: 10,
          label: _sequenceLength.toString(),
          onChanged: (value) {
            setState(() {
              _sequenceLength = value.toInt();
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildIntervalSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '数字表示間隔',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '${_intervalSeconds.toStringAsFixed(1)} 秒',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '数字が表示される間隔です',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _intervalSeconds,
          min: 1.0,
          max: 4.0,
          divisions: 6,
          label: '${_intervalSeconds.toStringAsFixed(1)}秒',
          onChanged: (value) {
            setState(() {
              _intervalSeconds = value;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildLanguageSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '読み上げ言語',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'ja-JP',
              label: Text('日本語'),
              icon: Icon(Icons.translate),
            ),
            ButtonSegment(
              value: 'en-US',
              label: Text('English'),
              icon: Icon(Icons.language),
            ),
          ],
          selected: {_language},
          onSelectionChanged: (Set<String> selection) {
            setState(() {
              _language = selection.first;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildSpeechRateSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '読み上げ速度',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '${(_speechRate * 100).toInt()}%',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _speechRate,
          min: 0.5,
          max: 1.5,
          divisions: 10,
          label: '${(_speechRate * 100).toInt()}%',
          onChanged: (value) {
            setState(() {
              _speechRate = value;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildVoiceInputSwitch(ThemeData theme) {
    return SwitchListTile(
      title: Text(
        '音声入力を使用',
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        _enableVoiceInput 
            ? '音声で数字を回答できます' 
            : 'ボタンタップで回答します',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: _enableVoiceInput,
      onChanged: (value) {
        setState(() {
          _enableVoiceInput = value;
        });
      },
    );
  }
  
  void _resetToDefaults() {
    setState(() {
      _nLevel = 1;
      _sequenceLength = 30;
      _intervalSeconds = 2.0;
      _language = 'ja-JP';
      _speechRate = 1.0;
      _enableVoiceInput = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('設定をデフォルトに戻しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _startNBackTask() {
    final config = NBackConfig(
      nLevel: _nLevel,
      sequenceLength: _sequenceLength,
      intervalMs: (_intervalSeconds * 1000).toInt(),
      language: _language,
      speechRate: _speechRate,
    );
    
    // TODO: N-back実行画面に遷移
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => NBackExecutionScreen(
    //       config: config,
    //       useVoiceInput: _enableVoiceInput,
    //     ),
    //   ),
    // );
  }
}