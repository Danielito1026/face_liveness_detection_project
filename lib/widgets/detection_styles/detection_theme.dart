// face_liveness_theme.dart
// Location: lib/features/face/widgets/face_liveness_theme.dart
//
// Default visual constants for the face liveness widget system.
// Based on the timekeeping app's design language: dark navy, crimson accents,
// glassmorphism surfaces.
//
// Other projects override these by passing a custom FaceLivenessStyle — they
// never need to touch this file. This file is the "what it looks like by default"
// source of truth.

import 'package:flutter/material.dart';
import '../face_liveness/liveness_challenge.dart';

// ---------------------------------------------------------------------------
// Color palette
// ---------------------------------------------------------------------------

class DetectionColors {
  DetectionColors._();

  // Core palette — timekeeping app identity
  static const Color navyDark = Color(0xFF0D1B2A);
  static const Color navyMid = Color(0xFF1B2A3B);
  static const Color navyLight = Color(0xFF243447);

  static const Color crimson = Color(0xFFBE1E2D);
  static const Color crimsonLight = Color(0xFFE8293B);
  static const Color crimsonGlow = Color(0x40BE1E2D); // for glows/shadows

  static const Color white = Color(0xFFFFFFFF);
  static const Color whiteHigh = Color(0xFFF0F4F8);
  static const Color whiteMid = Color(0xFFB0BEC5);
  static const Color whiteLow = Color(0x80FFFFFF); // 50% white

  // Overlay tint on camera preview (the dim area outside the cutout)
  static const Color cameraOverlay = Color.fromARGB(
    204,
    43,
    48,
    54,
  ); // 80% navyDark

  // Timer bar
  static const Color timerActive = crimson;
  static const Color timerWarning = Color(
    0xFFFF6B35,
  ); // orange — < 20% remaining
  static const Color timerTrack = Color(0xFF243447);

  // Challenge progress dots
  static const Color dotComplete = crimson;
  static const Color dotActive = whiteHigh;
  static const Color dotInactive = Color(0xFF3A4D61);

  // Glassmorphism overlay panel
  static const Color glassFill = Color(0x26FFFFFF); // 15% white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white

  // Unsupported device dialog
  static const Color dialogBackground = navyMid;
  static const Color dialogBorder = Color(0x33FFFFFF);

  // Success flash (brief overlay when a challenge passes)
  static const Color successFlash = Color(0x3300C853);
}

// ---------------------------------------------------------------------------
// Text styles
// ---------------------------------------------------------------------------

class DetectionTextStyles {
  DetectionTextStyles._();

  static const String _fontFamily = 'Roboto'; // matches app-wide font

  static const TextStyle challengeInstruction = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: DetectionColors.whiteHigh,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const TextStyle challengeSubtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: DetectionColors.whiteMid,
    letterSpacing: 0.2,
  );

  static const TextStyle timerLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: DetectionColors.whiteMid,
    letterSpacing: 0.5,
  );

  static const TextStyle dialogTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: DetectionColors.whiteHigh,
  );

  static const TextStyle dialogBody = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: DetectionColors.whiteMid,
    height: 1.5,
  );

  static const TextStyle dialogButton = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: DetectionColors.crimsonLight,
    letterSpacing: 0.3,
  );
}

// ---------------------------------------------------------------------------
// Challenge display config
// ---------------------------------------------------------------------------

/// Visual representation of a single challenge shown in ChallengeOverlay.
/// Each challenge has an icon (IconData) and instruction text.
/// Both are fully overridable via FaceLivenessStyle.challengeDisplayMap.
class ChallengeDisplayConfig {
  final IconData icon;
  final String instruction;

  /// Optional subtitle shown below the instruction (e.g. "Hold still").
  final String? subtitle;

  const ChallengeDisplayConfig({
    required this.icon,
    required this.instruction,
    this.subtitle,
  });

  ChallengeDisplayConfig copyWith({
    IconData? icon,
    String? instruction,
    String? subtitle,
  }) {
    return ChallengeDisplayConfig(
      icon: icon ?? this.icon,
      instruction: instruction ?? this.instruction,
      subtitle: subtitle ?? this.subtitle,
    );
  }
}

// ---------------------------------------------------------------------------
// Default challenge display map
// ---------------------------------------------------------------------------

class DetectionTheme {
  DetectionTheme._();

  /// Default icon + text for each challenge.
  /// Used by ChallengeOverlay unless overridden in FaceLivenessStyle.
  static const Map<LivenessChallenge, ChallengeDisplayConfig>
  challengeDisplayDefaults = {
    LivenessChallenge.blink: ChallengeDisplayConfig(
      icon: Icons.remove_red_eye_outlined,
      instruction: 'Blink your eyes',
      subtitle: 'Blink slowly and clearly',
    ),
    LivenessChallenge.smile: ChallengeDisplayConfig(
      icon: Icons.sentiment_satisfied_alt_outlined,
      instruction: 'Give a smile',
      subtitle: 'Show your teeth if you can',
    ),
    LivenessChallenge.turnLeft: ChallengeDisplayConfig(
      icon: Icons.arrow_back_rounded,
      instruction: 'Turn your head left',
      subtitle: 'Slowly turn to your left',
    ),
    LivenessChallenge.turnRight: ChallengeDisplayConfig(
      icon: Icons.arrow_forward_rounded,
      instruction: 'Turn your head right',
      subtitle: 'Slowly turn to your right',
    ),
    LivenessChallenge.lookUp: ChallengeDisplayConfig(
      icon: Icons.arrow_upward_rounded,
      instruction: 'Look up',
      subtitle: 'Tilt your head upward',
    ),
    LivenessChallenge.lookDown: ChallengeDisplayConfig(
      icon: Icons.arrow_downward_rounded,
      instruction: 'Look down',
      subtitle: 'Tilt your head downward',
    ),
  };

  /// Session timer bar height
  static const double timerBarHeight = 6.0;

  /// Progress dot size
  static const double dotSize = 10.0;

  /// Progress dot spacing
  static const double dotSpacing = 8.0;

  // ---------------------------------------------------------------------------
  // Animation durations
  // ---------------------------------------------------------------------------

  static const Duration overlayTransitionIn = Duration(milliseconds: 300);
  static const Duration overlayTransitionOut = Duration(milliseconds: 200);
  static const Duration successFlashDuration = Duration(milliseconds: 400);
  static const Duration timerBarUpdateInterval = Duration(milliseconds: 100);
}

class CutoutDefaults {
  // ---------------------------------------------------------------------------
  // Dimension constants
  // ---------------------------------------------------------------------------
  static const double cutoutVerticalCenter = 0.42;

  /// Oval cutout: fraction of screen width
  static const double cutoutWidthFactor = 0.85;

  /// Oval cutout: fraction of screen height
  static const double cutoutHeightFactor = 0.50;

  /// Camera frame border width (default)
  static const double frameBorderWidth = 2.5;

  /// Corner radius for RectCutout default
  static const double rectBorderRadius = 24.0;

  /// Challenge overlay panel height
  static const double overlayPanelHeight = 120.0;
}
