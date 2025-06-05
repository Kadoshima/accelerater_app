import '../../../core/utils/result.dart';
import '../../entities/heart_rate_data.dart';
import '../../repositories/bluetooth_repository.dart';

/// 心拍数データを取得するユースケース
class GetHeartRateUseCase {
  final BluetoothRepository _repository;

  GetHeartRateUseCase(this._repository);

  /// 心拍数データストリームを取得
  Stream<Result<HeartRateData>> getHeartRateStream(String deviceId) {
    return _repository.getHeartRateStream(deviceId);
  }

  /// 心拍数データの検証
  bool isValidHeartRate(int heartRate) {
    return heartRate >= 40 && heartRate <= 220;
  }

  /// 平均心拍数を計算
  double calculateAverageHeartRate(List<HeartRateData> data) {
    if (data.isEmpty) return 0;
    
    final sum = data.fold<double>(0, (sum, item) => sum + item.heartRate);
    return sum / data.length;
  }

  /// 心拍数の変動を計算
  double calculateHeartRateVariability(List<HeartRateData> data) {
    if (data.length < 2) return 0;
    
    final differences = <double>[];
    for (int i = 1; i < data.length; i++) {
      final diff = (data[i].heartRate - data[i - 1].heartRate).abs().toDouble();
      differences.add(diff);
    }
    
    final sum = differences.fold<double>(0, (sum, item) => sum + item);
    return sum / differences.length;
  }
}