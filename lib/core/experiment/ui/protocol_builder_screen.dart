import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/protocol_interface.dart';
import '../models/protocol_models.dart';
import '../protocols/simple_protocol.dart';
import '../../plugins/research_plugin.dart';

/// Visual protocol builder screen
class ProtocolBuilderScreen extends ConsumerStatefulWidget {
  const ProtocolBuilderScreen({super.key});

  @override
  ConsumerState<ProtocolBuilderScreen> createState() => _ProtocolBuilderScreenState();
}

class _ProtocolBuilderScreenState extends ConsumerState<ProtocolBuilderScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<ProtocolPhase> _phases = [];
  final List<SensorType> _selectedSensors = [];
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protocol Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProtocol,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Protocol basics
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Protocol Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Sensor selection
            Text(
              'Required Sensors',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SensorType.values.map((type) {
                final isSelected = _selectedSensors.contains(type);
                return FilterChip(
                  label: Text(type.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSensors.add(type);
                      } else {
                        _selectedSensors.remove(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            
            // Phases
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Protocol Phases',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addPhase,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Phase list
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _phases.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final phase = _phases.removeAt(oldIndex);
                    _phases.insert(newIndex, phase);
                  });
                },
                itemBuilder: (context, index) {
                  final phase = _phases[index];
                  return Card(
                    key: ValueKey(phase.id),
                    child: ListTile(
                      leading: Icon(_getPhaseIcon(phase.type)),
                      title: Text(phase.name),
                      subtitle: Text(phase.description),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (phase.duration != null)
                            Text('${phase.duration!.inSeconds}s'),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editPhase(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deletePhase(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Quick templates
            const SizedBox(height: 16),
            Text(
              'Quick Templates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.timer),
                  label: const Text('Timed Measurement'),
                  onPressed: _addTimedMeasurementTemplate,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Interval Training'),
                  onPressed: _addIntervalTrainingTemplate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getPhaseIcon(PhaseType type) {
    switch (type) {
      case PhaseType.preparation:
        return Icons.info;
      case PhaseType.measurement:
        return Icons.sensors;
      case PhaseType.rest:
        return Icons.pause;
      case PhaseType.intervention:
        return Icons.play_arrow;
      case PhaseType.collection:
        return Icons.data_usage;
      case PhaseType.survey:
        return Icons.quiz;
      case PhaseType.custom:
        return Icons.more_horiz;
    }
  }
  
  void _addPhase() {
    showDialog(
      context: context,
      builder: (context) => PhaseEditDialog(
        onSave: (phase) {
          setState(() {
            _phases.add(phase);
          });
        },
      ),
    );
  }
  
  void _editPhase(int index) {
    showDialog(
      context: context,
      builder: (context) => PhaseEditDialog(
        phase: _phases[index],
        onSave: (phase) {
          setState(() {
            _phases[index] = phase;
          });
        },
      ),
    );
  }
  
  void _deletePhase(int index) {
    setState(() {
      _phases.removeAt(index);
    });
  }
  
  void _addTimedMeasurementTemplate() {
    setState(() {
      _phases.clear();
      _phases.addAll([
        ProtocolPhase(
          id: 'instruction_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Instructions',
          description: 'Read the instructions carefully',
          type: PhaseType.preparation,
          duration: const Duration(seconds: 10),
          actions: [
            ProtocolAction(
              id: 'show_instruction',
              type: ActionType.displayInstruction,
              parameters: {'text': 'Prepare for measurement'},
            ),
          ],
          transitionConditions: [],
        ),
        ProtocolPhase(
          id: 'measurement_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Measurement',
          description: 'Data collection in progress',
          type: PhaseType.measurement,
          duration: const Duration(seconds: 60),
          actions: [
            ProtocolAction(
              id: 'start_sensors',
              type: ActionType.startSensorCollection,
              parameters: {},
            ),
          ],
          transitionConditions: [],
        ),
      ]);
    });
  }
  
  void _addIntervalTrainingTemplate() {
    setState(() {
      _phases.clear();
      // Add preparation
      _phases.add(ProtocolPhase(
        id: 'prep_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Preparation',
        description: 'Get ready',
        type: PhaseType.preparation,
        duration: const Duration(seconds: 10),
        actions: [],
        transitionConditions: [],
      ));
      
      // Add 3 work/rest intervals
      for (int i = 0; i < 3; i++) {
        _phases.add(ProtocolPhase(
          id: 'work_${i}_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Work ${i + 1}',
          description: 'Perform activity',
          type: PhaseType.measurement,
          duration: const Duration(seconds: 30),
          actions: i == 0 ? [
            ProtocolAction(
              id: 'start_sensors',
              type: ActionType.startSensorCollection,
              parameters: {},
            ),
          ] : [],
          transitionConditions: [],
        ));
        
        if (i < 2) { // No rest after last interval
          _phases.add(ProtocolPhase(
            id: 'rest_${i}_${DateTime.now().millisecondsSinceEpoch}',
            name: 'Rest ${i + 1}',
            description: 'Rest',
            type: PhaseType.rest,
            duration: const Duration(seconds: 15),
            actions: [],
            transitionConditions: [],
          ));
        }
      }
    });
  }
  
  void _saveProtocol() {
    if (_nameController.text.isEmpty || _phases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a name and at least one phase'),
        ),
      );
      return;
    }
    
    final protocol = SimpleProtocol(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text,
      description: _descriptionController.text,
      requiredSensors: _selectedSensors,
      phases: _phases,
    );
    
    // TODO: Save protocol to storage
    Navigator.of(context).pop(protocol);
  }
}

/// Dialog for editing a protocol phase
class PhaseEditDialog extends StatefulWidget {
  final ProtocolPhase? phase;
  final Function(ProtocolPhase) onSave;
  
  const PhaseEditDialog({
    super.key,
    this.phase,
    required this.onSave,
  });
  
  @override
  State<PhaseEditDialog> createState() => _PhaseEditDialogState();
}

class _PhaseEditDialogState extends State<PhaseEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late PhaseType _selectedType;
  Duration? _duration;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.phase?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.phase?.description ?? '',
    );
    _selectedType = widget.phase?.type ?? PhaseType.measurement;
    _duration = widget.phase?.duration;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.phase == null ? 'Add Phase' : 'Edit Phase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Phase Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PhaseType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Phase Type',
              ),
              items: PhaseType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Duration (seconds): '),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Optional',
                    ),
                    controller: TextEditingController(
                      text: _duration?.inSeconds.toString() ?? '',
                    ),
                    onChanged: (value) {
                      final seconds = int.tryParse(value);
                      setState(() {
                        _duration = seconds != null 
                            ? Duration(seconds: seconds) 
                            : null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              return;
            }
            
            final phase = ProtocolPhase(
              id: widget.phase?.id ?? 
                  'phase_${DateTime.now().millisecondsSinceEpoch}',
              name: _nameController.text,
              description: _descriptionController.text,
              type: _selectedType,
              duration: _duration,
              actions: widget.phase?.actions ?? [],
              transitionConditions: widget.phase?.transitionConditions ?? [],
            );
            
            widget.onSave(phase);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}