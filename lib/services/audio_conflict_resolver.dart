import 'dart:collection';

/// メトロノームとn-back音声の衝突を検出し、自動的に調整するリゾルバー
class AudioConflictResolver {
  // 衝突検出の閾値（ミリ秒）
  static const int _conflictThreshold = 200;
  
  // 自動シフト量（ミリ秒）
  static const int _shiftAmount = 100;
  
  // スケジュール済みイベントのキュー
  final Queue<AudioEvent> _metronomeEvents = Queue<AudioEvent>();
  final Queue<AudioEvent> _nBackEvents = Queue<AudioEvent>();
  
  // 衝突ログ
  final List<ConflictLog> _conflictHistory = [];
  
  // 次回のメトロノームクリック予測時刻
  DateTime? _nextMetronomeClick;
  double _metronomeBpm = 100.0;
  
  /// リゾルバーの初期化
  void initialize(double metronomeBpm) {
    _metronomeBpm = metronomeBpm;
    _metronomeEvents.clear();
    _nBackEvents.clear();
    _conflictHistory.clear();
    _updateNextMetronomeClick();
  }
  
  /// メトロノームBPMの更新
  void updateMetronomeBpm(double bpm) {
    _metronomeBpm = bpm;
    _updateNextMetronomeClick();
  }
  
  /// 次のメトロノームクリック時刻を予測
  void _updateNextMetronomeClick() {
    final intervalMs = (60000 / _metronomeBpm).round();
    _nextMetronomeClick = DateTime.now().add(Duration(milliseconds: intervalMs));
  }
  
  /// n-back音声再生時刻をスケジュール
  /// originalTime: 元の予定時刻
  /// duration: 音声の長さ（ミリ秒）
  /// returns: 調整後の再生時刻
  DateTime scheduleNBackAudio({
    required DateTime originalTime,
    required int duration,
  }) {
    // メトロノームクリックとの衝突をチェック
    DateTime adjustedTime = originalTime;
    bool conflictDetected = false;
    
    // 次の数クリック分の予測時刻と比較
    for (int i = 0; i < 5; i++) {
      final clickTime = _getMetronomeClickTime(i);
      if (clickTime == null) continue;
      
      // 衝突検出
      final timeDiff = originalTime.difference(clickTime).inMilliseconds.abs();
      if (timeDiff < _conflictThreshold) {
        conflictDetected = true;
        
        // 前後どちらにシフトするか決定
        if (originalTime.isAfter(clickTime)) {
          // 後ろにシフト
          adjustedTime = clickTime.add(Duration(milliseconds: _conflictThreshold));
        } else {
          // 前にシフト
          adjustedTime = clickTime.subtract(Duration(milliseconds: _conflictThreshold));
        }
        
        // ログに記録
        _conflictHistory.add(ConflictLog(
          originalTime: originalTime,
          adjustedTime: adjustedTime,
          conflictType: ConflictType.metronomeClick,
          shiftAmount: adjustedTime.difference(originalTime).inMilliseconds,
        ));
        
        break;
      }
    }
    
    // 既存のn-backイベントとの衝突もチェック
    for (final event in _nBackEvents) {
      final eventEnd = event.scheduledTime.add(Duration(milliseconds: event.duration));
      
      // イベントが重なるかチェック
      if (_isOverlapping(
        adjustedTime,
        adjustedTime.add(Duration(milliseconds: duration)),
        event.scheduledTime,
        eventEnd,
      )) {
        // 既存イベントの後にシフト
        adjustedTime = eventEnd.add(Duration(milliseconds: 50));
        
        _conflictHistory.add(ConflictLog(
          originalTime: originalTime,
          adjustedTime: adjustedTime,
          conflictType: ConflictType.nBackOverlap,
          shiftAmount: adjustedTime.difference(originalTime).inMilliseconds,
        ));
      }
    }
    
    // スケジュールに追加
    _nBackEvents.add(AudioEvent(
      scheduledTime: adjustedTime,
      duration: duration,
      eventType: AudioEventType.nBack,
    ));
    
    // 古いイベントをクリーンアップ
    _cleanupOldEvents();
    
    return adjustedTime;
  }
  
  /// メトロノームクリック時刻を取得（n番目のクリック）
  DateTime? _getMetronomeClickTime(int n) {
    if (_nextMetronomeClick == null) return null;
    
    final intervalMs = (60000 / _metronomeBpm).round();
    return _nextMetronomeClick!.add(Duration(milliseconds: intervalMs * n));
  }
  
  /// 時間範囲の重なりをチェック
  bool _isOverlapping(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }
  
  /// 古いイベントをクリーンアップ
  void _cleanupOldEvents() {
    final now = DateTime.now();
    
    // 過去のイベントを削除
    while (_nBackEvents.isNotEmpty && 
           _nBackEvents.first.scheduledTime.isBefore(now)) {
      _nBackEvents.removeFirst();
    }
    
    // ログも一定期間後に削除（メモリ節約）
    if (_conflictHistory.length > 1000) {
      _conflictHistory.removeRange(0, _conflictHistory.length - 1000);
    }
  }
  
  /// メトロノームクリックを記録（実際の発生時刻）
  void recordMetronomeClick(DateTime actualTime) {
    _metronomeEvents.add(AudioEvent(
      scheduledTime: actualTime,
      duration: 50, // クリック音の長さ
      eventType: AudioEventType.metronome,
    ));
    
    // 次回予測を更新
    _updateNextMetronomeClick();
    
    // クリーンアップ
    _cleanupOldEvents();
  }
  
  /// 衝突統計を取得
  Map<String, dynamic> getConflictStatistics() {
    int metronomeConflicts = 0;
    int nBackOverlaps = 0;
    int totalShiftMs = 0;
    
    for (final log in _conflictHistory) {
      if (log.conflictType == ConflictType.metronomeClick) {
        metronomeConflicts++;
      } else {
        nBackOverlaps++;
      }
      totalShiftMs += log.shiftAmount.abs();
    }
    
    return {
      'totalConflicts': _conflictHistory.length,
      'metronomeConflicts': metronomeConflicts,
      'nBackOverlaps': nBackOverlaps,
      'averageShiftMs': _conflictHistory.isEmpty 
          ? 0 
          : totalShiftMs / _conflictHistory.length,
      'recentConflicts': _getRecentConflicts(10),
    };
  }
  
  /// 最近の衝突ログを取得
  List<Map<String, dynamic>> _getRecentConflicts(int count) {
    final startIndex = (_conflictHistory.length - count).clamp(0, _conflictHistory.length);
    
    return _conflictHistory
        .sublist(startIndex)
        .map((log) => log.toJson())
        .toList();
  }
  
  /// 衝突ログをエクスポート
  List<ConflictLog> getConflictHistory() {
    return List.unmodifiable(_conflictHistory);
  }
  
  /// デバッグ情報
  Map<String, dynamic> getDebugInfo() {
    return {
      'metronomeBpm': _metronomeBpm,
      'nextMetronomeClick': _nextMetronomeClick?.toIso8601String(),
      'scheduledNBackEvents': _nBackEvents.length,
      'conflictHistorySize': _conflictHistory.length,
      'conflictThresholdMs': _conflictThreshold,
      'shiftAmountMs': _shiftAmount,
    };
  }
}

/// 音声イベントのモデル
class AudioEvent {
  final DateTime scheduledTime;
  final int duration; // ミリ秒
  final AudioEventType eventType;
  
  AudioEvent({
    required this.scheduledTime,
    required this.duration,
    required this.eventType,
  });
}

/// 音声イベントの種類
enum AudioEventType {
  metronome,
  nBack,
}

/// 衝突ログのモデル
class ConflictLog {
  final DateTime originalTime;
  final DateTime adjustedTime;
  final ConflictType conflictType;
  final int shiftAmount; // ミリ秒（正：後ろ、負：前）
  final DateTime loggedAt;
  
  ConflictLog({
    required this.originalTime,
    required this.adjustedTime,
    required this.conflictType,
    required this.shiftAmount,
  }) : loggedAt = DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'originalTime': originalTime.toIso8601String(),
      'adjustedTime': adjustedTime.toIso8601String(),
      'conflictType': conflictType.toString(),
      'shiftAmountMs': shiftAmount,
      'loggedAt': loggedAt.toIso8601String(),
    };
  }
}

/// 衝突の種類
enum ConflictType {
  metronomeClick, // メトロノームクリックとの衝突
  nBackOverlap,   // n-back音声同士の重複
}