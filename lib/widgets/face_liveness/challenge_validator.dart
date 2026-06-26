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

import 'package:flutter/widgets.dart';
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
        enableTracking:
            false, // tracking not needed; we just need per-frame angles
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
  /// [screenSize] and [cutoutRect] together enable cutout containment checking.
  /// When both are provided, the face bounding box is projected from raw buffer
  /// coordinates to screen coordinates — accounting for sensor rotation and
  /// front camera mirroring — and the face center must fall inside [cutoutRect]
  /// before any challenge threshold is evaluated. Pass null to skip the check.
  ///
  /// Returns [ChallengeResult.pass] when the challenge threshold is met.
  /// Returns [ChallengeResult.notYet] when a valid face is present but
  /// the threshold hasn't been crossed yet.
  /// Returns [ChallengeResult.noFace] when no usable face is in the frame,
  /// or when the face center is outside [cutoutRect].
  /// Returns [ChallengeResult.error] on ML Kit processing failure.
  Future<ChallengeResult> evaluate({
    required InputImage image,
    required LivenessChallenge challenge,
    Size? screenSize,
    Rect? cutoutRect,
  }) async {
    assert(_isInitialized, 'Call initialize() before evaluate().');
    assert(!_isDisposed, 'ChallengeValidator has been disposed.');

    try {
      final faces = await _detector.processImage(image);

      // No face in frame
      if (faces.isEmpty) return ChallengeResult.noFace;

      // Use the largest detected face (most prominent in frame)
      final face = _largestFace(faces);

      // Validate face quality (area / landmark count)
      if (!_isFaceValid(face)) return ChallengeResult.noFace;

      // Validate face is inside the cutout region
      if (screenSize != null && cutoutRect != null) {
        final rawImageSize = image.metadata?.size;
        final rotation = image.metadata?.rotation;
        if (rawImageSize != null &&
            rotation != null &&
            !_isFaceInCutout(
              face,
              rawImageSize,
              rotation,
              screenSize,
              cutoutRect,
            )) {
          return ChallengeResult.noFace;
        }
      }

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

  /// Projects the face bounding box center from ML Kit image coordinates to
  /// screen coordinates and checks whether it falls inside [cutoutRect].
  ///
  /// ── Coordinate spaces involved ──────────────────────────────────────────
  ///
  /// 1. Raw buffer space  — the NV21 bytes as delivered by the camera driver.
  ///    On Android with a portrait phone, the sensor is typically rotated 90°,
  ///    so the raw buffer is LANDSCAPE in memory (e.g. 640 w × 480 h).
  ///    [rawImageSize] is this size. ML Kit boundingBox values live here.
  ///
  /// 2. Logical image space — the buffer after applying [rotation].
  ///    For rotation90/270 we swap width↔height: e.g. 480 w × 640 h.
  ///    This is the coordinate space that matches the upright camera preview.
  ///
  /// 3. Screen space — logical pixels on the device display.
  ///    The camera preview is rendered with BoxFit.cover from logical image
  ///    space, scaling to fill the screen and cropping the shorter axis.
  ///    [screenSize] and [cutoutRect] are in this space.
  ///
  /// ── Transform steps ──────────────────────────────────────────────────────
  ///
  /// A. Rotate the face center from raw buffer → logical image space.
  ///    Rotation is always counter-clockwise (ML Kit convention).
  ///    We rotate clockwise to reverse it.
  ///
  /// B. Mirror X in logical image space for the front camera.
  ///    The flutter camera plugin mirrors the preview; ML Kit sees the raw
  ///    unmirrored frame. After rotation the logical image width is known.
  ///
  /// C. BoxFit.cover scale + crop: scale by the dominant axis, subtract
  ///    the half-crop offset on the non-dominant axis.
  bool _isFaceInCutout(
    Face face,
    Size rawImageSize,
    InputImageRotation rotation,
    Size screenSize,
    Rect cutoutRect,
  ) {
    // ── A. Rotate face center from raw buffer → logical image space ──
    double x = face.boundingBox.center.dx;
    double y = face.boundingBox.center.dy;
    final double rw = rawImageSize.width;
    final double rh = rawImageSize.height;

    // After applying rotation, these are the logical image dimensions.
    // For 0/180 the buffer is already portrait; for 90/270 swap.
    final double logicalW;
    final double logicalH;

    switch (rotation) {
      case InputImageRotation.rotation0deg:
        // No rotation needed — axes already match display
        logicalW = rw;
        logicalH = rh;
      // x, y unchanged

      case InputImageRotation.rotation90deg:
        // Raw buffer is landscape; display is portrait.
        // Clockwise 90° reversal: (x, y) → (rh - y, x)
        final rotX = rh - y;
        final rotY = x;
        x = rotX;
        y = rotY;
        logicalW = rh; // swapped
        logicalH = rw;

      case InputImageRotation.rotation180deg:
        // 180° flip: (x, y) → (rw - x, rh - y)
        x = rw - x;
        y = rh - y;
        logicalW = rw;
        logicalH = rh;

      case InputImageRotation.rotation270deg:
        // Counter-clockwise 90° reversal: (x, y) → (y, rw - x)
        final rotX = y;
        final rotY = rw - x;
        x = rotX;
        y = rotY;
        logicalW = rh; // swapped
        logicalH = rw;
    }

    // ── B. Mirror X for front camera (preview is horizontally flipped) ──
    x = logicalW - x;

    // ── C. BoxFit.cover: scale to fill screen, crop the smaller axis ──
    final scaleX = screenSize.width / logicalW;
    final scaleY = screenSize.height / logicalH;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    final scaledW = logicalW * scale;
    final scaledH = logicalH * scale;

    final cropX = (scaledW - screenSize.width) / 2;
    final cropY = (scaledH - screenSize.height) / 2;

    final screenX = x * scale - cropX;
    final screenY = y * scale - cropY;

    return cutoutRect.contains(Offset(screenX, screenY));
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

    final eyesClosed =
        leftOpen < LivenessThresholds.blinkClosedThreshold &&
        rightOpen < LivenessThresholds.blinkClosedThreshold;

    final eyesOpen =
        leftOpen > LivenessThresholds.blinkReopenThreshold &&
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