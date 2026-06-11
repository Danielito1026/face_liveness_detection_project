// main.dart — Sample usage of FaceLivenessWidget
//
// Demonstrates:
//   1. Camera permission check on app launch using permission_handler
//   2. A minimal demo screen that drives FaceLivenessWidget
//   3. All three style usage patterns (default / copyWith / custom overlay)
//   4. Handling onPass, onTimeout, onUnsupportedDevice
//
// In your real app, FaceLivenessWidget lives inside FaceLivenessScreen,
// and onPass/onTimeout are wired to FaceNotifier (Riverpod). This sample
// uses plain StatefulWidget to keep it dependency-free and easy to follow.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// Widget system imports — adjust paths to match your project structure
import 'widgets/face_liveness/face_liveness_widget.dart';
import 'widgets/face_liveness/face_liveness_config.dart';
import 'widgets/face_liveness/face_liveness_style.dart';
import 'widgets/face_liveness/face_liveness_theme.dart';
import 'widgets/face_liveness/liveness_challenge.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

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
        scaffoldBackgroundColor: FaceLivenessColors.navyDark,
      ),
      home: const PermissionGate(),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. PermissionGate
//
// Checks camera permission before navigating to the demo screen.
// In your real app this logic lives in permission_helper.dart and is
// called from FaceLivenessScreen.initState or before routing.
// ---------------------------------------------------------------------------

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
              color: FaceLivenessColors.crimson,
              strokeWidth: 2.5,
            ),
          ),
        _PermissionStatus.denied => _PermissionDeniedView(
            message: 'Camera access is required for face verification.',
            actionLabel: 'Try Again',
            onAction: _checkPermission,
          ),
        _PermissionStatus.permanentlyDenied => _PermissionDeniedView(
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

enum _PermissionStatus { checking, denied, permanentlyDenied }

class _PermissionDeniedView extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionDeniedView({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: FaceLivenessColors.crimson,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: FaceLivenessTextStyles.dialogBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FaceLivenessColors.crimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: FaceLivenessTextStyles.dialogButton.copyWith(
                    color: FaceLivenessColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. LivenessDemoScreen
//
// Selector screen showing three style variants to try.
// In your real app this is FaceLivenessScreen, driven by FaceNotifier.
// ---------------------------------------------------------------------------

class LivenessDemoScreen extends StatelessWidget {
  const LivenessDemoScreen({super.key});

  // Hardcoded config simulating what your backend returns.
  // In production: FaceLivenessConfig.fromJson(response.data)
  static final _sampleConfig = FaceLivenessConfig(
    challengeSequence: const [
      LivenessChallenge.blink,
      LivenessChallenge.smile,
      LivenessChallenge.turnLeft,
    ],
    isRandom: false,
    secondsPerChallenge: 20,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Face Liveness — Style Demos',
                style: FaceLivenessTextStyles.dialogTitle,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a variant to launch the liveness widget with that style.',
                style: FaceLivenessTextStyles.dialogBody,
              ),
              const SizedBox(height: 40),

              // --- Usage 1: Default style ---
              _DemoTile(
                label: 'Default Style',
                description:
                    'Dark navy + crimson. Oval cutout.\n'
                    'FaceLivenessStyle.defaults()',
                onTap: () => _launch(context, style: FaceLivenessStyle.defaults()),
              ),

              const SizedBox(height: 16),

              // --- Usage 2: copyWith override ---
              _DemoTile(
                label: 'copyWith Override',
                description:
                    'Same defaults, rect cutout, blue border.\n'
                    'FaceLivenessStyle.defaults().copyWith(...)',
                onTap: () => _launch(
                  context,
                  style: FaceLivenessStyle.defaults().copyWith(
                    cutoutShape: const RectCutout(borderRadius: 20),
                    frameBorderColor: const Color(0xFF2196F3),
                    timerBarActiveColor: const Color(0xFF2196F3),
                    dotCompleteColor: const Color(0xFF2196F3),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Usage 3: Custom challenge overlay builder ---
              _DemoTile(
                label: 'Custom Overlay Builder',
                description:
                    'Default style + custom overlay widget per challenge.\n'
                    'challengeOverlayBuilder: (c) => MyOverlay(c)',
                onTap: () => _launch(
                  context,
                  style: FaceLivenessStyle.defaults(),
                  useCustomOverlay: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launch(
    BuildContext context, {
    required FaceLivenessStyle style,
    bool useCustomOverlay = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LivenessRunnerScreen(
          config: _sampleConfig,
          style: style,
          useCustomOverlay: useCustomOverlay,
        ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback onTap;

  const _DemoTile({
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: FaceLivenessColors.navyMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FaceLivenessColors.glassBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: FaceLivenessTextStyles.challengeInstruction),
                  const SizedBox(height: 4),
                  Text(description, style: FaceLivenessTextStyles.challengeSubtitle),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: FaceLivenessColors.whiteMid,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. _LivenessRunnerScreen
//
// Wraps FaceLivenessWidget and handles the three callbacks.
// This is the equivalent of your FaceLivenessScreen in the real app —
// the only difference is FaceNotifier replaces the local state here.
// ---------------------------------------------------------------------------

class _LivenessRunnerScreen extends StatefulWidget {
  final FaceLivenessConfig config;
  final FaceLivenessStyle style;
  final bool useCustomOverlay;

  const _LivenessRunnerScreen({
    required this.config,
    required this.style,
    required this.useCustomOverlay,
  });

  @override
  State<_LivenessRunnerScreen> createState() => _LivenessRunnerScreenState();
}

class _LivenessRunnerScreenState extends State<_LivenessRunnerScreen> {
  // In the real app this is driven by FaceNotifier's AsyncNotifier state.
  // Here we use a simple local enum to show the three outcome states.
  _SessionOutcome _outcome = _SessionOutcome.running;

  void _onPass() {
    if (!mounted) return;
    setState(() => _outcome = _SessionOutcome.passed);
  }

  void _onTimeout() {
    if (!mounted) return;
    setState(() => _outcome = _SessionOutcome.timedOut);
  }

  void _onUnsupportedDevice() {
    // In the real app: go_router pops back to the home screen.
    // Here we just pop the navigator.
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _retry() {
    setState(() => _outcome = _SessionOutcome.running);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar — liveness widget is full screen
      body: switch (_outcome) {
        _SessionOutcome.running => FaceLivenessWidget(
            config: widget.config,
            style: widget.style,
            onPass: _onPass,
            onTimeout: _onTimeout,
            onUnsupportedDevice: _onUnsupportedDevice,

            // Usage 3: custom overlay replaces ChallengeOverlay per challenge
            challengeOverlayBuilder: widget.useCustomOverlay
                ? (challenge) => _SampleCustomOverlay(challenge: challenge)
                : null,
          ),

        _SessionOutcome.passed => _ResultView(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF00C853),
            title: 'Verified',
            message:
                'All challenges passed. In the real app, '
                'FaceNotifier would POST to /api/attendance/submit here.',
            actionLabel: 'Try Again',
            onAction: _retry,
          ),

        _SessionOutcome.timedOut => _ResultView(
            icon: Icons.timer_off_outlined,
            iconColor: FaceLivenessColors.timerWarning,
            title: 'Time\'s Up',
            message:
                'Session expired. In the real app, FaceNotifier '
                'increments the retry counter. 3 timeouts → home screen.',
            actionLabel: 'Retry',
            onAction: _retry,
          ),
      },
    );
  }
}

enum _SessionOutcome { running, passed, timedOut }

// ---------------------------------------------------------------------------
// Result view (pass / timeout)
// ---------------------------------------------------------------------------

class _ResultView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _ResultView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 20),
            Text(
              title,
              style: FaceLivenessTextStyles.dialogTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: FaceLivenessTextStyles.dialogBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FaceLivenessColors.crimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: FaceLivenessTextStyles.dialogButton.copyWith(
                    color: FaceLivenessColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sample custom overlay (Usage 3)
//
// Demonstrates how another project replaces the default ChallengeOverlay
// entirely via challengeOverlayBuilder. This one uses a pill-shaped banner
// instead of the glassmorphism panel — different look, same data.
// ---------------------------------------------------------------------------

class _SampleCustomOverlay extends StatelessWidget {
  final LivenessChallenge challenge;

  const _SampleCustomOverlay({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (challenge) {
      LivenessChallenge.blink => (Icons.remove_red_eye_outlined, 'Blink'),
      LivenessChallenge.smile => (Icons.sentiment_satisfied_alt_outlined, 'Smile'),
      LivenessChallenge.turnLeft => (Icons.arrow_back_rounded, 'Turn Left'),
      LivenessChallenge.turnRight => (Icons.arrow_forward_rounded, 'Turn Right'),
      LivenessChallenge.lookUp => (Icons.arrow_upward_rounded, 'Look Up'),
      LivenessChallenge.lookDown => (Icons.arrow_downward_rounded, 'Look Down'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0), // deep blue — example alternate brand
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402196F3),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}