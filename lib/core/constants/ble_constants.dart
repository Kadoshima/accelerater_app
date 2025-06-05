/// BLE関連の定数を定義
class BleConstants {
  BleConstants._();

  // 心拍数サービス
  static const String heartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String heartRateMeasurementCharUuid = "00002a37-0000-1000-8000-00805f9b34fb";

  // IMUサービス（M5Stick）
  static const String imuServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String imuCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String m5StickDeviceName = "M5StickIMU";

  // Huaweiプロトコル
  static const int huaweiHeaderByte1 = 0x5a;
  static const int huaweiHeaderByte2 = 0x00;
  static const int huaweiHeartRateCommand = 0x09;

  // 心拍数の有効範囲
  static const int minHeartRate = 30;
  static const int maxHeartRate = 220;

  // タイムアウトと間隔
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration scanTimeout = Duration(seconds: 5);
  static const Duration heartRateUpdateInterval = Duration(seconds: 1);
  static const Duration dataRecordingInterval = Duration(seconds: 2);
  
  // 重複除去のしきい値
  static const Duration heartRateDuplicateThreshold = Duration(milliseconds: 500);
}