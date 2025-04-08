import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // flutter_blue_plusライブラリ
import 'dart:async'; // Streamの取り扱いに必要
import 'dart:io';
import 'dart:convert'; // jsonDecodeで使用するため、これは残す
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math; // Mathクラスを使うためにインポート（as mathで修飾）
import 'package:azblob/azblob.dart' as azblob; // Azure Blob Storage
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 環境変数管理用
import 'package:http/http.dart' as http;

// 独自モジュール
import 'models/sensor_data.dart';
import 'utils/gait_analysis_service.dart'; // 新しいサービスをインポート
import 'services/metronome.dart';

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
  List<FlSpot> bpmSpots = []; // SPMデータ格納用 (名前はそのまま)
  double minY = 40; // SPM範囲に合わせて調整
  double maxY = 160; // SPM範囲に合わせて調整

  // メトロノーム関連
  late Metronome _metronome;
  bool get isPlaying => _metronome.isPlaying;
  double get currentMusicBPM => _metronome.currentBpm;
  MusicTempo? selectedTempo;
  final List<MusicTempo> tempoPresets = [
    MusicTempo(name: '60 BPM', bpm: 60.0),
    MusicTempo(name: '80 BPM', bpm: 80.0),
    MusicTempo(name: '100 BPM', bpm: 100.0),
    MusicTempo(name: '120 BPM', bpm: 120.0),
    MusicTempo(name: '140 BPM', bpm: 140.0),
  ];

  // 実験モード関連
  bool isExperimentMode = false;
  int experimentDurationSeconds = 60;
  DateTime? experimentStartTime;
  Timer? experimentTimer;
  int remainingSeconds = 0;

  // 歩行解析サービス
  late final GaitAnalysisService gaitAnalysisService;

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

  @override
  void initState() {
    super.initState();

    // 初期化を非同期で安全に行う
    _initBluetooth();

    // cadenceDetector = RightFootCadenceDetector(); // 新しい検出器を初期化 // 削除

    // 歩行解析サービスを初期化
    gaitAnalysisService =
        GaitAnalysisService(samplingRate: 50.0); // サンプリングレートを指定

    _metronome = Metronome(); // Metronomeインスタンスを作成
    _metronome.initialize().then((_) {
      // Metronomeを初期化
      selectedTempo = tempoPresets[2]; // Default to 100 BPM
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
        'gait_data_${selectedTempo?.bpm ?? currentMusicBPM}_target_${DateFormat('yyyyMMdd_HHmmss').format(experimentStartTime!)}';

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

  // 実験データを記録 (SPMを記録するように変更)
  void _recordExperimentData() {
    // 最新の歩行解析結果を取得
    double detectedSpm = gaitAnalysisService.currentSpm; // SPMを取得
    // 信頼度は現アルゴリズムでは直接出力されないため、一旦固定値 or null
    double? reliability = null; // もしくは推定値を計算する方法を別途実装

    // 最新のセンサーデータ
    double? accX = latestData?.accX;
    double? accY = latestData?.accY;
    double? accZ = latestData?.accZ;
    double? magnitude = latestData?.magnitude;

    final record = ExperimentRecord(
      timestamp: DateTime.now(),
      targetBPM: currentMusicBPM, // 音楽テンポは targetBPM として記録
      detectedBPM: detectedSpm > 0 ? detectedSpm : null, // 検出されたSPMを記録
      reliability: reliability,
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

  // Azure Blob Storageにファイルをアップロード（複数の接続方法を試行）
  Future<void> _uploadToAzure(String filePath, String blobName) async {
    // --- デバッグ用ハードコード ---
    const String hardcodedConnectionString =
        'BlobEndpoint=https://hagiharatest.blob.core.windows.net/;QueueEndpoint=https://hagiharatest.queue.core.windows.net/;FileEndpoint=https://hagiharatest.file.core.windows.net/;TableEndpoint=https://hagiharatest.table.core.windows.net/;SharedAccessSignature=sv=2024-11-04&ss=bfqt&srt=sco&sp=rwdlacupiytfx&se=2025-08-08T13:00:17Z&st=2025-04-07T05:00:17Z&spr=https,http&sig=j7yyunF0c%2FukvQtCwHmgcErI0KyYlco9AhaALYao6xk%3D';
    String? hardcodedSasToken;
    final hcSasMatch = RegExp(r'SharedAccessSignature=([^;]+)')
        .firstMatch(hardcodedConnectionString);
    if (hcSasMatch != null && hcSasMatch.groupCount >= 1) {
      hardcodedSasToken = hcSasMatch.group(1);
    }
    const String hcAccountName = 'hagiharatest';
    const String hcContainerName = 'healthcaredata'; // 新しいコンテナ名
    print('--- ハードコードされた接続情報を使用 --- ');
    // --- デバッグ用ハードコードここまで ---

    try {
      // 環境変数の代わりにハードコード値を使用
      print('--- 使用する接続情報 --- ');
      print('AZURE_STORAGE_ACCOUNT: $hcAccountName');
      if (hardcodedConnectionString.isNotEmpty) {
        final int maxConnLength = hardcodedConnectionString.length > 50
            ? 50
            : hardcodedConnectionString.length;
        print(
            '接続文字列 (ハードコード): ${hardcodedConnectionString.substring(0, maxConnLength)}...');
      } else {
        print('接続文字列 (ハードコード): 空');
      }
      if (hardcodedSasToken != null && hardcodedSasToken.isNotEmpty) {
        final int maxSasLength =
            hardcodedSasToken.length > 20 ? 20 : hardcodedSasToken.length;
        print(
            'SASトークン (ハードコード): ${hardcodedSasToken.substring(0, maxSasLength)}...');
      } else {
        print('SASトークン (ハードコード): nullまたは空');
      }
      print('コンテナ名: $hcContainerName');
      print('------------------------');

      File file = File(filePath);
      if (!await file.exists()) {
        print('アップロードファイルが見つかりません: $filePath');
        throw Exception('ファイルが見つかりません: $filePath');
      }

      print('Azure Blob Storageへアップロード開始: $blobName');

      // ファイルの内容を読み込む
      final content = await file.readAsBytes();
      print('ファイル読み込み完了: ${content.length} バイト');

      // React参考コードのように実装
      try {
        print('React参考コード方式でのアップロード試行');

        // SASトークンを正しく整形（先頭に?がなければ追加）
        String sasToken = hardcodedSasToken ?? '';
        if (!sasToken.startsWith('?') && !sasToken.isEmpty) {
          sasToken = '?' + sasToken;
        }

        // Reactコードと同様にURLを構築
        final blobUrl = 'https://$hcAccountName.blob.core.windows.net$sasToken';
        print(
            'Base Blob URL: ${blobUrl.substring(0, blobUrl.length > 100 ? 100 : blobUrl.length)}...');

        // コンテナクライアント部分をHTTPリクエストとして実装
        final containerUrl = '$blobUrl&comp=list';
        print(
            'コンテナURL確認: ${containerUrl.substring(0, containerUrl.length > 100 ? 100 : containerUrl.length)}...');

        // ブロブのアップロードURL
        final uploadUrl =
            'https://$hcAccountName.blob.core.windows.net/$hcContainerName/$blobName$sasToken';
        print(
            'アップロードURL: ${uploadUrl.substring(0, uploadUrl.length > 100 ? 100 : uploadUrl.length)}...');

        final headers = {
          'Content-Type': 'text/csv',
          'x-ms-blob-type': 'BlockBlob',
          'x-ms-version': '2021-06-08', // Azure Storage REST APIバージョン
        };

        final response = await http.put(
          Uri.parse(uploadUrl),
          headers: headers,
          body: content,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('アップロード成功: $hcContainerName/$blobName');
          print('ステータスコード: ${response.statusCode}');
          _showUploadSuccess(blobName);
          return;
        } else {
          final errorDetails =
              'ステータスコード: ${response.statusCode}, レスポンス: ${response.body}';
          print('アップロード失敗: $errorDetails');
          throw Exception('HTTP $errorDetails');
        }
      } catch (e) {
        print('React方式でのアップロード失敗: $e');

        // 別方法を試行 - sasTokenを別の形式で使用
        try {
          print('別方法: SASトークン形式変更でのアップロード試行');

          // SASトークンを直接使用（SharedAccessSignatureプレフィックスを削除）
          String sasToken = hardcodedSasToken ?? '';
          // SAS トークンから "SharedAccessSignature=" プレフィックスを削除
          if (sasToken.startsWith('SharedAccessSignature=')) {
            sasToken = sasToken.substring('SharedAccessSignature='.length);
          }

          if (sasToken.startsWith('sv=') && !sasToken.startsWith('?')) {
            sasToken = '?' + sasToken;
          }

          final uploadUrl =
              'https://$hcAccountName.blob.core.windows.net/$hcContainerName/$blobName$sasToken';
          print(
              '新しいアップロードURL: ${uploadUrl.substring(0, uploadUrl.length > 100 ? 100 : uploadUrl.length)}...');

          final headers = {
            'Content-Type': 'text/csv',
            'x-ms-blob-type': 'BlockBlob',
            'x-ms-version': '2021-06-08',
          };

          final response = await http.put(
            Uri.parse(uploadUrl),
            headers: headers,
            body: content,
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            print('別方法でのアップロード成功: $hcContainerName/$blobName');
            print('ステータスコード: ${response.statusCode}');
            _showUploadSuccess(blobName);
            return;
          } else {
            final errorDetails =
                'ステータスコード: ${response.statusCode}, レスポンス: ${response.body}';
            print('別方法でのアップロード失敗: $errorDetails');
            throw Exception('HTTP $errorDetails');
          }
        } catch (altError) {
          print('別方法でもアップロード失敗: $altError');

          // 最後の手段 - azblob + 接続文字列を試す
          try {
            print('最終手段: azblob + 接続文字列を使用してアップロード試行');
            final storage =
                azblob.AzureStorage.parse(hardcodedConnectionString);

            final fullBlobPath = '$hcContainerName/$blobName';
            print('azblob アップロード先: $fullBlobPath');

            await storage.putBlob(
              fullBlobPath,
              bodyBytes: content,
              contentType: 'text/csv',
            );

            print('azblob方式でのアップロード成功: $fullBlobPath');
            _showUploadSuccess(blobName);
            return;
          } catch (backupError) {
            print('すべての方法でアップロード失敗: $backupError');
            throw Exception(
                'すべてのアップロード方法が失敗しました: 元のエラー: $e, 別方法エラー: $altError, azblob エラー: $backupError');
          }
        }
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

  // アップロード成功時の通知表示
  void _showUploadSuccess(String blobName) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Azureへデータをアップロードしました: $blobName'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // データ保存時にAzureにもアップロードするよう修正
  Future<void> _saveExperimentData() async {
    // 実験ファイル名の確認
    if (experimentFileName.isEmpty) {
      experimentFileName =
          'gait_data_${selectedTempo?.bpm ?? currentMusicBPM}_target_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    }

    // ローカルにCSVファイルとして保存
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$experimentFileName.csv';

    // CSVデータの作成
    List<List<dynamic>> csvData = [
      [
        'Timestamp',
        'Target BPM',
        'Detected SPM', // ヘッダー変更
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
      // Azureへアップロード - healthcaredataコンテナを使用
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
                Text('• Azure: healthcaredata/$experimentFileName.csv',
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

  /// Bluetooth Serial通信のセットアップ (データ処理部分を変更)
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

  /// 新しいセンサーデータを処理するメソッド
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
      gaitAnalysisService.addSensorData(sensorData);

      // UI表示用の値を更新
      _displaySpm = gaitAnalysisService.currentSpm;
      _displayStepCount = gaitAnalysisService.stepCount;

      // グラフ用データの更新 (SPM)
      if (_displaySpm > 0) {
        _updateSpmGraphData(_displaySpm);
      }

      // 実験モードで記録中なら記録 (タイマー内で実施)
      // if (isRecording && experimentTimer != null) { ... }
    });
  }

  /// SPMグラフデータを更新するメソッド
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
                ? _buildExperimentModeUI() // 実験モードUI
                : _buildDataMonitorModeUI(), // モニターモードUI
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
                                gridData: FlGridData(show: true),
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
                                  topTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(
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
                                    dotData: FlDotData(show: false),
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
        Card(
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
                                gridData: FlGridData(show: true),
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
                                      // X軸は経過時間 or レコード数で表示
                                      // getTitlesWidget: ...
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(
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
                                    dotData: FlDotData(show: false),
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
                                      "目標: ${record.targetBPM.toStringAsFixed(1)} BPM / " +
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
    // アクセラレーショングラフ用のデータ (変更なし)
    // ...

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
                        const Icon(Icons.directions_walk,
                            color: Colors.blue), // アイコン変更
                        const SizedBox(width: 8),
                        const Text(
                          '歩行ピッチ (SPM)', // ラベル変更
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _displaySpm > 0
                              ? _displaySpm.toStringAsFixed(1)
                              : '--',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
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
                        Text(
                          '歩数: $_displayStepCount',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- 加速度情報カード (変更なし) ---
            Card(
                // ... (加速度表示部分は変更なし)
                ),
            const SizedBox(height: 16),

            // --- SPM推移グラフ ---
            if (bpmSpots.length > 1) // データが2点以上あれば表示
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
                            gridData: FlGridData(show: true),
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
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
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
                                dotData: FlDotData(show: false),
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
}

// 歩行検出アルゴリズム用クラス
// Definitions moved to lib/utils/right_foot_cadence_detector.dart
