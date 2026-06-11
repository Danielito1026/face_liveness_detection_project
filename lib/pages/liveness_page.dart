import 'package:flutter/material.dart';
import 'package:flutter_face_liveness/flutter_face_liveness.dart';

class LivenessPage extends StatefulWidget {
  const LivenessPage({super.key});

  @override
  State<LivenessPage> createState() => _LivenessPageState();
}

class _LivenessPageState extends State<LivenessPage> {
  bool _isVerified = false;
  bool _isFailed = false;
  String? _failReason;
  LivenessResult? _result;

  void _onSuccess(LivenessResult result) {
    setState(() {
      _isVerified = true;
      _isFailed = false;
      _result = result;
    });

    // TODO: Send result.faceId + result.sessionId to your backend for verification
    debugPrint('Face ID: ${result.faceId}');
    debugPrint('Is new face: ${result.isFaceIdNew}');
    debugPrint('Session ID: ${result.sessionId}');
    debugPrint('Confidence: ${result.confidenceScore}');
  }

  void _onFailed(String reason) {
    setState(() {
      _isFailed = true;
      _isVerified = false;
      _failReason = reason;
    });

    _showFailDialog(reason);
  }

  void _showFailDialog(String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verification failed'),
        content: Text(_friendlyReason(reason)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reset();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  String _friendlyReason(String reason) {
    switch (reason) {
      case 'SPOOF_DETECTED':
        return 'A spoofing attempt was detected. Please use your real face.';
      case 'TIMEOUT':
        return 'Verification timed out. Please try again.';
      case 'NO_FACE':
        return 'No face detected. Make sure your face is clearly visible.';
      case 'VIDEO_REPLAY':
        return 'A video replay was detected. Please use a live camera feed.';
      case 'LOW_CONFIDENCE':
        return 'Confidence score too low. Please try in better lighting.';
      default:
        return 'Verification failed ($reason). Please try again.';
    }
  }

  void _reset() {
    setState(() {
      _isVerified = false;
      _isFailed = false;
      _failReason = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Identity Verification',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isVerified ? _buildSuccessView() : _buildLivenessView(),
    );
  }

  Widget _buildLivenessView() {
    return Stack(
      children: [
        FlutterFaceLiveness(
          actions: const [
            LivenessAction.blink,
            LivenessAction.turnLeft,
            LivenessAction.turnRight,
          ],
          config: const LivenessConfig(
            enableAntiSpoof: true,
            enableFaceId: true,
            enableVideoReplayDetection: true,
            randomizeActions: true,
            enableFaceMesh: true,
          ),
          onSuccess: _onSuccess,
          onFailed: _onFailed,
        ),

        // Top hint overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Follow the on-screen instructions to verify your identity.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final result = _result!;
    final score = (result.confidenceScore * 100).toStringAsFixed(1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),

            // Success icon
            const Icon(Icons.verified_user_rounded,
                size: 80, color: Color(0xFF22C55E)),
            const SizedBox(height: 16),
            const Text(
              'Verification complete',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              result.isFaceIdNew!
                  ? 'New face enrolled successfully.'
                  : 'Returning face recognized.',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Result card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _resultRow('Face ID', result.faceId!,
                      valueColor: const Color(0xFF4F8EF7)),
                  _resultRow(
                    'Status',
                    result.isFaceIdNew! ? 'New enrollment' : 'Returning user',
                    valueColor: const Color(0xFF22C55E),
                  ),
                  _resultRow('Session ID', result.sessionId!,
                      valueColor: const Color(0xFF4F8EF7)),
                  _resultRow('Confidence', '$score%',
                      valueColor: _scoreColor(result.confidenceScore),
                      isLast: true),
                ],
              ),
            ),

            const Spacer(),

            // Continue button
            FilledButton(
              onPressed: () {
                // TODO: Navigate to your next screen after verification
                // e.g. Navigator.pushReplacementNamed(context, '/home');
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F8EF7),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),

            // Retry link
            TextButton(
              onPressed: _reset,
              child: const Text('Verify again',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(
    String label,
    String value, {
    Color valueColor = Colors.white,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.90) return const Color(0xFF22C55E);
    if (score >= 0.75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}