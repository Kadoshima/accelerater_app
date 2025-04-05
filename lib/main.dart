import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // flutter_blue_plusライブラリ
import 'dart:async'; // Streamの取り扱いに必要
import 'dart:io';
import 'dart:convert'; // JSONのデコード用
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:azblob/azblob.dart' as azblob;
import 'dart:typed_data'; // Uint8List のために追加

// Azure Blob Storage 設定 (ハードコード)
const String azureSasUrlString =
    "https://hagiharatest.blob.core.windows.net/healthcaredata?sp=r&st=2025-04-05T11:00:37Z&se=2025-04-05T19:00:37Z&spr=https&sv=2024-11-04&sr=c&sig=ZVYBS%2Bloljb7PICeI2lsQzOnEBXD5SjEaneatdZjaw0%3D";
const String azureContainerName = "healthcaredata"; // SAS URLからコンテナ名を取得

void main() {
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
class M5SensorData {
  final String device;
  final int timestamp;
  final String type;
  final Map<String, dynamic> data;

  M5SensorData({
    required this.device,
    required this.timestamp,
    required this.type,
    required this.data,
  });

  factory M5SensorData.fromJson(Map<String, dynamic> json) {
    return M5SensorData(
      device: json['device'],
      timestamp: json['timestamp'],
      type: json['type'],
      data: json['data'],
    );
  }

  // raw または imu データからのアクセサ
  double? get accX =>
      (type == 'raw' || type == 'imu') ? data['accX']?.toDouble() : null;
  double? get accY =>
      (type == 'raw' || type == 'imu') ? data['accY']?.toDouble() : null;
  double? get accZ =>
      (type == 'raw' || type == 'imu') ? data['accZ']?.toDouble() : null;
  double? get magnitude => type == 'raw' ? data['magnitude']?.toDouble() : null;

  // bpmデータからのアクセサ
  double? get bpm => type == 'bpm' ? data['bpm']?.toDouble() : null;
  int? get lastInterval => type == 'bpm' ? data['lastInterval'] : null;
}

// 実験記録用のデータモデル
class ExperimentRecord {
  final DateTime timestamp;
  final double targetBPM;
  final double? detectedBPM;
  final double? reliability; // 信頼性スコア

  ExperimentRecord({
    required this.timestamp,
    required this.targetBPM,
    this.detectedBPM,
    this.reliability,
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

  // 音楽プレイヤー
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  double currentMusicBPM = 100.0;
  bool isAutoAdjustEnabled = false; // 自動テンポ調整フラグ
  double lastAutoAdjustTime = 0; // 最後に自動調整した時刻（ミリ秒）
  static const double AUTO_ADJUST_INTERVAL = 5000; // 自動調整の間隔（ミリ秒）
  static const double MIN_RELIABILITY_FOR_ADJUST = 0.6; // 自動調整に必要な最小信頼性

  // 段階的テンポ変更用
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
  final targetDeviceName = "M5StickGait";

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

  @override
  void initState() {
    super.initState();

    // 初期化を非同期で安全に行う
    _initBluetooth();
    _initAudioPlayer();
  }

  // オーディオプレーヤーの初期化
  Future<void> _initAudioPlayer() async {
    try {
      // メトロノーム音源を設定
      await _audioPlayer.setAsset('assets/sounds/metronome_click.mp3');

      // 初期テンポを設定
      selectedTempo = tempoPresets[1]; // 100 BPM
      currentMusicBPM = selectedTempo!.bpm;

      // スピード調整（1.0がデフォルト）
      await _audioPlayer.setSpeed(1.0);
    } catch (e) {
      print('オーディオプレーヤー初期化エラー: $e');
    }
  }

  // 音楽の再生/一時停止を切り替える
  Future<void> _togglePlayback() async {
    try {
      if (isPlaying) {
        await _audioPlayer.pause();
        if (isRecording && experimentTimer != null) {
          experimentTimer!.cancel();
          experimentTimer = null;
        }
      } else {
        // 選択されたテンポに応じて再生速度を調整
        if (selectedTempo != null) {
          currentMusicBPM = selectedTempo!.bpm;

          // 実験モードの場合はタイマーを開始
          if (isExperimentMode && isRecording) {
            _startExperiment();
          }
        }

        // ループ再生を有効にして開始
        await _audioPlayer.setLoopMode(LoopMode.one);
        await _audioPlayer.play();
      }

      setState(() {
        isPlaying = !isPlaying;
      });
    } catch (e) {
      print('再生エラー: $e');
    }
  }

  // テンポを変更する
  Future<void> _changeTempo(MusicTempo tempo) async {
    try {
      currentMusicBPM = tempo.bpm;
      selectedTempo = tempo;

      // 再生中なら新しいテンポを適用
      if (isPlaying) {
        // テンポに応じた再生速度を計算（100BPMを基準に）
        // 例：110BPM = 110/100 = 1.1倍速
        double speedRatio = tempo.bpm / 100.0;
        await _audioPlayer.setSpeed(speedRatio);
      }

      setState(() {});
    } catch (e) {
      print('テンポ変更エラー: $e');
    }
  }

  // 実験を開始する
  void _startExperiment() {
    // 実験開始時刻を記録
    experimentStartTime = DateTime.now();
    remainingSeconds = experimentDurationSeconds;

    // 実験ファイル名を設定
    experimentFileName =
        'experiment_${selectedTempo!.bpm}_bpm_${DateFormat('yyyyMMdd_HHmmss').format(experimentStartTime!)}';

    // タイマーを設定して1秒ごとに更新
    experimentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        remainingSeconds--;

        // 実験終了時の処理
        if (remainingSeconds <= 0) {
          timer.cancel();
          _finishExperiment();
        }
      });

      // 1秒ごとにデータを記録
      if (latestData != null && latestData!.type == 'bpm') {
        _recordExperimentData();
      }
    });
  }

  // 実験データを記録
  void _recordExperimentData() {
    final record = ExperimentRecord(
      timestamp: DateTime.now(),
      targetBPM: currentMusicBPM,
      detectedBPM: latestData?.bpm,
      reliability: stepDetector.reliabilityScore,
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
      await _audioPlayer.pause();
      setState(() {
        isPlaying = false;
      });
    }

    // 完了メッセージを表示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('実験データを保存しました: $experimentFileName'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Azure Blob Storageにファイルをアップロード
  Future<void> _uploadToAzure(String filePath, String blobName) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        print('アップロードファイルが見つかりません: $filePath');
        return;
      }

      print('Azure Blob Storageへアップロード開始: $blobName');

      // azblobパッケージを使用してアップロード
      final storage = azblob.AzureStorage.parse(azureSasUrlString);

      // ファイルの内容をUint8Listとして読み込む
      Uint8List content = await file.readAsBytes();

      // azblobはパスからコンテナ名を自動判別しないため、Blob名を指定
      await storage.putBlob(blobName,
          bodyBytes: content, contentType: 'text/csv');

      print('Azure Blob Storageへのアップロード成功: $blobName');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Azureへデータをアップロードしました: $blobName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Azure Blob Storageへのアップロードエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Azureへのアップロードに失敗しました: $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // データ保存時にAzureにもアップロードするよう修正
  Future<void> _saveExperimentData() async {
    // ... (既存のローカル保存処理) ...
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$experimentFileName.csv';
    // ... (既存のCSV書き込み処理) ...

    print('実験データをローカルに保存しました: $filePath');

    // Azure Blob Storageへのアップロード
    await _uploadToAzure(filePath, '$experimentFileName.csv');
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
          print('デバイス発見: ${r.device.name} (${r.device.id})');

          // ターゲット名と一致するデバイスを発見したら接続へ
          if (r.device.name == targetDeviceName) {
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
                    print('受信データ: $jsonString');

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
    _audioPlayer.dispose();

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
    final statusText = () {
      if (isScanning) return "スキャン中...";
      if (isConnecting) return "接続中...";
      if (isConnected) return "接続済み";
      return "未接続";
    }();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthCore M5 - 歩行測定'),
        actions: [
          if (isConnected)
            IconButton(
              icon: Icon(isExperimentMode ? Icons.science : Icons.bluetooth),
              onPressed: () {
                setState(() {
                  isExperimentMode = !isExperimentMode;
                  if (isRecording) {
                    _toggleRecording(); // 記録中なら停止
                  }
                });
              },
              tooltip: isExperimentMode ? '通常モード' : '実験モード',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 接続状態表示
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isConnected ? Colors.green.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: isConnected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "状態: $statusText",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isConnected ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: isScanning ? null : startScan,
                    child: const Text("デバイスをスキャン"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // スキャン結果表示
            if (_scanResults.isNotEmpty && !isConnected) ...[
              const Text("見つかったデバイス:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    final result = _scanResults[index];
                    final name = result.device.name.isNotEmpty
                        ? result.device.name
                        : "不明なデバイス";
                    final id = result.device.id.toString();
                    final rssi = result.rssi.toString();

                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text('ID: $id, 信号強度: $rssi dBm'),
                        trailing: ElevatedButton(
                          child: const Text('接続'),
                          onPressed: isConnecting ||
                                  (isConnected &&
                                      targetDevice?.id == result.device.id)
                              ? null
                              : () {
                                  // 手動で接続
                                  FlutterBluePlus.stopScan();
                                  connectToDevice(result.device);
                                },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (!isScanning && !isConnected) ...[
              const Text("デバイスが見つかりませんでした。再スキャンしてください。"),
            ],

            if (isConnected) ...[
              const SizedBox(height: 16),
              if (isExperimentMode) ...[
                // 実験モード表示
                _buildExperimentModeView(),
              ] else ...[
                // 通常のデータ表示
                Expanded(
                  flex: 3,
                  child: _buildDataDisplay(),
                ),
              ],
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: disconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text("切断"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 実験モードのビュー
  Widget _buildExperimentModeView() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 実験モードヘッダー
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.science, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "歩行ピッチ精度評価モード",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // テンポ選択
          Row(
            children: [
              const Text("テスト用テンポ: "),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<MusicTempo>(
                  isExpanded: true,
                  value: selectedTempo,
                  items: tempoPresets.map((tempo) {
                    return DropdownMenuItem<MusicTempo>(
                      value: tempo,
                      child: Text(tempo.name),
                    );
                  }).toList(),
                  onChanged: isPlaying
                      ? null
                      : (tempo) {
                          if (tempo != null) {
                            _changeTempo(tempo);
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 再生/記録コントロール
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(isPlaying ? "一時停止" : "再生"),
                onPressed: _togglePlayback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPlaying ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                icon:
                    Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
                label: Text(isRecording ? "記録停止" : "記録開始"),
                onPressed: latestData == null ? null : _toggleRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 残り時間表示（記録中のみ）
          if (isRecording && experimentTimer != null) ...[
            LinearProgressIndicator(
              value: remainingSeconds / experimentDurationSeconds,
            ),
            const SizedBox(height: 4),
            Text(
              "残り時間: $remainingSeconds 秒",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
          ],

          // データ表示
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "設定テンポ: ${currentMusicBPM.toStringAsFixed(1)} BPM",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (latestData != null && latestData!.type == 'bpm')
                      Text(
                        "検出テンポ: ${latestData!.bpm?.toStringAsFixed(1) ?? '?'} BPM",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // グラフ表示
                if (isRecording && bpmSpots.isNotEmpty)
                  Expanded(
                    child: _buildBpmChart(),
                  )
                else
                  const Expanded(
                    child: Center(
                      child: Text("記録を開始すると、ここにグラフが表示されます"),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // BPMグラフを構築
  Widget _buildBpmChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: bpmSpots.length.toDouble(),
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('時間 (秒)'),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 5 == 0) {
                  return Text(value.toInt().toString());
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('BPM'),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 10 == 0) {
                  return Text(value.toInt().toString());
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: FlGridData(
          drawHorizontalLine: true,
          horizontalInterval: 10,
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          // BPMデータライン
          LineChartBarData(
            spots: bpmSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
          // 目標BPMライン
          LineChartBarData(
            spots: [
              FlSpot(0, currentMusicBPM),
              FlSpot(bpmSpots.length.toDouble(), currentMusicBPM),
            ],
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
        ],
      ),
    );
  }

  Widget _buildDataDisplay() {
    if (latestData == null) {
      return const Center(child: Text("データ待機中..."));
    }

    // if (latestData!.type == 'raw') { // 元の条件
    if (latestData!.type == 'raw' || latestData!.type == 'imu') {
      // 'imu' でも加速度表示
      // 加速度データ表示
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("加速度データモード:", // 表示名を変更
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),

          // 値の表示
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("X軸加速度: ${latestData!.accX?.toStringAsFixed(3)} G"),
                    Text("Y軸加速度: ${latestData!.accY?.toStringAsFixed(3)} G"),
                    Text("Z軸加速度: ${latestData!.accZ?.toStringAsFixed(3)} G"),
                    Text(
                        "合成加速度: ${latestData!.magnitude?.toStringAsFixed(3) ?? '計算中...'} G"),
                  ],
                ),
              ),

              // 独自計算のBPM表示
              if (calculatedBpmFromRaw != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("独自歩行検出:",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("BPM: ${calculatedBpmFromRaw!.toStringAsFixed(1)}",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                          "間隔: ${stepDetector.getLastStepInterval() ?? '?'} ms"),
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            color: _getReliabilityColor(
                                stepDetector.reliabilityScore),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "信頼性: ${(stepDetector.reliabilityScore * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                                color: _getReliabilityColor(
                                    stepDetector.reliabilityScore),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            stepDetector.reset();
                            calculatedBpmFromRaw = null;
                          });
                        },
                        child: const Text("リセット"),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // 自動テンポ調整ボタン（BPM検出中かつ再生中のみ表示）
          if (calculatedBpmFromRaw != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(isPlaying
                      ? (isAutoAdjustEnabled ? Icons.sync : Icons.sync_disabled)
                      : Icons.music_note),
                  label: Text(isPlaying
                      ? (isAutoAdjustEnabled ? "自動調整ON" : "自動調整OFF")
                      : "音楽テンポ: ${currentMusicBPM.toStringAsFixed(1)} BPM"),
                  onPressed: isPlaying
                      ? () {
                          setState(() {
                            isAutoAdjustEnabled = !isAutoAdjustEnabled;
                            // 自動調整を有効にする場合は段階的変更を無効化
                            if (isAutoAdjustEnabled) {
                              _stopGradualTempoChange();
                              _autoAdjustTempo(); // 有効化時に即座に一度調整
                            }
                          });
                        }
                      : () {
                          _togglePlayback();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAutoAdjustEnabled
                        ? Colors.green
                        : (isPlaying ? Colors.blue : Colors.orange),
                  ),
                ),
                if (isPlaying) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: _togglePlayback,
                    color: Colors.red,
                  ),
                ],
              ],
            ),

            // 段階的テンポ変更コントロール
            if (isPlaying && !isAutoAdjustEnabled) ...[
              const SizedBox(height: 8),
              const Divider(),
              const Text("段階的テンポ変更:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),

              // 段階的テンポ変更のパラメータ設定
              if (!isGradualTempoChangeEnabled) ...[
                Row(
                  children: [
                    const Text("目標BPM: "),
                    Expanded(
                      child: Slider(
                        value: targetBPM,
                        min: 80.0,
                        max: 140.0,
                        divisions: 60,
                        label: targetBPM.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            targetBPM = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(targetBPM.toStringAsFixed(1)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text("変化速度: "),
                    Expanded(
                      child: Slider(
                        value: tempoChangeStep,
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        label: "${tempoChangeStep.toStringAsFixed(1)} BPM/分",
                        onChanged: (value) {
                          setState(() {
                            tempoChangeStep = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text("${tempoChangeStep.toStringAsFixed(1)}/分"),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("段階的テンポ変更開始"),
                  onPressed: _startGradualTempoChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ] else ...[
                // 進行中の段階的テンポ変更の状態表示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        "${initialBPM.toStringAsFixed(1)} → ${targetBPM.toStringAsFixed(1)} BPM"),
                    const SizedBox(width: 8),
                    Text("(${tempoChangeStep.toStringAsFixed(1)} BPM/分)"),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (currentMusicBPM - initialBPM).abs() /
                      (targetBPM - initialBPM).abs(),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text("停止"),
                  onPressed: _stopGradualTempoChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ],
          ],

          // グラフ表示切替ボタン
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(
                    showRawDataGraph ? Icons.visibility_off : Icons.visibility),
                label: Text(showRawDataGraph ? "グラフを隠す" : "グラフを表示"),
                onPressed: () {
                  setState(() {
                    showRawDataGraph = !showRawDataGraph;
                    if (showRawDataGraph && accXSpots.isEmpty) {
                      // グラフ表示時にデータがない場合は初期化
                      accXSpots.clear();
                      accYSpots.clear();
                      accZSpots.clear();
                      magnitudeSpots.clear();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: showRawDataGraph ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // グラフ表示
          if (showRawDataGraph) ...[
            const Text("加速度グラフ:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: _buildAccelerationChart(),
            ),
          ] else ...[
            // 履歴表示
            const Text("履歴:", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: dataHistory.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final data = dataHistory[dataHistory.length - 1 - index];
                  if (data.type == 'raw' || data.type == 'imu') {
                    return ListTile(
                      dense: true,
                      title: Text("時刻: ${_formatTimestamp(data.timestamp)}"),
                      subtitle: Text("X: ${data.accX?.toStringAsFixed(2)}, " +
                          "Y: ${data.accY?.toStringAsFixed(2)}, " +
                          "Z: ${data.accZ?.toStringAsFixed(2)}"),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ],
        ],
      );
    } else if (latestData!.type == 'bpm') {
      // BPMデータ表示
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("歩行ピッチモード:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text("歩行ピッチ: ${latestData!.bpm?.toStringAsFixed(1)} steps/min",
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text("最終ステップ間隔: ${latestData!.lastInterval} ms"),

          // 音楽再生コントロール
          if (latestData!.bpm != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(isPlaying
                      ? (isAutoAdjustEnabled ? Icons.sync : Icons.sync_disabled)
                      : Icons.music_note),
                  label: Text(isPlaying
                      ? (isAutoAdjustEnabled ? "自動調整ON" : "自動調整OFF")
                      : "音楽テンポ: ${currentMusicBPM.toStringAsFixed(1)} BPM"),
                  onPressed: isPlaying
                      ? () {
                          setState(() {
                            isAutoAdjustEnabled = !isAutoAdjustEnabled;
                            if (isAutoAdjustEnabled) {
                              _stopGradualTempoChange();
                              // BPMモードでは、デバイスから送られてくるBPMを使用
                              double detectedBPM = latestData!.bpm!;
                              double newBPM = currentMusicBPM +
                                  (detectedBPM - currentMusicBPM) * 0.3;
                              newBPM = newBPM.clamp(80.0, 140.0);
                              _changeMusicTempo(newBPM);
                            }
                          });
                        }
                      : () {
                          _togglePlayback();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAutoAdjustEnabled
                        ? Colors.green
                        : (isPlaying ? Colors.blue : Colors.orange),
                  ),
                ),
                if (isPlaying) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: _togglePlayback,
                    color: Colors.red,
                  ),
                ],
              ],
            ),

            // 段階的テンポ変更コントロール (BPMモードでも同様に提供)
            if (isPlaying && !isAutoAdjustEnabled) ...[
              const SizedBox(height: 8),
              const Divider(),
              const Text("段階的テンポ変更:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),

              // 段階的テンポ変更のパラメータ設定
              if (!isGradualTempoChangeEnabled) ...[
                Row(
                  children: [
                    const Text("目標BPM: "),
                    Expanded(
                      child: Slider(
                        value: targetBPM,
                        min: 80.0,
                        max: 140.0,
                        divisions: 60,
                        label: targetBPM.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            targetBPM = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(targetBPM.toStringAsFixed(1)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text("変化速度: "),
                    Expanded(
                      child: Slider(
                        value: tempoChangeStep,
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        label: "${tempoChangeStep.toStringAsFixed(1)} BPM/分",
                        onChanged: (value) {
                          setState(() {
                            tempoChangeStep = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text("${tempoChangeStep.toStringAsFixed(1)}/分"),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("段階的テンポ変更開始"),
                  onPressed: _startGradualTempoChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ] else ...[
                // 進行中の段階的テンポ変更の状態表示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        "${initialBPM.toStringAsFixed(1)} → ${targetBPM.toStringAsFixed(1)} BPM"),
                    const SizedBox(width: 8),
                    Text("(${tempoChangeStep.toStringAsFixed(1)} BPM/分)"),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (currentMusicBPM - initialBPM).abs() /
                      (targetBPM - initialBPM).abs(),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text("停止"),
                  onPressed: _stopGradualTempoChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ],
          ],

          const SizedBox(height: 16),
          const Text("履歴:", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: dataHistory.length,
              reverse: true,
              itemBuilder: (context, index) {
                final data = dataHistory[dataHistory.length - 1 - index];
                if (data.type == 'bpm') {
                  return ListTile(
                    dense: true,
                    title: Text("時刻: ${_formatTimestamp(data.timestamp)}"),
                    subtitle: Text("BPM: ${data.bpm?.toStringAsFixed(1)}, " +
                        "間隔: ${data.lastInterval} ms"),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      );
    } else {
      // その他のタイプの場合 (念のため)
      return Center(child: Text("不明なデータタイプ: ${latestData!.type}"));
    }
  }

  // 加速度データのグラフを構築
  Widget _buildAccelerationChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxGraphPoints.toDouble(),
        minY: -1.2,
        maxY: 1.2,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            axisNameWidget: Text('サンプル'),
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('加速度 (G)'),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == -1 || value == 0 || value == 1) {
                  return Text(value.toInt().toString());
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: const FlGridData(
          drawHorizontalLine: true,
          horizontalInterval: 0.5,
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          // X軸加速度
          LineChartBarData(
            spots: accXSpots,
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          // Y軸加速度
          LineChartBarData(
            spots: accYSpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          // Z軸加速度
          LineChartBarData(
            spots: accZSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          // 合成加速度
          LineChartBarData(
            spots: magnitudeSpots,
            isCurved: true,
            color: Colors.purple,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.black.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                String name = '';
                Color color = Colors.white;

                switch (spot.barIndex) {
                  case 0:
                    name = 'X軸';
                    color = Colors.red;
                    break;
                  case 1:
                    name = 'Y軸';
                    color = Colors.green;
                    break;
                  case 2:
                    name = 'Z軸';
                    color = Colors.blue;
                    break;
                  case 3:
                    name = '合成';
                    color = Colors.purple;
                    break;
                }

                return LineTooltipItem(
                  '$name: ${spot.y.toStringAsFixed(3)}',
                  TextStyle(color: color, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.hour}:${date.minute}:${date.second}.${date.millisecond}";
  }

  // RAWデータ処理メソッド
  void _processRawData(M5SensorData sensorData) {
    final double? accX = sensorData.accX;
    final double? accY = sensorData.accY;
    final double? accZ = sensorData.accZ;
    double? magnitude = sensorData.magnitude;

    // 加速度データがなければ処理中断
    if (accX == null || accY == null || accZ == null) {
      print('必要な加速度データがnullです。');
      return;
    }

    // magnitude がない場合は計算する
    magnitude ??= sqrt(accX * accX + accY * accY + accZ * accZ);

    // グラフデータを更新
    if (showRawDataGraph) {
      final x = accXSpots.length.toDouble();
      accXSpots.add(FlSpot(x, accX));
      accYSpots.add(FlSpot(x, accY));
      accZSpots.add(FlSpot(x, accZ));
      magnitudeSpots.add(FlSpot(x, magnitude));

      // グラフポイント数の制限
      if (accXSpots.length > maxGraphPoints) {
        accXSpots.removeAt(0);
        accYSpots.removeAt(0);
        accZSpots.removeAt(0);
        magnitudeSpots.removeAt(0);

        // インデックスを修正
        for (int i = 0; i < accXSpots.length; i++) {
          accXSpots[i] = FlSpot(i.toDouble(), accXSpots[i].y);
          accYSpots[i] = FlSpot(i.toDouble(), accYSpots[i].y);
          accZSpots[i] = FlSpot(i.toDouble(), accZSpots[i].y);
          magnitudeSpots[i] = FlSpot(i.toDouble(), magnitudeSpots[i].y);
        }
      }
    }

    // 独自の歩行検出アルゴリズムを実行
    bool stepDetected =
        stepDetector.detectStep(magnitude, sensorData.timestamp);

    if (stepDetected) {
      print('ステップ検出: timestamp=${sensorData.timestamp}');
      calculatedBpmFromRaw = stepDetector.lastCalculatedBpm;

      // 自動テンポ調整が有効なら実行
      if (isAutoAdjustEnabled && isPlaying && !isExperimentMode) {
        _autoAdjustTempo();
      }
    }

    // 実験モードで記録中ならデータを記録
    if (isRecording &&
        experimentTimer != null &&
        calculatedBpmFromRaw != null) {
      final record = ExperimentRecord(
        timestamp: DateTime.now(),
        targetBPM: currentMusicBPM,
        detectedBPM: calculatedBpmFromRaw,
        reliability: stepDetector.reliabilityScore,
      );

      experimentRecords.add(record);
      _updateGraphData();
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

  // 自動テンポ調整機能
  void _autoAdjustTempo() {
    // 必要なデータがない場合は何もしない
    if (calculatedBpmFromRaw == null ||
        stepDetector.reliabilityScore < MIN_RELIABILITY_FOR_ADJUST) {
      return;
    }

    // 前回の調整から十分な時間が経過していない場合はスキップ
    double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble();
    if (currentTime - lastAutoAdjustTime < AUTO_ADJUST_INTERVAL) {
      return;
    }

    // 最新の測定BPMを取得
    double detectedBPM = calculatedBpmFromRaw!;

    // 現在のテンポとの差を計算
    double bpmDifference = (detectedBPM - currentMusicBPM).abs();

    // 差が大きい場合（5%以上）、テンポを徐々に調整
    if (bpmDifference > currentMusicBPM * 0.05) {
      // 新しいテンポを計算（検出BPMと現在のBPMの中間値に調整）
      double newBPM = currentMusicBPM + (detectedBPM - currentMusicBPM) * 0.3;

      // BPMの範囲を制限（80-140 BPM）
      newBPM = newBPM.clamp(80.0, 140.0);

      // テンポを変更
      _changeMusicTempo(newBPM);

      // 調整時刻を記録
      lastAutoAdjustTime = currentTime;

      print('テンポ自動調整: $currentMusicBPM BPM (検出: $detectedBPM BPM)');
    }
  }

  // 任意のBPM値に音楽テンポを変更する
  Future<void> _changeMusicTempo(double bpm) async {
    try {
      // BPM値を更新
      currentMusicBPM = bpm;

      // 再生中なら速度を調整
      if (isPlaying) {
        // テンポに応じた再生速度を計算（100BPMを基準に）
        double speedRatio = bpm / 100.0;
        await _audioPlayer.setSpeed(speedRatio);
      }

      // UI更新
      if (mounted) {
        setState(() {
          // 最も近いプリセットを選択
          selectedTempo = _findNearestTempoPreset(bpm);
        });
      }
    } catch (e) {
      print('テンポ変更エラー: $e');
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

  // 段階的テンポ変更を開始
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
        );

        experimentRecords.add(record);
      }

      // UIを更新
      if (mounted) {
        setState(() {});
      }
    });
  }

  // 段階的テンポ変更を停止
  void _stopGradualTempoChange() {
    if (!isGradualTempoChangeEnabled) return;

    // タイマーを停止
    if (gradualTempoTimer != null) {
      gradualTempoTimer!.cancel();
      gradualTempoTimer = null;
    }

    isGradualTempoChangeEnabled = false;
    print('段階的テンポ変更終了: $currentMusicBPM BPM');

    // UIを更新
    if (mounted) {
      setState(() {});
    }

    // 実験モードでなく、かつデータが記録されていれば、CSV保存を提案
    if (!isExperimentMode && experimentRecords.isNotEmpty) {
      _showSaveDataDialog();
    }
  }

  // データ保存ダイアログを表示
  void _showSaveDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('テンポ変更データの保存'),
          content: const Text('段階的テンポ変更中のデータをローカルとAzureに保存しますか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                experimentRecords.clear(); // 保存しなくてもデータはクリア
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                experimentFileName =
                    'gradual_tempo_${initialBPM.toInt()}_to_${targetBPM.toInt()}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

                // ローカル保存とAzureアップロードを実行
                final directory = await getApplicationDocumentsDirectory();
                final filePath = '${directory.path}/$experimentFileName.csv';

                List<List<dynamic>> csvData = [
                  [
                    'Timestamp',
                    'Target BPM',
                    'Detected BPM',
                    'Reliability'
                  ], // ヘッダー行
                ];
                csvData
                    .addAll(experimentRecords.map((e) => e.toCSV()).toList());
                String csvString = const ListToCsvConverter().convert(csvData);

                try {
                  await File(filePath).writeAsString(csvString);
                  print('実験データをローカルに保存しました: $filePath');

                  // Azureへのアップロード
                  await _uploadToAzure(
                      filePath, '$experimentFileName.csv'); // Blob名に拡張子を追加
                } catch (e) {
                  print("ファイルの書き込みまたはアップロードエラー: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('データ保存/アップロードに失敗: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }

                experimentRecords.clear();
              },
              child: const Text('保存してアップロード'),
            ),
          ],
        );
      },
    );
  }
}

// 歩行検出アルゴリズム用クラス
class StepDetector {
  // 基本設定
  double _baseThreshold = 0.10; // 基本閾値 (少し下げてみる)
  double _adaptiveThreshold = 0.10; // 適応的閾値（動的に調整される）
  int _minStepInterval = 400; // 最小ステップ間隔 (ms)
  int _maxStepInterval = 2000; // 最大ステップ間隔 (ms)

  // バッファとウィンドウ
  final int _windowSize = 20; // 解析ウィンドウサイズ
  final List<double> _magnitudeBuffer = []; // 加速度バッファ
  final List<int> _timestampBuffer = []; // タイムスタンプバッファ

  // ステップ履歴
  List<int> stepTimestamps = []; // 検出したステップのタイムスタンプ
  List<double> stepConfidences = []; // 各ステップの信頼度

  // 状態変数
  double? lastCalculatedBpm; // 最後に計算したBPM
  double _currentReliabilityScore = 0.0; // 現在の信頼性スコア (0.0-1.0)

  // フィルター用
  final List<double> _filteredMagnitude = []; // フィルター適用後の値
  double _lastMagnitude = 0.0;

  // 設定用ゲッターとセッター
  double get baseThreshold => _baseThreshold;
  set baseThreshold(double value) {
    if (value > 0 && value < 1.0) {
      _baseThreshold = value;
      _adaptiveThreshold = value; // 初期値としても設定
    }
  }

  int get minStepInterval => _minStepInterval;
  set minStepInterval(int value) {
    if (value > 100 && value < _maxStepInterval) {
      _minStepInterval = value;
    }
  }

  int get maxStepInterval => _maxStepInterval;
  set maxStepInterval(int value) {
    if (value > _minStepInterval) {
      _maxStepInterval = value;
    }
  }

  // 信頼性スコアのゲッター
  double get reliabilityScore => _currentReliabilityScore;

  // 加速度データを追加
  void addAccelerationData(double magnitude, int timestamp) {
    // バッファに追加
    _magnitudeBuffer.add(magnitude);
    _timestampBuffer.add(timestamp);

    // バッファサイズを制限
    if (_magnitudeBuffer.length > _windowSize * 2) {
      _magnitudeBuffer.removeAt(0);
      _timestampBuffer.removeAt(0);
    }

    // バンドパスフィルター適用（簡易版）
    double filteredValue = _applyBandpassFilter(magnitude);
    _filteredMagnitude.add(filteredValue);

    // フィルターバッファも同様に制限
    if (_filteredMagnitude.length > _windowSize * 2) {
      _filteredMagnitude.removeAt(0);
    }

    // 閾値を動的に調整
    _updateAdaptiveThreshold();
  }

  // バンドパスフィルタ処理（簡易版）
  double _applyBandpassFilter(double magnitude) {
    // ローパスフィルタ（高周波ノイズ除去）
    double alpha = 0.3; // ローパスフィルタ係数
    double lowPassValue = alpha * magnitude + (1 - alpha) * _lastMagnitude;

    // ハイパスフィルタ（重力成分除去）
    double beta = 0.8; // ハイパスフィルタ係数
    double highPassValue = beta * (lowPassValue - _lastMagnitude);

    _lastMagnitude = lowPassValue;
    return highPassValue.abs(); // 絶対値を使用
  }

  // 適応的閾値の更新
  void _updateAdaptiveThreshold() {
    if (_magnitudeBuffer.length < 10) return;

    // 直近のデータから標準偏差を計算
    double sum = 0.0;
    double sumSq = 0.0;

    for (int i = _magnitudeBuffer.length - 10;
        i < _magnitudeBuffer.length;
        i++) {
      sum += _magnitudeBuffer[i];
      sumSq += _magnitudeBuffer[i] * _magnitudeBuffer[i];
    }

    double mean = sum / 10;
    double variance = (sumSq / 10) - (mean * mean);
    double stdDev = variance > 0 ? sqrt(variance) : 0.0;

    // 標準偏差に基づいて閾値を調整（ノイズレベルに応じて）
    double noiseLevel = stdDev * 2.0;
    _adaptiveThreshold = max(_baseThreshold, noiseLevel);
  }

  // 歩行検出メソッド - 改良版ピーク検出
  bool detectStep(double magnitude, int timestamp) {
    // データを追加
    addAccelerationData(magnitude, timestamp);

    // データが十分にない場合
    if (_filteredMagnitude.length < _windowSize) {
      return false;
    }

    // ピーク検出（中央値がウィンドウ内で最大か確認）
    int centerIndex = _filteredMagnitude.length - (_windowSize ~/ 2) - 1;
    if (centerIndex < 0) return false;

    double centerValue = _filteredMagnitude[centerIndex];
    bool isPeak = true;

    // ピークのチェック（前後の値と比較）
    for (int i = 1; i <= _windowSize ~/ 4; i++) {
      int beforeIndex = centerIndex - i;
      int afterIndex = centerIndex + i;

      if (beforeIndex >= 0 && _filteredMagnitude[beforeIndex] > centerValue) {
        isPeak = false;
        break;
      }

      if (afterIndex < _filteredMagnitude.length &&
          _filteredMagnitude[afterIndex] > centerValue) {
        isPeak = false;
        break;
      }
    }

    // ピークが閾値を超えているか確認
    bool isOverThreshold = centerValue > _adaptiveThreshold;

    // 前回のステップからの時間間隔チェック
    int currentTime = _timestampBuffer[centerIndex];
    int timeSinceLastStep = stepTimestamps.isNotEmpty
        ? currentTime - stepTimestamps.last
        : _maxStepInterval + 1;

    bool isValidInterval = timeSinceLastStep >= _minStepInterval &&
        timeSinceLastStep <= _maxStepInterval;

    // ステップの信頼度を計算
    double confidence = 0.0;
    if (isPeak && isOverThreshold && isValidInterval) {
      // 閾値からの距離に基づく信頼度（閾値の倍なら最大）
      double thresholdRatio = min(centerValue / _adaptiveThreshold, 2.0) / 2.0;

      // 間隔の理想値からの距離（理想は800ms前後）
      double intervalOptimality = 0.0;
      if (stepTimestamps.isNotEmpty) {
        double idealInterval = 800.0; // ms
        double intervalDiff = (timeSinceLastStep - idealInterval).abs();
        intervalOptimality =
            max(0.0, 1.0 - intervalDiff / 400.0); // 400msの差で0になる
      } else {
        intervalOptimality = 0.5; // 最初のステップ
      }

      // 最終信頼度を計算（閾値比率:70%, 間隔最適性:30%）
      confidence = thresholdRatio * 0.7 + intervalOptimality * 0.3;

      // ステップとして検出
      print(
          '  ✅ Step Detected! (Val: ${centerValue.toStringAsFixed(3)}, Thresh: ${_adaptiveThreshold.toStringAsFixed(3)}, Interval: $timeSinceLastStep ms, Confidence: ${(confidence * 100).toStringAsFixed(1)}%)');
      stepTimestamps.add(currentTime);
      stepConfidences.add(confidence);

      // 古いデータを削除（最大20ステップを保持）
      if (stepTimestamps.length > 20) {
        stepTimestamps.removeAt(0);
        stepConfidences.removeAt(0);
      }

      // BPM計算
      calculateBpm();

      // 信頼性スコアを更新
      _updateReliabilityScore();

      return true;
    } else {
      // デバッグログ：なぜステップと判定されなかったか
      String reason = "";
      if (!isPeak) reason += "Not Peak; ";
      if (!isOverThreshold)
        reason +=
            "Under Threshold (${centerValue.toStringAsFixed(3)} < ${_adaptiveThreshold.toStringAsFixed(3)}); ";
      if (!isValidInterval)
        reason += "Invalid Interval ($timeSinceLastStep ms); ";
      if (reason.isNotEmpty) {
        // print('  ❌ Not a step: $reason');
      }
    }

    return false;
  }

  // BPM計算メソッド - 信頼度重み付き
  double? calculateBpm() {
    if (stepTimestamps.length < 3) return null;

    // 信頼度重み付きの間隔計算
    double totalWeightedInterval = 0.0;
    double totalWeight = 0.0;

    for (int i = 1; i < stepTimestamps.length; i++) {
      int interval = stepTimestamps[i] - stepTimestamps[i - 1];
      double weight = (stepConfidences[i] + stepConfidences[i - 1]) / 2.0;

      totalWeightedInterval += interval * weight;
      totalWeight += weight;
    }

    if (totalWeight > 0) {
      double avgInterval = totalWeightedInterval / totalWeight;
      // BPM = 60000 / 平均間隔（ミリ秒）
      lastCalculatedBpm = 60000 / avgInterval;

      // 合理的な範囲内か確認（40-200 BPM）
      if (lastCalculatedBpm! < 40 || lastCalculatedBpm! > 200) {
        lastCalculatedBpm = null;
      }

      return lastCalculatedBpm;
    }

    return lastCalculatedBpm;
  }

  // 信頼性スコアの更新
  void _updateReliabilityScore() {
    if (stepConfidences.isEmpty) {
      _currentReliabilityScore = 0.0;
      return;
    }

    // 最新の5つのステップ（または全て）の平均信頼度を使用
    int count = min(5, stepConfidences.length);
    double sum = 0.0;

    for (int i = stepConfidences.length - 1;
        i >= stepConfidences.length - count;
        i--) {
      sum += stepConfidences[i];
    }

    _currentReliabilityScore = sum / count;
  }

  // 最後に検出されたステップの間隔（ミリ秒）
  int? getLastStepInterval() {
    if (stepTimestamps.length >= 2) {
      return stepTimestamps.last - stepTimestamps[stepTimestamps.length - 2];
    }
    return null;
  }

  // 直近のステップの平均信頼度を取得
  double getAverageConfidence() {
    if (stepConfidences.isEmpty) return 0.0;

    double sum = 0.0;
    for (double confidence in stepConfidences) {
      sum += confidence;
    }

    return sum / stepConfidences.length;
  }

  // 検出器のリセット
  void reset() {
    _magnitudeBuffer.clear();
    _timestampBuffer.clear();
    _filteredMagnitude.clear();
    stepTimestamps.clear();
    stepConfidences.clear();
    lastCalculatedBpm = null;
    _currentReliabilityScore = 0.0;
    _lastMagnitude = 0.0;
    _adaptiveThreshold = _baseThreshold;
  }
}
