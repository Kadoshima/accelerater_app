import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // flutter_blue_plusライブラリ
import 'dart:async'; // Streamの取り扱いに必要
import 'dart:io';
import 'dart:convert'; // jsonDecodeで使用するため、これは残す
// Uint8List用に追加
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math; // Mathクラスを使うためにインポート（as mathで修飾）
// Azure Blob Storage
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 環境変数管理用
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // 位置情報を取得するためのパッケージ
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';

// 独自モジュール
import 'models/sensor_data.dart';
import 'utils/gait_analysis_service.dart'; // 新しいサービスをインポート
import 'services/metronome.dart'; // メトロノームサービス
import 'services/native_metronome.dart'; // ネイティブメトロノームサービス
import 'services/background_service.dart'; // バックグラウンドサービス
import 'screens/experiment_screen.dart'; // 新しい実験画面
import 'utils/spm_analysis.dart';
import 'widgets/device_connection_screen.dart'; // デバイス接続画面
import 'core/theme/app_theme.dart'; // Design system theme
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'services/adaptive_tempo_controller.dart';
import 'core/theme/app_spacing.dart';
import 'presentation/widgets/common/app_card.dart';
import 'presentation/widgets/common/app_button.dart';
import 'presentation/widgets/cv_trend_chart.dart';

// 実験フェーズを定義する列挙型（クラスの外に定義）
enum ExperimentPhase {
  freeWalking, // 自由歩行フェーズ
  pitchAdjustment, // ピッチ調整フェーズ
  pitchIncreasing // ピッチ増加フェーズ
}

void main() async {
  // 環境変数の読み込み
  await dotenv.load(fileName: ".env");

  // 環境変数の読み込み確認
  print('--- main関数での環境変数読み込み確認 ---');
  print('AZURE_STORAGE_ACCOUNT: ${dotenv.env['AZURE_STORAGE_ACCOUNT']}');
  if (dotenv.env['AZURE_SAS_TOKEN'] != null) {
    print(
        'AZURE_SAS_TOKEN: ${dotenv.env['AZURE_SAS_TOKEN']!.substring(0, 20)}...');
  } else {
    print('AZURE_SAS_TOKEN: null');
  }
  print('AZURE_CONTAINER_NAME: ${dotenv.env['AZURE_CONTAINER_NAME']}');
  print('--------------------------------------');

  // アプリ起動時にFlutterBluePlusを初期化
  if (Platform.isAndroid) {
    // Android固有の初期化
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  } else if (Platform.isIOS) {
    // iOS固有の初期化（ログレベルを下げる）
    FlutterBluePlus.setLogLevel(LogLevel.info, color: false);
  }

  // バックグラウンドサービスの初期化
  await BackgroundService.initialize();

  runApp(const MyApp());
}

/// メインのウィジェット
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthCore M5 Demo',
      theme: AppTheme.darkTheme, // Use our new dark theme
      home: const BLEHomePage(),
    );
  }
}

// M5Stackから受信するデータモデル
// Definitions moved to lib/models/sensor_data.dart

// 実験記録用のデータモデル
class ExperimentRecord {
  final DateTime timestamp;
  final double targetBPM;
  final double? detectedBPM;
  final double? reliability; // 信頼性スコア

  // 加速度センサーデータ
  final double? accX;
  final double? accY;
  final double? accZ;
  final double? magnitude;

  ExperimentRecord({
    required this.timestamp,
    required this.targetBPM,
    this.detectedBPM,
    this.reliability,
    this.accX,
    this.accY,
    this.accZ,
    this.magnitude,
  });

  // CSVレコードに変換するメソッド
  List<dynamic> toCSV() {
    return [
      DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp),
      targetBPM,
      detectedBPM ?? 'N/A',
      reliability != null
          ? '${(reliability! * 100).toStringAsFixed(1)}%'
          : 'N/A',
      accX?.toStringAsFixed(6) ?? 'N/A',
      accY?.toStringAsFixed(6) ?? 'N/A',
      accZ?.toStringAsFixed(6) ?? 'N/A',
      magnitude?.toStringAsFixed(6) ?? 'N/A',
    ];
  }
}

// 音楽のテンポ設定用クラス
class MusicTempo {
  final String name;
  final double bpm;

  MusicTempo({required this.name, required this.bpm});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MusicTempo && other.name == name && other.bpm == bpm;
  }

  @override
  int get hashCode => name.hashCode ^ bpm.hashCode;
}

/// ホーム画面
class BLEHomePage extends StatefulWidget {
  const BLEHomePage({Key? key}) : super(key: key);

  @override
  State<BLEHomePage> createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  // スキャン/接続周り
  bool isScanning = false;
  bool isConnecting = false;
  bool isConnected = false;

  // 受信したデータ
  M5SensorData? latestData;
  List<M5SensorData> dataHistory = [];
  static const int maxHistorySize = 100; // 最大履歴サイズ

  // 実験記録
  List<ExperimentRecord> experimentRecords = [];
  bool isRecording = false;
  String experimentFileName = '';
  String subjectId = ''; // 被験者番号

  // グラフデータ
  List<FlSpot> bpmSpots = []; // SPMデータ格納用 (名前はそのまま)
  double minY = 40; // SPM範囲に合わせて調整
  double maxY = 160; // SPM範囲に合わせて調整

  // メトロノーム関連
  late Metronome _metronome;
  late NativeMetronome _nativeMetronome; // ネイティブメトロノームの追加
  bool _useNativeMetronome = true; // ネイティブメトロノームを使用するフラグ
  bool useVibration = true; // バイブレーション機能の有効/無効フラグ

  // メトロノームのゲッター（ネイティブかDartかを抽象化）
  bool get isPlaying =>
      _useNativeMetronome ? _nativeMetronome.isPlaying : _metronome.isPlaying;
  double get currentMusicBPM =>
      _useNativeMetronome ? _nativeMetronome.currentBpm : _metronome.currentBpm;

  MusicTempo? selectedTempo;
  // メトロノーム操作用テンポリスト (80から10ずつ増加)
  final List<MusicTempo> metronomeTempoPresets = [
    MusicTempo(name: '80 BPM', bpm: 80.0),
    MusicTempo(name: '90 BPM', bpm: 90.0),
    MusicTempo(name: '100 BPM', bpm: 100.0),
    MusicTempo(name: '110 BPM', bpm: 110.0),
    MusicTempo(name: '120 BPM', bpm: 120.0),
    MusicTempo(name: '130 BPM', bpm: 130.0),
    MusicTempo(name: '140 BPM', bpm: 140.0),
    MusicTempo(name: '150 BPM', bpm: 150.0),
  ];
  // 実験モード用テンポリスト (10ずつ増加)
  final List<MusicTempo> experimentTempoPresets = [
    MusicTempo(name: '60 BPM', bpm: 60.0),
    MusicTempo(name: '70 BPM', bpm: 70.0),
    MusicTempo(name: '80 BPM', bpm: 80.0),
    MusicTempo(name: '90 BPM', bpm: 90.0),
    MusicTempo(name: '100 BPM', bpm: 100.0),
    MusicTempo(name: '110 BPM', bpm: 110.0),
    MusicTempo(name: '120 BPM', bpm: 120.0),
    MusicTempo(name: '130 BPM', bpm: 130.0),
    MusicTempo(name: '140 BPM', bpm: 140.0),
    MusicTempo(name: '150 BPM', bpm: 150.0),
  ];

  // 実験モード関連
  bool isExperimentMode = false; // 旧：実験モード→新：無音データ収集モード
  bool isRealExperimentMode = false; // 本実験モード
  int experimentDurationSeconds = 300; // デフォルト5分
  DateTime? experimentStartTime;
  Timer? experimentTimer;
  int remainingSeconds = 0;

  // 本実験モード関連
  ExperimentPhase currentPhase = ExperimentPhase.freeWalking;
  int phaseStableSeconds = 0; // 現在のフェーズで安定している秒数
  double baseWalkingPitch = 0.0; // 自由歩行時のピッチ（BPM）
  double targetPitch = 0.0; // 現在の目標ピッチ（BPM）
  DateTime? phaseStartTime; // フェーズ開始時刻
  List<double> recentPitches = []; // 最近の歩行ピッチを記録
  Timer? pitchAdjustmentTimer; // ピッチ調整用タイマー
  bool isPitchStable = false; // ピッチが安定しているか
  int stableCountdown = 0; // 安定までのカウントダウン秒数
  int pitchIncreaseCount = 0; // ピッチを何回増加させたか
  DateTime? lastPitchChangeTime; // 最後にピッチを変更した時刻

  // 設定パラメータ
  int freeWalkingDurationSeconds = 300; // 自由歩行フェーズの期間 (5分)
  int stableThresholdSeconds = 60; // 安定とみなす秒数 (1分)
  double pitchDifferenceThreshold = 10.0; // ピッチ差の閾値
  double pitchIncrementStep = 5.0; // ピッチ増加ステップ

  // 適応的テンポ制御
  final AdaptiveTempoController _adaptiveTempoController =
      AdaptiveTempoController();
  final List<double> _strideIntervals = []; // ストライド間隔の履歴
  double _currentCV = 0.0; // 現在の変動係数
  DateTime? _lastStepTime; // 最後のステップ時刻
  final List<double> _cvHistory = []; // CV値の履歴（グラフ表示用）

  // 歩行解析サービス
  GaitAnalysisService? gaitAnalysisService;

  // UI表示用変数
  double _displaySpm = 0.0; // 表示するSPM
  int _displayStepCount = 0; // 表示するステップ数

  // デバイス名
  final targetDeviceName = "M5StickIMU";

  // サービスUUIDとキャラクタリスティックUUID
  final serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final charUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  // 接続先デバイス
  BluetoothDevice? targetDevice;

  // 心拍センサー関連
  BluetoothDevice? heartRateDevice;
  final Guid heartRateServiceUuid =
      Guid("0000180d-0000-1000-8000-00805f9b34fb");
  final Guid heartRateMeasurementCharUuid =
      Guid("00002a37-0000-1000-8000-00805f9b34fb");
  int currentHeartRate = 0;
  bool isHeartRateConnected = false;
  DateTime? _lastHeartRateUpdate;
  Timer? _heartRateDisplayTimer;
  final List<int> _recentHeartRates = []; // 最近の心拍数を保持（平滑化用）
  DateTime? _lastHeartRateReceived; // 最後に心拍データを受信した時刻

  // サブスクリプション管理用
  final List<StreamSubscription> _streamSubscriptions = [];

  // 重複したスキャン/接続リクエストを防ぐフラグ
  bool _isInitialized = false;
  bool _isDisposing = false;

  // スキャンで見つかったデバイスリスト
  final List<ScanResult> _scanResults = [];

  // スマホ加速度センサー利用フラグとサブスクリプション
  final bool _usePhoneSensor = false;
  StreamSubscription<AccelerometerEvent>? _phoneSensorSubscription;

  // RAWデータグラフ用
  List<FlSpot> accXSpots = [];
  List<FlSpot> accYSpots = [];
  List<FlSpot> accZSpots = [];
  List<FlSpot> magnitudeSpots = [];
  bool showRawDataGraph = true;

  // 新しい右足センサー向け歩行検出器
  // late final RightFootCadenceDetector cadenceDetector; // 削除

  // BPMの手動計算結果
  double? calculatedBpmFromRaw;

  // Detectorからの最新結果を保持する状態変数 (不要)
  // double _currentCalculatedBpm = 0.0; // 削除
  // double _currentConfidence = 0.0; // 削除
  // Map<String, dynamic> _currentDebugInfo = {}; // 削除

  // Azure Blob Storage接続情報
  String get azureStorageAccount =>
      dotenv.env['AZURE_STORAGE_ACCOUNT'] ?? 'hagiharatest';
  String get azureSasToken => dotenv.env['AZURE_SAS_TOKEN'] ?? '';
  String get azureConnectionString =>
      dotenv.env['AZURE_CONNECTION_STRING'] ?? '';
  String get containerName =>
      dotenv.env['AZURE_CONTAINER_NAME'] ?? 'accelerationdata';

  // 本実験の時系列データを記録
  List<Map<String, dynamic>> realExperimentTimeSeriesData = [];
  Timer? timeSeriesDataTimer;

  // 無音データ収集モード関連
  List<Map<String, dynamic>> silentWalkingData = [];
  Timer? silentWalkingDataTimer;
  DateTime? silentWalkingStartTime;

  // 位置情報関連
  Position? _currentPosition;
  bool _isLocationEnabled = false;
  String _locationErrorMessage = '';

  @override
  void initState() {
    super.initState();

    // エラーハンドリングの設定
    FlutterError.onError = (details) {
      print('FlutterError: ${details.exception}');
      print(details.stack);
    };

    // 歩行解析サービスを即座に初期化
    gaitAnalysisService = GaitAnalysisService();

    // メトロノームを即座に初期化
    _metronome = Metronome();
    _nativeMetronome = NativeMetronome();

    // 位置情報の権限を確認・リクエスト
    _checkLocationPermission();

    // 初期化はデバイス選択後に実施
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDeviceSelectionDialog();
    });

    // 心拍数表示更新タイマー（1秒ごと）
    _heartRateDisplayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recentHeartRates.isNotEmpty && mounted) {
        // 最新の心拍数を使用（平均ではなく最新値）
        setState(() {
          currentHeartRate = _recentHeartRates.last;
          _lastHeartRateUpdate = DateTime.now();
        });
      }
    });
  }

  // 位置情報の権限をチェックしてリクエスト
  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 位置情報サービスが有効かチェック
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocationEnabled = false;
          _locationErrorMessage = '位置情報サービスが無効です。設定から有効にしてください。';
        });
        return;
      }

      // 位置情報の権限をチェック
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 権限がない場合はリクエスト
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLocationEnabled = false;
            _locationErrorMessage = '位置情報の権限が拒否されました。';
          });
          return;
        }
      }

      // 永続的に拒否されている場合
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLocationEnabled = false;
          _locationErrorMessage = '位置情報の権限が永続的に拒否されています。設定から権限を許可してください。';
        });
        return;
      }

      // 位置情報の権限が許可された
      setState(() {
        _isLocationEnabled = true;
        _locationErrorMessage = '';
      });

      // 初期位置を取得
      _getCurrentLocation();
    } catch (e) {
      print('位置情報権限チェックエラー: $e');
      setState(() {
        _isLocationEnabled = false;
        _locationErrorMessage = '位置情報の設定中にエラーが発生しました。';
      });
    }
  }

  // 現在の位置情報を取得
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        print('位置情報取得: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('位置情報取得エラー: $e');
      if (mounted) {
        setState(() {
          _locationErrorMessage = '位置情報の取得に失敗しました。';
        });
      }
    }
  }

  // デバイス選択ダイアログを表示
  Future<void> _showDeviceSelectionDialog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceConnectionScreen(
          onConnectionComplete: (BluetoothDevice? imu, BluetoothDevice? hr) {
            setState(() {
              targetDevice = imu;
              heartRateDevice = hr;
              isConnected = imu != null;
              isHeartRateConnected = hr != null;
            });
            Navigator.pop(context);
            _initializeComponents();
          },
        ),
      ),
    );
  }

  // コンポーネントを初期化する
  Future<void> _initializeComponents() async {
    try {
      // メトロノームサービスの初期化（改善版）
      await _initializeMetronomes();

      // データ入力元の初期化
      if (targetDevice != null) {
        await _setupSerialCommunication();
      }

      // 心拍センサーの初期化
      if (heartRateDevice != null) {
        await _setupHeartRateMonitoring();
      }

      setState(() {}); // UI更新
    } catch (e) {
      print('初期化エラー: $e');
    }
  }

  // スマホの加速度センサーを監視開始
  void _startPhoneSensorStream() {
    _phoneSensorSubscription?.cancel();
    _phoneSensorSubscription = accelerometerEvents.listen((event) {
      final sensorData = M5SensorData(
        device: 'phone',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: 'raw',
        data: {
          'accX': event.x,
          'accY': event.y,
          'accZ': event.z,
        },
      );
      _processSensorData(sensorData);
    });
  }

  // バイブレーションサポートのチェックメソッドは削除して、
  // 単純にHapticFeedbackを使用する実装に変更

  // 音楽の再生/一時停止を切り替える
  Future<void> _togglePlayback() async {
    try {
      if (_useNativeMetronome) {
        try {
          if (_nativeMetronome.isPlaying) {
            await _nativeMetronome.stop();
            if (isRecording && experimentTimer != null) {
              experimentTimer!.cancel();
              experimentTimer = null;
            }
          } else {
            await _nativeMetronome.start(bpm: currentMusicBPM);
            if (isExperimentMode && isRecording) {
              _startExperiment();
            }
          }
        } catch (e) {
          // ネイティブメトロノームでエラーが発生した場合、Dartメトロノームに切り替え
          print('ネイティブメトロノーム操作エラー: $e');
          setState(() {
            _useNativeMetronome = false;
          });
          // Dartメトロノームで再度試行
          if (_metronome.isPlaying) {
            await _metronome.stop();
          } else {
            await _metronome.start(bpm: currentMusicBPM);
            if (isExperimentMode && isRecording) {
              _startExperiment();
            }
          }
        }
      } else {
        if (_metronome.isPlaying) {
          await _metronome.stop();
          if (isRecording && experimentTimer != null) {
            experimentTimer!.cancel();
            experimentTimer = null;
          }
        } else {
          await _metronome.start(bpm: currentMusicBPM);
          if (isExperimentMode && isRecording) {
            _startExperiment();
          }
        }
      }

      // ボタン表示の更新のため、setState呼び出し
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('再生切り替えエラー: $e');
    }
  }

  // テンポを変更する
  Future<void> _changeTempo(MusicTempo tempo) async {
    try {
      if (_useNativeMetronome) {
        try {
          await _nativeMetronome.changeTempo(tempo.bpm);
        } catch (e) {
          // ネイティブメトロノームでエラーが発生した場合、Dartメトロノームに切り替え
          print('ネイティブメトロノームテンポ変更エラー: $e');
          setState(() {
            _useNativeMetronome = false;
          });
          // Dartメトロノームで再度試行
          await _metronome.changeTempo(tempo.bpm);
        }
      } else {
        await _metronome.changeTempo(tempo.bpm);
      }

      // 適切なリストから一致するBPMを持つテンポを探す
      MusicTempo? matchedTempo;

      // 実験モードとメトロノームモードの両方のリストを確認
      for (var t in experimentTempoPresets) {
        if (t.bpm == tempo.bpm) {
          matchedTempo = t;
          break;
        }
      }

      // 見つからなければメトロノームリストも確認
      if (matchedTempo == null) {
        for (var t in metronomeTempoPresets) {
          if (t.bpm == tempo.bpm) {
            matchedTempo = t;
            break;
          }
        }
      }

      // いずれかのリストで見つかったテンポを使用、なければ引数をそのまま使用
      selectedTempo = matchedTempo ?? tempo;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('テンポ変更エラー: $e');
    }
  }

  // 任意のBPM値に音楽テンポを変更する
  Future<void> _changeMusicTempo(double bpm) async {
    try {
      if (_useNativeMetronome) {
        try {
          await _nativeMetronome.changeTempo(bpm);
        } catch (e) {
          // ネイティブメトロノームでエラーが発生した場合、Dartメトロノームに切り替え
          print('ネイティブメトロノームテンポ変更エラー: $e');
          setState(() {
            _useNativeMetronome = false;
          });
          // Dartメトロノームで再度試行
          await _metronome.changeTempo(bpm);
        }
      } else {
        await _metronome.changeTempo(bpm);
      }

      if (mounted) {
        setState(() {
          // 既存のmetronomeTempoPresetsから最も近いものを選択し、
          // 新しいインスタンスを作成しないようにする
          selectedTempo = _findNearestTempoPreset(bpm);
        });
      }
    } catch (e) {
      print('音楽テンポ変更エラー: $e');
    }
  }

  // 実験を開始する（被験者番号入力ダイアログを表示）
  void _startExperimentWithDialog() async {
    if (!_usePhoneSensor && !isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('デバイスに接続してください'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 被験者番号入力ダイアログを表示
    String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String tempSubjectId = '';
        // 現在選択されているテンポをデフォルト値として使用
        MusicTempo tempTempo =
            selectedTempo ?? experimentTempoPresets[2]; // デフォルト 80 BPM
        int tempDuration = experimentDurationSeconds;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('被験者情報'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '被験者番号',
                      hintText: '例: S001',
                    ),
                    onChanged: (value) {
                      tempSubjectId = value;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('テンポ設定（BPM）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<MusicTempo>(
                    value: tempTempo,
                    isExpanded: true,
                    items: experimentTempoPresets.map((tempo) {
                      return DropdownMenuItem<MusicTempo>(
                        value: tempo,
                        child: Text(tempo.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        if (value != null) {
                          // 必ず元のリストのインスタンスを使用
                          tempTempo = experimentTempoPresets
                              .firstWhere((item) => item.bpm == value.bpm);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('記録時間',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<int>(
                    value: tempDuration,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem<int>(value: 5 * 60, child: Text('5分')),
                      DropdownMenuItem<int>(value: 10 * 60, child: Text('10分')),
                      DropdownMenuItem<int>(value: 15 * 60, child: Text('15分')),
                      DropdownMenuItem<int>(value: 20 * 60, child: Text('20分')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        tempDuration = value ?? 5 * 60;
                      });
                    },
                  ),
                  Text('実験時間: ${tempDuration ~/ 60}分 ($tempDuration秒)'),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('開始'),
                onPressed: () {
                  // 入力が空の場合は日時を被験者IDとする
                  if (tempSubjectId.isEmpty) {
                    tempSubjectId =
                        'S${DateFormat('MMddHHmm').format(DateTime.now())}';
                  }
                  // 選択されたテンポと時間を記録（元のリストから取得）
                  selectedTempo = experimentTempoPresets
                      .firstWhere((item) => item.bpm == tempTempo.bpm);
                  experimentDurationSeconds = tempDuration;
                  Navigator.of(context).pop(tempSubjectId);
                },
              ),
            ],
          );
        });
      },
    );

    // ダイアログでキャンセルされた場合
    if (result == null) return;

    // 被験者番号を保存
    subjectId = result;

    // 選択されたテンポに変更
    if (selectedTempo != null) {
      await _changeTempo(selectedTempo!);
    }

    // 実験開始
    _startExperiment();

    // メトロノーム再生開始
    if (!isPlaying) {
      await _metronome.start(bpm: currentMusicBPM);
      if (mounted) {
        setState(() {});
      }
    }
  }

  // 実験を開始する（内部実装）
  void _startExperiment() async {
    // 実験開始時刻を記録
    experimentStartTime = DateTime.now();
    remainingSeconds = experimentDurationSeconds;

    // 実験ファイル名を設定（被験者番号を含める）
    experimentFileName =
        'gait_data_${subjectId}_${selectedTempo?.bpm ?? currentMusicBPM}_target_${DateFormat('yyyyMMdd_HHmmss').format(experimentStartTime!)}';

    // 実験状態をSharedPreferencesに保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_experiment_running', true);
    await prefs.setString('experiment_file_name', experimentFileName);
    await prefs.setString('subject_id', subjectId);
    await prefs.setInt('experiment_duration', experimentDurationSeconds);
    await prefs.setDouble('target_bpm', selectedTempo?.bpm ?? currentMusicBPM);

    // バックグラウンドサービスを開始
    await BackgroundService.startService();

    // 加速度データを高頻度（100ms間隔）で記録するタイマー
    experimentTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // タイマー用カウンター（1秒ごとに更新）
      if (timer.tick % 10 == 0) {
        setState(() {
          remainingSeconds--;

          // 実験終了時の処理
          if (remainingSeconds <= 0) {
            timer.cancel();
            _finishExperiment();
          }
        });
      }

      // 最新の加速度データがあれば記録
      if (latestData != null) {
        _recordExperimentData();
      }
    });

    setState(() {
      isRecording = true;
    });

    print(
        '加速度データの記録を開始しました: $experimentFileName (被験者: $subjectId, $experimentDurationSeconds秒間)');
  }

  // 実験データを記録 (SPMを記録するように変更)
  void _recordExperimentData() {
    // 最新の歩行解析結果を取得
    double detectedSpm = gaitAnalysisService?.currentSpm ?? 0.0; // SPMを取得
    // 信頼度値も取得
    double reliability = gaitAnalysisService?.reliability ?? 0.0;

    // 最新のセンサーデータ
    double? accX = latestData?.accX;
    double? accY = latestData?.accY;
    double? accZ = latestData?.accZ;
    double? magnitude = latestData?.magnitude;

    // デバッグログ
    if (isRecording) {
      print(
          'データ記録中: SPM=${detectedSpm.toStringAsFixed(1)}, 信頼度=${(reliability * 100).toStringAsFixed(1)}%, 加速度=${magnitude?.toStringAsFixed(3) ?? "N/A"}');
    }

    final record = ExperimentRecord(
      timestamp: DateTime.now(),
      targetBPM: currentMusicBPM, // 音楽テンポは targetBPM として記録
      detectedBPM: detectedSpm > 0 ? detectedSpm : null, // 検出されたSPMを記録
      reliability: reliability > 0 ? reliability : null, // 信頼度も記録
      accX: accX,
      accY: accY,
      accZ: accZ,
      magnitude: magnitude,
    );

    if (mounted) {
      setState(() {
        experimentRecords.add(record);

        // Update graph data if SPM is valid
        if (detectedSpm > 0) {
          final time = (experimentRecords.length).toDouble(); // X軸はレコード数
          // bpmSpotsをspmSpotsに変更検討 or そのままBPMとしてプロット
          bpmSpots.add(FlSpot(time, detectedSpm));

          // Y軸の範囲を調整 (40-160 SPM程度を想定)
          if (detectedSpm < minY) minY = detectedSpm - 10;
          if (detectedSpm > maxY) maxY = detectedSpm + 10;
          if (minY < 40) minY = 40;
          if (maxY > 180) maxY = 180;
        }
      });
    }
  }

  // グラフデータを更新
  void _updateGraphData() {
    if (latestData == null || latestData!.type != 'bpm') return;

    final time = (experimentRecords.length).toDouble();
    final bpm = latestData!.bpm!;

    setState(() {
      bpmSpots.add(FlSpot(time, bpm));

      // Y軸の範囲を調整
      if (bpm < minY) minY = bpm - 5;
      if (bpm > maxY) maxY = bpm + 5;
    });
  }

  // 実験を終了する
  void _finishExperiment() async {
    if (!isRecording) return;

    // 実験状態をSharedPreferencesから削除
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_experiment_running', false);

    // バックグラウンドサービスを停止
    await BackgroundService.stopService();

    setState(() {
      isRecording = false;
      remainingSeconds = 0;
    });

    print(
        '実験記録を終了しました: $experimentFileName (${experimentRecords.length}件のデータ)');

    // 音声を停止
    if (isPlaying) {
      await _metronome.stop();
      if (mounted) {
        setState(() {});
      }
    }

    // CSVに変換してローカルに保存
    String csvData = await _saveExperimentDataToCSV();

    // Azureにデータをアップロード
    try {
      await _uploadDataToAzure(csvData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('データがAzureに自動アップロードされました'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Azureアップロードエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Azureへのアップロードに失敗しました: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // 実験データをクリア
    experimentRecords.clear();
    bpmSpots.clear();
    minY = 40;
    maxY = 160;
  }

  // 実験データをCSVに保存し、データを返す
  Future<String> _saveExperimentDataToCSV() async {
    if (experimentRecords.isEmpty) {
      print('保存するデータがありません');
      return '';
    }

    try {
      // CSVヘッダー
      List<List<dynamic>> csvData = [
        [
          'Timestamp',
          'TargetBPM',
          'DetectedBPM',
          'Reliability',
          'AccX',
          'AccY',
          'AccZ',
          'Magnitude'
        ]
      ];

      // データ行を追加
      for (var record in experimentRecords) {
        csvData.add(record.toCSV());
      }

      // CSVに変換
      String csv = const ListToCsvConverter().convert(csvData);

      // 保存先ディレクトリを取得
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$experimentFileName.csv';
      final file = File(path);

      // ファイルに書き込み
      await file.writeAsString(csv);
      print('ファイルに保存しました: $path');

      return csv;
    } catch (e) {
      print('CSV保存エラー: $e');
      rethrow;
    }
  }

  // Azureにデータをアップロード
  Future<void> _uploadDataToAzure(String csvData) async {
    if (csvData.isEmpty) {
      print('アップロードするデータがありません');
      return;
    }

    try {
      print('===== Azureアップロードを開始します =====');
      print('アカウント名: $azureStorageAccount');
      print('コンテナ名: $containerName');
      print('ファイル名: $experimentFileName.csv');
      print('SASトークン長: ${azureSasToken.length}文字');

      // アップロードをリトライするメソッド
      bool uploaded = false;
      int retries = 0;
      const maxRetries = 3;

      while (!uploaded && retries < maxRetries) {
        try {
          // 接続方法1: SAS Tokenを使う
          if (azureSasToken.isNotEmpty) {
            // 修正: HTTP直接リクエストを使用する方法に変更
            try {
              // SASトークンの先頭に?があれば削除
              String sasToken = azureSasToken;
              if (sasToken.startsWith('?')) {
                sasToken = sasToken.substring(1); // 先頭の?を削除
              }

              print(
                  '処理済みSASトークン（最初の10文字）: ${sasToken.substring(0, math.min(10, sasToken.length))}...');

              // 直接HTTPリクエストを使用してアップロード
              final accountName = azureStorageAccount;
              final blobName = '$experimentFileName.csv';

              // URIを構築
              final uri = Uri.parse(
                  'https://$accountName.blob.core.windows.net/$containerName/$blobName?$sasToken');

              print('アップロードURL: $uri');

              final headers = {
                'x-ms-blob-type': 'BlockBlob',
                'Content-Type': 'text/csv',
              };

              final bytes = utf8.encode(csvData);
              print('アップロードデータサイズ: ${bytes.length} バイト');

              final response = await http.put(
                uri,
                headers: headers,
                body: bytes,
              );

              if (response.statusCode == 201) {
                print('BLOBが正常にアップロードされました！（HTTP直接リクエスト使用）');
                print(
                    'レスポンス: ${response.statusCode} - ${response.reasonPhrase}');
                uploaded = true;
              } else {
                print(
                    'HTTP直接アップロードエラー: ${response.statusCode} - ${response.reasonPhrase}');
                print('レスポンス本文: ${response.body}');
                retries++;
              }
            } catch (uploadError) {
              print('SAS Tokenアップロードエラー: $uploadError');
              if (uploadError.toString().contains('Blob')) {
                print('Blobエラーの詳細情報: ${uploadError.toString()}');
              }
              retries++;
            }
          }
          // 接続方法2: 接続文字列を使う
          else if (azureConnectionString.isNotEmpty) {
            final headers = {
              'x-ms-blob-type': 'BlockBlob',
              'Content-Type': 'text/csv',
            };

            final Uri uri = Uri.parse(
                'https://$azureStorageAccount.blob.core.windows.net/$containerName/$experimentFileName.csv');

            final response =
                await http.put(uri, headers: headers, body: csvData);

            if (response.statusCode == 201) {
              print('BLOBが正常にアップロードされました！（接続文字列使用）');
              uploaded = true;
            } else {
              print(
                  '接続文字列アップロードエラー: ${response.statusCode} - ${response.reasonPhrase}');
              retries++;
            }
          } else {
            throw Exception('Azure接続情報が設定されていません');
          }
        } catch (e) {
          print('Azureアップロード試行エラー ($retries): $e');
          retries++;
          await Future.delayed(const Duration(seconds: 2)); // リトライ前に待機
        }
      }

      if (!uploaded) {
        throw Exception('$maxRetries回リトライ後も失敗しました');
      }
    } catch (e) {
      print('Azureアップロードエラー: $e');
      rethrow;
    }
  }

  // GMT形式の日付文字列を取得
  String _getGMTRequestDate() {
    final now = DateTime.now().toUtc();
    final weekday =
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][now.weekday - 1];
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][now.month - 1];
    return '$weekday, ${now.day.toString().padLeft(2, '0')} $month ${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} GMT';
  }

  // 記録ボタンのビルド
  Widget _buildRecordingButton() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: ElevatedButton.icon(
        icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
        label: Text(isRecording ? '記録終了' : '記録開始'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isRecording ? AppColors.error : AppColors.success,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onPressed: !isConnected
            ? null
            : () {
                if (isRecording) {
                  _finishExperiment();
                } else {
                  _startExperimentWithDialog(); // ダイアログ表示バージョンを使用
                }
              },
      ),
    );
  }

  @override
  void dispose() {
    // ウィジェット破棄の際の安全な処理
    _isDisposing = true;

    // すべてのストリームサブスクリプションをキャンセル
    for (var subscription in _streamSubscriptions) {
      subscription.cancel();
    }
    _streamSubscriptions.clear();

    // スマホセンサーストリームの停止
    _phoneSensorSubscription?.cancel();

    // オーディオプレーヤーの解放
    // _audioPlayer.dispose();

    // タイマーの解放
    if (experimentTimer != null) {
      experimentTimer!.cancel();
    }

    // 心拍数表示タイマーの解放
    _heartRateDisplayTimer?.cancel();

    // 切断処理
    disconnect().then((_) {
      super.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('Gait Analysis App'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // 被験者IDが設定されている場合は表示
          if (subjectId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '被験者ID: $subjectId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          // 被験者ID設定ボタン
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '被験者IDを設定',
            onPressed: _showSubjectIdDialog,
          ),

          // 新しい実験画面へのボタンを追加
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: '新実験モード',
            onPressed: () {
              if (gaitAnalysisService != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExperimentScreen(
                      gaitAnalysisService: gaitAnalysisService!,
                      metronome: _metronome,
                      nativeMetronome: _nativeMetronome,
                      useNativeMetronome: _useNativeMetronome,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('初期化中です。しばらくお待ちください。'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 位置情報エラーメッセージ
          if (_locationErrorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.warning.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationErrorMessage,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // Bluetooth接続ステータス - 常に表示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: (isConnected && isHeartRateConnected)
                ? AppColors.success.withOpacity(0.1)
                : (isConnected || isHeartRateConnected)
                    ? AppColors.warning.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
            child: Row(
              children: [
                // IMU接続状態
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  isConnected ? 'IMU' : 'IMU未接続',
                  style: TextStyle(
                    color: isConnected ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                // 心拍センサー接続状態
                Icon(
                  isHeartRateConnected ? Icons.favorite : Icons.favorite_border,
                  color: isHeartRateConnected
                      ? AppColors.success
                      : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  isHeartRateConnected ? '心拍' : '心拍未接続',
                  style: TextStyle(
                    color: isHeartRateConnected
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    _showDeviceSelectionDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                        color: AppColors.borderLight, width: 1),
                  ),
                  child: Text(isConnected ? '再接続' : 'スキャン'),
                ),
              ],
            ),
          ),

          // メインコンテンツ - Expandedで残りの空間を使う
          Expanded(
            child: isRealExperimentMode
                ? _buildRealExperimentModeUI() // 本実験モードUI
                : (isExperimentMode
                    ? _buildSilentDataCollectionModeUI() // 無音データ収集モードUI（修正）
                    : _buildDataMonitorModeUI()), // モニターモードUI
          ),

          // モード切り替えボタン - 常に下部に表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textTertiary.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(isExperimentMode
                      ? Icons.monitor_heart_outlined
                      : Icons.mic_off_outlined),
                  label: Text(isExperimentMode ? 'モニターモードに戻る' : '無音データ収集モード'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isExperimentMode ? AppColors.accent : AppColors.warning,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    // 被験者IDが空の場合は、まず被験者IDを入力するダイアログを表示
                    if (!isExperimentMode && subjectId.isEmpty) {
                      _showSubjectIdDialog(afterIdSet: () {
                        _toggleExperimentMode();
                      });
                    } else {
                      _toggleExperimentMode();
                    }
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.psychology_outlined),
                  label: Text(isRealExperimentMode ? '通常モードに戻る' : '本実験モードへ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRealExperimentMode
                        ? AppColors.accent
                        : AppColors.accentDark,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    // 被験者IDが空の場合は、まず被験者IDを入力するダイアログを表示
                    if (!isRealExperimentMode && subjectId.isEmpty) {
                      _showSubjectIdDialog(afterIdSet: () {
                        _toggleRealExperimentMode();
                      });
                    } else {
                      _toggleRealExperimentMode();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  } // This closes the build() method

  // 本実験を初期化する
  void _initializeRealExperiment() {
    // フェーズを初期状態にリセット
    currentPhase = ExperimentPhase.freeWalking;
    phaseStableSeconds = 0;
    baseWalkingPitch = 0.0;
    targetPitch = 0.0;
    phaseStartTime = DateTime.now();
    recentPitches.clear();
    isPitchStable = false;
    stableCountdown = 0;
    pitchIncreaseCount = 0;
    lastPitchChangeTime = null;

    // 時系列データをリセット
    realExperimentTimeSeriesData.clear();

    // 通知を表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('自由歩行フェーズを開始しました。自然に歩いてください。'),
        duration: Duration(seconds: 3),
      ),
    );

    // 定期的に歩行ピッチをチェックするタイマーを開始
    pitchAdjustmentTimer?.cancel();
    pitchAdjustmentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateExperimentPhase();
    });

    // 定期的に時系列データを記録するタイマーを開始（2秒ごと）
    timeSeriesDataTimer?.cancel();
    timeSeriesDataTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _recordTimeSeriesData();
    });
  }

  // 本実験を終了する
  void _stopRealExperiment() {
    // 音楽を停止
    if (isPlaying) {
      _metronome.stop();
    }

    // タイマーをキャンセル
    pitchAdjustmentTimer?.cancel();
    pitchAdjustmentTimer = null;

    timeSeriesDataTimer?.cancel();
    timeSeriesDataTimer = null;

    // 実験データが存在する場合、保存してAzureにアップロード
    if (realExperimentTimeSeriesData.isNotEmpty) {
      _saveAndUploadRealExperimentData();
    }

    // 通知を表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('実験を終了しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 時系列データを記録
  void _recordTimeSeriesData() {
    // 現在の実験フェーズ名を取得（英語で）
    String phaseNameEn = _getPhaseNameInEnglish();

    // 位置情報が設定されていない場合は取得を試みる
    if (_isLocationEnabled && _currentPosition == null) {
      _getCurrentLocation();
    }

    // 適応制御の状態を取得
    final controlStatus = _adaptiveTempoController.getControlStatus();

    // 現在のデータポイントを記録
    realExperimentTimeSeriesData.add({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'phase': phaseNameEn,
      'targetBPM': targetPitch > 0 ? targetPitch : 0.0,
      'currentSPM': _displaySpm > 0 ? _displaySpm : 0.0,
      'cv': _currentCV,
      'stabilityScore': controlStatus['stabilityScore'] ?? 0.0,
      'responsivenessScore': controlStatus['responsivenessScore'] ?? 0.0,
      'phaseStableSeconds': phaseStableSeconds,
      'pitchIncreaseCount': pitchIncreaseCount,
      'isPlaying': isPlaying,
      'remainingSeconds': remainingSeconds,
      'latitude': _currentPosition?.latitude,
      'longitude': _currentPosition?.longitude,
      'altitude': _currentPosition?.altitude,
      'speed': _currentPosition?.speed,
    });

    print('Time series data recorded: ${realExperimentTimeSeriesData.length}, '
        'Phase=$phaseNameEn, '
        'TargetBPM=${targetPitch > 0 ? targetPitch.toStringAsFixed(1) : "N/A"}, '
        'CurrentSPM=${_displaySpm > 0 ? _displaySpm.toStringAsFixed(1) : "N/A"}');
  }

  // フェーズ名を英語で取得
  String _getPhaseNameInEnglish() {
    switch (currentPhase) {
      case ExperimentPhase.freeWalking:
        return 'Free Walking';
      case ExperimentPhase.pitchAdjustment:
        return 'Pitch Adjustment';
      case ExperimentPhase.pitchIncreasing:
        return 'Pitch Increasing';
      default:
        return 'Unknown';
    }
  }

  // 本実験データをCSV形式で保存してAzureにアップロードする
  Future<void> _saveAndUploadRealExperimentData() async {
    try {
      // ファイル名を設定
      final fileName =
          'real_experiment_${subjectId.isEmpty ? 'unknown' : subjectId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      // 最大のピッチ増加回数を記録（最大到達BPM）
      final maxReachedBpm = pitchIncreaseCount > 0
          ? baseWalkingPitch + (pitchIncreaseCount * pitchIncrementStep)
          : baseWalkingPitch;

      // 時系列データが空の場合は処理を中止
      if (realExperimentTimeSeriesData.isEmpty) {
        print('Time series data is empty');
        return;
      }

      // 時系列データのCSVヘッダー
      List<List<dynamic>> timeSeriesCSV = [];

      // メタデータ行（実験の概要情報）
      timeSeriesCSV.add([
        '# Experiment_Summary',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ]);

      timeSeriesCSV.add([
        '# Subject_ID',
        '# Experiment_DateTime',
        '# Base_Pitch_BPM',
        '# Max_Reached_BPM',
        '# Pitch_Increase_Count',
        '# Pitch_Increment_Step_BPM',
        '# Experiment_Duration_Sec',
        '# Phase_Stability_Time_Sec',
        '# Data_Points_Count',
      ]);

      timeSeriesCSV.add([
        subjectId.isEmpty ? 'unknown' : subjectId,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        baseWalkingPitch.toStringAsFixed(1),
        maxReachedBpm.toStringAsFixed(1),
        pitchIncreaseCount,
        pitchIncrementStep.toStringAsFixed(1),
        phaseStartTime != null
            ? DateTime.now().difference(phaseStartTime!).inSeconds
            : 0,
        stableThresholdSeconds,
        realExperimentTimeSeriesData.length,
      ]);

      // 空行を追加してデータ部分と分ける
      timeSeriesCSV.add([
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ]);

      // ヘッダー行
      timeSeriesCSV.add([
        'Timestamp_Unix',
        'Timestamp_Readable',
        'Elapsed_Time_Sec',
        'Phase',
        'Target_BPM',
        'Walking_SPM',
        'CV_Percent',
        'Stability_Score',
        'Responsiveness_Score',
        'Stability_Time_Sec',
        'Pitch_Increase_Count',
        'Audio_Playback',
        'Latitude',
        'Longitude',
        'Altitude',
        'Speed',
      ]);

      // 最初のタイムスタンプを基準にする
      int firstTimestamp = realExperimentTimeSeriesData.first['timestamp'];

      // データ行を追加
      for (var dataPoint in realExperimentTimeSeriesData) {
        int timestamp = dataPoint['timestamp'];
        double elapsedSeconds = (timestamp - firstTimestamp) / 1000.0;

        timeSeriesCSV.add([
          timestamp, // Unix timestamp (milliseconds)
          DateFormat('yyyy-MM-dd HH:mm:ss.SSS')
              .format(DateTime.fromMillisecondsSinceEpoch(timestamp)),
          elapsedSeconds.toStringAsFixed(1),
          dataPoint['phase'],
          dataPoint['targetBPM'].toStringAsFixed(1),
          dataPoint['currentSPM'].toStringAsFixed(1),
          (dataPoint['cv'] * 100).toStringAsFixed(2),
          dataPoint['stabilityScore'].toStringAsFixed(3),
          dataPoint['responsivenessScore'].toStringAsFixed(3),
          dataPoint['phaseStableSeconds'],
          dataPoint['pitchIncreaseCount'],
          dataPoint['isPlaying'] ? 'Playing' : 'Stopped',
          dataPoint['latitude'] != null
              ? dataPoint['latitude'].toString()
              : 'N/A',
          dataPoint['longitude'] != null
              ? dataPoint['longitude'].toString()
              : 'N/A',
          dataPoint['altitude'] != null
              ? dataPoint['altitude'].toString()
              : 'N/A',
          dataPoint['speed'] != null ? dataPoint['speed'].toString() : 'N/A',
        ]);
      }

      // 時系列CSVに変換
      String timeSeriesCsv = const ListToCsvConverter().convert(timeSeriesCSV);

      // 時系列ファイルに保存
      final directory = await getApplicationDocumentsDirectory();
      final dataPath = '${directory.path}/$fileName.csv';
      final dataFile = File(dataPath);
      await dataFile.writeAsString(timeSeriesCsv, encoding: utf8);
      print('Experiment data saved to file: $dataPath');

      // Azureにアップロード
      try {
        // データをアップロード
        String originalFileName = experimentFileName;
        experimentFileName = fileName;
        await _uploadDataToAzure(timeSeriesCsv);
        experimentFileName = originalFileName; // 元に戻す

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Experiment data uploaded to Azure'),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        print('Azure upload error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload to Azure: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Save basic analysis results locally
      try {
        final summaryPath = await saveSpmAnalysis(
          timeSeriesData: realExperimentTimeSeriesData,
          subjectId: subjectId,
          filePrefix: fileName,
        );
        print('Analysis summary saved to: $summaryPath');
      } catch (e) {
        print('Failed to save analysis summary: $e');
      }
    } catch (e) {
      print('Error saving experiment data: $e');
    }
  }

  // 実験フェーズを更新する
  void _updateExperimentPhase() {
    if (!mounted) return;

    // 現在の歩行ピッチを取得
    double currentPitch = gaitAnalysisService?.currentSpm ?? 0.0;

    // 有効な歩行ピッチがない場合はスキップ
    if (currentPitch <= 0) return;

    // 最近のピッチに追加
    recentPitches.add(currentPitch);
    if (recentPitches.length > 10) {
      // 直近10秒分のデータを保持
      recentPitches.removeAt(0);
    }

    setState(() {
      switch (currentPhase) {
        case ExperimentPhase.freeWalking:
          _handleFreeWalkingPhase(currentPitch);
          break;
        case ExperimentPhase.pitchAdjustment:
          _handlePitchAdjustmentPhase(currentPitch);
          break;
        case ExperimentPhase.pitchIncreasing:
          _handlePitchIncreasingPhase(currentPitch);
          break;
      }
    });
  }

  // 自由歩行フェーズの処理
  void _handleFreeWalkingPhase(double currentPitch) {
    // フェーズの経過時間を計算
    final elapsedSeconds = DateTime.now().difference(phaseStartTime!).inSeconds;

    // フェーズの残り時間
    remainingSeconds = freeWalkingDurationSeconds - elapsedSeconds;

    // ストライド間隔を計算して履歴に追加
    if (_lastStepTime != null) {
      final interval =
          DateTime.now().difference(_lastStepTime!).inMilliseconds / 1000.0;
      if (interval > 0.3 && interval < 1.5) {
        // 妥当な間隔のみ
        _strideIntervals.add(interval);
        if (_strideIntervals.length > 30) {
          _strideIntervals.removeAt(0);
        }
        // CVを計算
        if (_strideIntervals.length >= 5) {
          _currentCV = GaitStabilityAnalyzer.calculateCV(_strideIntervals);

          // CV履歴に追加（グラフ表示用）
          _cvHistory.add(_currentCV);
          if (_cvHistory.length > 60) {
            // 最大60データポイント（約2分間）
            _cvHistory.removeAt(0);
          }
        }
      }
    }
    _lastStepTime = DateTime.now();

    // フェーズ終了判定
    if (elapsedSeconds >= freeWalkingDurationSeconds) {
      // 過去10秒間の平均歩行ピッチを計算
      if (recentPitches.isNotEmpty) {
        baseWalkingPitch =
            recentPitches.reduce((a, b) => a + b) / recentPitches.length;
        baseWalkingPitch = (baseWalkingPitch / 5).round() * 5.0; // 5の倍数に丸める
        targetPitch = baseWalkingPitch;

        // 適応的テンポ制御を初期化
        _adaptiveTempoController.initialize(baseWalkingPitch);

        // 次のフェーズに移行
        currentPhase = ExperimentPhase.pitchAdjustment;
        phaseStartTime = DateTime.now();

        // 音楽テンポを設定して再生開始
        _changeMusicTempo(targetPitch);
        if (!isPlaying) {
          _metronome.start(bpm: targetPitch);
        }

        print('自由歩行フェーズ終了: 基準ピッチ=$baseWalkingPitch BPM');

        // 通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ピッチ調整フェーズに移行しました。BPM: ${baseWalkingPitch.toStringAsFixed(1)}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ピッチ調整フェーズの処理
  void _handlePitchAdjustmentPhase(double currentPitch) {
    // ストライド間隔を更新
    if (_lastStepTime != null) {
      final interval =
          DateTime.now().difference(_lastStepTime!).inMilliseconds / 1000.0;
      if (interval > 0.3 && interval < 1.5) {
        _strideIntervals.add(interval);
        if (_strideIntervals.length > 30) {
          _strideIntervals.removeAt(0);
        }
        if (_strideIntervals.length >= 5) {
          _currentCV = GaitStabilityAnalyzer.calculateCV(_strideIntervals);

          // CV履歴に追加（グラフ表示用）
          _cvHistory.add(_currentCV);
          if (_cvHistory.length > 60) {
            // 最大60データポイント（約2分間）
            _cvHistory.removeAt(0);
          }
        }
      }
    }
    _lastStepTime = DateTime.now();

    // 適応的テンポ制御で目標SPMを更新
    final adaptedTargetSpm = _adaptiveTempoController.updateTargetSpm(
      currentSpm: currentPitch,
      currentCv: _currentCV,
      timestamp: DateTime.now(),
    );

    // 微細な調整のみ行う（無意識的な誘導）
    if ((adaptedTargetSpm - targetPitch).abs() > 0.5) {
      targetPitch = adaptedTargetSpm;
      _changeMusicTempo(targetPitch);
    }

    // 現在のピッチと目標ピッチの差を計算
    final pitchDifference = (currentPitch - targetPitch).abs();

    // ピッチの差が閾値以内か確認
    final isCloseToTarget = pitchDifference < 5.0;

    // ピッチが目標に近い場合、安定カウンターを増加
    if (isCloseToTarget) {
      phaseStableSeconds++;

      // 安定した状態が続いたら次のフェーズへ
      if (phaseStableSeconds >= stableThresholdSeconds) {
        currentPhase = ExperimentPhase.pitchIncreasing;
        phaseStartTime = DateTime.now();
        phaseStableSeconds = 0;

        // 適応的制御で次の目標を設定
        targetPitch = _adaptiveTempoController.getNextIncreasedTarget();
        _changeMusicTempo(targetPitch);

        print(
            'ピッチ調整フェーズ終了: 次のピッチ目標=$targetPitch BPM, CV=${_currentCV.toStringAsFixed(3)}');

        // 通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ピッチ増加フェーズに移行しました。新しいBPM: ${targetPitch.toStringAsFixed(1)}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      // 安定していない場合、カウンターをリセット
      phaseStableSeconds = 0;
    }
  }

  // ピッチ増加フェーズの処理
  void _handlePitchIncreasingPhase(double currentPitch) {
    // 現在のピッチと目標ピッチの差を計算
    final pitchDifference = currentPitch - targetPitch;

    // ピッチの差が閾値以内か確認
    final isCloseToTarget = pitchDifference.abs() < 5.0;

    // ピッチ差が大きく、ユーザーが追従できていない場合
    if (pitchDifference < -10.0 &&
        (lastPitchChangeTime == null ||
            DateTime.now().difference(lastPitchChangeTime!).inSeconds >= 10)) {
      // ピッチを下げる
      targetPitch -= pitchIncrementStep;
      _changeMusicTempo(targetPitch);
      lastPitchChangeTime = DateTime.now();
      phaseStableSeconds = 0;

      print('ピッチ減少: ユーザーがついていけないため $targetPitch BPM に下げました');

      // 通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('テンポを下げました: ${targetPitch.toStringAsFixed(1)} BPM'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    // ピッチが目標に近い場合、安定カウンターを増加
    else if (isCloseToTarget) {
      phaseStableSeconds++;

      // 安定した状態が30秒続いたら次のピッチ目標へ
      if (phaseStableSeconds >= stableThresholdSeconds) {
        // 次のピッチ目標を設定（5 BPM増加）
        targetPitch += pitchIncrementStep;
        _changeMusicTempo(targetPitch);
        lastPitchChangeTime = DateTime.now();
        phaseStableSeconds = 0;
        pitchIncreaseCount++;

        print('ピッチ増加: 次のピッチ目標=$targetPitch BPM ($pitchIncreaseCount回目)');

        // 通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('テンポを上げました: ${targetPitch.toStringAsFixed(1)} BPM'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // 安定していない場合、カウンターをリセット
      phaseStableSeconds = 0;
    }
  }

  // 本実験モードのUIを構築
  Widget _buildRealExperimentModeUI() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 実験フェーズ情報カード
            Card(
              elevation: 4,
              color: _getPhaseColor(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(_getPhaseIcon(), color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _getPhaseName(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: _showExperimentSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPhaseInfoContent(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 歩行ピッチ情報カード
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_walk, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '歩行ピッチ情報',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '現在のピッチ:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_displaySpm > 0 ? _displaySpm.toStringAsFixed(1) : "--"} SPM',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '目標ピッチ:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${targetPitch > 0 ? targetPitch.toStringAsFixed(1) : "--"} BPM',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: targetPitch > 0
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: targetPitch > 0 && _displaySpm > 0
                          ? math.min(1.0, _displaySpm / targetPitch)
                          : 0.0,
                      backgroundColor: Colors.grey.shade200,
                      color: _getPitchProgressColor(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (phaseStableSeconds > 0)
                          Text(
                            '安定: $phaseStableSeconds / $stableThresholdSeconds 秒',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 音楽再生コントロールカード
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.music_note, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          '音楽コントロール',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '現在のテンポ: ${currentMusicBPM.toStringAsFixed(1)} BPM',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon:
                              Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          label: Text(isPlaying ? '一時停止' : '再生'),
                          onPressed: currentPhase == ExperimentPhase.freeWalking
                              ? null
                              : _togglePlayback,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isPlaying ? Colors.orange : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SPM推移グラフ
            if (bpmSpots.length > 1)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timeline, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'SPM推移グラフ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) =>
                                      Text(value.toInt().toString()),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 5000,
                                  getTitlesWidget: (value, meta) {
                                    final dt =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            value.toInt());
                                    return Text(
                                        DateFormat('HH:mm:ss').format(dt));
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            minX: bpmSpots.first.x,
                            maxX: bpmSpots.last.x,
                            minY: minY,
                            maxY: maxY,
                            lineBarsData: [
                              // 検出SPM
                              LineChartBarData(
                                spots: bpmSpots,
                                isCurved: false,
                                color: Colors.blue,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                              ),
                              // 目標BPM（直線）
                              if (targetPitch > 0)
                                LineChartBarData(
                                  spots: [
                                    FlSpot(bpmSpots.first.x, targetPitch),
                                    FlSpot(bpmSpots.last.x, targetPitch),
                                  ],
                                  color: Colors.red.withOpacity(0.7),
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  dashArray: [5, 5],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // フェーズに応じたカラーを取得
  Color _getPhaseColor() {
    switch (currentPhase) {
      case ExperimentPhase.freeWalking:
        return AppColors.accent;
      case ExperimentPhase.pitchAdjustment:
        return AppColors.info;
      case ExperimentPhase.pitchIncreasing:
        return AppColors.accentDark;
    }
  }

  // フェーズに応じたアイコンを取得
  IconData _getPhaseIcon() {
    switch (currentPhase) {
      case ExperimentPhase.freeWalking:
        return Icons.directions_walk;
      case ExperimentPhase.pitchAdjustment:
        return Icons.sync;
      case ExperimentPhase.pitchIncreasing:
        return Icons.trending_up;
    }
  }

  // フェーズ名を取得
  String _getPhaseName() {
    switch (currentPhase) {
      case ExperimentPhase.freeWalking:
        return '自由歩行フェーズ';
      case ExperimentPhase.pitchAdjustment:
        return 'ピッチ調整フェーズ';
      case ExperimentPhase.pitchIncreasing:
        return 'ピッチ増加フェーズ';
    }
  }

  // フェーズ情報コンテンツを構築
  Widget _buildPhaseInfoContent() {
    switch (currentPhase) {
      case ExperimentPhase.freeWalking:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '自由に歩いてください。後半10秒間の歩行ピッチを計測します。',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '残り時間: $remainingSeconds 秒',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 1 - (remainingSeconds / freeWalkingDurationSeconds),
              backgroundColor: Colors.white.withOpacity(0.3),
              color: Colors.white,
            ),
          ],
        );
      case ExperimentPhase.pitchAdjustment:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ピッチを音楽に合わせてください。1分間安定したら次のフェーズに移行します。',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (phaseStableSeconds > 0)
              LinearProgressIndicator(
                value: phaseStableSeconds / stableThresholdSeconds,
                backgroundColor: Colors.white.withOpacity(0.3),
                color: Colors.white,
              ),
          ],
        );
      case ExperimentPhase.pitchIncreasing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ピッチを音楽に合わせてください。1分間安定したら次のピッチレベルに進みます。',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'ピッチ上昇回数: $pitchIncreaseCount 回',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (phaseStableSeconds > 0)
              LinearProgressIndicator(
                value: phaseStableSeconds / stableThresholdSeconds,
                backgroundColor: Colors.white.withOpacity(0.3),
                color: Colors.white,
              ),
          ],
        );
    }
  }

  // ピッチ進捗に応じた色を取得
  Color _getPitchProgressColor() {
    if (_displaySpm <= 0 || targetPitch <= 0) return Colors.grey;

    double ratio = _displaySpm / targetPitch;
    if (ratio > 1.05) return Colors.red; // 5%以上超過
    if (ratio > 0.95) return Colors.green; // ±5%以内
    if (ratio > 0.85) return Colors.orange; // 5〜15%不足
    return Colors.red; // 15%以上不足
  }

  // 実験設定ダイアログを表示
  void _showExperimentSettings() {
    showDialog(
      context: context,
      builder: (context) {
        int tempFreeWalkingDuration = freeWalkingDurationSeconds;
        int tempStableThreshold = stableThresholdSeconds;
        double tempPitchDifferenceThreshold = pitchDifferenceThreshold;
        double tempPitchIncrementStep = pitchIncrementStep;
        bool tempUseVibration = useVibration; // バイブレーション設定

        return AlertDialog(
          title: const Text('実験設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 既存の設定項目

                // ... 他の設定 ...

                const SizedBox(height: 16),

                // バイブレーション設定
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('バイブレーション',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: tempUseVibration,
                      onChanged: (value) {
                        setState(() {
                          tempUseVibration = value;
                        });
                      },
                    ),
                  ],
                ),
                const Text('音と一緒に振動フィードバックを提供します'),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  freeWalkingDurationSeconds = tempFreeWalkingDuration;
                  stableThresholdSeconds = tempStableThreshold;
                  pitchDifferenceThreshold = tempPitchDifferenceThreshold;
                  pitchIncrementStep = tempPitchIncrementStep;
                  useVibration = tempUseVibration;

                  // メトロノームにバイブレーション設定を反映
                  _metronome.setVibration(useVibration);
                });
                Navigator.of(context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // データモニターモードのUIを構築 (未使用のため削除)

  // 信頼性インジケーターを構築 (未使用のため削除)

  // 加速度データの列を構築
  Widget _buildAccelDataColumn(String title, double? value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value != null ? value.toStringAsFixed(3) : "--",
          style: TextStyle(
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          "G",
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ジャイロセンサーデータの列を構築
  Widget _buildGyroDataColumn(String title, double? value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value != null ? value.toStringAsFixed(3) : "--",
          style: TextStyle(
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          "deg/s",
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // 情報行を構築
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 実験モードのUIを構築
  Widget _buildExperimentMode() {
    return Column(
      children: [
        // 実験設定
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.science, color: Colors.amber),
                    SizedBox(width: 8),
                    Text(
                      '加速度データ収集',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '加速度データを記録して後から解析することができます。100ミリ秒ごとに3軸の加速度データとBPM情報を記録します。',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  '音声テンポの設定はファイル名と保存データに記録されます。実験目的に合わせたテンポを選択してください。',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('実験時間: '),
                        DropdownButton<int>(
                          value: experimentDurationSeconds,
                          items: [30, 60, 120, 180, 300].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                  '${value ~/ 60 > 0 ? "${value ~/ 60}分" : ""}${value % 60 > 0 ? "${value % 60}秒" : ""}'),
                            );
                          }).toList(),
                          onChanged: isRecording
                              ? null
                              : (int? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      experimentDurationSeconds = newValue;
                                      remainingSeconds = newValue;
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                    Text(
                      '推定サイズ: ${_estimateFileSize()}',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('音声テンポ: '),
                        DropdownButton<MusicTempo>(
                          value: selectedTempo,
                          items: experimentTempoPresets.map((tempo) {
                            return DropdownMenuItem<MusicTempo>(
                              value: tempo,
                              child: Text(tempo.name),
                            );
                          }).toList(),
                          onChanged: isRecording || isPlaying
                              ? null
                              : (MusicTempo? newTempo) {
                                  if (newTempo != null) {
                                    _changeTempo(newTempo);
                                  }
                                },
                        ),
                        if (isRecording || isPlaying)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Tooltip(
                              message: isPlaying
                                  ? '再生中はテンポを変更できません。一時停止してから変更してください。'
                                  : '記録中はテンポを変更できません。',
                              child: const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // 現在のBPM値を表示
                    Text(
                      '現在: ${currentMusicBPM.toStringAsFixed(1)} BPM',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(isPlaying ? "一時停止" : "再生"),
                      onPressed: _togglePlayback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isPlaying ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(
                          isRecording ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(isRecording ? "記録停止" : "記録開始"),
                      onPressed: latestData == null ? null : _toggleRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRecording ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 残り時間表示（記録中のみ）
        if (isRecording && experimentTimer != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.amber.shade50,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: remainingSeconds / experimentDurationSeconds,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "残り時間: $remainingSeconds 秒",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "記録データ: ${experimentRecords.length} 行",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // スクロール可能なデータ表示部分
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // BPMトラッキンググラフ
                if (bpmSpots.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.timeline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'SPM推移グラフ', // ラベル変更
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) =>
                                          Text(value.toInt().toString()),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: 5000, // 5秒ごと
                                      getTitlesWidget: (value, meta) {
                                        final dt =
                                            DateTime.fromMillisecondsSinceEpoch(
                                                value.toInt());
                                        return Text(
                                            DateFormat('HH:mm:ss').format(dt));
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: true),
                                minX: 0, // 実験開始からの時間 or レコード数
                                maxX: bpmSpots.length.toDouble(),
                                minY: minY,
                                maxY: maxY,
                                lineBarsData: [
                                  // 検出SPM
                                  LineChartBarData(
                                    spots: bpmSpots,
                                    isCurved: false,
                                    color: Colors.blue,
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                  ),
                                  // ターゲットBPM (直線)
                                  if (targetPitch > 0)
                                    LineChartBarData(
                                      spots: [
                                        FlSpot(bpmSpots.first.x, targetPitch),
                                        FlSpot(bpmSpots.last.x, targetPitch),
                                      ],
                                      color: Colors.red.withOpacity(0.5),
                                      barWidth: 2,
                                      dotData: const FlDotData(show: false),
                                      dashArray: [5, 5],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // データレコード表示 (SPMを表示するように修正)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.data_array, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              '収集データ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // データ統計情報
                        if (experimentRecords.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'データ統計情報',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '合計レコード数: ${experimentRecords.length}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const Text(
                                    '記録間隔: 100ミリ秒',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '推定ファイルサイズ: ${(experimentRecords.length * 100 / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '保存ファイル名: $experimentFileName',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (experimentRecords.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("まだデータがありません"),
                          )
                        else
                          Column(
                            children: experimentRecords.reversed
                                .take(5)
                                .map((record) {
                              return ListTile(
                                dense: true,
                                title: Text(
                                  "時刻: ${DateFormat('HH:mm:ss.SSS').format(record.timestamp)}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "目標: ${record.targetBPM.toStringAsFixed(1)} BPM / "
                                      "検出: ${record.detectedBPM?.toStringAsFixed(1) ?? 'N/A'} SPM", // 単位変更
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      "加速度: X=${record.accX?.toStringAsFixed(3) ?? 'N/A'}, Y=${record.accY?.toStringAsFixed(3) ?? 'N/A'}, Z=${record.accZ?.toStringAsFixed(3) ?? 'N/A'}",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 実験モードのUI (SPM表示に合わせる)
  Widget _buildExperimentModeUI() {
    return Column(
      children: [
        // 実験設定カード (変更なし)
        const Card(
            // ...
            ),
        // 残り時間表示 (変更なし)
        if (isRecording && experimentTimer != null) ...[
          // ...
        ],
        // スクロール可能なデータ表示部分
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // --- SPMトラッキンググラフ ---
                if (bpmSpots.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.timeline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'SPM推移グラフ', // ラベル変更
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) =>
                                          Text(value.toInt().toString()),
                                    ),
                                  ),
                                  bottomTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      // X軸は経過時間 or レコード数で表示
                                      // getTitlesWidget: ...
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: true),
                                minX: 0, // 実験開始からの時間 or レコード数
                                maxX: bpmSpots.length.toDouble(),
                                minY: minY,
                                maxY: maxY,
                                lineBarsData: [
                                  // 検出SPM
                                  LineChartBarData(
                                    spots: bpmSpots,
                                    isCurved: false,
                                    color: Colors.blue,
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                  ),
                                  // ターゲットBPM (直線)
                                  LineChartBarData(
                                    spots: [
                                      FlSpot(0, currentMusicBPM),
                                      FlSpot(bpmSpots.length.toDouble(),
                                          currentMusicBPM),
                                    ],
                                    color: Colors.red.withOpacity(0.5),
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                    dashArray: [5, 5],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // データレコード表示 (SPMを表示するように修正)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ... (ヘッダー部分は変更なし)
                        if (experimentRecords.isNotEmpty) ...[
                          // ... (統計情報表示は変更なし)
                        ],
                        const SizedBox(height: 8),
                        if (experimentRecords.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("まだデータがありません"),
                          )
                        else
                          Column(
                            children: experimentRecords.reversed
                                .take(5)
                                .map((record) {
                              return ListTile(
                                dense: true,
                                title: Text(
                                  "時刻: ${DateFormat('HH:mm:ss.SSS').format(record.timestamp)}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "目標: ${record.targetBPM.toStringAsFixed(1)} BPM / "
                                      "検出: ${record.detectedBPM?.toStringAsFixed(1) ?? 'N/A'} SPM", // 単位変更
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    // 加速度データ表示は変更なし
                                    Text(
                                      "加速度: X=${record.accX?.toStringAsFixed(3) ?? 'N/A'}, Y=${record.accY?.toStringAsFixed(3) ?? 'N/A'}, Z=${record.accZ?.toStringAsFixed(3) ?? 'N/A'}",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // データモニターモードのUI
  Widget _buildDataMonitorModeUI() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'リアルタイムデータ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // --- 歩行ピッチ (SPM) 表示カード ---
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(
                          Icons.directions_walk,
                          color: AppColors.accent,
                          size: AppSpacing.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '歩行ピッチ (SPM)',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      // 記録中インジケーター
                      if (isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.fiber_manual_record,
                                color: AppColors.textPrimary,
                                size: AppSpacing.iconXs,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                '記録中',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _displaySpm > 0 ? _displaySpm.toStringAsFixed(1) : '--',
                        style: AppTypography.displayLarge.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SPM', // 単位変更
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.indigo,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '歩数: $_displayStepCount',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (_currentCV > 0)
                            Text(
                              'CV: ${(_currentCV * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: _currentCV < 0.05
                                    ? AppColors.success
                                    : _currentCV < 0.08
                                        ? AppColors.warning
                                        : AppColors.error,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      latestData?.timestamp != null
                          ? '最終センサー更新: ${DateFormat('HH:mm:ss.SSS').format(DateTime.fromMillisecondsSinceEpoch(latestData!.timestamp))}'
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  // 記録ボタン追加 (新規追加)
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(
                          isRecording ? Icons.stop : Icons.fiber_manual_record,
                          color: Colors.white,
                        ),
                        label: Text(
                          isRecording ? "記録停止" : "記録開始",
                          style: const TextStyle(color: Colors.white),
                        ),
                        onPressed: latestData == null ? null : _toggleRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isRecording ? Colors.red : Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                      if (isRecording)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '収集データ: ${experimentRecords.length} 行',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- ★心拍数カード ---
            if (isHeartRateConnected)
              Card(
                elevation: 4,
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      const BorderSide(color: AppColors.borderLight, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.favorite, color: AppColors.error),
                          SizedBox(width: 8),
                          Text(
                            '心拍数',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currentHeartRate > 0
                                ? currentHeartRate.toString()
                                : '--',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'BPM',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (heartRateDevice != null)
                                Text(
                                  heartRateDevice!.platformName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              if (_lastHeartRateUpdate != null)
                                Text(
                                  '更新: ${DateTime.now().difference(_lastHeartRateUpdate!).inSeconds}秒前',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              if (_recentHeartRates.isNotEmpty)
                                Text(
                                  'サンプル数: ${_recentHeartRates.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (isHeartRateConnected) const SizedBox(height: 16),

            // --- CV（変動係数）トレンドチャート ---
            if (_cvHistory.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: const Icon(
                            Icons.show_chart,
                            color: AppColors.accent,
                            size: AppSpacing.iconMd,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '歩行安定性の推移',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CvTrendChart(
                      cvValues: _cvHistory,
                      targetCv: 0.05,
                      height: 200,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'CV値が低いほど歩行が安定しています（目標: 5%以下）',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // --- コントロールボタン ---
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // メトロノームボタン
                ElevatedButton.icon(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text('メトロノーム ${isPlaying ? "停止" : "再生"}'),
                  onPressed: _togglePlayback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isPlaying ? Colors.redAccent : const Color(0xFF424242),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                // メトロノーム設定ボタン
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: Text('BPM: ${selectedTempo?.bpm ?? 100}'),
                  onPressed: () => _showMetronomeSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                // センサー情報ボタン
                ElevatedButton.icon(
                  icon: const Icon(Icons.sensors),
                  label: const Text('センサー情報'),
                  onPressed: () => _showSensorInfo(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                // 歩行解析詳細ボタン
                ElevatedButton.icon(
                  icon: const Icon(Icons.analytics),
                  label: const Text('歩行解析'),
                  onPressed: () => _showGaitAnalysis(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- SPM推移グラフ ---
            if (bpmSpots.length > 1) // データが2点以上あれば表示
              Card(
                elevation: 4,
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      const BorderSide(color: AppColors.borderLight, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timeline, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'SPM推移グラフ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) =>
                                      Text(value.toInt().toString()),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 5000, // 5秒ごと
                                  getTitlesWidget: (value, meta) {
                                    final dt =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            value.toInt());
                                    return Text(
                                        DateFormat('HH:mm:ss').format(dt));
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            minX: bpmSpots.first.x,
                            maxX: bpmSpots.last.x,
                            minY: minY,
                            maxY: maxY,
                            lineBarsData: [
                              LineChartBarData(
                                spots: bpmSpots,
                                isCurved: false,
                                color: Colors.purple,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // --- ★データ保存・アップロードボタン (新規追加) ---
            if (isRecording && experimentRecords.isNotEmpty)
              Card(
                elevation: 4,
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      const BorderSide(color: AppColors.borderLight, width: 1),
                ),
                margin: const EdgeInsets.only(top: 16, bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_upload, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'データ保存・アップロード',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${experimentRecords.length}行のデータが記録されています。記録を停止して保存することができます。',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('記録停止 & Azureにアップロード'),
                          onPressed: () {
                            _toggleRecording(); // 記録停止
                            _finishExperiment(); // データ保存＆アップロード
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 最も近いテンポプリセットを見つける
  MusicTempo _findNearestTempoPreset(double bpm) {
    // 使用するテンポプリセットリストを決定（実験モードかどうかで切り替え）
    final tempoList =
        isExperimentMode ? experimentTempoPresets : metronomeTempoPresets;

    // 完全に一致するBPMがあるか確認
    for (var tempo in tempoList) {
      if (tempo.bpm == bpm) {
        return tempo;
      }
    }

    // 差が最小のものを探す
    MusicTempo nearest = tempoList[0];
    double minDiff = (nearest.bpm - bpm).abs();

    for (var tempo in tempoList) {
      double diff = (tempo.bpm - bpm).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = tempo;
      }
    }

    return nearest;
  }

  // 加速度データからBPMを計算する関数
  double? calculateBPMFromAcceleration(List<M5SensorData> data) {
    if (data.length < 20) {
      return null; // データ不足
    }

    try {
      // Y軸データの抽出（縦方向の加速度が歩行を最もよく反映）
      List<double> accY = data.map((d) => d.accY ?? 0.0).toList();

      // データの前処理
      const int windowSize = 5; // 移動平均のウィンドウサイズ
      List<double> smoothed = _applyMovingAverage(accY, windowSize);
      List<double> centered = _centerData(smoothed);

      // サンプリングレートの計算（データから推定）
      double samplingRate = _calculateSamplingRate(data);

      // 自己相関の計算
      int acMaxLag = (samplingRate * 2).floor(); // 最大2秒のラグを考慮
      List<double> autocorr = _computeAutocorrelation(centered, acMaxLag);

      // 歩行に関連する周波数範囲を設定
      const double minBPM = 60.0;
      const double maxBPM = 180.0;
      int minLag = (samplingRate * 60 / maxBPM).floor();
      int maxLag = (samplingRate * 60 / minBPM).floor();

      // 自己相関のピークを検出
      Map<String, dynamic> result =
          _findAutocorrelationPeak(autocorr, minLag, maxLag);

      int lag = result['lag'];
      double confidence = result['confidence'];

      // BPMを計算
      double bpm = 60.0 / (lag / samplingRate);

      // 結果が範囲外の場合は補正
      if (bpm > 180.0) bpm /= 2.0;
      if (bpm < 60.0) bpm *= 2.0;

      // 信頼度が低い場合はnullを返す（オプション）
      if (confidence < 0.3) {
        print('信頼度不足: $confidence, BPM計算をスキップ');
        return null;
      }

      print('歩行BPM計算: $bpm BPM (信頼度: ${confidence.toStringAsFixed(2)})');
      return bpm;
    } catch (e) {
      print('BPM計算エラー: $e');
      return null;
    }
  }

  // 移動平均を適用する関数
  List<double> _applyMovingAverage(List<double> data, int windowSize) {
    List<double> result = List<double>.filled(data.length, 0.0);

    for (int i = 0; i < data.length; i++) {
      double sum = 0.0;
      int count = 0;

      for (int j = i - (windowSize ~/ 2); j <= i + (windowSize ~/ 2); j++) {
        if (j >= 0 && j < data.length) {
          sum += data[j];
          count++;
        }
      }

      result[i] = sum / count;
    }

    return result;
  }

  // データを中心化する関数（平均を0にする）
  List<double> _centerData(List<double> data) {
    double mean = data.reduce((a, b) => a + b) / data.length;
    return data.map((value) => value - mean).toList();
  }

  // サンプリングレートを計算する関数
  double _calculateSamplingRate(List<M5SensorData> data) {
    // タイムスタンプがあればそれを使用
    if (data.length >= 2) {
      int startTime = data[0].timestamp;
      int endTime = data[data.length - 1].timestamp;
      double durationSeconds = (endTime - startTime) / 1000.0;
      if (durationSeconds > 0) {
        return (data.length - 1) / durationSeconds;
      }
    }

    // タイムスタンプがない場合や計算失敗時はデフォルト値を返す
    return 50.0; // デフォルトのサンプリングレート (50Hz)
  }

  // 自己相関を計算する関数
  List<double> _computeAutocorrelation(List<double> data, int maxLag) {
    List<double> result = List<double>.filled(maxLag + 1, 0.0);
    int n = data.length;

    for (int lag = 0; lag <= maxLag; lag++) {
      double sum = 0.0;
      int count = 0;

      for (int i = 0; i < n - lag; i++) {
        sum += data[i] * data[i + lag];
        count++;
      }

      if (count > 0) {
        result[lag] = sum / count;
      }
    }

    return result;
  }

  // 自己相関のピークを見つける関数
  Map<String, dynamic> _findAutocorrelationPeak(
      List<double> autocorr, int minLag, int maxLag) {
    double maxVal = double.negativeInfinity;
    int bestLag = minLag;

    int effectiveMaxLag =
        maxLag < autocorr.length ? maxLag : autocorr.length - 1;

    for (int lag = minLag; lag <= effectiveMaxLag; lag++) {
      if (autocorr[lag] > maxVal) {
        maxVal = autocorr[lag];
        bestLag = lag;
      }
    }

    // 信頼度の計算 (0-1の範囲に正規化)
    double confidence = 0.0;
    if (autocorr[0] > 0) {
      confidence = maxVal / autocorr[0]; // 自己相関のピーク値をラグ0の値で正規化
    }

    return {'lag': bestLag, 'confidence': confidence};
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  // SPM表示関数を修正
  String _formatSpm(double spm) {
    if (spm <= 0.1) return 'N/A';
    return spm.toStringAsFixed(1);
  }

  // 表示用の信頼度文字列のフォーマット
  String _formatReliability(double reliability) {
    if (reliability <= 0.01) return 'N/A';
    return '${(reliability * 100).toStringAsFixed(1)}%';
  }

  // CSVファイルのサイズ推定
  String _estimateFileSize() {
    // 1行あたりのサイズを概算（バイト単位）
    const int bytesPerRow = 100; // タイムスタンプ、BPM、加速度値などを含む

    // 合計行数 = 記録間隔（100ms）× 実験時間（秒）× 10
    int totalRows = (experimentDurationSeconds * 10);

    // 合計サイズ（キロバイト）
    double totalKB = (totalRows * bytesPerRow) / 1024;

    if (totalKB < 1024) {
      return '${totalKB.toStringAsFixed(1)} KB';
    } else {
      return '${(totalKB / 1024).toStringAsFixed(2)} MB';
    }
  }

  // 記録を開始/停止する
  void _toggleRecording() {
    if (isRecording) {
      // 記録を停止
      _finishExperiment();
    } else {
      // 記録を開始
      _startExperimentWithDialog();
    }
  }

  // Bluetooth初期化とリスナー設定を行う非同期メソッド
  Future<void> _initBluetooth() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 初期化を少し遅延させる（特にiOSでの安定性向上）
      await Future.delayed(const Duration(milliseconds: 800));

      // アダプタ状態の監視を設定
      _streamSubscriptions.add(FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          // Bluetoothが有効になったとき
          if (!isScanning && !isConnected && !_isDisposing) {
            // 自動的にスキャンを開始
            _startScanWithRetry();
          }
        } else {
          // Bluetoothが無効になったとき
          setState(() {
            isScanning = false;
          });
          if (isConnected) {
            disconnect();
          }
        }
      }, onError: (error) {
        print('アダプタ状態エラー: $error');
      }));

      // 少し遅延させてからスキャン開始
      await Future.delayed(const Duration(milliseconds: 200));
      _startScanWithRetry();
    } catch (e) {
      print('Bluetooth初期化エラー: $e');
      _isInitialized = false;
    }
  }

  // リトライ機能付きスキャン開始
  Future<void> _startScanWithRetry() async {
    if (_isDisposing) return;

    try {
      await startScan();
    } catch (e) {
      print('スキャン失敗、リトライします... $e');
      // エラー発生時は少し待ってリトライ
      if (!_isDisposing) {
        await Future.delayed(const Duration(seconds: 2));
        startScan();
      }
    }
  }

  /// BLEデバイスをスキャンして、目的のデバイスを見つけたら接続する
  Future<void> startScan() async {
    if (_isDisposing || isScanning) return;

    try {
      setState(() {
        isScanning = true;
        _scanResults.clear(); // スキャン開始時にリストをクリア
      });

      // Bluetoothが有効かどうか確認（非同期処理を正しくawaitする）
      BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        // Bluetoothがオフの場合はメッセージを表示
        setState(() {
          isScanning = false;
        });
        if (!mounted || _isDisposing) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetoothを有効にしてください'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // すでに接続している場合は一度切断しておく
      if (targetDevice != null) {
        await targetDevice!.disconnect();
        targetDevice = null;
        isConnected = false;
      }

      // スキャン前に実行中のスキャンをすべて停止
      bool isCurrentlyScanning = await FlutterBluePlus.isScanning.first;
      if (isCurrentlyScanning) {
        await FlutterBluePlus.stopScan();
        // 少し待機して次のスキャンを開始（特にiOSで重要）
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // スキャン結果のリスナー
      StreamSubscription scanResultsSubscription =
          FlutterBluePlus.scanResults.listen((results) {
        if (_isDisposing) return;

        setState(() {
          // すべてのスキャン結果を表示用に保存
          _scanResults.clear();
          _scanResults.addAll(results);
        });

        for (ScanResult r in results) {
          // デバッグ用にログ出力
          print('デバイス発見: ${r.device.platformName} (${r.device.remoteId})');

          // ターゲット名と一致するデバイスを発見したら接続へ
          if (r.device.platformName == targetDeviceName) {
            // スキャン停止を確実に実行
            FlutterBluePlus.stopScan().then((_) {
              if (!_isDisposing && mounted) {
                connectToDevice(r.device);
              }
            }).catchError((e) {
              print('スキャン停止エラー: $e');
            });
            break;
          }
        }
      }, onError: (error) {
        print('スキャンエラー: $error');
        if (!_isDisposing && mounted) {
          setState(() {
            isScanning = false;
          });
        }
      });
      _streamSubscriptions.add(scanResultsSubscription);

      // 状態監視
      StreamSubscription scanningSubscription =
          FlutterBluePlus.isScanning.listen((scanning) {
        if (!_isDisposing && mounted && !scanning) {
          setState(() {
            isScanning = false;
          });
        }
      }, onError: (error) {
        print('スキャン状態エラー: $error');
      });
      _streamSubscriptions.add(scanningSubscription);

      // スキャン開始
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      print('スキャン開始エラー: $e');
      if (!_isDisposing && mounted) {
        setState(() {
          isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('スキャンエラー: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 見つかったデバイスに接続
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isDisposing) return;

    try {
      if (!mounted) return;
      setState(() {
        isConnecting = true;
      });
      targetDevice = device;

      // 接続前に切断を試行（特にiOSでの安定性向上）
      try {
        await device.disconnect();
        // 少し待機してから接続（特にiOSで重要）
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // 初回接続時など切断エラーは無視
        print('事前切断無視: $e');
      }

      // 接続要求
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      if (!mounted || _isDisposing) return;
      setState(() {
        isConnecting = false;
        isConnected = true;
      });

      // 接続後の切断を監視
      StreamSubscription connectionSubscription =
          device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            !_isDisposing &&
            mounted) {
          setState(() {
            isConnected = false;
            targetDevice = null;
          });

          // 再スキャン
          Future.delayed(const Duration(seconds: 1), () {
            if (!_isDisposing && mounted && !isScanning) {
              startScan();
            }
          });
        }
      }, onError: (error) {
        print('接続状態エラー: $error');
      });
      _streamSubscriptions.add(connectionSubscription);

      // サービスを探す
      await _setupSerialCommunication();
    } catch (e) {
      print('接続エラー: $e');
      if (!_isDisposing && mounted) {
        setState(() {
          isConnecting = false;
          isConnected = false;
          targetDevice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('接続エラー: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Bluetooth Serial通信のセットアップ
  Future<void> _setupSerialCommunication() async {
    if (targetDevice == null || _isDisposing) return;
    try {
      List<BluetoothService> services = await targetDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid == serviceUuid) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid == charUuid) {
              await c.setNotifyValue(true);
              StreamSubscription characteristicSubscription =
                  c.lastValueStream.listen((value) {
                if (value.isEmpty || _isDisposing) return;
                try {
                  String jsonString = String.fromCharCodes(value);
                  final jsonData = jsonDecode(jsonString);
                  final sensorData = M5SensorData.fromJson(jsonData);

                  if (!_isDisposing && mounted) {
                    _processSensorData(sensorData);
                  }
                } catch (e) {
                  print('データ解析エラー: $e');
                }
              }, onError: (error) {
                print('キャラクタリスティック読み取りエラー: $error');
              });
              _streamSubscriptions.add(characteristicSubscription);
              print('Notify設定完了: ${c.uuid}');
              return; // キャラクタリスティック見つけたらループ抜ける
            }
          }
        }
      }
      print('ターゲットキャラクタリスティックが見つかりません');
    } catch (e) {
      print('サービス探索/Notify設定エラー: $e');
    }
  }

  // 心拍センサーのモニタリングをセットアップ
  Future<void> _setupHeartRateMonitoring() async {
    if (heartRateDevice == null || _isDisposing) return;

    print('=== 心拍センサーセットアップ開始 ===');
    print('デバイス名: ${heartRateDevice!.platformName}');
    print('デバイスID: ${heartRateDevice!.remoteId}');

    try {
      List<BluetoothService> services =
          await heartRateDevice!.discoverServices();
      print('発見されたサービス数: ${services.length}');

      // すべてのサービスとキャラクタリスティックをログ出力
      for (int i = 0; i < services.length; i++) {
        final service = services[i];
        print('\nサービス $i: ${service.uuid}');
        print('  キャラクタリスティック数: ${service.characteristics.length}');

        for (int j = 0; j < service.characteristics.length; j++) {
          final char = service.characteristics[j];
          print('    キャラ $j: ${char.uuid}');
          print('      プロパティ: 読み取り=${char.properties.read}, '
              '書き込み=${char.properties.write}, '
              '通知=${char.properties.notify}');
        }
      }

      // 標準の心拍サービスを探す
      bool foundHeartRateService = false;
      for (BluetoothService service in services) {
        if (service.uuid == heartRateServiceUuid) {
          print('\n標準心拍サービスを発見！');
          foundHeartRateService = true;
          foundHeartRateService = true;

          for (BluetoothCharacteristic c in service.characteristics) {
            print('  キャラクタリスティック: ${c.uuid}');

            if (c.uuid == heartRateMeasurementCharUuid) {
              print('  心拍測定キャラクタリスティックを発見！');

              // 通知を有効化
              await c.setNotifyValue(true);
              print('  通知を有効化しました');

              StreamSubscription characteristicSubscription =
                  c.lastValueStream.listen((value) {
                if (value.isEmpty || _isDisposing) return;
                // print('心拍データ受信: ${value.length}バイト');  // デバッグ用
                _processHeartRateData(value);
              }, onError: (error) {
                print('心拍データ受信エラー: $error');
              });

              _streamSubscriptions.add(characteristicSubscription);
              print('心拍センサーのNotify設定完了');
              // returnを削除して、他のサービスも設定を続ける
              // return;
            }
          }
        }
      }

      if (!foundHeartRateService) {
        print('\n標準心拍サービスが見つかりません');

        // Huaweiデバイスの場合、カスタムサービスを探す
        if (heartRateDevice!.platformName.toLowerCase().contains('huawei')) {
          print('Huaweiデバイスが接続されました（カスタムプロトコル）');
          print('カスタムサービスの検索を試みます...');

          // 心拍に関連しそうなキャラクタリスティックを探す
          for (BluetoothService service in services) {
            for (BluetoothCharacteristic c in service.characteristics) {
              // 通知可能なキャラクタリスティックをすべて試す
              if (c.properties.notify) {
                print('\n通知可能なキャラを発見: ${c.uuid} (サービス: ${service.uuid})');

                try {
                  await c.setNotifyValue(true);

                  StreamSubscription sub = c.lastValueStream.listen((value) {
                    if (value.isEmpty || _isDisposing) return;
                    // print('データ受信 from ${c.uuid}: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');  // デバッグ用

                    // Huaweiカスタムプロトコルをチェック（ヘッダー: 5a 00）
                    if (value.length >= 10 &&
                        value[0] == 0x5a &&
                        value[1] == 0x00) {
                      int command = value.length >= 5 ? value[4] : 0;
                      if (command == 0x09) {
                        // 心拍データコマンド
                        // print('  -> Huawei心拍データ検出！');  // デバッグ用
                        _processHeartRateData(value);
                      }
                    }
                    // その他の心拍データの可能性があるパターンをチェック
                    else if (value.length >= 2 &&
                        value[1] >= 30 &&
                        value[1] <= 220) {
                      // print('  -> 心拍データの可能性あり！');  // デバッグ用
                      _processHeartRateData(value);
                    }
                  });

                  _streamSubscriptions.add(sub);
                  print('  通知を有効化しました');
                } catch (e) {
                  print('  通知有効化エラー: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('心拍センサーセットアップエラー: $e');
    }

    print('=== 心拍センサーセットアップ終了 ===');
  }

  // 心拍データを処理する
  void _processHeartRateData(List<int> value) {
    if (value.isEmpty) {
      print('心拍データ処理: 空のデータ');
      return;
    }

    // デバッグ出力（必要に応じてコメントアウト）
    // print('\n=== 心拍データ処理 ===');
    // print('受信データ: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')} (${value.length}バイト)');
    // print('受信データ(10進数): ${value.join(', ')}');

    // Huaweiカスタムプロトコルのチェック
    if (value.length >= 4 && value[0] == 0x5a && value[1] == 0x00) {
      // print('Huaweiカスタムプロトコル検出');  // デバッグ用

      // パケット長を取得（リトルエンディアン）
      int payloadLength = value[2] | (value[3] << 8);
      // print('ペイロード長: $payloadLength バイト');  // デバッグ用

      if (value.length >= 6) {
        int command = value[4];
        int subCommand = value[5];
        // print('コマンド: 0x${command.toRadixString(16)}, サブコマンド: 0x${subCommand.toRadixString(16)}');  // デバッグ用

        // 心拍数パケット（コマンド 0x09）
        if (command == 0x09 && value.length >= 10) {
          int heartRate = value[9]; // 9番目のバイトが心拍数
          // print('Huaweiプロトコル心拍数: $heartRate BPM');  // デバッグ用

          // 妥当な心拍数の範囲をチェック（30-220 BPM）
          if (heartRate >= 30 && heartRate <= 220) {
            // 最近の心拍数リストに追加（平滑化用）
            _recentHeartRates.add(heartRate);
            if (_recentHeartRates.length > 5) {
              _recentHeartRates.removeAt(0);
            }

            // UIを更新
            if (mounted) {
              setState(() {
                currentHeartRate = heartRate;
                _lastHeartRateUpdate = DateTime.now();
              });
            }

            // デバッグ出力
            print('=== 心拍データ更新 (Huawei) ===');
            print('心拍数: $heartRate BPM');
            print('履歴: ${_recentHeartRates.join(', ')} BPM');
            print(
                '平均: ${(_recentHeartRates.reduce((a, b) => a + b) / _recentHeartRates.length).toStringAsFixed(1)} BPM');
            print('更新時刻: ${DateTime.now().toIso8601String()}');
            print('=============================');
          } else {
            print('警告: 異常な心拍数を検出: $heartRate BPM -> データを無視します'); // この警告は残す
          }
        } else {
          // print('その他のデータパケット（コマンド: 0x${command.toRadixString(16)}）');  // デバッグ用
        }
      }
    } else if (value.length >= 2) {
      // 標準BLE心拍測定フォーマットを試行
      // print('標準BLE心拍測定フォーマットとして処理を試行');  // デバッグ用

      int flags = value[0];
      int heartRate = value[1];

      // デバッグ出力（必要に応じてコメントアウト）
      // print('フラグバイト: 0x${flags.toRadixString(16).padLeft(2, '0')} (${flags.toRadixString(2).padLeft(8, '0')}b)');
      // print('  - 心拍数フォーマット: ${(flags & 0x01) == 1 ? "16ビット" : "8ビット"}');
      // print('  - センサー接触状態: ${(flags & 0x06) >> 1}');
      // print('  - エネルギー消費フィールド: ${(flags & 0x08) != 0 ? "あり" : "なし"}');
      // print('  - RR間隔: ${(flags & 0x10) != 0 ? "あり" : "なし"}');

      // 16ビット値の場合
      if ((flags & 0x01) == 1) {
        if (value.length >= 3) {
          heartRate = value[1] | (value[2] << 8);
          // print('16ビット心拍数: $heartRate BPM');  // デバッグ用
        } else {
          // print('エラー: 16ビットフォーマットだがデータ長不足');  // デバッグ用
          return;
        }
      } else {
        // print('8ビット心拍数: $heartRate BPM');  // デバッグ用
      }

      // 妥当な心拍数の範囲をチェック（30-220 BPM）
      if (heartRate >= 30 && heartRate <= 220) {
        // 重複データを避ける
        final now = DateTime.now();
        if (_lastHeartRateReceived == null ||
            now.difference(_lastHeartRateReceived!).inMilliseconds > 500) {
          // 最近の心拍数リストに追加
          _recentHeartRates.add(heartRate);
          if (_recentHeartRates.length > 3) {
            // バッファサイズを3に減らす
            _recentHeartRates.removeAt(0);
          }
          _lastHeartRateReceived = now;

          // UIを更新
          if (mounted) {
            setState(() {
              currentHeartRate = heartRate;
              _lastHeartRateUpdate = DateTime.now();
            });
          }

          // デバッグ出力
          print('=== 心拍データ更新 (標準BLE) ===');
          print('心拍数: $heartRate BPM');
          print('履歴: ${_recentHeartRates.join(', ')} BPM');
          print(
              '平均: ${(_recentHeartRates.reduce((a, b) => a + b) / _recentHeartRates.length).toStringAsFixed(1)} BPM');
          print('更新時刻: ${DateTime.now().toIso8601String()}');
          print('================================');
        }
      } else {
        print('警告: 異常な心拍数を検出: $heartRate BPM -> データを無視します');
      }
    } else {
      // print('データ長が不足: ${value.length}バイト');  // デバッグ用
    }

    // print('===================');  // デバッグ用
  }

  // 新しいセンサーデータを処理するメソッド
  void _processSensorData(M5SensorData sensorData) {
    if (!mounted) return; // マウントされていない場合は処理しない

    setState(() {
      latestData = sensorData;

      // 履歴に追加
      dataHistory.add(sensorData);
      if (dataHistory.length > maxHistorySize) {
        dataHistory.removeAt(0);
      }

      // 歩行解析サービスにデータを渡す
      gaitAnalysisService?.addSensorData(sensorData);

      // UI表示用の値を更新
      _displaySpm = gaitAnalysisService?.currentSpm ?? 0.0;
      _displayStepCount = gaitAnalysisService?.stepCount ?? 0;

      // グラフ用データの更新 (SPM)
      if (_displaySpm > 0) {
        _updateSpmGraphData(_displaySpm);
      }

      // 実験モードで記録中なら記録 (タイマー内で実施)
      // if (isRecording && experimentTimer != null) { ... }
    });
  }

  // SPMグラフデータを更新するメソッド
  void _updateSpmGraphData(double spm) {
    if (!mounted) return; // 安全チェック

    // タイムスタンプを取得（現在時刻 or 最後に受信したセンサーデータのタイムスタンプ）
    final time =
        (latestData?.timestamp ?? DateTime.now().millisecondsSinceEpoch)
            .toDouble();

    setState(() {
      // SPMデータをグラフに追加
      // タイムスタンプをX軸として追加
      bpmSpots.add(FlSpot(time, spm));

      // グラフ表示ポイント数の制限 (例: 過去5分 = 300秒 * 50Hz = 15000点 だと多すぎるので時間で制限)
      const int maxGraphDurationMillis = 5 * 60 * 1000; // 5分
      if (bpmSpots.isNotEmpty &&
          (time - bpmSpots.first.x) > maxGraphDurationMillis) {
        // 5分以上前のデータを削除
        bpmSpots
            .removeWhere((spot) => (time - spot.x) > maxGraphDurationMillis);
      }

      // Y軸の範囲を動的に調整 (既存の minY, maxY を利用)
      // グラフ内のデータに基づいて範囲を決定
      if (bpmSpots.isNotEmpty) {
        double currentMinSpotY = bpmSpots.map((s) => s.y).reduce(math.min);
        double currentMaxSpotY = bpmSpots.map((s) => s.y).reduce(math.max);

        // 範囲に少し余裕を持たせる
        double padding = 10.0;
        minY = math.max(40, currentMinSpotY - padding); // 最小値 40
        maxY = math.min(200, currentMaxSpotY + padding); // 最大値 200

        // 範囲が狭すぎる場合の調整 (最小40の幅を持たせる)
        if (maxY - minY < 40) {
          double center = (minY + maxY) / 2;
          minY = math.max(40, center - 20); // 最小値制限も考慮
          maxY = math.min(200, center + 20); // 最大値制限も考慮
        }
        // さらに狭い場合の最終調整
        if (maxY - minY < 40) {
          minY = 40;
          maxY = 80;
        }
        // 範囲の再制約
        minY = math.max(40, minY);
        maxY = math.min(200, maxY);
      } else {
        // データがない場合はデフォルト範囲
        minY = 40;
        maxY = 160;
      }
    });
  }

  // 切断
  Future<void> disconnect() async {
    try {
      if (targetDevice != null) {
        await targetDevice!.disconnect();
        if (!_isDisposing && mounted) {
          setState(() {
            targetDevice = null;
            isConnected = false;
          });
        }
      }
    } catch (e) {
      print('切断エラー: $e');
    }
  }

  // 無音データ収集モードの初期化
  void _initializeSilentDataCollection() {
    // データをリセット
    silentWalkingData.clear();
    silentWalkingStartTime = DateTime.now();

    // 通知を表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('無音データ収集を開始しました。自然に歩いてください。'),
        duration: Duration(seconds: 3),
      ),
    );

    // 定期的にデータを記録するタイマーを開始（2秒ごと）
    silentWalkingDataTimer?.cancel();
    silentWalkingDataTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      _recordSilentWalkingData();
    });
  }

  // 無音データ収集モードの停止
  void _stopSilentDataCollection() {
    // タイマーをキャンセル
    silentWalkingDataTimer?.cancel();
    silentWalkingDataTimer = null;

    // データが存在する場合、保存してAzureにアップロード
    if (silentWalkingData.isNotEmpty) {
      _saveAndUploadSilentWalkingData();
    }

    // 通知を表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('無音データ収集を終了しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 無音歩行データを記録
  void _recordSilentWalkingData() {
    // 位置情報が設定されていない場合は取得を試みる
    if (_isLocationEnabled && _currentPosition == null) {
      _getCurrentLocation();
    }

    // 現在のデータポイントを記録
    silentWalkingData.add({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'phase': 'Silent Walking',
      'targetBPM': 0.0, // 無音モードでは目標BPMなし
      'currentSPM': _displaySpm > 0 ? _displaySpm : 0.0,
      'stepCount': _displayStepCount,
      'elapsedSeconds': silentWalkingStartTime != null
          ? DateTime.now().difference(silentWalkingStartTime!).inSeconds
          : 0,
      'latitude': _currentPosition?.latitude,
      'longitude': _currentPosition?.longitude,
      'altitude': _currentPosition?.altitude,
      'speed': _currentPosition?.speed,
    });

    print('Silent walking data recorded: ${silentWalkingData.length}, '
        'SPM=${_displaySpm > 0 ? _displaySpm.toStringAsFixed(1) : "N/A"}, '
        'Steps=$_displayStepCount');
  }

  // 無音歩行データをCSV形式で保存してAzureにアップロードする
  Future<void> _saveAndUploadSilentWalkingData() async {
    try {
      // ファイル名を設定
      final fileName =
          'silent_walking_${subjectId.isEmpty ? 'unknown' : subjectId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      // データが空の場合は処理を中止
      if (silentWalkingData.isEmpty) {
        print('Silent walking data is empty');
        return;
      }

      // 時系列データのCSVヘッダー
      List<List<dynamic>> walkingDataCSV = [];

      // メタデータ行（実験の概要情報）
      walkingDataCSV.add([
        '# Silent_Walking_Summary',
        '',
        '',
        '',
        '',
        '',
      ]);

      walkingDataCSV.add([
        '# Subject_ID',
        '# Experiment_DateTime',
        '# Duration_Sec',
        '# Data_Points_Count',
        '# Avg_SPM',
        '# Total_Steps',
      ]);

      // 平均SPMを計算
      double avgSpm = 0;
      if (silentWalkingData.isNotEmpty) {
        double totalSpm = 0;
        int validDataPoints = 0;
        for (var dataPoint in silentWalkingData) {
          double spm = dataPoint['currentSPM'];
          if (spm > 0) {
            totalSpm += spm;
            validDataPoints++;
          }
        }
        if (validDataPoints > 0) {
          avgSpm = totalSpm / validDataPoints;
        }
      }

      // 総歩数を取得（最後のデータポイントの歩数）
      int totalSteps = silentWalkingData.isNotEmpty
          ? silentWalkingData.last['stepCount']
          : 0;

      // 実験時間を計算（最初と最後のタイムスタンプの差）
      int durationSec = silentWalkingData.length > 1
          ? (silentWalkingData.last['timestamp'] -
                  silentWalkingData.first['timestamp']) ~/
              1000
          : 0;

      walkingDataCSV.add([
        subjectId.isEmpty ? 'unknown' : subjectId,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        durationSec,
        silentWalkingData.length,
        avgSpm.toStringAsFixed(1),
        totalSteps,
      ]);

      // 空行を追加してデータ部分と分ける
      walkingDataCSV.add([
        '',
        '',
        '',
        '',
        '',
        '',
      ]);

      // ヘッダー行
      walkingDataCSV.add([
        'Timestamp_Unix',
        'Timestamp_Readable',
        'Elapsed_Time_Sec',
        'Phase',
        'Walking_SPM',
        'Step_Count',
        'Latitude',
        'Longitude',
        'Altitude',
        'Speed',
      ]);

      // 最初のタイムスタンプを基準にする
      int firstTimestamp = silentWalkingData.first['timestamp'];

      // データ行を追加
      for (var dataPoint in silentWalkingData) {
        int timestamp = dataPoint['timestamp'];
        double elapsedSeconds = (timestamp - firstTimestamp) / 1000.0;

        walkingDataCSV.add([
          timestamp, // Unix timestamp (milliseconds)
          DateFormat('yyyy-MM-dd HH:mm:ss.SSS')
              .format(DateTime.fromMillisecondsSinceEpoch(timestamp)),
          elapsedSeconds.toStringAsFixed(1),
          dataPoint['phase'],
          dataPoint['currentSPM'].toStringAsFixed(1),
          dataPoint['stepCount'],
          dataPoint['latitude'] != null
              ? dataPoint['latitude'].toString()
              : 'N/A',
          dataPoint['longitude'] != null
              ? dataPoint['longitude'].toString()
              : 'N/A',
          dataPoint['altitude'] != null
              ? dataPoint['altitude'].toString()
              : 'N/A',
          dataPoint['speed'] != null ? dataPoint['speed'].toString() : 'N/A',
        ]);
      }

      // CSVに変換
      String walkingDataCsv =
          const ListToCsvConverter().convert(walkingDataCSV);

      // ファイルに保存
      final directory = await getApplicationDocumentsDirectory();
      final dataPath = '${directory.path}/$fileName.csv';
      final dataFile = File(dataPath);
      await dataFile.writeAsString(walkingDataCsv, encoding: utf8);
      print('Silent walking data saved to file: $dataPath');

      // Azureにアップロード
      try {
        String originalFileName = experimentFileName;
        experimentFileName = fileName;
        await _uploadDataToAzure(walkingDataCsv);
        experimentFileName = originalFileName; // 元に戻す

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silent walking data uploaded to Azure'),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        print('Azure upload error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload to Azure: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error saving silent walking data: $e');
    }
  }

  // 無音データ収集モードのUIを構築
  Widget _buildSilentDataCollectionModeUI() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 無音データ収集モード説明カード
            Card(
              elevation: 4,
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic_off, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Text(
                          '無音データ収集モード',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (silentWalkingData.isNotEmpty)
                          Text(
                            '${silentWalkingData.length}件記録中',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '音声フィードバックなしで自然な歩行データを収集します。歩きながら自然な歩行パターンを記録します。',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '経過時間: ${silentWalkingStartTime != null ? (DateTime.now().difference(silentWalkingStartTime!).inSeconds / 60).toStringAsFixed(1) : "0.0"} 分',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('データを保存してアップロード'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onPressed: silentWalkingData.isEmpty
                              ? null
                              : _stopSilentDataCollection,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 歩行ピッチ情報カード
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_walk, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '歩行ピッチ情報',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '現在のピッチ:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_displaySpm > 0 ? _displaySpm.toStringAsFixed(1) : "--"} SPM',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '総歩数:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$_displayStepCount 歩',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SPM推移グラフ
            if (bpmSpots.length > 1)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timeline, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'SPM推移グラフ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) =>
                                      Text(value.toInt().toString()),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 5000, // 5秒ごと
                                  getTitlesWidget: (value, meta) {
                                    final dt =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            value.toInt());
                                    return Text(
                                        DateFormat('HH:mm:ss').format(dt));
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            minX: bpmSpots.first.x,
                            maxX: bpmSpots.last.x,
                            minY: minY,
                            maxY: maxY,
                            lineBarsData: [
                              // 検出SPM
                              LineChartBarData(
                                spots: bpmSpots,
                                isCurved: true,
                                color: Colors.purple,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 被験者ID入力ダイアログを表示
  void _showSubjectIdDialog({Function? afterIdSet}) {
    String tempSubjectId = subjectId;
    // TextEditingControllerを使用
    final TextEditingController controller =
        TextEditingController(text: subjectId);

    showDialog(
      context: context,
      barrierDismissible: false, // ダイアログ外をタップしても閉じない
      builder: (context) {
        return AlertDialog(
          title: const Text('被験者IDを入力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('実験データを識別するための被験者IDを入力してください。\n例: S001, P01, Taro など'),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '被験者ID',
                  hintText: '例: S001',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  tempSubjectId = value;
                },
                controller: controller, // initialValueの代わりにcontrollerを使用
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (tempSubjectId.trim().isNotEmpty) {
                  setState(() {
                    subjectId = tempSubjectId.trim();
                  });
                  Navigator.of(context).pop();

                  // コールバックがある場合は実行
                  if (afterIdSet != null) {
                    afterIdSet();
                  }

                  // 確認メッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('被験者ID「$subjectId」を設定しました'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  // 空の場合はエラーメッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('被験者IDを入力してください'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('設定'),
            ),
          ],
        );
      },
    );
  }

  // 無音データ収集モードの切り替え
  void _toggleExperimentMode() {
    setState(() {
      isExperimentMode = !isExperimentMode;
      isRealExperimentMode = false;
      if (!isExperimentMode) {
        _stopSilentDataCollection();
      } else {
        _initializeSilentDataCollection();
      }
    });
  }

  // 本実験モードの切り替え
  void _toggleRealExperimentMode() {
    setState(() {
      isRealExperimentMode = !isRealExperimentMode;
      isExperimentMode = false;
      if (isRealExperimentMode) {
        _initializeRealExperiment();
      } else {
        _stopRealExperiment();
      }
    });
  }

  // メトロノーム設定ダイアログを表示
  void _showMetronomeSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('メトロノーム設定'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('テンポ (BPM):'),
                  const SizedBox(height: 10),
                  DropdownButton<MusicTempo>(
                    value: selectedTempo,
                    isExpanded: true,
                    items: metronomeTempoPresets.map((tempo) {
                      return DropdownMenuItem<MusicTempo>(
                        value: tempo,
                        child: Text('${tempo.name} (${tempo.bpm} BPM)'),
                      );
                    }).toList(),
                    onChanged: isPlaying
                        ? null
                        : (MusicTempo? newTempo) {
                            if (newTempo != null) {
                              setState(() {
                                _changeTempo(newTempo);
                              });
                            }
                          },
                  ),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('メトロノームモード:'),
                        const SizedBox(width: 10),
                        Switch(
                          value: _useNativeMetronome,
                          onChanged: isPlaying
                              ? null
                              : (bool value) {
                                  setState(() {
                                    _useNativeMetronome = value;
                                  });
                                },
                        ),
                        Text(_useNativeMetronome ? 'ネイティブ' : 'Dart'),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  // センサー情報ダイアログを表示
  void _showSensorInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('センサー情報'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('加速度センサー',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('X軸: ${latestData?.accX?.toStringAsFixed(3) ?? "--"} G'),
                Text('Y軸: ${latestData?.accY?.toStringAsFixed(3) ?? "--"} G'),
                Text('Z軸: ${latestData?.accZ?.toStringAsFixed(3) ?? "--"} G'),
                Text(
                    '合成加速度: ${latestData?.magnitude?.toStringAsFixed(3) ?? "--"} G'),
                const SizedBox(height: 20),
                const Text('ジャイロセンサー',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                    'X軸: ${latestData?.gyroX?.toStringAsFixed(3) ?? "--"} deg/s'),
                Text(
                    'Y軸: ${latestData?.gyroY?.toStringAsFixed(3) ?? "--"} deg/s'),
                Text(
                    'Z軸: ${latestData?.gyroZ?.toStringAsFixed(3) ?? "--"} deg/s'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  // 歩行解析詳細ダイアログを表示
  void _showGaitAnalysis() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('歩行解析詳細'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'SPM (歩行ピッチ): ${(gaitAnalysisService?.currentSpm ?? 0.0) > 0.1 ? gaitAnalysisService!.currentSpm.toStringAsFixed(1) : "--"}'),
                const SizedBox(height: 10),
                const Text('ピーク検出アルゴリズム: トレンド除去+標準偏差閾値方式'),
                const SizedBox(height: 10),
                Text(
                    '信頼度スコア: ${((gaitAnalysisService?.reliability ?? 0.0) * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 10),
                const Text('直近ステップ間隔 (ms):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(() {
                  final intervals =
                      gaitAnalysisService?.getLatestStepIntervals() ?? [];
                  if (intervals.isEmpty) {
                    return '--';
                  }
                  return intervals
                      .map((iv) => iv.toStringAsFixed(0))
                      .join(', ');
                }()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  // メトロノームの初期化処理
  Future<void> _initializeMetronomes() async {
    // メトロノームインスタンスを作成
    _metronome = Metronome();
    _nativeMetronome = NativeMetronome();

    // プラットフォームを確認
    String platform = Platform.isIOS
        ? 'iOS'
        : Platform.isAndroid
            ? 'Android'
            : '不明';
    print('現在のプラットフォーム: $platform');

    // iOS/Androidともにネイティブメトロノームを使用
    print('メトロノームモード初期設定: ${_useNativeMetronome ? "ネイティブ" : "Dart"}');

    // Dartメトロノームの初期化（必ず成功するはず）
    try {
      await _metronome.initialize();
      print('Dartメトロノーム初期化完了');
    } catch (e) {
      print('Dartメトロノーム初期化エラー: $e');
      // エラーが発生しても続行する（クリティカルではない）
    }

    // ネイティブメトロノームの初期化（失敗する可能性あり）
    bool nativeSuccess = false;
    try {
      print('ネイティブメトロノーム初期化開始...');
      await _nativeMetronome.initialize();
      print('ネイティブメトロノーム初期化完了 ✓');
      nativeSuccess = true;
    } catch (e) {
      // ネイティブメトロノームの初期化に失敗した場合
      print('ネイティブメトロノーム初期化エラー: $e');
      print('Dartメトロノームモードに自動切り替えします');
      if (mounted) {
        setState(() {
          _useNativeMetronome = false;
        });
      }
      // エラー通知
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ネイティブメトロノームを使用できません。Dartモードで動作します。'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }

    // バイブレーション設定を反映
    _metronome.setVibration(useVibration);
    if (nativeSuccess) {
      try {
        await _nativeMetronome.setVibration(useVibration);
      } catch (e) {
        print('ネイティブバイブレーション設定エラー: $e');
      }
    }

    // テンポ設定
    if (selectedTempo != null) {
      _metronome.changeTempo(selectedTempo!.bpm);
      if (nativeSuccess) {
        try {
          await _nativeMetronome.changeTempo(selectedTempo!.bpm);
        } catch (e) {
          print('ネイティブテンポ設定エラー: $e');
        }
      }
    } else {
      // デフォルトテンポを設定
      selectedTempo = metronomeTempoPresets[0]; // 80 BPM
      _metronome.changeTempo(selectedTempo!.bpm);
      if (nativeSuccess) {
        try {
          await _nativeMetronome.changeTempo(selectedTempo!.bpm);
        } catch (e) {
          print('ネイティブデフォルトテンポ設定エラー: $e');
        }
      }
    }
  }
}
