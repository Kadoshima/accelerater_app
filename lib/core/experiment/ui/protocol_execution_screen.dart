import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/protocol_interface.dart';
import '../engine/protocol_engine.dart';
import '../../sensors/interfaces/sensor_interface.dart';
import '../../../presentation/providers/sensor_providers.dart';
import '../../plugins/research_plugin.dart';

/// Provider for protocol engine
final protocolEngineProvider = Provider<ProtocolEngine>((ref) {
  final sensorManager = ref.watch(sensorManagerProvider);
  final dataRecorder = ref.watch(sensorDataRecorderProvider);
  
  return ProtocolEngine(
    sensorManager: sensorManager,
    dataRecorder: dataRecorder,
  );
});

/// Screen for executing experiment protocols
class ProtocolExecutionScreen extends ConsumerStatefulWidget {
  final IExperimentProtocol protocol;
  
  const ProtocolExecutionScreen({
    super.key,
    required this.protocol,
  });

  @override
  ConsumerState<ProtocolExecutionScreen> createState() => 
      _ProtocolExecutionScreenState();
}

class _ProtocolExecutionScreenState 
    extends ConsumerState<ProtocolExecutionScreen> {
  late final ProtocolEngine _engine;
  ProtocolState _currentState = ProtocolState.idle;
  IProtocolPhase? _currentPhase;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _engine = ref.read(protocolEngineProvider);
    _engine.setUIContext(context);
    _initializeProtocol();
  }
  
  Future<void> _initializeProtocol() async {
    try {
      // Listen to state changes
      _engine.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _currentState = state;
            _currentPhase = _engine.currentPhase;
          });
        }
      });
      
      // Listen to events
      _engine.eventStream.listen((event) {
        if (mounted) {
          _handleProtocolEvent(event);
        }
      });
      
      // Load protocol
      await _engine.loadProtocol(widget.protocol);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }
  
  void _handleProtocolEvent(ProtocolEvent event) {
    // Log events or update UI based on event type
    debugPrint('Protocol event: ${event.type} - ${event.data}');
    
    // Show phase transitions
    if (event.type == 'phase_started' || event.type == 'phase_completed') {
      final phaseName = event.data?['phase'] ?? 'Unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phase ${event.type.split('_').last}: $phaseName'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }
        if (_currentState == ProtocolState.running || 
            _currentState == ProtocolState.paused) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit Protocol?'),
              content: const Text(
                'Are you sure you want to exit? Current progress will be lost.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            ),
          );
          
          if (shouldExit == true) {
            await _engine.stopProtocol();
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.protocol.name),
          actions: [
            if (_currentState == ProtocolState.running ||
                _currentState == ProtocolState.paused)
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stopProtocol,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }
    
    switch (_currentState) {
      case ProtocolState.idle:
      case ProtocolState.initializing:
        return const Center(
          child: CircularProgressIndicator(),
        );
        
      case ProtocolState.ready:
        return _buildReadyState();
        
      case ProtocolState.running:
        return _buildRunningState();
        
      case ProtocolState.paused:
        return _buildPausedState();
        
      case ProtocolState.completed:
        return _buildCompletedState();
        
      case ProtocolState.error:
        return _buildErrorState();
    }
  }
  
  Widget _buildReadyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Protocol Ready',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.protocol.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          
          // Required sensors status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Required Sensors',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...widget.protocol.requiredSensors.map((type) {
                    return _buildSensorStatus(type);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Protocol'),
            onPressed: _startProtocol,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSensorStatus(SensorType type) {
    final sensors = ref.watch(sensorsByTypeProvider(type));
    final hasConnected = sensors.any(
      (s) => s.status.value == SensorStatus.connected ||
             s.status.value == SensorStatus.collecting,
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            hasConnected ? Icons.check_circle : Icons.error,
            color: hasConnected ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(type.name),
          if (!hasConnected)
            const Text(' - Not connected', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
  
  Widget _buildRunningState() {
    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: _getProgress(),
          minHeight: 8,
        ),
        
        // Current phase info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentPhase != null) ...[
                  Text(
                    _currentPhase!.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentPhase!.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Phase-specific UI
                  Expanded(
                    child: _currentPhase!.buildUI(context),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Control buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
                onPressed: _pauseProtocol,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPausedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pause_circle, size: 64),
          const SizedBox(height: 24),
          Text(
            'Protocol Paused',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
                onPressed: _resumeProtocol,
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                onPressed: _stopProtocol,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompletedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            'Protocol Completed!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'All phases have been successfully completed.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 24),
          Text(
            'Protocol Error',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'An error occurred during protocol execution.',
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
  
  double? _getProgress() {
    if (widget.protocol.phases.isEmpty) return null;
    
    final currentIndex = widget.protocol.phases.indexOf(_currentPhase ?? 
        widget.protocol.phases.first);
    if (currentIndex == -1) return 0.0;
    
    return (currentIndex + 1) / widget.protocol.phases.length;
  }
  
  Future<void> _startProtocol() async {
    try {
      await _engine.startProtocol();
    } catch (e) {
      _showError(e.toString());
    }
  }
  
  Future<void> _pauseProtocol() async {
    try {
      await _engine.pauseProtocol();
    } catch (e) {
      _showError(e.toString());
    }
  }
  
  Future<void> _resumeProtocol() async {
    try {
      await _engine.resumeProtocol();
    } catch (e) {
      _showError(e.toString());
    }
  }
  
  Future<void> _stopProtocol() async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Protocol?'),
        content: const Text(
          'Are you sure you want to stop the protocol? Data will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    
    if (shouldStop == true) {
      try {
        await _engine.stopProtocol();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $message'),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  void dispose() {
    // Engine cleanup is handled by provider
    super.dispose();
  }
}