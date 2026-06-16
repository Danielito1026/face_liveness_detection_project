import 'package:face_detect_trial/pages/liveness_runner_screen.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_config.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_style.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_theme.dart';
import 'package:face_detect_trial/widgets/face_liveness/liveness_challenge.dart';
import 'package:flutter/material.dart';

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
                onTap: () =>
                    _launch(context, style: FaceLivenessStyle.defaults()),
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
        builder: (_) => LivenessRunnerScreen(
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
                  Text(
                    label,
                    style: FaceLivenessTextStyles.challengeInstruction,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: FaceLivenessTextStyles.challengeSubtitle,
                  ),
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