import 'dart:async';
import 'dart:collection';
import 'package:flutter_tts/flutter_tts.dart';
import 'audio_conflict_resolver.dart';
import 'experiment_flow_controller.dart';
import 'experiment_condition_manager.dart';
import '../models/nback_models.dart';

/// 音声ガイダンスサービス
/// 実験の各フェーズで適切なアナウンスを行う
class VoiceGuidanceService {
  final FlutterTts _tts = FlutterTts();
  final AudioConflictResolver? _conflictResolver;
  
  // アナウンスキュー
  final Queue<VoiceAnnouncement> _announcementQueue = Queue<VoiceAnnouncement>();
  bool _isAnnouncing = false;
  Timer? _queueProcessor;
  
  // 設定
  String _language = 'ja-JP';
  double _speechRate = 1.0;
  double _volume = 1.0;
  bool _isEnabled = true;
  
  // アナウンステンプレート
  static const Map<String, String> _templates = {
    // 実験開始・終了
    'experiment_start': '実験を開始します。指示に従って歩行を行ってください。',
    'experiment_complete': '実験が完了しました。お疲れ様でした。',
    'experiment_abort': '実験を中断しました。',
    
    // フェーズ遷移
    'phase_baseline': 'ベースライン測定を開始します。自由に歩行してください。',
    'phase_sync': '同期フェーズです。メトロノームのリズムに合わせて歩いてください。',
    'phase_challenge': 'チャレンジフェーズです。テンポの変化に注意してください。',
    'phase_stability': '安定観察期間です。そのまま歩き続けてください。',
    'phase_rest': '休憩時間です。#DURATION#分間休憩してください。',
    
    // 条件説明
    'condition_adaptive': '適応的テンポ制御モードです。',
    'condition_fixed': '固定テンポ制御モードです。',
    'condition_nback0': 'ゼロバック課題を行います。最初の数字を覚えてください。',
    'condition_nback1': 'ワンバック課題を行います。1つ前の数字と比較してください。',
    'condition_nback2': 'ツーバック課題を行います。2つ前の数字と比較してください。',
    
    // カウントダウン
    'countdown_10': '10秒前',
    'countdown_5': '5秒前',
    'countdown_3': '3',
    'countdown_2': '2',
    'countdown_1': '1',
    'countdown_start': 'スタート',
    
    // 警告・フィードバック
    'warning_low_accuracy': '正答率が低下しています。集中してください。',
    'warning_high_cv': '歩行のばらつきが大きくなっています。',
    'feedback_good_performance': '良好なパフォーマンスです。',
    'feedback_phase_complete': 'このフェーズが完了しました。',
    
    // エラー
    'error_sensor_disconnected': 'センサーの接続が切れました。',
    'error_data_recording': 'データ記録にエラーが発生しました。',
  };
  
  VoiceGuidanceService({AudioConflictResolver? conflictResolver})
      : _conflictResolver = conflictResolver;
  
  /// サービスの初期化
  Future<void> initialize({
    String language = 'ja-JP',
    double speechRate = 1.0,
    double volume = 1.0,
  }) async {
    _language = language;
    _speechRate = speechRate;
    _volume = volume;
    
    // TTSの設定
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(_volume);
    await _tts.setPitch(1.0);
    
    // iOS向けの設定
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers, // 他の音声を下げる
      ],
    );
    
    // コールバック設定
    _tts.setCompletionHandler(() {
      _isAnnouncing = false;
      _processQueue();
    });
    
    // キュー処理タイマー
    _queueProcessor = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _processQueue(),
    );
  }
  
  /// フェーズ変更のアナウンス
  void announcePhaseChange(ExperimentPhase phase, {Duration? restDuration}) {
    if (!_isEnabled) return;
    
    String? message;
    Priority priority = Priority.high;
    
    switch (phase) {
      case ExperimentPhase.baseline:
        message = _templates['phase_baseline'];
        break;
      case ExperimentPhase.syncPhase:
        message = _templates['phase_sync'];
        break;
      case ExperimentPhase.challengePhase1:
      case ExperimentPhase.challengePhase2:
        message = _templates['phase_challenge'];
        break;
      case ExperimentPhase.stabilityObservation:
        message = _templates['phase_stability'];
        break;
      case ExperimentPhase.rest:
        if (restDuration != null) {
          message = _templates['phase_rest']!.replaceAll(
            '#DURATION#',
            restDuration.inMinutes.toString(),
          );
        }
        break;
      case ExperimentPhase.completed:
        message = _templates['experiment_complete'];
        priority = Priority.critical;
        break;
      case ExperimentPhase.aborted:
        message = _templates['experiment_abort'];
        priority = Priority.critical;
        break;
      default:
        break;
    }
    
    if (message != null) {
      _enqueueAnnouncement(message, priority: priority);
    }
  }
  
  /// 条件変更のアナウンス
  void announceConditionChange(ExperimentCondition condition) {
    if (!_isEnabled) return;
    
    final messages = <String>[];
    
    // テンポ制御モード
    if (condition.tempoControl == TempoControl.adaptive) {
      messages.add(_templates['condition_adaptive']!);
    } else {
      messages.add(_templates['condition_fixed']!);
    }
    
    // 認知負荷
    switch (condition.cognitiveLoad) {
      case CognitiveLoad.nBack0:
        messages.add(_templates['condition_nback0']!);
        break;
      case CognitiveLoad.nBack1:
        messages.add(_templates['condition_nback1']!);
        break;
      case CognitiveLoad.nBack2:
        messages.add(_templates['condition_nback2']!);
        break;
      default:
        break;
    }
    
    // メッセージを結合してアナウンス
    if (messages.isNotEmpty) {
      _enqueueAnnouncement(
        messages.join(' '),
        priority: Priority.high,
      );
    }
  }
  
  /// カウントダウンアナウンス
  Future<void> announceCountdown({
    required int seconds,
    String? endMessage,
  }) async {
    if (!_isEnabled || seconds <= 0) return;
    
    // カウントダウンメッセージをスケジュール
    for (int i = seconds; i > 0; i--) {
      final delay = Duration(seconds: seconds - i);
      
      Timer(delay, () {
        String? message;
        
        if (i == 10) {
          message = _templates['countdown_10'];
        } else if (i == 5) {
          message = _templates['countdown_5'];
        } else if (i <= 3) {
          message = _templates['countdown_$i'];
        }
        
        if (message != null) {
          _enqueueAnnouncement(
            message,
            priority: Priority.high,
            immediate: true,
          );
        }
      });
    }
    
    // 開始メッセージ
    Timer(Duration(seconds: seconds), () {
      _enqueueAnnouncement(
        endMessage ?? _templates['countdown_start']!,
        priority: Priority.critical,
        immediate: true,
      );
    });
  }
  
  /// 警告アナウンス
  void announceWarning(WarningType type) {
    if (!_isEnabled) return;
    
    String? message;
    
    switch (type) {
      case WarningType.lowAccuracy:
        message = _templates['warning_low_accuracy'];
        break;
      case WarningType.highCv:
        message = _templates['warning_high_cv'];
        break;
      case WarningType.sensorDisconnected:
        message = _templates['error_sensor_disconnected'];
        break;
      case WarningType.dataError:
        message = _templates['error_data_recording'];
        break;
    }
    
    if (message != null) {
      _enqueueAnnouncement(
        message,
        priority: Priority.high,
        immediate: true,
      );
    }
  }
  
  /// カスタムアナウンス
  void announceCustom(
    String message, {
    Priority priority = Priority.normal,
    bool immediate = false,
  }) {
    if (!_isEnabled || message.isEmpty) return;
    
    _enqueueAnnouncement(message, priority: priority, immediate: immediate);
  }
  
  /// アナウンスをキューに追加
  void _enqueueAnnouncement(
    String message, {
    Priority priority = Priority.normal,
    bool immediate = false,
  }) {
    final announcement = VoiceAnnouncement(
      message: message,
      priority: priority,
      timestamp: DateTime.now(),
      immediate: immediate,
    );
    
    if (immediate && priority == Priority.critical) {
      // 緊急メッセージは即座に再生
      _announcementQueue.clear();
      _tts.stop();
      _isAnnouncing = false;
    }
    
    _announcementQueue.add(announcement);
    
    // 優先度でソート
    final sorted = _announcementQueue.toList()
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    _announcementQueue.clear();
    _announcementQueue.addAll(sorted);
  }
  
  /// キューを処理
  void _processQueue() async {
    if (_isAnnouncing || _announcementQueue.isEmpty) return;
    
    final announcement = _announcementQueue.removeFirst();
    
    // 古いメッセージはスキップ
    if (DateTime.now().difference(announcement.timestamp).inSeconds > 30) {
      return;
    }
    
    _isAnnouncing = true;
    
    // 衝突回避
    DateTime speakTime = DateTime.now();
    if (_conflictResolver != null) {
      speakTime = _conflictResolver!.scheduleNBackAudio(
        originalTime: speakTime,
        duration: _estimateSpeechDuration(announcement.message),
      );
      
      // スケジュールされた時刻まで待機
      final delay = speakTime.difference(DateTime.now());
      if (!delay.isNegative) {
        await Future.delayed(delay);
      }
    }
    
    // アナウンス実行
    await _tts.speak(announcement.message);
  }
  
  /// 音声の推定時間（ミリ秒）
  int _estimateSpeechDuration(String text) {
    // 簡易的な推定: 1文字100ms + 基本時間500ms
    return 500 + (text.length * 100 ~/ _speechRate);
  }
  
  /// 音声ガイダンスの有効/無効切り替え
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    
    if (!enabled) {
      _announcementQueue.clear();
      _tts.stop();
    }
  }
  
  /// 言語設定
  Future<void> setLanguage(String language) async {
    _language = language;
    await _tts.setLanguage(language);
  }
  
  /// 音量設定
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }
  
  /// 速度設定
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    await _tts.setSpeechRate(_speechRate);
  }
  
  /// リソースの解放
  void dispose() {
    _queueProcessor?.cancel();
    _announcementQueue.clear();
    _tts.stop();
  }
}

/// 音声アナウンスメント
class VoiceAnnouncement {
  final String message;
  final Priority priority;
  final DateTime timestamp;
  final bool immediate;
  
  VoiceAnnouncement({
    required this.message,
    required this.priority,
    required this.timestamp,
    this.immediate = false,
  });
}

/// 優先度
enum Priority {
  low,
  normal,
  high,
  critical,
}

/// 警告タイプ
enum WarningType {
  lowAccuracy,
  highCv,
  sensorDisconnected,
  dataError,
}