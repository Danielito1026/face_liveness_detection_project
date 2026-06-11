// liveness_thresholds.dart
// Location: lib/core/constants/liveness_thresholds.dart
//
// Tunable ML Kit detection thresholds for each liveness challenge.
// All constants live here — ChallengeValidator reads from this file only.
//
// These are NOT fetched from the backend. Tune them here and rebuild.
// Adjust if detection feels too sensitive or too lenient on target devices.
//
// Threshold guide:
//   BLINK    — eye open probability drops below this value = eye is closed
//   SMILE    — smiling probability must exceed this value = genuine smile
//   TURN     — head Euler Y angle magnitude must exceed this = clear head turn
//   TILT     — head Euler X angle magnitude must exceed this = clear head tilt
//
// ML Kit property reference:
//   leftEyeOpenProbability / rightEyeOpenProbability  → 0.0 (closed) to 1.0 (open)
//   smilingProbability                                → 0.0 (neutral) to 1.0 (full smile)
//   headEulerAngleY                                   → positive = left, negative = right
//   headEulerAngleX                                   → positive = up, negative = down

class LivenessThresholds {
  LivenessThresholds._();

  // ---------------------------------------------------------------------------
  // Blink
  // ---------------------------------------------------------------------------

  /// Eye open probability below this = eye considered closed.
  /// Applied to both left and right eye — both must close for blink detection.
  static const double blinkClosedThreshold = 0.2;

  /// After a blink is detected (eyes closed), eyes must reopen above this
  /// probability before the challenge is marked as complete.
  /// Prevents a held-closed-eye from triggering multiple blinks.
  static const double blinkReopenThreshold = 0.7;

  // ---------------------------------------------------------------------------
  // Smile
  // ---------------------------------------------------------------------------

  /// Smiling probability must exceed this for a smile to be detected.
  static const double smileThreshold = 0.8;

  // ---------------------------------------------------------------------------
  // Head turn (Euler Y)
  // ---------------------------------------------------------------------------

  /// Head must turn beyond this angle (degrees) to detect a left or right turn.
  /// turnLeft  = headEulerAngleY >  turnThreshold
  /// turnRight = headEulerAngleY < -turnThreshold
  static const double turnThreshold = 30.0;

  // ---------------------------------------------------------------------------
  // Head tilt (Euler X)
  // ---------------------------------------------------------------------------

  /// Head must tilt beyond this angle (degrees) to detect look up or look down.
  /// lookUp   = headEulerAngleX >  tiltThreshold
  /// lookDown = headEulerAngleX < -tiltThreshold
  static const double tiltThreshold = 20.0;

  // ---------------------------------------------------------------------------
  // Face presence
  // ---------------------------------------------------------------------------

  /// Minimum number of landmarks ML Kit must detect for a face reading to be
  /// considered valid. Guards against partial/obscured face detections.
  static const int minimumLandmarkCount = 5;

  /// Minimum bounding box area (width × height in pixels) for a detected face
  /// to be considered close enough to the camera.
  /// Too small = face is too far away; ignore detection until user moves closer.
  static const double minimumFaceAreaPx = 40000.0; // ~200×200 px equivalent
}