import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // flutter_blue_plusライブラリ
import 'dart:async'; // Streamの取り扱いに必要
import 'dart:io';
import 'dart:convert'; // JSONのデコード用
import 'package:audioplayers/audioplayers.dart'; // シンプルな音声再生用
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter/services.dart'; // HapticFeedback用
import 'package:azblob/azblob.dart' as azblob; // Azure Blob Storage
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8, base64; // base64 エンコーディング用
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 環境変数管理用

// 独自モジュール
import 'models/sensor_data.dart';
import 'utils/step_detector.dart';
import 'services/metronome.dart';

void main() async {
  // 環境変数の読み込み
  await dotenv.load(fileName: ".env");

  // アプリ起動時にFlutterBluePlusを初期化
  if (Platform.isAndroid) {
    // Android固有の初期化
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  } else if (Platform.isIOS) {
    // iOS固有の初期化（ログレベルを下げる）
    FlutterBluePlus.setLogLevel(LogLevel.info, color: false);
  }

  runApp(const MyApp());
}

/// メインのウィジェット
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthCore M5 Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
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
          ? (reliability! * 100).toStringAsFixed(1) + '%'
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

  // グラフデータ
  List<FlSpot> bpmSpots = [];
  double minY = 60;
  double maxY = 130;

  // 音楽プレイヤー関連の変数を削除
  // final AudioPlayer _audioPlayer = AudioPlayer();
  // Uint8List? _clickSoundBytes; // メモリ上のクリック音データ

  // isPlayingとcurrentMusicBPMはメトロノームの状態を反映させる
  bool get isPlaying => _metronome.isPlaying;
  double get currentMusicBPM => _metronome.currentBpm;

  // メトロノームインスタンス
  late Metronome _metronome;

  bool isAutoAdjustEnabled = false; // 自動テンポ調整フラグ
  double lastAutoAdjustTime = 0; // 最後に自動調整した時刻（ミリ秒）
  static const double AUTO_ADJUST_INTERVAL = 5000; // 自動調整の間隔（ミリ秒）

  // 段階的テンポ変更用 (メトロノームクラスに移管検討)
  bool isGradualTempoChangeEnabled = false; // 段階的テンポ変更フラグ
  double targetBPM = 120.0; // 目標BPM
  double initialBPM = 100.0; // 初期BPM
  double tempoChangeStep = 1.0; // テンポ変更ステップ（BPM/分）
  int tempoChangeIntervalSeconds = 10; // テンポ変更間隔（秒）
  Timer? gradualTempoTimer; // テンポ変更タイマー

  // 音楽テンポのプリセット
  final List<MusicTempo> tempoPresets = [
    MusicTempo(name: '90 BPM', bpm: 90.0),
    MusicTempo(name: '100 BPM', bpm: 100.0),
    MusicTempo(name: '110 BPM', bpm: 110.0),
    MusicTempo(name: '120 BPM', bpm: 120.0),
  ];
  MusicTempo? selectedTempo;

  // 実験モード
  bool isExperimentMode = false;
  int experimentDurationSeconds = 60; // 1分間の実験
  DateTime? experimentStartTime;
  Timer? experimentTimer;
  int remainingSeconds = 0;

  // デバイス名
  final targetDeviceName = "M5StickIMU";

  // サービスUUIDとキャラクタリスティックUUID
  final serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final charUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  // 接続先デバイス
  BluetoothDevice? targetDevice;

  // サブスクリプション管理用
  final List<StreamSubscription> _streamSubscriptions = [];

  // 重複したスキャン/接続リクエストを防ぐフラグ
  bool _isInitialized = false;
  bool _isDisposing = false;

  // スキャンで見つかったデバイスリスト
  final List<ScanResult> _scanResults = [];

  // RAWデータグラフ用
  List<FlSpot> accXSpots = [];
  List<FlSpot> accYSpots = [];
  List<FlSpot> accZSpots = [];
  List<FlSpot> magnitudeSpots = [];
  static const int maxGraphPoints = 50; // グラフの最大ポイント数
  bool showRawDataGraph = true;

  // 独自の歩行検出アルゴリズム用クラス
  final StepDetector stepDetector = StepDetector();

  // BPMの手動計算結果
  double? calculatedBpmFromRaw;

  // Azure Blob Storage接続情報
  String get azureConnectionString =>
      dotenv.env['AZURE_CONNECTION_STRING'] ?? '';
  String get containerName =>
      dotenv.env['AZURE_CONTAINER_NAME'] ?? 'accelerationdata';

  @override
  void initState() {
    super.initState();

    // 初期化を非同期で安全に行う
    _initBluetooth();
    _metronome = Metronome(); // Metronomeインスタンスを作成
    _metronome.initialize().then((_) {
      // Metronomeを初期化
      // 初期テンポをメトロノームにも設定
      selectedTempo = tempoPresets[1]; // 100 BPM
      _metronome.changeTempo(selectedTempo!.bpm);
      if (mounted) {
        setState(() {}); // UI更新
      }
    }).catchError((e) {
      print('メトロノーム初期化エラー: $e');
    });
  }

  // 音楽の再生/一時停止を切り替える
  Future<void> _togglePlayback() async {
    try {
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
      // isPlaying は Metronome の状態に依存するため、ここでsetStateを呼ぶ必要は基本ないが、
      // ボタン表示の更新のためには必要。
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
      await _metronome.changeTempo(tempo.bpm);
      selectedTempo = tempo;
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
      await _metronome.changeTempo(bpm);
      if (mounted) {
        setState(() {
          selectedTempo = _findNearestTempoPreset(bpm);
        });
      }
    } catch (e) {
      print('音楽テンポ変更エラー: $e');
    }
  }

  // 実験を開始する
  void _startExperiment() {
    // 実験開始時刻を記録
    experimentStartTime = DateTime.now();
    remainingSeconds = experimentDurationSeconds;

    // 実験ファイル名を設定
    experimentFileName =
        'acceleration_data_${currentMusicBPM.toStringAsFixed(0)}_bpm_${DateFormat('yyyyMMdd_HHmmss').format(experimentStartTime!)}';

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

    // 記録開始メッセージ
    // print('加速度データの記録を開始しました: $experimentFileName (100msごと)');
  }

  // 実験データを記録
  void _recordExperimentData() {
    // 最新のデータを取得
    double? detectedBpm = latestData?.bpm;
    double? reliability = stepDetector.reliabilityScore;

    // BPMデータがない場合、歩行検出から直接取得
    if (detectedBpm == null && calculatedBpmFromRaw != null) {
      detectedBpm = calculatedBpmFromRaw;
    }

    // 最新の加速度データを取得
    double? accX = latestData?.accX;
    double? accY = latestData?.accY;
    double? accZ = latestData?.accZ;
    double? magnitude = latestData?.magnitude;

    final record = ExperimentRecord(
      timestamp: DateTime.now(),
      targetBPM: currentMusicBPM,
      detectedBPM: detectedBpm,
      reliability: reliability,
      accX: accX,
      accY: accY,
      accZ: accZ,
      magnitude: magnitude,
    );

    setState(() {
      experimentRecords.add(record);
    });

    // グラフにプロットするデータも更新
    _updateGraphData();
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

  // 実験を終了
  Future<void> _finishExperiment() async {
    if (!isRecording) return;

    // 再生を停止
    if (isPlaying) {
      await _metronome.stop();
      setState(() {
        // isPlaying = false;
      });
    }

    setState(() {
      isRecording = false;
    });

    // データを保存
    if (experimentRecords.isNotEmpty) {
      try {
        await _saveExperimentData();
      } catch (e) {
        print('データ保存エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('データ保存に失敗しました: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
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
    return '$weekday, ${now.day.toString().padLeft(2, '0')} $month ${now.year} ' +
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} GMT';
  }

  // Azure Blob Storage の共有キー認証ヘッダを作成
  String _createAuthorizationHeader(String stringToSign, String accountKey) {
    final keyBytes = base64.decode(accountKey);
    final hmacSha256 = crypto.Hmac(crypto.sha256, keyBytes);
    final stringToSignBytes = utf8.encode(stringToSign);
    final signature = hmacSha256.convert(stringToSignBytes);
    return base64.encode(signature.bytes);
  }

  // Azure Blob Storageにファイルをアップロード（SAS URL方式）
  Future<void> _uploadToAzure(String filePath, String blobName) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        print('アップロードファイルが見つかりません: $filePath');
        throw Exception('ファイルが見つかりません: $filePath');
      }

      print('Azure Blob Storageへアップロード開始: $blobName');

      // ファイルの内容を読み込む
      final content = await file.readAsBytes();
      print('ファイル読み込み完了: ${content.length} バイト');

      try {
        // SAS URL を使用してAzureストレージクライアントを初期化
        final storage =
            azblob.AzureStorage.parse(azureConnectionString); // 接続文字列方式に変更
        print('Azure Storage接続成功 (接続文字列)');

        // SAS URLではコンテナ名を含めてアップロード
        final fullBlobPath = '$containerName/$blobName';
        print('アップロード先: $fullBlobPath');

        // ファイルをアップロード
        await storage.putBlob(
          fullBlobPath,
          bodyBytes: content,
          contentType: 'text/csv',
        );

        print('Azure Blob Storageへのアップロード成功: $fullBlobPath');

        // 成功通知
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Azureへデータをアップロードしました: $blobName'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        final errorDetails = e.toString();
        print('Azure Blob Storageアップロードエラー: $errorDetails'); // 元のログ

        // AzureStorageExceptionの詳細を出力
        if (e is azblob.AzureStorageException) {
          print('>>> AzureStorageException詳細 <<<');
          print('Status Code: ${e.statusCode}');
          print('Message: ${e.message}');
          // print('Details: ${e.details}'); // details プロパティは存在しないためコメントアウト
          print('---------------------------------');
        }

        throw Exception('アップロードエラー: $errorDetails'); // エラーを再スロー
      }
    } catch (e) {
      print('Azure Blob Storageへのアップロード処理失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Azureへのアップロードに失敗しました: $e'),
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.red,
          ),
        );
      }
      throw e;
    }
  }

  // データ保存時にAzureにもアップロードするよう修正
  Future<void> _saveExperimentData() async {
    // 実験ファイル名の確認
    if (experimentFileName.isEmpty) {
      experimentFileName =
          'acceleration_data_${selectedTempo?.bpm ?? currentMusicBPM}_bpm_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    }

    // ローカルにCSVファイルとして保存
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$experimentFileName.csv';

    // CSVデータの作成
    List<List<dynamic>> csvData = [
      [
        'Timestamp',
        'Target BPM',
        'Detected BPM',
        'Reliability',
        'AccX',
        'AccY',
        'AccZ',
        'Magnitude'
      ], // ヘッダー行
    ];
    csvData.addAll(experimentRecords.map((e) => e.toCSV()).toList());
    String csvString = const ListToCsvConverter().convert(csvData);

    // ファイルに書き込み
    await File(filePath).writeAsString(csvString);
    print('実験データをローカルに保存しました: $filePath');
    print(
        'データ行数: ${experimentRecords.length}, ファイルサイズ: ${(csvString.length / 1024).toStringAsFixed(2)} KB');

    // 保存完了メッセージを表示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '加速度データをローカルに保存しました: $experimentFileName\n${experimentRecords.length}行のデータ'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Azure Blob Storageへのアップロード
    if (mounted) {
      // アップロード中表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(width: 16),
              Text('Azureにデータをアップロード中...'),
            ],
          ),
          duration: Duration(seconds: 10),
          backgroundColor: Colors.blue,
        ),
      );
    }

    try {
      // Azureへアップロード
      await _uploadToAzure(filePath, '$experimentFileName.csv');

      // データ保存場所を通知
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('データ保存完了'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ファイル名: $experimentFileName.csv'),
                const SizedBox(height: 8),
                Text('データ数: ${experimentRecords.length}行'),
                const SizedBox(height: 16),
                const Text('保存先:'),
                Text('• ローカル: $filePath', style: const TextStyle(fontSize: 14)),
                Text('• Azure: $containerName/$experimentFileName.csv',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Azureアップロードエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Azureへのアップロードに失敗しました: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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

  /// 見つかったデバイスに接続
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

  /// Bluetooth Serial通信のセットアップ
  Future<void> _setupSerialCommunication() async {
    if (targetDevice == null || _isDisposing) return;

    try {
      // M5StickGaitのBluetoothサービスを探索
      List<BluetoothService> services = await targetDevice!.discoverServices();

      for (BluetoothService service in services) {
        print('サービス発見: ${service.uuid}');

        // 指定されたサービスUUIDを探す
        if (service.uuid == serviceUuid) {
          // サービス内のキャラクタリスティックを探索
          for (BluetoothCharacteristic c in service.characteristics) {
            // 指定されたキャラクタリスティックUUIDを探す
            if (c.uuid == charUuid) {
              print('通知可能なキャラクタリスティック発見: ${c.uuid}');

              try {
                // Notifyを有効化
                await c.setNotifyValue(true);

                // データリスナーの設定
                StreamSubscription characteristicSubscription =
                    c.lastValueStream.listen((value) {
                  if (value.isEmpty || _isDisposing) return;

                  try {
                    // 受信したバイト列をUTF-8文字列に変換
                    String jsonString = String.fromCharCodes(value);
                    // print('受信データ: $jsonString'); // この行をコメントアウト

                    // JSONとして解析
                    final jsonData = jsonDecode(jsonString);
                    final sensorData = M5SensorData.fromJson(jsonData);

                    if (!_isDisposing && mounted) {
                      setState(() {
                        latestData = sensorData;

                        // 履歴に追加
                        dataHistory.add(sensorData);
                        if (dataHistory.length > maxHistorySize) {
                          dataHistory.removeAt(0);
                        }

                        // データタイプに応じた処理
                        if (sensorData.type == 'raw' ||
                            sensorData.type == 'imu') {
                          // デバッグ出力追加（センサーデータ確認用）
                          /* print(
                              '📱 IMUデータ: X=${sensorData.accX?.toStringAsFixed(3)}, Y=${sensorData.accY?.toStringAsFixed(3)}, Z=${sensorData.accZ?.toStringAsFixed(3)}'); */

                          // RAWデータの場合は加速度データを処理
                          _processRawData(sensorData);
                        } else if (sensorData.type == 'bpm') {
                          // BPMデータの場合
                          // 自動テンポ調整が有効なら実行
                          if (isAutoAdjustEnabled &&
                              isPlaying &&
                              !isExperimentMode &&
                              sensorData.bpm != null) {
                            double currentTime = DateTime.now()
                                .millisecondsSinceEpoch
                                .toDouble();
                            if (currentTime - lastAutoAdjustTime >=
                                AUTO_ADJUST_INTERVAL) {
                              double detectedBPM = sensorData.bpm!;
                              double bpmDifference =
                                  (detectedBPM - currentMusicBPM).abs();

                              if (bpmDifference > currentMusicBPM * 0.05) {
                                double newBPM = currentMusicBPM +
                                    (detectedBPM - currentMusicBPM) * 0.3;
                                newBPM = newBPM.clamp(80.0, 140.0);
                                _changeMusicTempo(newBPM);
                                lastAutoAdjustTime = currentTime;
                                print(
                                    'BPMモードテンポ自動調整: $currentMusicBPM BPM (検出: $detectedBPM BPM)');
                              }
                            }
                          }

                          // 実験モードで記録中なら記録にも追加
                          if (isRecording && experimentTimer != null) {
                            _recordExperimentData();
                          }
                        }
                      });
                    }
                  } catch (e) {
                    print('データ解析エラー: $e');
                  }
                }, onError: (error) {
                  print('キャラクタリスティック読み取りエラー: $error');
                });
                _streamSubscriptions.add(characteristicSubscription);
              } catch (e) {
                print('通知有効化エラー: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('サービス探索エラー: $e');
    }
  }

  /// 切断
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

  // テスト記録の開始/停止
  void _toggleRecording() {
    setState(() {
      if (isRecording) {
        // 記録停止
        if (experimentTimer != null) {
          experimentTimer!.cancel();
          experimentTimer = null;
        }
        _finishExperiment();
      } else {
        // 記録開始
        experimentRecords.clear();
        bpmSpots.clear();
        isRecording = true;

        if (isPlaying && isExperimentMode) {
          _startExperiment();
        }
      }
    });
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

    // オーディオプレーヤーの解放
    // _audioPlayer.dispose();

    // タイマーの解放
    if (experimentTimer != null) {
      experimentTimer!.cancel();
    }

    // 切断処理
    disconnect().then((_) {
      super.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthCore M5 - 歩行測定'),
        backgroundColor: Colors.blueGrey.shade800,
      ),
      body: Column(
        children: [
          // Bluetooth接続ステータス - 常に表示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                  color:
                      isConnected ? Colors.green.shade800 : Colors.red.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'M5StickIMUに接続中' : 'デバイスに接続していません',
                  style: TextStyle(
                    color: isConnected
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: isScanning
                      ? null
                      : () {
                          print('スキャンボタンが押されました');
                          startScan();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected
                        ? Colors.orange.shade200
                        : Colors.blue.shade200,
                    foregroundColor: Colors.black87,
                  ),
                  child: Text(isConnected ? '再接続' : 'スキャン'),
                ),
              ],
            ),
          ),

          // メインコンテンツ - Expandedで残りの空間を使う
          Expanded(
            child: isExperimentMode
                ? _buildExperimentMode()
                : _buildDataMonitorMode(),
          ),

          // 実験モード切り替えボタン - 常に下部に表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: Icon(isExperimentMode
                  ? Icons.monitor_heart_outlined
                  : Icons.science_outlined),
              label: Text(isExperimentMode ? 'モニターモードに戻る' : '精度評価モードへ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isExperimentMode ? Colors.blue : Colors.amber,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  isExperimentMode = !isExperimentMode;
                  if (!isExperimentMode) {
                    isRecording = false;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // データモニターモードのUIを構築
  Widget _buildDataMonitorMode() {
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

            // 歩行BPM情報
            Card(
              elevation: 4,
              color: Colors.lightBlue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_heart, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          '歩行ピッチ (BPM)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // 信頼性インジケーター
                        stepDetector.reliabilityScore > 0
                            ? Row(
                                children: [
                                  Text(
                                    '信頼性: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  _buildReliabilityIndicator(
                                      stepDetector.reliabilityScore),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          calculatedBpmFromRaw != null
                              ? '${calculatedBpmFromRaw!.toStringAsFixed(1)}'
                              : '--',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'BPM',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.indigo,
                          ),
                        ),
                        const Spacer(),
                        // 最終更新時間
                        Text(
                          latestData?.timestamp != null
                              ? '最終更新: ${DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(latestData!.timestamp))}'
                              : '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 加速度センサー情報
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.speed, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '加速度情報',
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
                        _buildAccelDataColumn(
                            'X軸', latestData?.accX, Colors.red),
                        _buildAccelDataColumn(
                            'Y軸', latestData?.accY, Colors.green),
                        _buildAccelDataColumn(
                            'Z軸', latestData?.accZ, Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          '合成加速度:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          latestData?.magnitude != null
                              ? '${latestData!.magnitude!.toStringAsFixed(3)} G'
                              : '-- G',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 歩行ピッチ計算の詳細
            Card(
              elevation: 4,
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          '歩行解析情報',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        '検出ステップ数:', '${stepDetector.stepTimestamps.length}'),
                    _buildInfoRow(
                        '最新ステップ間隔:',
                        stepDetector.getLastStepInterval() != null
                            ? '${stepDetector.getLastStepInterval()!.toStringAsFixed(0)} ms'
                            : '-- ms'),
                    _buildInfoRow(
                        '生データBPM:',
                        calculatedBpmFromRaw != null
                            ? '${calculatedBpmFromRaw!.toStringAsFixed(1)} BPM'
                            : '-- BPM'),
                    _buildInfoRow(
                        'フィルター適用BPM:',
                        latestData?.bpm != null
                            ? '${latestData!.bpm!.toStringAsFixed(1)} BPM'
                            : '-- BPM'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 信頼性インジケーターを構築
  Widget _buildReliabilityIndicator(double reliability) {
    final int filledStars = (reliability * 5).round();
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < filledStars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

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
                          items: tempoPresets.map((tempo) {
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
                              child: Icon(
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
                                'BPM推移グラフ',
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
                                gridData: FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: true),
                                minX: 0,
                                maxX: bpmSpots.length.toDouble(),
                                minY: minY,
                                maxY: maxY,
                                lineBarsData: [
                                  // 検出BPM
                                  LineChartBarData(
                                    spots: bpmSpots,
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 3,
                                    dotData: FlDotData(show: false),
                                  ),
                                  // ターゲットBPM (直線)
                                  LineChartBarData(
                                    spots: [
                                      FlSpot(0, currentMusicBPM),
                                      FlSpot(bpmSpots.length.toDouble(),
                                          currentMusicBPM),
                                    ],
                                    isCurved: false,
                                    color: Colors.red.withOpacity(0.5),
                                    barWidth: 2,
                                    dotData: FlDotData(show: false),
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

                // データレコード表示
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
                                  Text(
                                    '記録間隔: 100ミリ秒',
                                    style: const TextStyle(fontSize: 14),
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
                                      "目標: ${record.targetBPM.toStringAsFixed(1)} BPM / " +
                                          "検出: ${record.detectedBPM?.toStringAsFixed(1) ?? 'N/A'} BPM",
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

                        // スクロール可能なエリアの下部に十分なスペースを確保
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

  // RAWデータ処理メソッド
  void _processRawData(M5SensorData sensorData) {
    final double? accX = sensorData.accX;
    final double? accY = sensorData.accY; // Y軸データを取得
    final double? accZ = sensorData.accZ;
    double? magnitude = sensorData.magnitude;

    // X軸加速度データがなければ処理中断
    if (accX == null) {
      // print('X軸加速度データがnullです。'); // デバッグ出力削減
      return;
    }

    // magnitude がない場合は計算する (グラフ表示等で使う可能性のため残す)
    if (accY != null && accZ != null) {
      magnitude ??= sqrt(accX * accX + accY * accY + accZ * accZ);
    }

    // グラフデータ更新 (magnitude を使用)
    if (showRawDataGraph && magnitude != null) {
      final x = magnitudeSpots.length.toDouble(); // magnitudeSpotsを基準にする
      // X, Y, Zも更新
      if (accX != null) accXSpots.add(FlSpot(x, accX));
      if (accY != null) accYSpots.add(FlSpot(x, accY));
      if (accZ != null) accZSpots.add(FlSpot(x, accZ));
      magnitudeSpots.add(FlSpot(x, magnitude));

      // グラフポイント数の制限
      while (magnitudeSpots.length > maxGraphPoints) {
        magnitudeSpots.removeAt(0);
        if (accXSpots.isNotEmpty) accXSpots.removeAt(0);
        if (accYSpots.isNotEmpty) accYSpots.removeAt(0);
        if (accZSpots.isNotEmpty) accZSpots.removeAt(0);
      }
      // インデックスを修正
      for (int i = 0; i < magnitudeSpots.length; i++) {
        if (i < accXSpots.length)
          accXSpots[i] = FlSpot(i.toDouble(), accXSpots[i].y);
        if (i < accYSpots.length)
          accYSpots[i] = FlSpot(i.toDouble(), accYSpots[i].y);
        if (i < accZSpots.length)
          accZSpots[i] = FlSpot(i.toDouble(), accZSpots[i].y);
        magnitudeSpots[i] = FlSpot(i.toDouble(), magnitudeSpots[i].y);
      }
    }

    // StepDetectorにはX軸データを渡す
    stepDetector.processData(accX, sensorData.timestamp).then((_) {
      // 計算が終わったらUIを更新 (必要なら)
      if (mounted && stepDetector.lastCalculatedBpm != calculatedBpmFromRaw) {
        setState(() {
          calculatedBpmFromRaw = stepDetector.lastCalculatedBpm;
        });
      }
    });

    // 実験モードで記録中ならデータを記録 (accXも記録)
    if (isRecording && experimentTimer != null) {
      final record = ExperimentRecord(
        timestamp: DateTime.now(),
        targetBPM: currentMusicBPM,
        detectedBPM: calculatedBpmFromRaw, // StepDetectorからのBPM
        reliability: stepDetector.reliabilityScore,
        accX: accX,
        accY: accY,
        accZ: accZ,
        magnitude: magnitude,
      );

      experimentRecords.add(record);
    }
  }

  Color _getReliabilityColor(double reliabilityScore) {
    if (reliabilityScore > 0.7) {
      return Colors.green;
    } else if (reliabilityScore > 0.5) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  // 指定したBPMに最も近いテンポプリセットを見つける
  MusicTempo _findNearestTempoPreset(double bpm) {
    MusicTempo nearest = tempoPresets[0];
    double minDiff = (tempoPresets[0].bpm - bpm).abs();

    for (var tempo in tempoPresets) {
      double diff = (tempo.bpm - bpm).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = tempo;
      }
    }

    return nearest;
  }

  // 段階的テンポ変更を開始（未使用）
  /*
  void _startGradualTempoChange() {
    if (isGradualTempoChangeEnabled || !isPlaying) return;

    // 自動テンポ調整を無効化
    isAutoAdjustEnabled = false;

    // 初期設定
    initialBPM = currentMusicBPM;
    isGradualTempoChangeEnabled = true;

    // 現在のBPMと目標BPMから必要なステップ数を計算
    double totalChange = (targetBPM - initialBPM).abs();
    double totalMinutes = totalChange / tempoChangeStep;
    int totalSteps = (totalMinutes * 60 / tempoChangeIntervalSeconds).ceil();
    double actualStepBPM = totalChange / totalSteps; // 実際のステップサイズ

    // テンポ変化の方向（増加か減少か）
    int direction = targetBPM > initialBPM ? 1 : -1;

    // 開始メッセージ
    print(
        '段階的テンポ変更開始: $initialBPM → $targetBPM BPM（$totalSteps ステップ、${tempoChangeIntervalSeconds}秒毎、${actualStepBPM.abs().toStringAsFixed(2)} BPM/ステップ）');

    int currentStep = 0;

    // タイマーでテンポを徐々に変更
    gradualTempoTimer =
        Timer.periodic(Duration(seconds: tempoChangeIntervalSeconds), (timer) {
      currentStep++;

      // 新しいBPMを計算
      double newBPM = initialBPM + (actualStepBPM * currentStep * direction);

      // 目標に達したかチェック
      if ((direction > 0 && newBPM >= targetBPM) ||
          (direction < 0 && newBPM <= targetBPM)) {
        newBPM = targetBPM;
        _stopGradualTempoChange(); // 目標達成で終了
      }

      // テンポを変更
      _changeMusicTempo(newBPM);

      print('段階的テンポ変更: ステップ $currentStep/$totalSteps - $newBPM BPM');

      // 実験データの記録（実験モードでは記録済み）
      if (!isExperimentMode && calculatedBpmFromRaw != null) {
        final record = ExperimentRecord(
          timestamp: DateTime.now(),
          targetBPM: newBPM,
          detectedBPM: calculatedBpmFromRaw,
          reliability: stepDetector.reliabilityScore,
          accX: latestData?.accX,
          accY: latestData?.accY,
          accZ: latestData?.accZ,
          magnitude: latestData?.magnitude,
        );

        experimentRecords.add(record);
      }

      // UIを更新
      if (mounted) {
        setState(() {});
      }
    });
  }
  */
}

// 歩行検出アルゴリズム用クラス
// Definitions moved to lib/utils/step_detector.dart
