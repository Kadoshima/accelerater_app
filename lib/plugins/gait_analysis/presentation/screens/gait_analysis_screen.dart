import 'package:flutter/material.dart';
import '../../services/gait_analysis_service.dart';
import '../../services/adaptive_tempo_controller.dart';
import '../../services/metronome.dart';
import '../../services/native_metronome.dart';

/// 歩行解析プラグインのメイン画面
class GaitAnalysisScreen extends StatefulWidget {
  final GaitAnalysisService gaitAnalysisService;
  final AdaptiveTempoController adaptiveTempoController;
  final Metronome metronome;
  final NativeMetronome nativeMetronome;

  const GaitAnalysisScreen({
    Key? key,
    required this.gaitAnalysisService,
    required this.adaptiveTempoController,
    required this.metronome,
    required this.nativeMetronome,
  }) : super(key: key);

  @override
  State<GaitAnalysisScreen> createState() => _GaitAnalysisScreenState();
}

class _GaitAnalysisScreenState extends State<GaitAnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歩行解析'),
      ),
      body: const Center(
        child: Text('歩行解析プラグイン画面\n実装予定'),
      ),
    );
  }
}