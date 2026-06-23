// challenge_validator.dart
// Location: lib/features/face/widgets/challenge_validator.dart
//
// Stateless ML Kit face detection processor.
// Receives a camera image frame, runs face detection, and evaluates whether
// the currently active challenge has been passed.
//
// Responsibilities (per architecture doc §7.5):
//   - Accepts a stream of camera frames via ML Kit FaceDetector
//   - Applies threshold constants from liveness_thresholds.dart
//   - Emits a single ChallengeResult (pass / fail) per active challenge
//   - Stateless: no retry logic, no timer logic (those live in ChallengeDirector)
//
// ChallengeValidator does NOT know:
//   - Which challenge comes next
//   - How many retries have been used
//   - Whether the session has timed out
//
// Usage:
//   final validator = ChallengeValidator();
//   await validator.initialize();
//
//   // In camera frame callback:
//   final result = await validator.evaluate(
//     image: cameraImage,
//     inputImageRotation: rotation,
//     challenge: LivenessChallenge.blink,
//   );
//   if (result == ChallengeResult.pass) { ... }
//
//   // When done:
//   await validator.dispose();

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'liveness_challenge.dart';
import 'liveness_thresholds.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

enum ChallengeResult {
  /// The face passed the current challenge threshold.
  pass,

  /// The face was detected but did not meet the challenge threshold yet.
  notYet,

  /// No face detected in the frame, or face too small / too few landmarks.
  noFace,

  /// ML Kit returned an error processing this frame. Caller should skip frame.
  error,
}

// ---------------------------------------------------------------------------
// Blink state — only internal piece of per-challenge state needed
// ---------------------------------------------------------------------------

/// Tracks the two-phase blink detection (close → reopen).
/// Reset by ChallengeDirector each time a blink challenge becomes active.
class _BlinkState {
  bool eyesClosed = false;
}

// ---------------------------------------------------------------------------
// ChallengeValidator
// ---------------------------------------------------------------------------

class ChallengeValidator {
  late final FaceDetector _detector;

  /// Internal blink state — reset when blink challenge starts.
  final _BlinkState _blinkState = _BlinkState();

  bool _isInitialized = false;
  bool _isDisposed = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes the ML Kit FaceDetector with the options needed for liveness.
  /// Must be called before [evaluate]. Safe to call once and reuse across
  /// multiple challenges.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _detector = FaceDetector(
      options: FaceDetectorOptions(
        // Classification required for blink + smile probability scores
        enableClassification: true,
        // Euler angles required for head turn + tilt detection
        enableTracking: false, // tracking not needed; we just need per-frame angles
        // Performance mode: accurate for liveness (not real-time streaming game)
        performanceMode: FaceDetectorMode.accurate,
        // Minimum face size as fraction of image — filters out tiny/far faces
        minFaceSize: 0.25,
      ),
    );

    _isInitialized = true;
  }

  /// Releases the ML Kit FaceDetector. Call in the parent widget's dispose().
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _detector.close();
  }

  // ---------------------------------------------------------------------------
  // Blink state reset
  // ---------------------------------------------------------------------------

  /// Called by ChallengeDirector each time a blink challenge becomes the
  /// active challenge. Resets the two-phase blink tracking.
  void resetBlinkState() {
    _blinkState.eyesClosed = false;
  }

  // ---------------------------------------------------------------------------
  // Frame evaluation
  // ---------------------------------------------------------------------------

  /// Processes a single [InputImage] frame and evaluates it against [challenge].
  ///
  /// [image] must be an [InputImage] built from the camera plugin's CameraImage.
  /// Use [InputImage.fromBytes] with the correct [InputImageMetadata].
  ///
  /// Returns [ChallengeResult.pass] when the challenge threshold is met.
  /// Returns [ChallengeResult.notYet] when a valid face is present but
  /// the threshold hasn't been crossed yet.
  /// Returns [ChallengeResult.noFace] when no usable face is in the frame.
  /// Returns [ChallengeResult.error] on ML Kit processing failure.
  Future<ChallengeResult> evaluate({
    required InputImage image,
    required LivenessChallenge challenge,
  }) async {
    assert(_isInitialized, 'Call initialize() before evaluate().');
    assert(!_isDisposed, 'ChallengeValidator has been disposed.');

    try {
      final faces = await _detector.processImage(image);

      // No face in frame
      if (faces.isEmpty) return ChallengeResult.noFace;

      // Use the largest detected face (most prominent in frame)
      final face = _largestFace(faces);

      // Validate face quality before checking challenge thresholds
      if (!_isFaceValid(face)) return ChallengeResult.noFace;

      return _evaluateChallenge(face, challenge);
    } catch (_) {
      return ChallengeResult.error;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns the face with the largest bounding box area.
  Face _largestFace(List<Face> faces) {
    return faces.reduce((a, b) {
      final aArea = a.boundingBox.width * a.boundingBox.height;
      final bArea = b.boundingBox.width * b.boundingBox.height;
      return aArea >= bArea ? a : b;
    });
  }

  /// Validates that the detected face meets minimum quality requirements.
  /// Filters out faces that are too small (user too far from camera).
  bool _isFaceValid(Face face) {
    final area = face.boundingBox.width * face.boundingBox.height;
    return area >= LivenessThresholds.minimumFaceAreaPx;
  }

  /// Routes to the appropriate challenge evaluator.
  ChallengeResult _evaluateChallenge(Face face, LivenessChallenge challenge) {
    return switch (challenge) {
      LivenessChallenge.blink => _evaluateBlink(face),
      LivenessChallenge.smile => _evaluateSmile(face),
      LivenessChallenge.turnLeft => _evaluateTurnLeft(face),
      LivenessChallenge.turnRight => _evaluateTurnRight(face),
      LivenessChallenge.lookUp => _evaluateLookUp(face),
      LivenessChallenge.lookDown => _evaluateLookDown(face),
    };
  }

  // --- Blink ---
  // Two-phase: detect eyes closing, then detect eyes reopening.
  // Prevents a held-closed-eye from counting as a blink.
  ChallengeResult _evaluateBlink(Face face) {
    final leftOpen = face.leftEyeOpenProbability;
    final rightOpen = face.rightEyeOpenProbability;

    // If classification data is missing, skip this frame
    if (leftOpen == null || rightOpen == null) return ChallengeResult.notYet;

    final eyesClosed = leftOpen < LivenessThresholds.blinkClosedThreshold &&
        rightOpen < LivenessThresholds.blinkClosedThreshold;

    final eyesOpen = leftOpen > LivenessThresholds.blinkReopenThreshold &&
        rightOpen > LivenessThresholds.blinkReopenThreshold;

    if (!_blinkState.eyesClosed && eyesClosed) {
      // Phase 1: eyes just closed
      _blinkState.eyesClosed = true;
      return ChallengeResult.notYet;
    }

    if (_blinkState.eyesClosed && eyesOpen) {
      // Phase 2: eyes reopened after closing — full blink complete
      return ChallengeResult.pass;
    }

    return ChallengeResult.notYet;
  }

  // --- Smile ---
  ChallengeResult _evaluateSmile(Face face) {
    final smiling = face.smilingProbability;
    if (smiling == null) return ChallengeResult.notYet;
    return smiling > LivenessThresholds.smileThreshold
        ? ChallengeResult.pass
        : ChallengeResult.notYet;
  }

  // --- Turn left ---
  // Positive Y angle = face turned to the subject's left
  ChallengeResult _evaluateTurnLeft(Face face) {
    final angleY = face.headEulerAngleY;
    if (angleY == null) return ChallengeResult.notYet;
    return angleY > LivenessThresholds.turnThreshold
        ? ChallengeResult.pass
        : ChallengeResult.notYet;
  }

  // --- Turn right ---
  // Negative Y angle = face turned to the subject's right
  ChallengeResult _evaluateTurnRight(Face face) {
    final angleY = face.headEulerAngleY;
    if (angleY == null) return ChallengeResult.notYet;
    return angleY < -LivenessThresholds.turnThreshold
        ? ChallengeResult.pass
        : ChallengeResult.notYet;
  }

  // --- Look up ---
  // Positive X angle = head tilted upward
  ChallengeResult _evaluateLookUp(Face face) {
    final angleX = face.headEulerAngleX;
    if (angleX == null) return ChallengeResult.notYet;
    return angleX > LivenessThresholds.tiltThreshold
        ? ChallengeResult.pass
        : ChallengeResult.notYet;
  }

  // --- Look down ---
  // Negative X angle = head tilted downward
  ChallengeResult _evaluateLookDown(Face face) {
    final angleX = face.headEulerAngleX;
    if (angleX == null) return ChallengeResult.notYet;
    return angleX < -LivenessThresholds.tiltThreshold
        ? ChallengeResult.pass
        : ChallengeResult.notYet;
  }
}