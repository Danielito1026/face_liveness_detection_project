import 'package:face_detect_trial/pages/result_view.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_config.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_style.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_theme.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_widget.dart';
import 'package:face_detect_trial/widgets/face_liveness/liveness_challenge.dart';
import 'package:flutter/material.dart';

class LivenessRunnerScreen extends StatefulWidget {
  final FaceLivenessConfig config;
  final FaceLivenessStyle style;
  final bool useCustomOverlay;

  const LivenessRunnerScreen({
    super.key,
    required this.config,
    required this.style,
    required this.useCustomOverlay,
  });

  @override
  State<LivenessRunnerScreen> createState() => _LivenessRunnerScreenState();
}

class _LivenessRunnerScreenState extends State<LivenessRunnerScreen> {
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

        _SessionOutcome.passed => ResultView(
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF00C853),
          title: 'Verified',
          message:
              'All challenges passed. In the real app, '
              'FaceNotifier would POST to /api/attendance/submit here.',
          actionLabel: 'Try Again',
          onAction: _retry,
        ),

        _SessionOutcome.timedOut => ResultView(
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
      LivenessChallenge.smile => (
        Icons.sentiment_satisfied_alt_outlined,
        'Smile',
      ),
      LivenessChallenge.turnLeft => (Icons.arrow_back_rounded, 'Turn Left'),
      LivenessChallenge.turnRight => (
        Icons.arrow_forward_rounded,
        'Turn Right',
      ),
      LivenessChallenge.lookUp => (Icons.arrow_upward_rounded, 'Look Up'),
      LivenessChallenge.lookDown => (Icons.arrow_downward_rounded, 'Look Down'),
      LivenessChallenge.faceOnly => (Icons.face, 'Face'),
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
