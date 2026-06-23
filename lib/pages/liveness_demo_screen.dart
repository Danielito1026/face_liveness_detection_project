import 'package:face_detect_trial/pages/liveness_runner_screen.dart';
import 'package:face_detect_trial/pages/qr_scanner_page.dart';
import 'package:face_detect_trial/widgets/face_liveness/face_liveness_config.dart';
import 'package:face_detect_trial/widgets/detection_styles/detection_style.dart';
import 'package:face_detect_trial/widgets/detection_styles/detection_theme.dart';
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
                style: DetectionTextStyles.dialogTitle,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a variant to launch the liveness widget with that style.',
                style: DetectionTextStyles.dialogBody,
              ),
              const SizedBox(height: 40),

              // --- Usage 1: Default style ---
              _DemoTile(
                label: 'Default Style',
                description:
                    'Dark navy + crimson. Oval cutout.\n'
                    'DetectionStyle.defaults()',
                onTap: () => _launch(context, style: DetectionStyle.defaults()),
              ),

              const SizedBox(height: 16),

              // --- Usage 2: copyWith override ---
              _DemoTile(
                label: 'copyWith Override',
                description:
                    'Same defaults, rect cutout, blue border.\n'
                    'DetectionStyle.defaults().copyWith(...)',
                onTap: () => _launch(
                  context,
                  style: DetectionStyle.defaults().copyWith(
                    cutoutShape: const RectCutout(
                      widthFactor: .80,
                      heightFactor: .40,
                      borderRadius: 20,
                    ),
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
                  style: DetectionStyle.defaults(),
                  useCustomOverlay: true,
                ),
              ),

              const SizedBox(height: 16),

              _DemoTile(
                label: 'QR Code Scanner Page',
                description:
                    'Default style + custom overlay widget per challenge',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QrScannerPage()),
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
    required DetectionStyle style,
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
          color: DetectionColors.navyMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DetectionColors.glassBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: DetectionTextStyles.challengeInstruction),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: DetectionTextStyles.challengeSubtitle,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: DetectionColors.whiteMid,
            ),
          ],
        ),
      ),
    );
  }
}
