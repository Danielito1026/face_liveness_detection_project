// challenge_progress_dots.dart
// Location: lib/features/face/widgets/challenge_progress_dots.dart
//
// Row of dots showing the challenge sequence: complete / active / upcoming.
// Driven by ChallengeDirectorState from ChallengeDirector.stateStream.
//
// Visual states per dot:
//   complete  — filled crimson dot with a checkmark icon
//   active    — white dot with a subtle pulse animation
//   inactive  — dim dot (upcoming challenges)
//
// Usage:
//   ChallengeProgressDots(
//     totalChallenges: state.totalChallenges,
//     completedCount: state.completedCount,
//     activeIndex: state.activeIndex,
//     style: widget.style,
//   )

import 'package:flutter/material.dart';
import '../detection_styles/detection_style.dart';
import '../detection_styles/detection_theme.dart';

class ChallengeProgressDots extends StatelessWidget {
  /// Total number of challenges in this session.
  final int totalChallenges;

  /// Number of challenges fully completed (before the active one).
  final int completedCount;

  /// 0-based index of the currently active challenge.
  final int activeIndex;

  /// Style config — drives dot colors and size.
  final DetectionStyle style;

  const ChallengeProgressDots({
    super.key,
    required this.totalChallenges,
    required this.completedCount,
    required this.activeIndex,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalChallenges, (index) {
        final isComplete = index < completedCount;
        final isActive = index == activeIndex;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: DetectionTheme.dotSpacing / 2,
          ),
          child: isActive
              ? _PulsingDot(style: style)
              : _StaticDot(
                  isComplete: isComplete,
                  style: style,
                ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Static dot — complete or inactive
// ---------------------------------------------------------------------------

class _StaticDot extends StatelessWidget {
  final bool isComplete;
  final DetectionStyle style;

  const _StaticDot({
    required this.isComplete,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: style.dotSize,
      height: style.dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isComplete ? style.dotCompleteColor : style.dotInactiveColor,
        boxShadow: isComplete
            ? [
                BoxShadow(
                  color: style.dotCompleteColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: Offset.zero,
                ),
              ]
            : null,
      ),
      child: isComplete
          ? Icon(
              Icons.check,
              size: style.dotSize * 0.65,
              color: DetectionColors.white,
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing dot — active challenge
// ---------------------------------------------------------------------------

class _PulsingDot extends StatefulWidget {
  final DetectionStyle style;

  const _PulsingDot({required this.style});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          width: widget.style.dotSize,
          height: widget.style.dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.style.dotActiveColor,
            boxShadow: [
              BoxShadow(
                color: widget.style.dotActiveColor.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}