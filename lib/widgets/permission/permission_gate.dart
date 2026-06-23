import 'package:face_detect_trial/pages/liveness_demo_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:face_detect_trial/widgets/permission/permission_denied_view.dart';
import 'package:face_detect_trial/widgets/detection_styles/detection_theme.dart';

// ---------------------------------------------------------------------------
// Checks camera permission before navigating to the demo screen.
// In your real app this logic lives in permission_helper.dart and is
// called from FaceLivenessScreen.initState or before routing.
// ---------------------------------------------------------------------------
enum _PermissionStatus { checking, denied, permanentlyDenied }

class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  _PermissionStatus _status = _PermissionStatus.checking;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      _proceed();
      return;
    }

    // Not granted yet — request it
    final result = await Permission.camera.request();

    if (!mounted) return;

    if (result.isGranted) {
      _proceed();
    } else if (result.isPermanentlyDenied) {
      setState(() => _status = _PermissionStatus.permanentlyDenied);
    } else {
      setState(() => _status = _PermissionStatus.denied);
    }
  }

  void _proceed() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LivenessDemoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_status) {
        _PermissionStatus.checking => const Center(
          child: CircularProgressIndicator(
            color: DetectionColors.crimson,
            strokeWidth: 2.5,
          ),
        ),
        _PermissionStatus.denied => PermissionDeniedView(
          message: 'Camera access is required for face verification.',
          actionLabel: 'Try Again',
          onAction: _checkPermission,
        ),
        _PermissionStatus.permanentlyDenied => PermissionDeniedView(
          message:
              'Camera access was permanently denied. '
              'Enable it in your device settings to continue.',
          actionLabel: 'Open Settings',
          onAction: () async {
            await openAppSettings();
          },
        ),
      },
    );
  }
}
