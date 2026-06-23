import 'package:face_detect_trial/widgets/permission/permission_gate.dart';
import 'package:flutter/material.dart';
import 'widgets/detection_styles/detection_theme.dart';

void main() {
  runApp(const SampleApp());
}

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Liveness Sample',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: DetectionColors.navyDark,
      ),
      home: const PermissionGate(),
    );
  }
}
