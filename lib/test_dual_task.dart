import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/dual_task_menu_screen.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const TestDualTaskApp());
}

class TestDualTaskApp extends StatelessWidget {
  const TestDualTaskApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Dual Task Protocol Test',
        theme: AppTheme.darkTheme,
        home: const DualTaskMenuScreen(),
      ),
    );
  }
}