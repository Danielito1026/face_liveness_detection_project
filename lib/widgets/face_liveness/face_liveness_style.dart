// face_liveness_style.dart
// Location: lib/features/face/widgets/face_liveness_style.dart
//
// Style configuration for the face liveness widget system.
// Covers colors, text styles, cutout shape, and per-challenge display overrides.
//
// Usage — use defaults (timekeeping app look):
//
//   FaceLivenessWidget(style: FaceLivenessStyle.defaults(), ...)
//
// Usage — override specific values in another project:
//
//   FaceLivenessWidget(
//     style: FaceLivenessStyle.defaults().copyWith(
//       frameBorderColor: Colors.blue,
//       cutoutShape: RectCutout(borderRadius: 16),
//     ),
//     ...
//   )
//
// Usage — full custom style from scratch:
//
//   FaceLivenessWidget(
//     style: FaceLivenessStyle(
//       cutoutShape: OvalCutout(),
//       cameraOverlayColor: Colors.black87,
//       ...
//     ),
//     ...
//   )

import 'package:flutter/material.dart';
import 'face_liveness_theme.dart';
import 'liveness_challenge.dart';

// ---------------------------------------------------------------------------
// Cutout shape
// ---------------------------------------------------------------------------

/// Sealed class for the camera frame cutout shape.
/// Extend with additional shapes if needed in future (e.g. CircleCutout).
sealed class CutoutShape {
  const CutoutShape();
}

/// Oval (ellipse) cutout. Default for face detection — natural face framing.
class OvalCutout extends CutoutShape {
  /// Fraction of screen width the oval occupies. Default: 0.70.
  final double widthFactor;

  /// Fraction of screen height the oval occupies. Default: 0.42.
  final double heightFactor;

  const OvalCutout({
    this.widthFactor = FaceLivenessTheme.cutoutWidthFactor,
    this.heightFactor = FaceLivenessTheme.cutoutHeightFactor,
  });
}

/// Rounded rectangle cutout. Use for ID card scanning or square face frames.
class RectCutout extends CutoutShape {
  /// Fraction of screen width. Default: 0.70.
  final double widthFactor;

  /// Fraction of screen height. Default: 0.42.
  final double heightFactor;

  /// Corner radius in logical pixels. Default: 24.
  final double borderRadius;

  const RectCutout({
    this.widthFactor = FaceLivenessTheme.cutoutWidthFactor,
    this.heightFactor = FaceLivenessTheme.cutoutHeightFactor,
    this.borderRadius = FaceLivenessTheme.rectBorderRadius,
  });
}

// ---------------------------------------------------------------------------
// Style model
// ---------------------------------------------------------------------------

class FaceLivenessStyle {
  // --- Camera frame ---

  /// Shape of the transparent cutout over the camera preview.
  final CutoutShape cutoutShape;

  /// Color of the dimmed area outside the cutout.
  final Color cameraOverlayColor;

  /// Border color of the cutout frame.
  final Color frameBorderColor;

  /// Border width of the cutout frame in logical pixels.
  final double frameBorderWidth;

  // --- Challenge overlay panel ---

  /// Background fill of the glassmorphism overlay panel.
  final Color overlayPanelColor;

  /// Border color of the overlay panel.
  final Color overlayPanelBorderColor;

  /// Icon color in the challenge overlay.
  final Color challengeIconColor;

  /// Icon size in the challenge overlay.
  final double challengeIconSize;

  /// Text style for the main challenge instruction.
  final TextStyle instructionTextStyle;

  /// Text style for the optional challenge subtitle.
  final TextStyle subtitleTextStyle;

  // --- Session timer bar ---

  /// Color of the timer bar when time is healthy (> 20% remaining).
  final Color timerBarActiveColor;

  /// Color of the timer bar when time is low (≤ 20% remaining).
  final Color timerBarWarningColor;

  /// Background track color of the timer bar.
  final Color timerBarTrackColor;

  /// Height of the timer bar in logical pixels.
  final double timerBarHeight;

  // --- Challenge progress dots ---

  /// Color of completed challenge dots.
  final Color dotCompleteColor;

  /// Color of the currently active challenge dot.
  final Color dotActiveColor;

  /// Color of upcoming (not yet reached) challenge dots.
  final Color dotInactiveColor;

  /// Diameter of each dot in logical pixels.
  final double dotSize;

  // --- Unsupported device dialog ---

  /// Background color of the unsupported device dialog.
  final Color dialogBackgroundColor;

  /// Border color of the unsupported device dialog.
  final Color dialogBorderColor;

  /// Text style for the dialog title.
  final TextStyle dialogTitleStyle;

  /// Text style for the dialog body.
  final TextStyle dialogBodyStyle;

  /// Text style for the dialog action button.
  final TextStyle dialogButtonStyle;

  // --- "No face detected" hint ---

  /// Background color of the "no face detected" hint banner.
  final Color noFaceHintBackgroundColor;

  /// Text style for the "no face detected" hint message.
  final TextStyle noFaceHintTextStyle;

  /// Icon shown alongside the "no face detected" hint message.
  final IconData noFaceHintIcon;

  /// Message shown when no face has been detected for a sustained period.
  final String noFaceHintMessage;

  // --- Challenge display overrides ---

  /// Per-challenge icon and instruction overrides.
  /// Entries here are merged with [FaceLivenessTheme.challengeDisplayDefaults].
  /// You only need to provide the challenges you want to override.
  ///
  /// Example — change the smile instruction text:
  ///
  ///   challengeDisplayMap: {
  ///     LivenessChallenge.smile: ChallengeDisplayConfig(
  ///       icon: Icons.tag_faces,
  ///       instruction: 'Flash a big smile!',
  ///     ),
  ///   }
  final Map<LivenessChallenge, ChallengeDisplayConfig> challengeDisplayMap;

  const FaceLivenessStyle({
    required this.cutoutShape,
    required this.cameraOverlayColor,
    required this.frameBorderColor,
    required this.frameBorderWidth,
    required this.overlayPanelColor,
    required this.overlayPanelBorderColor,
    required this.challengeIconColor,
    required this.challengeIconSize,
    required this.instructionTextStyle,
    required this.subtitleTextStyle,
    required this.timerBarActiveColor,
    required this.timerBarWarningColor,
    required this.timerBarTrackColor,
    required this.timerBarHeight,
    required this.dotCompleteColor,
    required this.dotActiveColor,
    required this.dotInactiveColor,
    required this.dotSize,
    required this.dialogBackgroundColor,
    required this.dialogBorderColor,
    required this.dialogTitleStyle,
    required this.dialogBodyStyle,
    required this.dialogButtonStyle,
    required this.noFaceHintBackgroundColor,
    required this.noFaceHintTextStyle,
    required this.noFaceHintIcon,
    required this.noFaceHintMessage,
    this.challengeDisplayMap = const {},
  });

  // ---------------------------------------------------------------------------
  // Default factory — timekeeping app look (dark navy + crimson)
  // ---------------------------------------------------------------------------

  factory FaceLivenessStyle.defaults() {
    return FaceLivenessStyle(
      // Camera frame
      cutoutShape: const OvalCutout(),
      cameraOverlayColor: FaceLivenessColors.cameraOverlay,
      frameBorderColor: FaceLivenessColors.crimson,
      frameBorderWidth: FaceLivenessTheme.frameBorderWidth,

      // Challenge overlay panel
      overlayPanelColor: FaceLivenessColors.glassFill,
      overlayPanelBorderColor: FaceLivenessColors.glassBorder,
      challengeIconColor: FaceLivenessColors.crimsonLight,
      challengeIconSize: 36,
      instructionTextStyle: FaceLivenessTextStyles.challengeInstruction,
      subtitleTextStyle: FaceLivenessTextStyles.challengeSubtitle,

      // Timer bar
      timerBarActiveColor: FaceLivenessColors.timerActive,
      timerBarWarningColor: FaceLivenessColors.timerWarning,
      timerBarTrackColor: FaceLivenessColors.timerTrack,
      timerBarHeight: FaceLivenessTheme.timerBarHeight,

      // Progress dots
      dotCompleteColor: FaceLivenessColors.dotComplete,
      dotActiveColor: FaceLivenessColors.dotActive,
      dotInactiveColor: FaceLivenessColors.dotInactive,
      dotSize: FaceLivenessTheme.dotSize,

      // Dialog
      dialogBackgroundColor: FaceLivenessColors.dialogBackground,
      dialogBorderColor: FaceLivenessColors.dialogBorder,
      dialogTitleStyle: FaceLivenessTextStyles.dialogTitle,
      dialogBodyStyle: FaceLivenessTextStyles.dialogBody,
      dialogButtonStyle: FaceLivenessTextStyles.dialogButton,

      // No face detected hint
      noFaceHintBackgroundColor: FaceLivenessColors.dialogBackground,
      noFaceHintTextStyle: FaceLivenessTextStyles.challengeSubtitle,
      noFaceHintIcon: Icons.face_retouching_off_outlined,
      noFaceHintMessage: 'No face detected. Center your face in the frame.',

      // No challenge display overrides — use FaceLivenessTheme.challengeDisplayDefaults
      challengeDisplayMap: const {},
    );
  }

  // ---------------------------------------------------------------------------
  // Resolved challenge display (merges defaults with overrides)
  // ---------------------------------------------------------------------------

  /// Returns the display config for [challenge], applying any override from
  /// [challengeDisplayMap] on top of [FaceLivenessTheme.challengeDisplayDefaults].
  ChallengeDisplayConfig resolveDisplayConfig(LivenessChallenge challenge) {
    final base = FaceLivenessTheme.challengeDisplayDefaults[challenge]!;
    final override = challengeDisplayMap[challenge];
    if (override == null) return base;
    return base.copyWith(
      icon: override.icon,
      instruction: override.instruction,
      subtitle: override.subtitle,
    );
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  FaceLivenessStyle copyWith({
    CutoutShape? cutoutShape,
    Color? cameraOverlayColor,
    Color? frameBorderColor,
    double? frameBorderWidth,
    Color? overlayPanelColor,
    Color? overlayPanelBorderColor,
    Color? challengeIconColor,
    double? challengeIconSize,
    TextStyle? instructionTextStyle,
    TextStyle? subtitleTextStyle,
    Color? timerBarActiveColor,
    Color? timerBarWarningColor,
    Color? timerBarTrackColor,
    double? timerBarHeight,
    Color? dotCompleteColor,
    Color? dotActiveColor,
    Color? dotInactiveColor,
    double? dotSize,
    Color? dialogBackgroundColor,
    Color? dialogBorderColor,
    TextStyle? dialogTitleStyle,
    TextStyle? dialogBodyStyle,
    TextStyle? dialogButtonStyle,
    Color? noFaceHintBackgroundColor,
    TextStyle? noFaceHintTextStyle,
    IconData? noFaceHintIcon,
    String? noFaceHintMessage,
    Map<LivenessChallenge, ChallengeDisplayConfig>? challengeDisplayMap,
  }) {
    return FaceLivenessStyle(
      cutoutShape: cutoutShape ?? this.cutoutShape,
      cameraOverlayColor: cameraOverlayColor ?? this.cameraOverlayColor,
      frameBorderColor: frameBorderColor ?? this.frameBorderColor,
      frameBorderWidth: frameBorderWidth ?? this.frameBorderWidth,
      overlayPanelColor: overlayPanelColor ?? this.overlayPanelColor,
      overlayPanelBorderColor:
          overlayPanelBorderColor ?? this.overlayPanelBorderColor,
      challengeIconColor: challengeIconColor ?? this.challengeIconColor,
      challengeIconSize: challengeIconSize ?? this.challengeIconSize,
      instructionTextStyle: instructionTextStyle ?? this.instructionTextStyle,
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      timerBarActiveColor: timerBarActiveColor ?? this.timerBarActiveColor,
      timerBarWarningColor: timerBarWarningColor ?? this.timerBarWarningColor,
      timerBarTrackColor: timerBarTrackColor ?? this.timerBarTrackColor,
      timerBarHeight: timerBarHeight ?? this.timerBarHeight,
      dotCompleteColor: dotCompleteColor ?? this.dotCompleteColor,
      dotActiveColor: dotActiveColor ?? this.dotActiveColor,
      dotInactiveColor: dotInactiveColor ?? this.dotInactiveColor,
      dotSize: dotSize ?? this.dotSize,
      dialogBackgroundColor:
          dialogBackgroundColor ?? this.dialogBackgroundColor,
      dialogBorderColor: dialogBorderColor ?? this.dialogBorderColor,
      dialogTitleStyle: dialogTitleStyle ?? this.dialogTitleStyle,
      dialogBodyStyle: dialogBodyStyle ?? this.dialogBodyStyle,
      dialogButtonStyle: dialogButtonStyle ?? this.dialogButtonStyle,
      noFaceHintBackgroundColor:
          noFaceHintBackgroundColor ?? this.noFaceHintBackgroundColor,
      noFaceHintTextStyle: noFaceHintTextStyle ?? this.noFaceHintTextStyle,
      noFaceHintIcon: noFaceHintIcon ?? this.noFaceHintIcon,
      noFaceHintMessage: noFaceHintMessage ?? this.noFaceHintMessage,
      challengeDisplayMap: challengeDisplayMap ?? this.challengeDisplayMap,
    );
  }
}
