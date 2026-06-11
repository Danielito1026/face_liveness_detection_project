// face_liveness_config.dart
//
// Behavior configuration for the face liveness widget.
// Values are typically sourced from the backend (admin-configured).
// This model is intentionally free of UI concerns — style lives in FaceLivenessStyle.
//
// Usage (from FaceNotifier after fetching backend config):
//
//   final config = FaceLivenessConfig.fromJson(response.data);
//
//   FaceLivenessWidget(
//     config: config,
//     style: FaceLivenessStyle.defaults(),
//     onPass: _handlePass,
//     onTimeout: _handleTimeout,
//   );

import 'package:flutter/foundation.dart';
import 'liveness_challenge.dart'; // core/enums/liveness_challenge.dart

class FaceLivenessConfig {
  /// The ordered list of challenges to present in this session.
  /// When [isRandom] is true, ChallengeDirector will shuffle this list.
  /// When false, challenges are presented in the exact order given.
  final List<LivenessChallenge> challengeSequence;

  /// Whether ChallengeDirector should randomize the challenge order each session.
  /// Comes from backend config. Helps prevent spoofing via memorized sequences.
  final bool isRandom;

  /// Seconds allocated per challenge. Session timer = challengeSequence.length × this.
  /// Default: 20 seconds per challenge (matches architecture doc).
  final int secondsPerChallenge;

  const FaceLivenessConfig({
    required this.challengeSequence,
    required this.isRandom,
    this.secondsPerChallenge = 20,
  }) : assert(
          challengeSequence.length > 0,
          'challengeSequence must contain at least one challenge.',
        );

  /// Total session duration in seconds.
  /// Used by ChallengeDirector to initialize the countdown timer.
  int get sessionDurationSeconds => challengeSequence.length * secondsPerChallenge;

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory FaceLivenessConfig.fromJson(Map<String, dynamic> json) {
    final rawSequence = json['challengeSequence'] as List<dynamic>? ?? [];

    final challenges = rawSequence
        .map((e) => LivenessChallenge.fromString(e as String))
        .whereType<LivenessChallenge>() // silently drops unrecognized values
        .toList();

    assert(
      challenges.isNotEmpty,
      'Backend returned an empty or unrecognizable challengeSequence.',
    );

    return FaceLivenessConfig(
      challengeSequence: challenges,
      isRandom: json['isRandom'] as bool? ?? false,
      secondsPerChallenge: json['secondsPerChallenge'] as int? ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
        'challengeSequence': challengeSequence.map((c) => c.value).toList(),
        'isRandom': isRandom,
        'secondsPerChallenge': secondsPerChallenge,
      };

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  FaceLivenessConfig copyWith({
    List<LivenessChallenge>? challengeSequence,
    bool? isRandom,
    int? secondsPerChallenge,
  }) {
    return FaceLivenessConfig(
      challengeSequence: challengeSequence ?? this.challengeSequence,
      isRandom: isRandom ?? this.isRandom,
      secondsPerChallenge: secondsPerChallenge ?? this.secondsPerChallenge,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceLivenessConfig &&
          runtimeType == other.runtimeType &&
          listEquals(challengeSequence, other.challengeSequence) &&
          isRandom == other.isRandom &&
          secondsPerChallenge == other.secondsPerChallenge;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(challengeSequence), isRandom, secondsPerChallenge);

  @override
  String toString() =>
      'FaceLivenessConfig(challenges: ${challengeSequence.map((c) => c.value).toList()}, '
      'isRandom: $isRandom, secondsPerChallenge: $secondsPerChallenge)';
}