// liveness_challenge.dart
// Location: lib/core/enums/liveness_challenge.dart
//
// Enum for all supported liveness challenges.
// Used by FaceLivenessConfig, ChallengeDirector, ChallengeValidator,
// and ChallengeOverlay.
//
// Adding a new challenge:
//   1. Add the enum value here with its string key.
//   2. Add a threshold constant in liveness_thresholds.dart.
//   3. Add detection logic in ChallengeValidator.
//   4. Add a ChallengeDisplayConfig entry in FaceLivenessTheme.challengeDisplayDefaults.

enum LivenessChallenge {
  blink('blink'),
  smile('smile'),
  turnLeft('turnLeft'),
  turnRight('turnRight'),
  lookUp('lookUp'),
  lookDown('lookDown');

  const LivenessChallenge(this.value);

  /// String key that matches backend config values.
  final String value;

  /// Parses a backend string into a [LivenessChallenge].
  /// Returns null for unrecognized values instead of throwing —
  /// lets FaceLivenessConfig.fromJson silently skip unknown future challenges.
  static LivenessChallenge? fromString(String value) {
    for (final challenge in LivenessChallenge.values) {
      if (challenge.value == value) return challenge;
    }
    return null;
  }
}