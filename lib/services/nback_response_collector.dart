import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/nback_models.dart';

/// N-back応答収集システム
class NBackResponseCollector {
  // 音声認識
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  
  // 応答収集用のコントローラー
  final StreamController<NBackUserInput> _inputController = 
      StreamController<NBackUserInput>.broadcast();
  
  // タイムアウト管理
  Timer? _timeoutTimer;
  int _currentSequenceIndex = 0;
  DateTime? _presentationTime;
  
  // 設定
  Duration _responseTimeout = const Duration(seconds: 2);
  bool _useVoiceInput = true;
  
  /// 入力ストリーム
  Stream<NBackUserInput> get inputStream => _inputController.stream;
  
  /// 初期化
  Future<void> initialize({
    bool useVoiceInput = true,
    Duration responseTimeout = const Duration(seconds: 2),
  }) async {
    _useVoiceInput = useVoiceInput;
    _responseTimeout = responseTimeout;
    
    if (_useVoiceInput) {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) => _handleSpeechError(error),
        onStatus: (status) => _handleSpeechStatus(status),
      );
    }
  }
  
  /// 応答収集を開始（次の数字が提示されたとき）
  void startCollecting({
    required int sequenceIndex,
    required int presentedDigit,
  }) {
    _currentSequenceIndex = sequenceIndex;
    _presentationTime = DateTime.now();
    
    // 前回のタイマーをキャンセル
    _timeoutTimer?.cancel();
    
    // タイムアウトタイマーを設定
    _timeoutTimer = Timer(_responseTimeout, () {
      _handleTimeout();
    });
    
    // 音声認識を開始
    if (_useVoiceInput && _speechEnabled) {
      _startListening();
    }
  }
  
  /// 応答を待機（非同期）
  Future<NBackResponse?> waitForResponse() async {
    final completer = Completer<NBackResponse?>();
    StreamSubscription<NBackUserInput>? subscription;
    
    // タイムアウトタイマー
    final timeoutTimer = Timer(_responseTimeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
        subscription?.cancel();
      }
    });
    
    // 入力を待機
    subscription = inputStream.listen((input) {
      if (input.sequenceIndex == _currentSequenceIndex) {
        final response = NBackResponse(
          sequenceIndex: input.sequenceIndex,
          presentedDigit: 0, // 実際の刺激は外部で管理
          respondedDigit: input.inputDigit,
          isCorrect: false, // 正誤判定は外部で行う
          timestamp: input.timestamp,
          reactionTimeMs: input.reactionTimeMs,
          responseType: input.responseType,
        );
        
        if (!completer.isCompleted) {
          completer.complete(response);
          timeoutTimer.cancel();
          subscription?.cancel();
        }
      }
    });
    
    return completer.future;
  }
  
  /// ボタン入力を処理
  void handleButtonInput(int digit) {
    if (_presentationTime == null) return;
    
    final reactionTime = DateTime.now().difference(_presentationTime!).inMilliseconds;
    
    _inputController.add(NBackUserInput(
      sequenceIndex: _currentSequenceIndex,
      inputDigit: digit,
      responseType: ResponseType.button,
      reactionTimeMs: reactionTime,
      timestamp: DateTime.now(),
    ));
    
    // タイマーをキャンセル
    _timeoutTimer?.cancel();
    
    // 音声認識を停止
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
  }
  
  /// 応答をスキップ
  void skipResponse() {
    _inputController.add(NBackUserInput(
      sequenceIndex: _currentSequenceIndex,
      inputDigit: null,
      responseType: ResponseType.skipped,
      reactionTimeMs: null,
      timestamp: DateTime.now(),
    ));
    
    // タイマーをキャンセル
    _timeoutTimer?.cancel();
    
    // 音声認識を停止
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
  }
  
  /// 音声認識を開始
  void _startListening() async {
    if (!_speechEnabled) return;
    
    await _speechToText.listen(
      onResult: (result) => _handleSpeechResult(result),
      listenFor: _responseTimeout,
      pauseFor: const Duration(seconds: 1),
      localeId: 'ja_JP', // 日本語の数字認識
      onSoundLevelChange: (level) => {},
    );
  }
  
  /// 音声認識結果を処理
  void _handleSpeechResult(result) {
    if (!result.finalResult || _presentationTime == null) return;
    
    // 認識されたテキストから数字を抽出
    final recognizedDigit = _extractDigitFromSpeech(result.recognizedWords);
    
    if (recognizedDigit != null) {
      final reactionTime = DateTime.now().difference(_presentationTime!).inMilliseconds;
      
      _inputController.add(NBackUserInput(
        sequenceIndex: _currentSequenceIndex,
        inputDigit: recognizedDigit,
        responseType: ResponseType.voice,
        reactionTimeMs: reactionTime,
        timestamp: DateTime.now(),
        rawSpeechInput: result.recognizedWords,
      ));
      
      // タイマーをキャンセル
      _timeoutTimer?.cancel();
    }
  }
  
  /// 音声から数字を抽出
  int? _extractDigitFromSpeech(String speech) {
    // 日本語の数字認識
    final japaneseDigits = {
      'ゼロ': 0, 'れい': 0, 'まる': 0,
      'いち': 1, 'ひとつ': 1,
      'に': 2, 'ふたつ': 2,
      'さん': 3, 'みっつ': 3,
      'よん': 4, 'し': 4, 'よっつ': 4,
      'ご': 5, 'いつつ': 5,
      'ろく': 6, 'むっつ': 6,
      'なな': 7, 'しち': 7, 'ななつ': 7,
      'はち': 8, 'やっつ': 8,
      'きゅう': 9, 'く': 9, 'ここのつ': 9,
    };
    
    // 数字をそのまま認識
    final digitMatch = RegExp(r'[0-9]').firstMatch(speech);
    if (digitMatch != null) {
      return int.parse(digitMatch.group(0)!);
    }
    
    // 日本語の数字を認識
    final lowerSpeech = speech.toLowerCase();
    for (final entry in japaneseDigits.entries) {
      if (lowerSpeech.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// タイムアウト処理
  void _handleTimeout() {
    _inputController.add(NBackUserInput(
      sequenceIndex: _currentSequenceIndex,
      inputDigit: null,
      responseType: ResponseType.timeout,
      reactionTimeMs: null,
      timestamp: DateTime.now(),
    ));
    
    // 音声認識を停止
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
  }
  
  /// 音声認識エラー処理
  void _handleSpeechError(dynamic error) {
    // Speech recognition error: $error
    // エラーが発生した場合はボタン入力にフォールバック
  }
  
  /// 音声認識ステータス処理
  void _handleSpeechStatus(String status) {
    // Speech recognition status: $status
  }
  
  /// 音声入力の可用性をチェック
  Future<bool> checkVoiceInputAvailability() async {
    if (!_useVoiceInput) return false;
    
    try {
      final available = await _speechToText.initialize();
      return available;
    } catch (e) {
      return false;
    }
  }
  
  /// 設定を更新
  void updateSettings({
    bool? useVoiceInput,
    Duration? responseTimeout,
  }) {
    if (useVoiceInput != null) {
      _useVoiceInput = useVoiceInput;
    }
    if (responseTimeout != null) {
      _responseTimeout = responseTimeout;
    }
  }
  
  /// リソースを解放
  void dispose() {
    _timeoutTimer?.cancel();
    _speechToText.stop();
    _inputController.close();
  }
}

/// N-backユーザー入力
class NBackUserInput {
  final int sequenceIndex;
  final int? inputDigit;
  final ResponseType responseType;
  final int? reactionTimeMs;
  final DateTime timestamp;
  final String? rawSpeechInput;
  
  NBackUserInput({
    required this.sequenceIndex,
    required this.inputDigit,
    required this.responseType,
    required this.reactionTimeMs,
    required this.timestamp,
    this.rawSpeechInput,
  });
  
  /// NBackResponseに変換
  NBackResponse toResponse(int presentedDigit, int nLevel) {
    // 正解判定
    bool isCorrect = false;
    if (responseType == ResponseType.timeout || responseType == ResponseType.skipped) {
      isCorrect = false;
    } else if (inputDigit != null) {
      // N-backルールに基づいて正解判定
      // この判定は実際のシーケンスと照合する必要があるため、
      // 外部で行う必要がある
      isCorrect = inputDigit == presentedDigit;
    }
    
    return NBackResponse(
      sequenceIndex: sequenceIndex,
      presentedDigit: presentedDigit,
      respondedDigit: inputDigit,
      isCorrect: isCorrect,
      timestamp: timestamp,
      reactionTimeMs: reactionTimeMs,
      responseType: responseType,
    );
  }
}