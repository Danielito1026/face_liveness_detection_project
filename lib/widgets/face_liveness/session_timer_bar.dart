// session_timer_bar.dart
// Location: lib/features/face/widgets/session_timer_bar.dart
//
// Animated progress bar showing remaining session time.
// Listens to ChallengeDirector.timerProgressStream (0.0 to 1.0).
//
// Visual behaviour:
//   - Bar drains left to right over the session duration
//   - Color transitions from timerBarActiveColor to timerBarWarningColor
//     when progress drops to or below 20% remaining (configurable via
//     [warningThreshold])
//   - Smooth interpolation via AnimatedContainer — no jank on 100ms ticks
//
// Usage:
//   SessionTimerBar(
//     progress: _timerProgress,   // 0.0–1.0 from timerProgressStream
//     style: widget.style,
//   )

import 'package:flutter/material.dart';
import '../detection_styles/detection_style.dart';
import '../detection_styles/detection_theme.dart';

class SessionTimerBar extends StatelessWidget {
  /// Remaining time as a fraction: 1.0 = full, 0.0 = expired.
  /// Driven by ChallengeDirector.timerProgressStream.
  final double progress;

  /// Style config — drives colors and bar height.
  final DetectionStyle style;

  /// Progress fraction at which the bar switches to warning color.
  /// Default: 0.2 (20% remaining).
  final double warningThreshold;

  const SessionTimerBar({
    super.key,
    required this.progress,
    required this.style,
    this.warningThreshold = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = progress <= warningThreshold;
    final barColor = isWarning
        ? style.timerBarWarningColor
        : style.timerBarActiveColor;

    return SizedBox(
      height: style.timerBarHeight,
      child: Stack(
        children: [
          // Track (full-width background)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: style.timerBarTrackColor,
              borderRadius: BorderRadius.circular(style.timerBarHeight / 2),
            ),
          ),

          // Active bar (drains from right)
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedContainer(
                duration: DetectionTheme.timerBarUpdateInterval,
                curve: Curves.linear,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(style.timerBarHeight / 2),
                  // Subtle glow on the active bar
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: Offset.zero,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}