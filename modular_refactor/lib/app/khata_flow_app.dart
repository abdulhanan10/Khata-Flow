import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_gate.dart';

class KhataFlowApp extends StatelessWidget {
  const KhataFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhataFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
