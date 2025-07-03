import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/data_synchronization_service.dart';

void main() {
  group('DataSynchronizationService', () {
    late DataSynchronizationService service;

    setUp(() {
      service = DataSynchronizationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initializes with correct base time', () {
      service.startRecording(sessionId: 'test-session');
      
      final baseTime = service.getBaseTime();
      expect(baseTime, isNotNull);
      expect(baseTime.isBefore(DateTime.now()), isTrue);
    });

    test('synchronizes IMU data at 100Hz', () async {
      service.startRecording(sessionId: 'test-session');
      
      // 100Hzのデータを記録
      final startTime = DateTime.now();
      for (int i = 0; i < 100; i++) {
        service.recordImuData(
          timestamp: startTime.add(Duration(milliseconds: i * 10)),
          accelerometer: [0.0, 0.0, 9.8],
          gyroscope: [0.0, 0.0, 0.0],
        );
      }
      
      final imuData = service.getImuData();
      expect(imuData.length, equals(100));
      
      // タイムスタンプが正しく10ms間隔であることを確認
      for (int i = 1; i < imuData.length; i++) {
        final diff = imuData[i].timestamp.difference(imuData[i-1].timestamp);
        expect(diff.inMilliseconds, closeTo(10, 2)); // ±2msの許容誤差
      }
    });

    test('handles heart rate data at 3-second intervals', () async {
      service.startRecording(sessionId: 'test-session');
      
      final startTime = DateTime.now();
      
      // 3秒間隔で心拍データを記録
      for (int i = 0; i < 5; i++) {
        service.recordHeartRate(
          timestamp: startTime.add(Duration(seconds: i * 3)),
          heartRate: 60 + i * 5,
        );
      }
      
      final hrData = service.getHeartRateData();
      expect(hrData.length, equals(5));
      
      // 3秒間隔の確認
      for (int i = 1; i < hrData.length; i++) {
        final diff = hrData[i].timestamp.difference(hrData[i-1].timestamp);
        expect(diff.inSeconds, equals(3));
      }
    });

    test('aligns different sampling rates correctly', () async {
      service.startRecording(sessionId: 'test-session');
      
      final startTime = DateTime.now();
      
      // 異なるサンプリングレートでデータを記録
      // IMU: 100Hz (10ms間隔)
      for (int i = 0; i < 300; i++) {
        service.recordImuData(
          timestamp: startTime.add(Duration(milliseconds: i * 10)),
          accelerometer: [0.0, 0.0, 9.8],
          gyroscope: [0.0, 0.0, 0.0],
        );
      }
      
      // Heart rate: 3秒間隔
      service.recordHeartRate(
        timestamp: startTime,
        heartRate: 65,
      );
      service.recordHeartRate(
        timestamp: startTime.add(Duration(seconds: 3)),
        heartRate: 70,
      );
      
      // N-back: 2秒間隔
      for (int i = 0; i < 5; i++) {
        service.recordNBackEvent(
          timestamp: startTime.add(Duration(seconds: i * 2)),
          eventType: 'stimulus',
          data: {'digit': i + 1},
        );
      }
      
      // データの整合性を確認
      final alignedData = service.getAlignedData(
        startTime: startTime,
        endTime: startTime.add(Duration(seconds: 10)),
      );
      
      expect(alignedData['imu']?.length, greaterThan(0));
      expect(alignedData['heartRate']?.length, greaterThan(0));
      expect(alignedData['nback']?.length, greaterThan(0));
      
      // すべてのデータが指定時間範囲内にあることを確認
      for (final imuPoint in alignedData['imu'] ?? []) {
        expect(imuPoint.timestamp.isAfter(startTime) || 
               imuPoint.timestamp.isAtSameMomentAs(startTime), isTrue);
        expect(imuPoint.timestamp.isBefore(startTime.add(Duration(seconds: 10))) ||
               imuPoint.timestamp.isAtSameMomentAs(startTime.add(Duration(seconds: 10))), isTrue);
      }
    });

    test('buffers data correctly and flushes on demand', () async {
      service.startRecording(sessionId: 'test-session');
      
      // バッファサイズを超えるデータを追加
      final startTime = DateTime.now();
      for (int i = 0; i < 2000; i++) {
        service.recordImuData(
          timestamp: startTime.add(Duration(milliseconds: i * 10)),
          accelerometer: [i.toDouble(), 0.0, 9.8],
          gyroscope: [0.0, i.toDouble(), 0.0],
        );
      }
      
      // 手動フラッシュ前のバッファサイズを確認
      final bufferSize = service.getBufferSize();
      expect(bufferSize['imu'], lessThanOrEqualTo(1000)); // 自動フラッシュが発生
      
      // 手動フラッシュ
      await service.flushBuffers();
      
      // フラッシュ後のバッファサイズ
      final afterFlush = service.getBufferSize();
      expect(afterFlush['imu'], equals(0));
    });

    test('handles timestamp synchronization with NTP offset', () {
      service.startRecording(sessionId: 'test-session');
      
      // NTPオフセットをシミュレート（5秒の差）
      final ntpOffset = Duration(seconds: 5);
      service.setNtpOffset(ntpOffset);
      
      final localTime = DateTime.now();
      final syncedTime = service.getSynchronizedTimestamp(localTime);
      
      expect(syncedTime.difference(localTime), equals(ntpOffset));
    });

    test('exports synchronized data in correct format', () async {
      service.startRecording(sessionId: 'test-session');
      
      final startTime = DateTime.now();
      
      // データを記録
      service.recordImuData(
        timestamp: startTime,
        accelerometer: [0.1, 0.2, 9.8],
        gyroscope: [0.01, 0.02, 0.03],
      );
      
      service.recordHeartRate(
        timestamp: startTime,
        heartRate: 72,
      );
      
      service.recordNBackEvent(
        timestamp: startTime,
        eventType: 'response',
        data: {
          'stimulus': 5,
          'response': 5,
          'correct': true,
          'reactionTime': 523,
        },
      );
      
      // エクスポート
      final exportData = await service.exportData();
      
      expect(exportData, contains('sessionId'));
      expect(exportData, contains('baseTime'));
      expect(exportData, contains('imuData'));
      expect(exportData, contains('heartRateData'));
      expect(exportData, contains('nbackEvents'));
      
      // JSONとして解析可能か確認
      expect(() => Map<String, dynamic>.from(exportData), returnsNormally);
    });

    test('handles missing data gracefully', () {
      service.startRecording(sessionId: 'test-session');
      
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(seconds: 10));
      
      // 一部のデータタイプのみ記録
      service.recordImuData(
        timestamp: startTime,
        accelerometer: [0.0, 0.0, 9.8],
        gyroscope: [0.0, 0.0, 0.0],
      );
      
      // 心拍データなし、N-backデータなし
      
      final alignedData = service.getAlignedData(
        startTime: startTime,
        endTime: endTime,
      );
      
      expect(alignedData['imu']?.length, equals(1));
      expect(alignedData['heartRate']?.length, equals(0));
      expect(alignedData['nback']?.length, equals(0));
    });

    test('calculates time drift statistics', () {
      service.startRecording(sessionId: 'test-session');
      
      final baseTime = DateTime.now();
      
      // 理想的なタイミングとわずかにずれたデータを記録
      for (int i = 0; i < 100; i++) {
        final idealTime = baseTime.add(Duration(milliseconds: i * 10));
        final actualTime = idealTime.add(Duration(
          microseconds: (i % 2 == 0 ? 500 : -500),
        ));
        
        service.recordImuData(
          timestamp: actualTime,
          accelerometer: [0.0, 0.0, 9.8],
          gyroscope: [0.0, 0.0, 0.0],
        );
      }
      
      final driftStats = service.getTimeDriftStatistics();
      
      expect(driftStats['maxDrift'], isNotNull);
      expect(driftStats['meanDrift'], isNotNull);
      expect(driftStats['stdDrift'], isNotNull);
      
      // ドリフトが1ms以内であることを確認
      expect(driftStats['maxDrift'], lessThanOrEqualTo(1.0));
    });
  });
}