import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../models/experiment_models.dart';
import '../services/experiment_controller.dart';
import '../utils/gait_analysis_service.dart';
import '../services/metronome.dart';
import '../services/native_metronome.dart';
import '../utils/experiment_utils.dart';

// Design system imports
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_spacing.dart';
import '../presentation/widgets/common/app_card.dart';
import '../presentation/widgets/common/app_button.dart';
import '../presentation/widgets/common/app_text_field.dart';

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

class _ExperimentScreenState extends State<ExperimentScreen>
    with TickerProviderStateMixin {
  late final ExperimentController _experimentController;
  late final AnimationController _phaseTransitionController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // UIコントロール状態
  bool _isConfiguring = true;
  bool _isRunning = false;

  // 実験設定
  ExperimentCondition _selectedCondition = ExperimentCondition.conditionA;
  String _subjectId = '';
  final Map<String, dynamic> _subjectData = {};
  InductionVariation _inductionVariation = InductionVariation.increasing;
  
  // 新しい実験設定
  ExperimentType _experimentType = ExperimentType.traditional;
  bool _useAdaptiveControl = false;
  int _randomPhaseCount = 6;
  List<RandomPhaseInfo>? _randomPhaseSequence;

  // 誘導フェーズ設定
  double _inductionStepPercent = 5.0;
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
  final List<FlSpot> _heartRateSpots = [];
  double _minY = 40.0;
  double _maxY = 160.0;
  double _maxX = 60.0;

  // アンケート回答
  final int _fatigueLevel = 3;
  final int _concentrationLevel = 3;
  final int _awarenessLevel = 3;

  @override
  void initState() {
    super.initState();

    _phaseTransitionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

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
    _phaseTransitionController.dispose();
    _pulseController.dispose();
    _experimentController.dispose();
    super.dispose();
  }

  void _handleMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.bodyMedium),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }

  void _handleSessionComplete(ExperimentSession session) {
    setState(() {
      _isRunning = false;
      _isConfiguring = true;
    });
  }

  void _handlePhaseChange(
      ExperimentSession session, AdvancedExperimentPhase phase) {
    _phaseTransitionController.forward(from: 0);
    setState(() {
      if (phase == AdvancedExperimentPhase.evaluation) {
        _showEvaluationDialog();
      }
    });
  }

  void _handleDataRecorded(
      ExperimentSession session, Map<String, dynamic> data) {
    setState(() {
      final time = session.getElapsedSeconds() / 60.0;
      final currentSpm = data['currentSPM'] as double;
      final targetSpm = data['targetSPM'] as double;
      final heartRate = data['heartRate'] as double? ?? 0;

      if (currentSpm > 0) {
        if (_spmSpots.isNotEmpty && _spmSpots.last.x >= time - 0.1) {
          _spmSpots[_spmSpots.length - 1] = FlSpot(time, currentSpm);
        } else {
          _spmSpots.add(FlSpot(time, currentSpm));
        }
        while (_spmSpots.isNotEmpty && time - _spmSpots.first.x > 60) {
          _spmSpots.removeAt(0);
        }
        if (currentSpm < _minY) _minY = math.max(40, currentSpm - 10);
        if (currentSpm > _maxY) _maxY = math.min(180, currentSpm + 10);
      }

      if (targetSpm > 0) {
        if (_targetSpots.isNotEmpty && _targetSpots.last.x >= time - 0.1) {
          _targetSpots[_targetSpots.length - 1] = FlSpot(time, targetSpm);
        } else {
          _targetSpots.add(FlSpot(time, targetSpm));
        }
        while (_targetSpots.isNotEmpty && time - _targetSpots.first.x > 60) {
          _targetSpots.removeAt(0);
        }
      }

      if (heartRate > 0) {
        _heartRateSpots.add(FlSpot(time, heartRate));
        while (_heartRateSpots.isNotEmpty && time - _heartRateSpots.first.x > 60) {
          _heartRateSpots.removeAt(0);
        }
      }

      _maxX = math.max(time + 1, 10.0);
    });
  }

  void _startExperiment() async {
    if (_subjectId.isEmpty) {
      _subjectId = 'S${DateFormat('MMddHHmm').format(DateTime.now())}';
    }

    // 実験タイプに応じた設定
    ExperimentCondition condition = _selectedCondition;
    List<RandomPhaseInfo>? randomSequence;
    
    if (_experimentType == ExperimentType.randomOrder) {
      // ランダム実験の場合
      condition = ExperimentUtils.createReactionStudyCondition(
        useAdaptiveControl: _useAdaptiveControl,
      );
      
      // ランダムフェーズシーケンスを生成
      randomSequence = ExperimentUtils.generateRandomPhaseSequence(
        phaseCount: _randomPhaseCount,
        minPhaseDuration: const Duration(minutes: 1),
        maxPhaseDuration: const Duration(minutes: 3),
      );
      _randomPhaseSequence = randomSequence;
    } else {
      // 従来型の実験の場合、選択された条件に適応制御フラグを設定
      condition = ExperimentCondition(
        id: _selectedCondition.id,
        name: _selectedCondition.name,
        useMetronome: _selectedCondition.useMetronome,
        explicitInstruction: _selectedCondition.explicitInstruction,
        description: _selectedCondition.description,
        useAdaptiveControl: _useAdaptiveControl,
      );
    }

    final customPhaseDurations = <AdvancedExperimentPhase, Duration>{};
    _phaseDurationMinutes.forEach((phase, minutes) {
      customPhaseDurations[phase] = Duration(seconds: (minutes * 60).round());
    });

    await _experimentController.startExperiment(
      condition: condition,
      subjectId: _subjectId,
      subjectData: _subjectData,
      inductionVariation: _inductionVariation,
      customPhaseDurations: customPhaseDurations,
      inductionStepPercent: _inductionStepPercent / 100,
      inductionStepCount: _inductionStepCount,
      experimentType: _experimentType,
      randomPhaseSequence: randomSequence,
    );

    setState(() {
      _isConfiguring = false;
      _isRunning = true;
      _spmSpots.clear();
      _targetSpots.clear();
      _heartRateSpots.clear();
    });
  }

  void _stopExperiment() async {
    await _experimentController.stopExperiment();
    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _experimentController.currentSession;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          '歩行リズム誘導実験',
          style: AppTypography.headlineSmall,
        ),
        actions: [
          AppIconButton(
            icon: Icons.help_outline,
            onPressed: _showHelpDialog,
            tooltip: 'ヘルプ',
            iconColor: AppColors.textSecondary,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isConfiguring
            ? _buildConfigScreen()
            : _buildExperimentScreen(session),
      ),
      floatingActionButton: _isRunning
          ? _buildFloatingActionButton()
          : null,
    );
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: FloatingActionButton(
        backgroundColor: AppColors.error,
        onPressed: _stopExperiment,
        child: const Icon(Icons.stop, size: 28),
      ),
    );
  }

  Widget _buildConfigScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigHeader(),
          const SizedBox(height: AppSpacing.xl),
          _buildSubjectInfoSection(),
          const SizedBox(height: AppSpacing.xl),
          _buildExperimentTypeSection(),
          const SizedBox(height: AppSpacing.xl),
          if (_experimentType == ExperimentType.traditional) ...[
            _buildExperimentConditionSection(),
            const SizedBox(height: AppSpacing.xl),
            _buildInductionVariationSection(),
            const SizedBox(height: AppSpacing.xl),
            _buildInductionPhaseSection(),
            const SizedBox(height: AppSpacing.xl),
            _buildPhaseDurationSection(),
          ] else ...[
            _buildRandomExperimentSection(),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildAdaptiveControlSection(),
          const SizedBox(height: AppSpacing.xxxl),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildConfigHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '実験設定',
          style: AppTypography.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '実験条件を設定してください',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectInfoSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.person_outline,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '被験者情報',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: '被験者ID',
            hint: '例: S001 (空欄の場合は自動生成)',
            prefixIcon: Icons.badge_outlined,
            onChanged: (value) {
              setState(() {
                _subjectId = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentTypeSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.category_outlined,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '実験タイプ',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ExperimentTypeCard(
                  title: '従来型実験',
                  subtitle: '順序固定・個別対応',
                  icon: Icons.timeline,
                  isSelected: _experimentType == ExperimentType.traditional,
                  onTap: () {
                    setState(() {
                      _experimentType = ExperimentType.traditional;
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ExperimentTypeCard(
                  title: '反応研究実験',
                  subtitle: 'ランダム順序・反応測定',
                  icon: Icons.shuffle,
                  isSelected: _experimentType == ExperimentType.randomOrder,
                  onTap: () {
                    setState(() {
                      _experimentType = ExperimentType.randomOrder;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRandomExperimentSection() {
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.shuffle,
                    color: AppColors.accent,
                    size: AppSpacing.iconMd,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'ランダム実験設定',
                    style: AppTypography.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SliderSetting(
                label: 'フェーズ数',
                value: _randomPhaseCount.toDouble(),
                min: 3,
                max: 12,
                divisions: 9,
                isInteger: true,
                onChanged: (value) {
                  setState(() {
                    _randomPhaseCount = value.round();
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (_randomPhaseSequence != null) ...[
                const Divider(height: AppSpacing.xl),
                const Text(
                  'フェーズシーケンス（プレビュー）',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._randomPhaseSequence!.map((phase) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        phase.type == RandomPhaseType.freeWalk
                            ? Icons.directions_walk
                            : phase.type == RandomPhaseType.pitchKeep
                                ? Icons.sync
                                : Icons.trending_up,
                        size: AppSpacing.iconSm,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${phase.name} (${phase.duration.inMinutes}分)',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdaptiveControlSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '個別対応機能',
                      style: AppTypography.titleLarge,
                    ),
                    Text(
                      '個人の反応に応じてテンポを自動調整',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _useAdaptiveControl,
                onChanged: (value) {
                  setState(() {
                    _useAdaptiveControl = value;
                  });
                },
                activeColor: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentConditionSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.science_outlined,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '実験条件',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...ExperimentCondition.allConditions.map((condition) {
            final isSelected = _selectedCondition == condition;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ConditionCard(
                condition: condition,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedCondition = condition;
                  });
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInductionVariationSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.trending_up,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '誘導バリエーション',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _VariationSelector(
            selectedVariation: _inductionVariation,
            onChanged: (variation) {
              setState(() {
                _inductionVariation = variation;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInductionPhaseSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '誘導フェーズ設定',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SliderSetting(
            label: 'テンポ変化幅',
            value: _inductionStepPercent,
            min: 1,
            max: 20,
            divisions: 19,
            suffix: '%',
            onChanged: (value) {
              setState(() {
                _inductionStepPercent = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _SliderSetting(
            label: 'ステップ数',
            value: _inductionStepCount.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            isInteger: true,
            onChanged: (value) {
              setState(() {
                _inductionStepCount = value.round();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseDurationSection() {
    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: AppColors.borderDark,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: AppSpacing.md),
          title: const Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'フェーズごとの所要時間',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          children: [
            ...AdvancedExperimentPhase.values.map((phase) {
              final phaseInfo = ExperimentPhaseInfo.phaseInfo[phase]!;
              return _PhaseDurationItem(
                phase: phase,
                phaseInfo: phaseInfo,
                duration: _phaseDurationMinutes[phase]!,
                onChanged: (value) {
                  setState(() {
                    _phaseDurationMinutes[phase] = value;
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return AppButton(
      text: '実験を開始',
      onPressed: _startExperiment,
      size: ButtonSize.large,
      width: double.infinity,
      icon: Icons.play_arrow,
    );
  }

  Widget _buildExperimentScreen(ExperimentSession? session) {
    if (session == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      );
    }

    final phaseInfo = session.getPhaseInfo();
    final currentSpm = _experimentController.getCurrentSpm();
    final isStable = _experimentController.isStable();
    final stableSeconds = _experimentController.getStableSeconds();

    return Column(
      children: [
        _buildPhaseHeader(session, phaseInfo),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              children: [
                _buildMetricsGrid(session, currentSpm, isStable, stableSeconds),
                const SizedBox(height: AppSpacing.lg),
                _buildChartSection(),
                const SizedBox(height: AppSpacing.lg),
                _buildProgressSection(session),
                const SizedBox(height: AppSpacing.lg),
                _buildDataStatusSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseHeader(ExperimentSession session, ExperimentPhaseInfo phaseInfo) {
    final remainingSeconds = session.getRemainingSeconds();
    final progress = session.getPhaseProgress();

    return AnimatedBuilder(
      animation: _phaseTransitionController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            20 * (1 - _phaseTransitionController.value),
          ),
          child: Opacity(
            opacity: _phaseTransitionController.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    phaseInfo.color.withOpacity(0.8),
                    phaseInfo.color.withOpacity(0.4),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            phaseInfo.icon,
                            color: AppColors.onPrimary,
                            size: AppSpacing.iconLg,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  phaseInfo.name,
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  phaseInfo.description,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.onPrimary.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Icon(
                            Icons.timer,
                            color: Colors.white.withOpacity(0.8),
                            size: AppSpacing.iconSm,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _formatDuration(Duration(seconds: remainingSeconds)),
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid(
    ExperimentSession session,
    double currentSpm,
    bool isStable,
    int stableSeconds,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: '歩行ピッチ',
                value: currentSpm.toStringAsFixed(1),
                unit: 'SPM',
                icon: Icons.directions_walk,
                color: AppColors.accent,
                isHighlighted: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (session.targetSpm > 0)
              Expanded(
                child: _MetricCard(
                  title: '目標',
                  value: session.targetSpm.toStringAsFixed(1),
                  unit: 'SPM',
                  icon: Icons.track_changes,
                  color: AppColors.warning,
                ),
              ),
            if (session.condition.useMetronome) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MetricCard(
                  title: 'メトロノーム',
                  value: _experimentController.currentTempo.toStringAsFixed(1),
                  unit: 'BPM',
                  icon: Icons.music_note,
                  color: AppColors.info,
                ),
              ),
            ],
          ],
        ),
        if (session.currentCV > 0 || session.responseTime != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (session.currentCV > 0)
                Expanded(
                  child: _MetricCard(
                    title: '変動係数',
                    value: (session.currentCV * 100).toStringAsFixed(1),
                    unit: '%',
                    icon: Icons.analytics,
                    color: AppColors.success,
                  ),
                ),
              if (session.responseTime != null) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MetricCard(
                    title: '反応時間',
                    value: session.responseTime!.inMilliseconds.toString(),
                    unit: 'ms',
                    icon: Icons.timer,
                    color: AppColors.info,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChartSection() {
    return AppCard(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'リアルタイムデータ',
                style: AppTypography.titleLarge,
              ),
              _buildChartLegend(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend() {
    return Row(
      children: [
        _buildLegendItem('現在', AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        _buildLegendItem('目標', AppColors.warning),
        if (_heartRateSpots.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.md),
          _buildLegendItem('心拍', AppColors.error),
        ],
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _maxX,
        minY: _minY,
        maxY: _maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: AppColors.borderDark,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(
              color: AppColors.borderDark,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: AppTypography.caption,
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: AppTypography.caption,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppColors.borderLight),
        ),
        lineBarsData: [
          // 現在のSPM
          LineChartBarData(
            spots: _spmSpots,
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.accent.withOpacity(0.3),
                  AppColors.accent.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // 目標SPM
          LineChartBarData(
            spots: _targetSpots,
            isCurved: false,
            color: AppColors.warning,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            dashArray: const [8, 4],
          ),
          // 心拍数
          if (_heartRateSpots.isNotEmpty)
            LineChartBarData(
              spots: _heartRateSpots,
              isCurved: true,
              color: AppColors.error,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ExperimentSession session) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '実験進行状況',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (session.baselineSpm > 0) ...[
            _buildInfoRow(
              'ベースライン',
              '${session.baselineSpm.toStringAsFixed(1)} SPM',
              Icons.straighten,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (session.followRate > 0) ...[
            _buildFollowRateIndicator(session.followRate),
            const SizedBox(height: AppSpacing.sm),
          ],
          _buildStabilityIndicator(
            _experimentController.isStable(),
            _experimentController.getStableSeconds(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: AppSpacing.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowRateIndicator(double followRate) {
    final color = _getFollowRateColor(followRate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.sync,
              size: AppSpacing.iconSm,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('追従率', style: AppTypography.bodyMedium),
            const Spacer(),
            Text(
              '${followRate.toStringAsFixed(1)}%',
              style: AppTypography.titleMedium.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: LinearProgressIndicator(
            value: followRate / 100,
            backgroundColor: AppColors.borderDark,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildStabilityIndicator(bool isStable, int stableSeconds) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isStable ? AppColors.success : AppColors.warning,
            shape: BoxShape.circle,
            boxShadow: isStable
                ? [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          isStable ? '安定中 ($stableSeconds秒)' : '適応中',
          style: AppTypography.bodyMedium.copyWith(
            color: isStable ? AppColors.success : AppColors.warning,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showEvaluationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.modalRadius),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _EvaluationForm(
              initialFatigue: _fatigueLevel,
              initialConcentration: _concentrationLevel,
              initialAwareness: _awarenessLevel,
              onSave: (fatigue, concentration, awareness, comments) {
                _experimentController.setSubjectiveEvaluation(
                  SubjectiveEvaluation(
                    fatigueLevel: fatigue,
                    concentrationLevel: concentration,
                    awarenessLevel: awareness,
                    comments: comments,
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataStatusSection() {
    // ExperimentControllerのaccelerometerBufferへのアクセスが必要
    // ここでは簡易的な表示のみ実装
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.storage,
                color: AppColors.accent,
                size: AppSpacing.iconMd,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'データ収集状況',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(
            '加速度データ',
            '収集中',
            Icons.sensors,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '※実験終了時に自動保存されます',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.modalRadius),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: AppColors.accent,
                        size: AppSpacing.iconLg,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        '実験の概要',
                        style: AppTypography.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '本実験は歩行リズムと音楽テンポの関係を調査するものです。',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildHelpSection(
                    '実験の流れ',
                    [
                      '準備・キャリブレーション: センサーの準備と実験説明',
                      'ベースライン測定: 通常のペースで自由に歩行',
                      '適応フェーズ: 歩行リズムを音に合わせる練習',
                      '誘導フェーズ: 徐々に変化するテンポに適応',
                      '後効果測定: 音が止まった後の歩行リズムを測定',
                      '事後評価: アンケートに回答',
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildHelpSection(
                    '注意事項',
                    [
                      '実験中は安全に歩行してください',
                      '各フェーズの指示に従ってください',
                      '途中で休憩が必要な場合は申し出てください',
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      text: '閉じる',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Color _getFollowRateColor(double rate) {
    if (rate >= 95) return AppColors.success;
    if (rate >= 85) return const Color(0xFF8BC34A);
    if (rate >= 75) return AppColors.warning;
    if (rate >= 60) return const Color(0xFFFF9800);
    return AppColors.error;
  }
}

// Custom Widgets

class _ExperimentTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExperimentTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: AppOutlinedCard(
        onTap: onTap,
        borderColor: isSelected ? AppColors.accent : AppColors.borderLight,
        borderWidth: isSelected ? 2 : 1,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: AppSpacing.iconLg,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final ExperimentCondition condition;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConditionCard({
    required this.condition,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: AppOutlinedCard(
        onTap: onTap,
        borderColor: isSelected ? AppColors.accent : AppColors.borderLight,
        borderWidth: isSelected ? 2 : 1,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.borderLight,
                  width: 2,
                ),
                color: isSelected ? AppColors.accent : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    condition.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    condition.description,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariationSelector extends StatelessWidget {
  final InductionVariation selectedVariation;
  final ValueChanged<InductionVariation> onChanged;

  const _VariationSelector({
    required this.selectedVariation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VariationOption(
            title: '漸増条件',
            subtitle: '+20%まで増加',
            icon: Icons.trending_up,
            isSelected: selectedVariation == InductionVariation.increasing,
            onTap: () => onChanged(InductionVariation.increasing),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _VariationOption(
            title: '漸減条件',
            subtitle: '-20%まで減少',
            icon: Icons.trending_down,
            isSelected: selectedVariation == InductionVariation.decreasing,
            onTap: () => onChanged(InductionVariation.decreasing),
          ),
        ),
      ],
    );
  }
}

class _VariationOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VariationOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: AppOutlinedCard(
        onTap: onTap,
        borderColor: isSelected ? AppColors.accent : AppColors.borderLight,
        borderWidth: isSelected ? 2 : 1,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: AppSpacing.iconLg,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? suffix;
  final bool isInteger;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.suffix,
    this.isInteger = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = isInteger
        ? value.round().toString()
        : value.toStringAsFixed(1);
    final displayText = suffix != null ? '$displayValue$suffix' : displayValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.titleMedium),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                displayText,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.borderDark,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withOpacity(0.1),
            valueIndicatorColor: AppColors.accent,
            valueIndicatorTextStyle: AppTypography.caption.copyWith(
              color: Colors.white,
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: displayText,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _PhaseDurationItem extends StatelessWidget {
  final AdvancedExperimentPhase phase;
  final ExperimentPhaseInfo phaseInfo;
  final double duration;
  final ValueChanged<double> onChanged;

  const _PhaseDurationItem({
    required this.phase,
    required this.phaseInfo,
    required this.duration,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            phaseInfo.icon,
            color: phaseInfo.color,
            size: AppSpacing.iconMd,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phaseInfo.name,
                  style: AppTypography.titleSmall,
                ),
                Text(
                  '${duration.toStringAsFixed(0)}分',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 180,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: phaseInfo.color,
                inactiveTrackColor: AppColors.borderDark,
                thumbColor: phaseInfo.color,
                overlayColor: phaseInfo.color.withOpacity(0.1),
              ),
              child: Slider(
                value: duration,
                min: 1,
                max: 15,
                divisions: 14,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: isHighlighted
          ? color.withOpacity(0.1)
          : AppColors.cardBackground,
      border: isHighlighted
          ? Border.all(color: color.withOpacity(0.3), width: 1)
          : null,
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: AppSpacing.iconLg,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTypography.headlineMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: AppTypography.caption.copyWith(
                    color: color.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvaluationForm extends StatefulWidget {
  final int initialFatigue;
  final int initialConcentration;
  final int initialAwareness;
  final Function(int, int, int, String) onSave;

  const _EvaluationForm({
    required this.initialFatigue,
    required this.initialConcentration,
    required this.initialAwareness,
    required this.onSave,
  });

  @override
  State<_EvaluationForm> createState() => _EvaluationFormState();
}

class _EvaluationFormState extends State<_EvaluationForm> {
  late int _fatigueLevel;
  late int _concentrationLevel;
  late int _awarenessLevel;
  String _comments = '';

  @override
  void initState() {
    super.initState();
    _fatigueLevel = widget.initialFatigue;
    _concentrationLevel = widget.initialConcentration;
    _awarenessLevel = widget.initialAwareness;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.assignment,
              color: AppColors.accent,
              size: AppSpacing.iconLg,
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              '実験後アンケート',
              style: AppTypography.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildRatingSection(
          '疲労度',
          '低い',
          '高い',
          _fatigueLevel,
          (value) => setState(() => _fatigueLevel = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildRatingSection(
          '集中度',
          '低い',
          '高い',
          _concentrationLevel,
          (value) => setState(() => _concentrationLevel = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildRatingSection(
          '音楽の聴こえ方・意識度',
          '低い',
          '高い',
          _awarenessLevel,
          (value) => setState(() => _awarenessLevel = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextArea(
          label: 'その他コメント',
          hint: '歩きやすさ、音の聞こえ方、実験中の感想など',
          onChanged: (value) => _comments = value,
          maxLines: 4,
          minLines: 3,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppOutlinedButton(
              text: 'キャンセル',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              text: '保存',
              onPressed: () {
                widget.onSave(
                  _fatigueLevel,
                  _concentrationLevel,
                  _awarenessLevel,
                  _comments,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection(
    String label,
    String lowLabel,
    String highLabel,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(lowLabel, style: AppTypography.caption),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  final isSelected = rating <= value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(rating),
                      child: Container(
                        height: 40,
                        margin: EdgeInsets.symmetric(
                          horizontal: index == 0 || index == 4 ? 0 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.borderDark,
                          borderRadius: BorderRadius.horizontal(
                            left: index == 0
                                ? const Radius.circular(AppSpacing.radiusSm)
                                : Radius.zero,
                            right: index == 4
                                ? const Radius.circular(AppSpacing.radiusSm)
                                : Radius.zero,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            rating.toString(),
                            style: AppTypography.titleSmall.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(highLabel, style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}