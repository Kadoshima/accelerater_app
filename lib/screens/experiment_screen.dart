import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../models/experiment_models.dart';
import '../services/experiment_controller.dart';
import '../utils/gait_analysis_service.dart';
import '../services/metronome.dart';
import '../services/native_metronome.dart';

class ExperimentScreen extends StatefulWidget {
  final GaitAnalysisService gaitAnalysisService;
  final Metronome metronome;
  final NativeMetronome nativeMetronome;
  final bool useNativeMetronome;

  const ExperimentScreen({
    Key? key,
    required this.gaitAnalysisService,
    required this.metronome,
    required this.nativeMetronome,
    this.useNativeMetronome = true,
  }) : super(key: key);

  @override
  State<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends State<ExperimentScreen> {
  late final ExperimentController _experimentController;

  // UIコントロール状態
  bool _isConfiguring = true; // 実験設定中（初期状態）
  bool _isRunning = false; // 実験実行中
  String _statusMessage = '実験を設定してください';

  // 実験設定
  ExperimentCondition _selectedCondition = ExperimentCondition.conditionA;
  String _subjectId = '';
  final Map<String, dynamic> _subjectData = {};
  InductionVariation _inductionVariation = InductionVariation.increasing;

  // 誘導フェーズ設定
  double _inductionStepPercent = 5.0; // %
  int _inductionStepCount = 4;

  // フェーズごとの所要時間（分）
  final Map<AdvancedExperimentPhase, double> _phaseDurationMinutes = {
    AdvancedExperimentPhase.preparation: 5,
    AdvancedExperimentPhase.baseline: 5,
    AdvancedExperimentPhase.adaptation: 2,
    AdvancedExperimentPhase.induction: 10,
    AdvancedExperimentPhase.postEffect: 5,
    AdvancedExperimentPhase.evaluation: 2,
  };

  // グラフデータ
  final List<FlSpot> _spmSpots = [];
  final List<FlSpot> _targetSpots = [];
  double _minY = 40.0;
  double _maxY = 160.0;
  double _maxX = 60.0;

  // アンケート回答
  int _fatigueLevel = 3;
  int _concentrationLevel = 3;
  int _awarenessLevel = 3;
  String _comments = '';

  @override
  void initState() {
    super.initState();

    // ExperimentControllerの初期化
    _experimentController = ExperimentController(
      gaitAnalysisService: widget.gaitAnalysisService,
      metronome: widget.metronome,
      nativeMetronome: widget.nativeMetronome,
      useNativeMetronome: widget.useNativeMetronome,
      onMessage: _handleMessage,
      onSessionComplete: _handleSessionComplete,
      onPhaseChange: _handlePhaseChange,
      onDataRecorded: _handleDataRecorded,
    );
  }

  @override
  void dispose() {
    _experimentController.dispose();
    super.dispose();
  }

  // メッセージハンドラー
  void _handleMessage(String message) {
    setState(() {
      _statusMessage = message;
    });

    // スナックバーで通知
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // セッション完了ハンドラー
  void _handleSessionComplete(ExperimentSession session) {
    setState(() {
      _isRunning = false;
      _isConfiguring = true;
      _statusMessage = '実験が完了しました';
    });
  }

  // フェーズ変更ハンドラー
  void _handlePhaseChange(
      ExperimentSession session, AdvancedExperimentPhase phase) {
    setState(() {
      // フェーズに応じたUI更新
      if (phase == AdvancedExperimentPhase.evaluation) {
        _showEvaluationDialog();
      }
    });
  }

  // データ記録ハンドラー
  void _handleDataRecorded(
      ExperimentSession session, Map<String, dynamic> data) {
    setState(() {
      // グラフデータの更新
      final time = session.getElapsedSeconds() / 60.0; // X軸は分単位
      final currentSpm = data['currentSPM'] as double;
      final targetSpm = data['targetSPM'] as double;

      if (currentSpm > 0) {
        // 直近のポイントの更新か新規追加
        if (_spmSpots.isNotEmpty && _spmSpots.last.x >= time - 0.1) {
          _spmSpots[_spmSpots.length - 1] = FlSpot(time, currentSpm);
        } else {
          _spmSpots.add(FlSpot(time, currentSpm));
        }

        // 古いデータの削除（60分以上前）
        while (_spmSpots.isNotEmpty && time - _spmSpots.first.x > 60) {
          _spmSpots.removeAt(0);
        }

        // Y軸の範囲を調整
        if (currentSpm < _minY) _minY = math.max(40, currentSpm - 10);
        if (currentSpm > _maxY) _maxY = math.min(180, currentSpm + 10);
      }

      if (targetSpm > 0) {
        // 目標SPMの更新
        if (_targetSpots.isNotEmpty && _targetSpots.last.x >= time - 0.1) {
          _targetSpots[_targetSpots.length - 1] = FlSpot(time, targetSpm);
        } else {
          _targetSpots.add(FlSpot(time, targetSpm));
        }

        // 古いデータの削除（60分以上前）
        while (_targetSpots.isNotEmpty && time - _targetSpots.first.x > 60) {
          _targetSpots.removeAt(0);
        }
      }

      // X軸の範囲を調整
      _maxX = math.max(time + 1, 10.0);
    });
  }

  // 実験を開始
  void _startExperiment() async {
    if (_subjectId.isEmpty) {
      // 被験者IDが空の場合は日時を使用
      _subjectId = 'S${DateFormat('MMddHHmm').format(DateTime.now())}';
    }

    // カスタムフェーズ時間の設定
    final customPhaseDurations = <AdvancedExperimentPhase, Duration>{};
    _phaseDurationMinutes.forEach((phase, minutes) {
      customPhaseDurations[phase] = Duration(seconds: (minutes * 60).round());
    });

    // 実験を開始
    await _experimentController.startExperiment(
      condition: _selectedCondition,
      subjectId: _subjectId,
      subjectData: _subjectData,
      inductionVariation: _inductionVariation,
      customPhaseDurations: customPhaseDurations,
      inductionStepPercent: _inductionStepPercent / 100,
      inductionStepCount: _inductionStepCount,
    );

    setState(() {
      _isConfiguring = false;
      _isRunning = true;
      _spmSpots.clear();
      _targetSpots.clear();
    });
  }

  // 実験を停止
  void _stopExperiment() async {
    await _experimentController.stopExperiment();

    setState(() {
      _isRunning = false;
    });
  }

  // アンケート表示
  void _showEvaluationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('実験後アンケート'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('疲労度 (1:低い - 5:高い)'),
                    Slider(
                      value: _fatigueLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _fatigueLevel.toString(),
                      onChanged: (value) {
                        setDialogState(() {
                          _fatigueLevel = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('集中度 (1:低い - 5:高い)'),
                    Slider(
                      value: _concentrationLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _concentrationLevel.toString(),
                      onChanged: (value) {
                        setDialogState(() {
                          _concentrationLevel = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('音楽の聴こえ方・意識度 (1:低い - 5:高い)'),
                    Slider(
                      value: _awarenessLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _awarenessLevel.toString(),
                      onChanged: (value) {
                        setDialogState(() {
                          _awarenessLevel = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('その他コメント'),
                    TextField(
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '歩きやすさ、音の聞こえ方、実験中の感想など',
                      ),
                      onChanged: (value) {
                        _comments = value;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('保存'),
                  onPressed: () {
                    // 評価データを保存
                    _experimentController.setSubjectiveEvaluation(
                      SubjectiveEvaluation(
                        fatigueLevel: _fatigueLevel,
                        concentrationLevel: _concentrationLevel,
                        awarenessLevel: _awarenessLevel,
                        comments: _comments,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _experimentController.currentSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('歩行リズム誘導実験'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: _isConfiguring
          ? _buildConfigScreen()
          : _buildExperimentScreen(session),
      floatingActionButton: _isRunning
          ? FloatingActionButton(
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop),
              onPressed: _stopExperiment,
            )
          : null,
    );
  }

  // 設定画面
  Widget _buildConfigScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '実験設定',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // 被験者情報
          const Text(
            '被験者情報',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: '被験者ID',
              hintText: '例: S001 (空欄の場合は自動生成)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _subjectId = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // 実験条件選択
          const Text(
            '実験条件',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...ExperimentCondition.allConditions.map((condition) {
            return RadioListTile<ExperimentCondition>(
              title: Text(condition.name),
              subtitle: Text(condition.description),
              value: condition,
              groupValue: _selectedCondition,
              onChanged: (value) {
                setState(() {
                  _selectedCondition = value!;
                });
              },
            );
          }).toList(),

          const SizedBox(height: 16),

          // 誘導バリエーション
          const Text(
            '誘導バリエーション',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          RadioListTile<InductionVariation>(
            title: const Text('漸増条件 (ベースラインから+20%まで増加)'),
            value: InductionVariation.increasing,
            groupValue: _inductionVariation,
            onChanged: (value) {
              setState(() {
                _inductionVariation = value!;
              });
            },
          ),
          RadioListTile<InductionVariation>(
            title: const Text('漸減条件 (ベースラインから-20%まで減少)'),
            value: InductionVariation.decreasing,
            groupValue: _inductionVariation,
            onChanged: (value) {
              setState(() {
                _inductionVariation = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '誘導フェーズ設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ListTile(
            title: const Text('テンポ変化幅 (1ステップあたり%)'),
            subtitle:
                Text('${_inductionStepPercent.toStringAsFixed(1)}%'),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: _inductionStepPercent,
                min: 1,
                max: 20,
                divisions: 19,
                label: '${_inductionStepPercent.toStringAsFixed(1)}%',
                onChanged: (value) {
                  setState(() {
                    _inductionStepPercent = value;
                  });
                },
              ),
            ),
          ),

          ListTile(
            title: const Text('ステップ数'),
            subtitle: Text(_inductionStepCount.toString()),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: _inductionStepCount.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _inductionStepCount.toString(),
                onChanged: (value) {
                  setState(() {
                    _inductionStepCount = value.round();
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // フェーズ時間設定
          ExpansionTile(
            title: const Text('フェーズごとの所要時間',
                style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              ...AdvancedExperimentPhase.values.map((phase) {
                final phaseInfo = ExperimentPhaseInfo.phaseInfo[phase]!;
                return ListTile(
                  title: Text(phaseInfo.name),
                  subtitle:
                      Text(_phaseDurationMinutes[phase]!.toString() + '分'),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: _phaseDurationMinutes[phase]!,
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: _phaseDurationMinutes[phase]!.toString() + '分',
                      onChanged: (value) {
                        setState(() {
                          _phaseDurationMinutes[phase] = value;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ],
          ),

          const SizedBox(height: 24),

          // 開始ボタン
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: _startExperiment,
              child: const Text('実験を開始', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // 実験画面
  Widget _buildExperimentScreen(ExperimentSession? session) {
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final phaseInfo = session.getPhaseInfo();
    final currentSpm = _experimentController.getCurrentSpm();
    final isStable = _experimentController.isStable();
    final stableSeconds = _experimentController.getStableSeconds();
    final remainingSeconds = session.getRemainingSeconds();
    final progress = session.getPhaseProgress();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // フェーズ情報カード
          Card(
            color: phaseInfo.color,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(phaseInfo.icon, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        phaseInfo.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phaseInfo.description,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '残り時間: ${_formatDuration(Duration(seconds: remainingSeconds))}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 歩行データカード
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '歩行データ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isStable ? Icons.check_circle : Icons.pending,
                            color: isStable ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isStable ? '安定中 ($stableSeconds秒)' : '適応中',
                            style: TextStyle(
                              color: isStable ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDataColumn(
                        '現在の歩行ピッチ',
                        '${currentSpm.toStringAsFixed(1)} SPM',
                        Icons.directions_walk,
                        Colors.blue,
                      ),
                      if (session.targetSpm > 0)
                        _buildDataColumn(
                          '目標ピッチ',
                          '${session.targetSpm.toStringAsFixed(1)} SPM',
                          Icons.track_changes,
                          Colors.orange,
                        ),
                      if (session.condition.useMetronome)
                        _buildDataColumn(
                          'メトロノーム',
                          '${_experimentController.currentTempo.toStringAsFixed(1)} BPM',
                          Icons.music_note,
                          Colors.purple,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (session.baselineSpm > 0)
                    Text(
                      'ベースライン: ${session.baselineSpm.toStringAsFixed(1)} SPM',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (session.followRate > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '追従率: ${session.followRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: session.followRate / 100,
                          backgroundColor: Colors.grey.shade200,
                          color: _getFollowRateColor(session.followRate),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // SPMグラフ
          Expanded(
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '歩行ピッチの推移',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _buildSpmChart(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 手動進行ボタン（デバッグ用、リリース時には削除）
          if (false) // デバッグフラグ
            TextButton(
              onPressed: () {
                _experimentController.advanceToNextPhase();
              },
              child: const Text('次のフェーズへ（デバッグ用）'),
            ),
        ],
      ),
    );
  }

  // データカラムを構築
  Widget _buildDataColumn(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // SPMグラフを構築
  Widget _buildSpmChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _maxX,
        minY: _minY,
        maxY: _maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black87, width: 1),
        ),
        lineBarsData: [
          // 現在のSPM
          LineChartBarData(
            spots: _spmSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          // 目標SPM
          LineChartBarData(
            spots: _targetSpots,
            isCurved: false,
            color: Colors.orange,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            dashArray: [5, 5], // 点線表示
          ),
        ],
      ),
    );
  }

  // ヘルプダイアログを表示
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('実験の概要'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '本実験は歩行リズムと音楽テンポの関係を調査するものです。',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('【実験の流れ】'),
                Text('1. 準備・キャリブレーション: センサーの準備と実験説明'),
                Text('2. ベースライン測定: 通常のペースで自由に歩行'),
                Text('3. 適応フェーズ: 歩行リズムを音に合わせる練習'),
                Text('4. 誘導フェーズ: 徐々に変化するテンポに適応'),
                Text('5. 後効果測定: 音が止まった後の歩行リズムを測定'),
                Text('6. 事後評価: アンケートに回答'),
                SizedBox(height: 8),
                Text('【注意事項】'),
                Text('・実験中は安全に歩行してください'),
                Text('・各フェーズの指示に従ってください'),
                Text('・途中で休憩が必要な場合は申し出てください'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 残り時間のフォーマット
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // 追従率の色を取得
  Color _getFollowRateColor(double rate) {
    if (rate >= 95) return Colors.green;
    if (rate >= 85) return Colors.lightGreen;
    if (rate >= 75) return Colors.yellow;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }
}
