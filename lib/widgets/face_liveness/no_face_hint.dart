// no_face_hint.dart
// Location: lib/features/face/widgets/no_face_hint.dart
//
// Small banner shown over the camera cutout when ChallengeValidator has
// reported ChallengeResult.noFace for a sustained period (debounced in
// ChallengeDirector — see reportFaceDetected / noFaceDetectedStream).
//
// This does NOT pause the session timer or block challenge detection —
// it's purely an informational hint to help the user reposition.
//
// Usage:
//   NoFaceHint(visible: _noFaceHintVisible, style: widget.style)

import 'package:face_detect_trial/widgets/face_liveness/face_liveness_theme.dart';
import 'package:flutter/material.dart';

import 'face_liveness_style.dart';

class NoFaceHint extends StatelessWidget {
  /// Whether the hint should be visible.
  /// Driven by ChallengeDirector.noFaceDetectedStream.
  final bool visible;

  /// Style config — drives background color, text style, icon, and message.
  final FaceLivenessStyle style;

  const NoFaceHint({super.key, required this.visible, required this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, -0.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1.0 : 0.0,
        // IgnorePointer + visibility gate so it doesn't intercept taps
        // or take layout space while hidden.
        child: IgnorePointer(
          ignoring: !visible,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: style.noFaceHintBackgroundColor.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: style.noFaceHintBackgroundColor.withValues(alpha: 0.8),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    style.noFaceHintIcon,
                    size: 18,
                    color: FaceLivenessColors.crimson,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      style.noFaceHintMessage,
                      style: style.noFaceHintTextStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
