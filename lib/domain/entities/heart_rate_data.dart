import 'package:freezed_annotation/freezed_annotation.dart';

part 'heart_rate_data.freezed.dart';

/// 心拍数データのエンティティ
@freezed
class HeartRateData with _$HeartRateData {
  const factory HeartRateData({
    required int heartRate,
    required DateTime timestamp,
    double? energyExpended,
    List<int>? rrIntervals,
    required HeartRateDataSource source,
  }) = _HeartRateData;
}

/// 心拍数データのソース
enum HeartRateDataSource {
  standardBle,
  huaweiProtocol,
  unknown,
}