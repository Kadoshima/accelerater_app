import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/experiment_condition_manager.dart';
import '../../services/experiment_flow_controller.dart';
import '../../services/adaptive_tempo_service.dart';
import '../../services/phase_error_engine.dart';
import '../../services/audio_conflict_resolver.dart';
import '../../services/extended_data_recorder.dart';
import '../../services/nback_sequence_generator.dart';
import '../../services/tts_service.dart';
import '../../services/nback_response_collector.dart';
import '../../services/data_synchronization_service.dart';
import '../../services/voice_guidance_service.dart';
import '../../models/nback_models.dart';
import '../widgets/nback_display_widget.dart';
import 'experiment_control_dashboard.dart';
import 'participant_instruction_screen.dart';
import 'nasa_tlx_screen.dart';
import 'rest_screen.dart';

/// 二重課題実験画面（統合版）
class DualTaskExperimentScreen extends ConsumerStatefulWidget {
  final int participantNumber;
  
  const DualTaskExperimentScreen({
    Key? key,
    required this.participantNumber,
  }) : super(key: key);
  
  @override
  ConsumerState<DualTaskExperimentScreen> createState() => 
      _DualTaskExperimentScreenState();
}

class _DualTaskExperimentScreenState 
    extends ConsumerState<DualTaskExperimentScreen> {
  // コアサービス
  late final ExperimentConditionManager _conditionManager;
  late final ExperimentFlowController _flowController;
  late final AdaptiveTempoService _tempoService;
  late final PhaseErrorEngine _phaseErrorEngine;
  late final AudioConflictResolver _conflictResolver;
  late final ExtendedDataRecorder _dataRecorder;
  
  // N-backサービス
  late final NBackSequenceGenerator _sequenceGenerator;
  late final TTSService _ttsService;
  late final NBackResponseCollector _responseCollector;
  
  // 統合サービス
  late final DataSynchronizationService _syncService;
  late final VoiceGuidanceService _voiceGuidance;
  
  // 状態管理
  ExperimentPhase _currentPhase = ExperimentPhase.notStarted;
  ExperimentCondition? _currentCondition;
  bool _isExperimenterView = true;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  void _initializeServices() async {
    // 音声衝突解決サービス
    _conflictResolver = AudioConflictResolver();
    
    // コアサービスの初期化
    _conditionManager = ExperimentConditionManager();
    _conditionManager.initialize(participantNumber: widget.participantNumber);
    
    _tempoService = AdaptiveTempoService();
    _phaseErrorEngine = PhaseErrorEngine();
    _dataRecorder = ExtendedDataRecorder();
    
    // N-backサービスの初期化
    _sequenceGenerator = NBackSequenceGenerator();
    _ttsService = TTSService();
    await _ttsService.initialize();
    
    _responseCollector = NBackResponseCollector();
    
    // 統合サービスの初期化
    _syncService = DataSynchronizationService(
      dataRecorder: _dataRecorder,
      phaseErrorEngine: _phaseErrorEngine,
    );
    _voiceGuidance = VoiceGuidanceService(conflictResolver: _conflictResolver);
    await _voiceGuidance.initialize();
    
    // フロー制御の初期化
    _flowController = ExperimentFlowController(
      conditionManager: _conditionManager,
      onPhaseChanged: _onPhaseChanged,
      onPhaseProgress: _onPhaseProgress,
      onBlockCompleted: _onBlockCompleted,
      onInstruction: _onInstruction,
    );
    
    // データレコーダーの初期化
    await _dataRecorder.startRecording(
      sessionId: 'DT_${DateTime.now().millisecondsSinceEpoch}',
      subjectId: 'P${widget.participantNumber.toString().padLeft(3, '0')}',
      experimentMetadata: {
        'type': 'dual_task_protocol',
        'conditions': 6,
      },
    );
  }
  
  void _onPhaseChanged(ExperimentPhase phase) {
    setState(() {
      _currentPhase = phase;
    });
    
    // 音声ガイダンス
    _voiceGuidance.announcePhaseChange(phase);
    
    // フェーズ別の処理
    switch (phase) {
      case ExperimentPhase.baseline:
        _startBaselineRecording();
        break;
      case ExperimentPhase.syncPhase:
        _startSyncPhase();
        break;
      case ExperimentPhase.challengePhase1:
      case ExperimentPhase.challengePhase2:
        _startChallengePhase();
        break;
      case ExperimentPhase.stabilityObservation:
        _startStabilityObservation();
        break;
      case ExperimentPhase.rest:
        _showRestScreen();
        break;
      case ExperimentPhase.completed:
        _completeExperiment();
        break;
      default:
        break;
    }
  }
  
  void _onPhaseProgress(Duration remaining) {
    // フェーズ進行の処理
  }
  
  void _onBlockCompleted() {
    // ブロック完了時の処理
    _showNasaTlxScreen();
  }
  
  void _onInstruction(String instruction) {
    // 指示の更新
  }
  
  void _startBaselineRecording() {
    // ベースライン記録開始
    _dataRecorder.updateCondition('baseline', _currentCondition?.tempoControl == TempoControl.adaptive ? true : false);
  }
  
  void _startSyncPhase() {
    // 同期フェーズ開始
    _dataRecorder.updateCondition('sync', _currentCondition?.tempoControl == TempoControl.adaptive ? true : false);
    
    if (_currentCondition?.tempoControl == TempoControl.adaptive) {
      // 適応制御は updateBpm メソッドで行う
    }
  }
  
  void _startChallengePhase() {
    // N-back課題の開始
    if (_currentCondition?.cognitiveLoad != CognitiveLoad.none) {
      _startNBackTask();
    }
  }
  
  void _startStabilityObservation() {
    // 安定観察期間の処理
  }
  
  void _startNBackTask() async {
    final nLevel = _getNBackLevel(_currentCondition!.cognitiveLoad);
    final sequence = _sequenceGenerator.generate(
      length: 30,
      nLevel: nLevel,
    ); // 30個の数字
    
    // N-backセッションの開始
    // TODO: セッションをデータレコーダーに記録
    
    // TTSによる数字読み上げ開始
    for (int i = 0; i < sequence.length; i++) {
      // 音声衝突チェック
      final scheduledTime = _conflictResolver.scheduleNBackAudio(
        originalTime: DateTime.now().add(Duration(seconds: i * 2)),
        duration: 1000,
      );
      
      // スケジュールされた時刻まで待機
      await Future.delayed(scheduledTime.difference(DateTime.now()));
      
      // 数字を読み上げ
      await _ttsService.speak(sequence[i].toString());
      
      // 応答収集を開始
      _responseCollector.startCollecting(
        sequenceIndex: i,
        presentedDigit: sequence[i],
      );
      
      // 応答を待機
      final response = await _responseCollector.waitForResponse();
      
      if (response != null) {
          // 応答を記録
          final isCorrect = _checkNBackResponse(
            sequence, i, nLevel, response.respondedDigit,
          );
          
          _dataRecorder.recordEvent(
            eventType: 'nback_response',
            data: {
              'stimulus': sequence[i],
              'response': response.respondedDigit,
              'isCorrect': isCorrect,
              'reactionTime': response.reactionTimeMs,
            },
          );
        }
      
      // 次の数字まで待機
      await Future.delayed(const Duration(seconds: 2));
    }
  }
  
  int _getNBackLevel(CognitiveLoad load) {
    switch (load) {
      case CognitiveLoad.nBack0:
        return 0;
      case CognitiveLoad.nBack1:
        return 1;
      case CognitiveLoad.nBack2:
        return 2;
      default:
        return 0;
    }
  }
  
  bool _checkNBackResponse(
    List<int> sequence,
    int currentIndex,
    int nLevel,
    int? response,
  ) {
    if (currentIndex < nLevel) return response == null;
    return response == sequence[currentIndex - nLevel];
  }
  
  void _showRestScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestScreen(
          restDuration: const Duration(minutes: 3),
          completedBlocks: _conditionManager.getCurrentBlockIndex() + 1,
          totalBlocks: 6,
          onRestComplete: () {
            Navigator.of(context).pop();
            // 休憩後の継続処理
          },
        ),
      ),
    );
  }
  
  void _showNasaTlxScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NasaTlxScreen(
          conditionId: _currentCondition?.id ?? '',
          onComplete: (ratings) {
            // NASA-TLX評価を保存
            _dataRecorder.recordEvent(
              eventType: 'nasa_tlx',
              data: {
                'conditionId': _currentCondition?.id ?? '',
                'ratings': ratings,
              },
            );
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
  
  void _completeExperiment() async {
    // データ保存
    await _dataRecorder.stopRecording();
    
    // mountedチェック
    if (!mounted) return;
    
    // 完了メッセージ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('実験完了'),
        content: const Text('実験が完了しました。お疲れ様でした。'),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
            child: const Text('終了'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isExperimenterView
          ? const ExperimentControlDashboard()
          : const ParticipantInstructionScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isExperimenterView = !_isExperimenterView;
          });
        },
        tooltip: _isExperimenterView ? '被験者画面' : '実験者画面',
        child: Icon(_isExperimenterView ? Icons.person : Icons.monitor),
      ),
    );
  }
  
  @override
  void dispose() {
    _flowController.dispose();
    _ttsService.dispose();
    _responseCollector.dispose();
    _syncService.dispose();
    _voiceGuidance.dispose();
    super.dispose();
  }
}