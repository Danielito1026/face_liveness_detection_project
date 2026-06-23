// face_liveness_widget.dart
// Location: lib/features/face/widgets/face_liveness_widget.dart
//
// Root widget for the face liveness verification flow.
// Self-contained: owns the CameraController, ChallengeValidator, and
// ChallengeDirector. All UI sub-widgets are driven from state here.
//
// Responsibilities:
//   - Initialize and dispose the front camera
//   - Initialize and dispose ChallengeValidator (ML Kit)
//   - Create and start ChallengeDirector with the given config
//   - Process camera frames and route results to the director
//   - Render: camera preview + cutout overlay + challenge UI + timer + dots
//   - Show UnsupportedDevicePrompt dialog on init failure
//   - Show SuccessFlash on each challenge pass
//   - Report onPass / onTimeout to the parent (FaceNotifier / FaceLivenessScreen)
//   - Register its own WidgetsBindingObserver to release camera on pause
//     (per architecture doc §11 — in addition to the root observer)
//
// No Riverpod inside this widget. No BuildContext held past frame boundaries.
// No routing calls. The parent decides what to do with onPass / onTimeout.
//
// ---------------------------------------------------------------------------
// Minimal usage (timekeeping app):
//
//   FaceLivenessWidget(
//     config: faceLivenessConfig,          // from backend via FaceNotifier
//     onPass: () => ref.read(faceNotifierProvider.notifier).submit(),
//     onTimeout: () => ref.read(faceNotifierProvider.notifier).onTimeout(),
//   )
//
// Usage with style overrides (another project):
//
//   FaceLivenessWidget(
//     config: faceLivenessConfig,
//     style: DetectionStyle.defaults().copyWith(
//       cutoutShape: RectCutout(borderRadius: 16),
//       frameBorderColor: Colors.blue,
//     ),
//     onPass: _handlePass,
//     onTimeout: _handleTimeout,
//     onUnsupportedDevice: _handleUnsupported,
//   )
//
// Usage with fully custom challenge overlay:
//
//   FaceLivenessWidget(
//     config: faceLivenessConfig,
//     onPass: _handlePass,
//     onTimeout: _handleTimeout,
//     challengeOverlayBuilder: (challenge) => MyCustomOverlay(challenge),
//   )
// ---------------------------------------------------------------------------

import 'dart:async';
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:face_detect_trial/widgets/camera/camera_input_stream.dart';
import 'package:face_detect_trial/widgets/camera/cutout_overlay_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'challenge_director.dart';
import 'challenge_overlay.dart';
import 'challenge_progress_dots.dart';
import 'challenge_validator.dart';
import 'face_liveness_config.dart';
import '../detection_styles/detection_style.dart';
import '../detection_styles/detection_theme.dart';
import 'liveness_challenge.dart';
import 'no_face_hint.dart';
import 'session_timer_bar.dart';
import 'unsupported_device_prompt.dart';

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class FaceLivenessWidget extends StatefulWidget {
  /// Behavior config — challenge sequence, randomization, timer duration.
  /// Typically sourced from the backend via FaceNotifier.
  final FaceLivenessConfig config;

  /// Visual style. Defaults to the timekeeping app's dark navy/crimson look.
  /// Use copyWith() to override individual values for other projects.
  final DetectionStyle style;

  /// Called when all challenges are passed within the session timer.
  /// Parent (FaceNotifier) should submit the session to the backend here.
  final VoidCallback onPass;

  /// Called when the session timer expires before all challenges are complete.
  /// Parent (FaceNotifier) should handle retry counting here.
  final VoidCallback onTimeout;

  /// Called when the front camera or ML Kit fails to initialize.
  /// Optional: if null, only the dialog's "Go Back" action is available.
  final VoidCallback? onUnsupportedDevice;

  /// Fully replaces the default ChallengeOverlay for a given challenge.
  /// Return null to fall back to the default overlay for that challenge.
  final Widget Function(LivenessChallenge challenge)? challengeOverlayBuilder;

  const FaceLivenessWidget({
    super.key,
    required this.config,
    this.style = const _DefaultStyle(),
    required this.onPass,
    required this.onTimeout,
    this.onUnsupportedDevice,
    this.challengeOverlayBuilder,
  });

  @override
  State<FaceLivenessWidget> createState() => _FaceLivenessWidgetState();
}

// ---------------------------------------------------------------------------
// Workaround: const default for style field
// ---------------------------------------------------------------------------

// DetectionStyle.defaults() is a factory, so it can't be a const default
// parameter. This private subclass bridges that gap cleanly.
class _DefaultStyle extends DetectionStyle {
  const _DefaultStyle()
    : super(
        cutoutShape: const OvalCutout(),
        cameraOverlayColor: DetectionColors.cameraOverlay,
        frameBorderColor: DetectionColors.crimson,
        frameBorderWidth: CutoutDefaults.frameBorderWidth,
        overlayPanelColor: DetectionColors.glassFill,
        overlayPanelBorderColor: DetectionColors.glassBorder,
        challengeIconColor: DetectionColors.crimsonLight,
        challengeIconSize: 36,
        instructionTextStyle: DetectionTextStyles.challengeInstruction,
        subtitleTextStyle: DetectionTextStyles.challengeSubtitle,
        timerBarActiveColor: DetectionColors.timerActive,
        timerBarWarningColor: DetectionColors.timerWarning,
        timerBarTrackColor: DetectionColors.timerTrack,
        timerBarHeight: DetectionTheme.timerBarHeight,
        dotCompleteColor: DetectionColors.dotComplete,
        dotActiveColor: DetectionColors.dotActive,
        dotInactiveColor: DetectionColors.dotInactive,
        dotSize: DetectionTheme.dotSize,
        dialogBackgroundColor: DetectionColors.dialogBackground,
        dialogBorderColor: DetectionColors.dialogBorder,
        dialogTitleStyle: DetectionTextStyles.dialogTitle,
        dialogBodyStyle: DetectionTextStyles.dialogBody,
        dialogButtonStyle: DetectionTextStyles.dialogButton,
        noFaceHintBackgroundColor: DetectionColors.dialogBackground,
        noFaceHintTextStyle: DetectionTextStyles.challengeSubtitle,
        noFaceHintIcon: Icons.face_retouching_off_outlined,
        noFaceHintMessage: 'No face detected. Center your face in the frame.',
      );
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _FaceLivenessWidgetState extends State<FaceLivenessWidget> {
  // --- Camera ---
  // Camera ownership lives in CameraInputStream; this key lets us call
  // pauseStream()/resumeStream() on it when the session completes.
  final _cameraKey = GlobalKey<CameraInputStreamState>();

  // --- Logic ---
  late final ChallengeValidator _validator;
  late ChallengeDirector _director;

  // --- Stream subscriptions ---
  StreamSubscription<ChallengeDirectorState>? _stateSub;
  StreamSubscription<double>? _timerSub;
  StreamSubscription<bool>? _noFaceSub;

  // --- UI state ---
  ChallengeDirectorState? _directorState;
  double _timerProgress = 1.0;
  bool _showSuccessFlash = false;
  bool _noFaceHintVisible = false;

  // --- Frame processing gate ---
  // Prevents overlapping async frame evaluations
  bool _isProcessingFrame = false;
  bool _sessionComplete = false;
  bool _validatorReady = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initValidator();
    _initDirector();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _timerSub?.cancel();
    _noFaceSub?.cancel();
    _director.dispose();
    _validator.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Init: validator
  // ---------------------------------------------------------------------------

  Future<void> _initValidator() async {
    _validator = ChallengeValidator();
    await _validator.initialize();
    _validatorReady = true;
  }

  // ---------------------------------------------------------------------------
  // Init: director
  // ---------------------------------------------------------------------------

  void _initDirector() {
    _director = ChallengeDirector(config: widget.config);

    _stateSub = _director.stateStream.listen(_onDirectorState);
    _timerSub = _director.timerProgressStream.listen(_onTimerProgress);
    _noFaceSub = _director.noFaceDetectedStream.listen(_onNoFaceChanged);

    _director.start();
  }

  // ---------------------------------------------------------------------------
  // Director stream handlers
  // ---------------------------------------------------------------------------

  void _onDirectorState(ChallengeDirectorState state) {
    if (!mounted) return;

    // Reset blink state when a blink challenge becomes active
    if (!state.isComplete && state.activeChallenge == LivenessChallenge.blink) {
      _validator.resetBlinkState();
    }

    // Clear stale no-face hint on challenge advance — give the new
    // challenge a fresh debounce window.
    if (!state.isComplete && _noFaceHintVisible) {
      _noFaceHintVisible = false;
    }

    if (state.isComplete) {
      _sessionComplete = true;
      _cameraKey.currentState?.pauseStream();

      if (state.result == LivenessSessionResult.pass) {
        // Brief delay lets the success flash finish before notifying parent
        Future.delayed(DetectionTheme.successFlashDuration, () {
          if (mounted) widget.onPass();
        });
      } else {
        widget.onTimeout();
      }
    }

    setState(() => _directorState = state);
  }

  void _onTimerProgress(double progress) {
    if (!mounted) return;
    setState(() => _timerProgress = progress);
  }

  void _onNoFaceChanged(bool noFaceDetected) {
    if (!mounted) return;
    setState(() => _noFaceHintVisible = noFaceDetected);
  }

  // ---------------------------------------------------------------------------
  // Frame processing
  // ---------------------------------------------------------------------------

  /// Called by CameraInputStream for every frame, already converted to InputImage.
  /// This widget owns the "is processing" gate — CameraInputStream doesn't throttle.
  void _onImage(InputImage inputImage) {
    if (_isProcessingFrame || _sessionComplete || !mounted) return;
    if (_directorState == null || _directorState!.isComplete) return;
    if (!_validatorReady) return; // validator still initializing

    _isProcessingFrame = true;
    _processFrame(inputImage).whenComplete(() => _isProcessingFrame = false);
  }

  Future<void> _processFrame(InputImage inputImage) async {
    try {
      final result = await _validator.evaluate(
        image: inputImage,
        challenge: _directorState!.activeChallenge,
      );

      // Report presence/absence so the director can debounce the
      // "no face detected" hint. `error` frames are treated as neutral
      // (not reported) — a single bad frame shouldn't trigger the hint.
      if (result == ChallengeResult.noFace) {
        _director.reportFaceDetected(false);
      } else if (result != ChallengeResult.error) {
        _director.reportFaceDetected(true);
      }

      if (result == ChallengeResult.pass) {
        await _onChallengePass();
      }
    } catch (_) {
      // Swallow frame errors silently — next frame will retry
    }
  }

  Future<void> _onChallengePass() async {
    if (!mounted || _sessionComplete) return;

    // Show success flash
    setState(() => _showSuccessFlash = true);
    await Future.delayed(DetectionTheme.successFlashDuration);

    if (!mounted) return;
    setState(() => _showSuccessFlash = false);

    // Advance director to next challenge (or emit pass if last)
    _director.onChallengePass();
  }

  // ---------------------------------------------------------------------------
  // Init failure → unsupported device dialog
  // ---------------------------------------------------------------------------

  void _handleInitFailure() {
    if (!mounted) return;
    // Post-frame so dialog shows after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showUnsupportedDeviceDialog(
        context: context,
        style: widget.style,
        onGoBack: () {
          Navigator.of(context).pop(); // close dialog
          widget.onUnsupportedDevice?.call();
        },
        onContactHR: widget.onUnsupportedDevice != null
            ? () {
                Navigator.of(context).pop();
                widget.onUnsupportedDevice?.call();
              }
            : null,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar icons on dark bg
      child: ColoredBox(
        color: DetectionColors.navyDark,
        child: CameraInputStream(
          key: _cameraKey,
          lensDirection: CameraLensDirection.front,
          onImage: _onImage,
          onInitFailure: _handleInitFailure,
          loadingWidget: _buildLoadingView(),
          overlayBuilder: _buildOverlay,
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: DetectionColors.crimson,
        strokeWidth: 2.5,
      ),
    );
  }

  /// Everything drawn on top of the live camera preview:
  /// cutout dim/border, success flash, no-face hint, challenge UI.
  Widget _buildOverlay(BuildContext context) {
    final state = _directorState;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cutout overlay — dims everything outside the face frame
        CutoutOverlayLayer(style: widget.style),

        // Success flash — brief green tint on challenge pass
        SuccessFlash(visible: _showSuccessFlash),

        // "No face detected" hint — debounced, shown over the cutout
        if (state != null && !state.isComplete)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: NoFaceHint(
                visible: _noFaceHintVisible,
                style: widget.style,
              ),
            ),
          ),

        // Challenge UI — timer bar, progress dots, overlay panel
        if (state != null && !state.isComplete)
          _ChallengeUiLayer(
            directorState: state,
            timerProgress: _timerProgress,
            style: widget.style,
            challengeOverlayBuilder: widget.challengeOverlayBuilder,
          ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Challenge UI layer — overlaid on the camera at the bottom
// ---------------------------------------------------------------------------

class _ChallengeUiLayer extends StatelessWidget {
  final ChallengeDirectorState directorState;
  final double timerProgress;
  final DetectionStyle style;
  final Widget Function(LivenessChallenge)? challengeOverlayBuilder;

  const _ChallengeUiLayer({
    required this.directorState,
    required this.timerProgress,
    required this.style,
    this.challengeOverlayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timer bar (full width)
              SessionTimerBar(progress: timerProgress, style: style),

              const SizedBox(height: 14),

              // Progress dots (centered)
              ChallengeProgressDots(
                totalChallenges: directorState.totalChallenges,
                completedCount: directorState.completedCount,
                activeIndex: directorState.activeIndex,
                style: style,
              ),

              const SizedBox(height: 16),

              // Challenge overlay panel
              _buildOverlay(directorState.activeChallenge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(LivenessChallenge challenge) {
    // Use custom builder if provided, fall back to default
    final custom = challengeOverlayBuilder?.call(challenge);
    if (custom != null) return custom;

    return ChallengeOverlay(challenge: challenge, style: style);
  }
}
