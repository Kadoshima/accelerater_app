import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/nback_models.dart';
import 'audio_conflict_resolver.dart';

/// Text-to-Speech サービスのラッパークラス
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioConflictResolver? _conflictResolver;
  
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;
  
  // 設定値
  String _language = 'ja-JP';
  double _speechRate = 1.0;
  double _volume = 1.0;
  double _pitch = 1.0;
  
  TTSService({AudioConflictResolver? conflictResolver}) 
      : _conflictResolver = conflictResolver;
  
  /// TTSエンジンを初期化
  Future<void> initialize({
    String language = 'ja-JP',
    double speechRate = 1.0,
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    _language = language;
    _speechRate = speechRate;
    _volume = volume;
    _pitch = pitch;
    
    // TTS設定
    await _flutterTts.setLanguage(_language);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);
    
    // iOS向けの設定
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
    );
    
    // コールバック設定
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
    
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      _speakCompleter?.completeError(Exception('TTS Error: $msg'));
      _speakCompleter = null;
    });
    
    _isInitialized = true;
  }
  
  /// 数字を読み上げる
  Future<void> speakDigit(int digit, {DateTime? scheduledTime}) async {
    if (!_isInitialized) {
      throw StateError('TTSService is not initialized');
    }
    
    // 衝突解決
    DateTime actualTime = scheduledTime ?? DateTime.now();
    if (_conflictResolver != null && scheduledTime != null) {
      // 推定発話時間（約500ms）
      actualTime = _conflictResolver!.scheduleNBackAudio(
        originalTime: scheduledTime,
        duration: 500,
      );
    }
    
    // スケジュール時刻まで待機
    final delay = actualTime.difference(DateTime.now());
    if (delay.isNegative == false) {
      await Future.delayed(delay);
    }
    
    // 数字を読み上げ
    await speak(digit.toString());
  }
  
  /// テキストを読み上げる
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      throw StateError('TTSService is not initialized');
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    _isSpeaking = true;
    _speakCompleter = Completer<void>();
    
    await _flutterTts.speak(text);
    
    // 完了を待つ
    await _speakCompleter!.future;
  }
  
  /// 読み上げを停止
  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    }
  }
  
  /// 言語を変更
  Future<void> setLanguage(String language) async {
    _language = language;
    await _flutterTts.setLanguage(_language);
  }
  
  /// 読み上げ速度を変更
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
    await _flutterTts.setSpeechRate(_speechRate);
  }
  
  /// 音量を変更
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
  }
  
  /// ピッチを変更
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_pitch);
  }
  
  /// 利用可能な言語を取得
  Future<List<String>> getAvailableLanguages() async {
    final languages = await _flutterTts.getLanguages;
    return List<String>.from(languages);
  }
  
  /// 利用可能な音声を取得
  Future<List<Map<String, String>>> getAvailableVoices() async {
    final voices = await _flutterTts.getVoices;
    return List<Map<String, String>>.from(
      voices.map((voice) => Map<String, String>.from(voice)),
    );
  }
  
  /// N-back設定からTTSを設定
  void configureFromNBack(NBackConfig config) {
    setLanguage(config.language);
    setSpeechRate(config.speechRate);
  }
  
  /// 現在の設定を取得
  Map<String, dynamic> getCurrentSettings() {
    return {
      'language': _language,
      'speechRate': _speechRate,
      'volume': _volume,
      'pitch': _pitch,
      'isInitialized': _isInitialized,
      'isSpeaking': _isSpeaking,
    };
  }
  
  /// リソースを解放
  void dispose() {
    stop();
    _isInitialized = false;
  }
}

/// 数字の多言語読み上げヘルパー
class DigitSpeechHelper {
  static const Map<String, Map<int, String>> _digitWords = {
    'ja-JP': {
      0: 'ゼロ',
      1: 'いち',
      2: 'に',
      3: 'さん',
      4: 'よん',
      5: 'ご',
      6: 'ろく',
      7: 'なな',
      8: 'はち',
      9: 'きゅう',
    },
    'en-US': {
      0: 'zero',
      1: 'one',
      2: 'two',
      3: 'three',
      4: 'four',
      5: 'five',
      6: 'six',
      7: 'seven',
      8: 'eight',
      9: 'nine',
    },
  };
  
  /// 数字を言語に応じた読み方に変換
  static String digitToWord(int digit, String language) {
    final languageMap = _digitWords[language] ?? _digitWords['en-US']!;
    return languageMap[digit] ?? digit.toString();
  }
  
  /// 複数の数字を読み上げ用テキストに変換
  static String digitsToSpeech(List<int> digits, String language) {
    return digits
        .map((digit) => digitToWord(digit, language))
        .join(' ');
  }
}