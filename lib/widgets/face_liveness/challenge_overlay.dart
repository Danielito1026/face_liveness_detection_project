// challenge_overlay.dart
// Location: lib/features/face/widgets/challenge_overlay.dart
//
// Animated overlay panel that shows the current liveness challenge
// as an icon + instruction text + optional subtitle.
//
// Animation:
//   - New challenge slides up + fades in (300ms)
//   - On challenge pass, slides down + fades out (200ms) before next slides in
//   - Uses AnimatedSwitcher with a custom SlideAndFade transition
//
// The panel uses a glassmorphism treatment by default (semi-transparent
// background + frosted border) matching the timekeeping app's design language.
// All colors and text styles come from DetectionStyle — no hardcoded values.
//
// Usage:
//   ChallengeOverlay(
//     challenge: LivenessChallenge.blink,
//     style: widget.style,
//   )
//
// To use a fully custom overlay, pass challengeOverlayBuilder to
// FaceLivenessWidget instead of using this widget directly.

import 'package:flutter/material.dart';
import '../detection_styles/detection_style.dart';
import '../detection_styles/detection_theme.dart';
import 'liveness_challenge.dart';

class ChallengeOverlay extends StatelessWidget {
  /// The currently active liveness challenge to display.
  final LivenessChallenge challenge;

  /// Style config — drives all colors, text styles, and icon appearance.
  final DetectionStyle style;

  const ChallengeOverlay({
    super.key,
    required this.challenge,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: DetectionTheme.overlayTransitionIn,
      reverseDuration: DetectionTheme.overlayTransitionOut,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return _SlideAndFadeTransition(animation: animation, child: child);
      },
      // Key on challenge value drives AnimatedSwitcher to rebuild on change
      child: _OverlayPanel(
        key: ValueKey(challenge.value),
        challenge: challenge,
        style: style,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------

class _OverlayPanel extends StatelessWidget {
  final LivenessChallenge challenge;
  final DetectionStyle style;

  const _OverlayPanel({
    super.key,
    required this.challenge,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final displayConfig = style.resolveDisplayConfig(challenge);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: style.overlayPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: style.overlayPanelBorderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ChallengeIcon(
            iconData: displayConfig.icon,
            style: style,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _ChallengeText(
              instruction: displayConfig.instruction,
              subtitle: displayConfig.subtitle,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon
// ---------------------------------------------------------------------------

class _ChallengeIcon extends StatefulWidget {
  final IconData iconData;
  final DetectionStyle style;

  const _ChallengeIcon({
    required this.iconData,
    required this.style,
  });

  @override
  State<_ChallengeIcon> createState() => _ChallengeIconState();
}

class _ChallengeIconState extends State<_ChallengeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DetectionColors.crimsonGlow,
          border: Border.all(
            color: widget.style.challengeIconColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Icon(
          widget.iconData,
          size: widget.style.challengeIconSize,
          color: widget.style.challengeIconColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

class _ChallengeText extends StatelessWidget {
  final String instruction;
  final String? subtitle;
  final DetectionStyle style;

  const _ChallengeText({
    required this.instruction,
    required this.subtitle,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          instruction,
          style: style.instructionTextStyle,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: style.subtitleTextStyle,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Success flash overlay
// ---------------------------------------------------------------------------

/// Brief green flash shown on top of the camera preview when a challenge passes.
/// Parent (FaceLivenessWidget) triggers this before advancing to next challenge.
///
/// Usage:
///   _SuccessFlash(visible: _showSuccessFlash)
class SuccessFlash extends StatelessWidget {
  final bool visible;

  const SuccessFlash({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: visible
          ? Container(
              color: DetectionColors.successFlash,
            )
          : const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide + fade transition
// ---------------------------------------------------------------------------

/// Slides content up while fading in; reverses on exit.
class _SlideAndFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SlideAndFadeTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}