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
//     style: FaceLivenessStyle.defaults().copyWith(
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
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'challenge_director.dart';
import 'challenge_overlay.dart';
import 'challenge_progress_dots.dart';
import 'challenge_validator.dart';
import 'face_liveness_config.dart';
import 'face_liveness_style.dart';
import 'face_liveness_theme.dart';
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
  final FaceLivenessStyle style;

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

// FaceLivenessStyle.defaults() is a factory, so it can't be a const default
// parameter. This private subclass bridges that gap cleanly.
class _DefaultStyle extends FaceLivenessStyle {
  const _DefaultStyle()
    : super(
        cutoutShape: const OvalCutout(),
        cameraOverlayColor: FaceLivenessColors.cameraOverlay,
        frameBorderColor: FaceLivenessColors.crimson,
        frameBorderWidth: FaceLivenessTheme.frameBorderWidth,
        overlayPanelColor: FaceLivenessColors.glassFill,
        overlayPanelBorderColor: FaceLivenessColors.glassBorder,
        challengeIconColor: FaceLivenessColors.crimsonLight,
        challengeIconSize: 36,
        instructionTextStyle: FaceLivenessTextStyles.challengeInstruction,
        subtitleTextStyle: FaceLivenessTextStyles.challengeSubtitle,
        timerBarActiveColor: FaceLivenessColors.timerActive,
        timerBarWarningColor: FaceLivenessColors.timerWarning,
        timerBarTrackColor: FaceLivenessColors.timerTrack,
        timerBarHeight: FaceLivenessTheme.timerBarHeight,
        dotCompleteColor: FaceLivenessColors.dotComplete,
        dotActiveColor: FaceLivenessColors.dotActive,
        dotInactiveColor: FaceLivenessColors.dotInactive,
        dotSize: FaceLivenessTheme.dotSize,
        dialogBackgroundColor: FaceLivenessColors.dialogBackground,
        dialogBorderColor: FaceLivenessColors.dialogBorder,
        dialogTitleStyle: FaceLivenessTextStyles.dialogTitle,
        dialogBodyStyle: FaceLivenessTextStyles.dialogBody,
        dialogButtonStyle: FaceLivenessTextStyles.dialogButton,
        noFaceHintBackgroundColor: FaceLivenessColors.dialogBackground,
        noFaceHintTextStyle: FaceLivenessTextStyles.challengeSubtitle,
        noFaceHintIcon: Icons.face_retouching_off_outlined,
        noFaceHintMessage: 'No face detected. Center your face in the frame.',
      );
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _FaceLivenessWidgetState extends State<FaceLivenessWidget>
    with WidgetsBindingObserver {
  // --- Camera ---
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

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

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initValidator();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSub?.cancel();
    _timerSub?.cancel();
    _noFaceSub?.cancel();
    _director.dispose();
    _validator.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // App lifecycle — camera resource cleanup on pause (architecture doc §11)
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _releaseCamera();
      _director.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Init: validator
  // ---------------------------------------------------------------------------

  Future<void> _initValidator() async {
    _validator = ChallengeValidator();
    await _validator.initialize();
  }

  // ---------------------------------------------------------------------------
  // Init: camera
  // ---------------------------------------------------------------------------

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      // Find front camera
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw CameraException(
          'NoCameraFound',
          'No front camera available on this device.',
        ),
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset
            .medium, // medium: good balance of detection quality + perf
        enableAudio: false,
        imageFormatGroup:
            ImageFormatGroup.nv21, // required for ML Kit on Android
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });

      // Camera ready — now start the director and frame stream
      _initDirector();
      _startImageStream();
    } catch (e) {
      _handleInitFailure();
    }
  }

  void _releaseCamera() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
    if (mounted) setState(() => _isCameraInitialized = false);
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
      _cameraController?.stopImageStream();

      if (state.result == LivenessSessionResult.pass) {
        // Brief delay lets the success flash finish before notifying parent
        Future.delayed(FaceLivenessTheme.successFlashDuration, () {
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

  void _startImageStream() {
    _cameraController?.startImageStream(_onCameraFrame);
  }

  void _onCameraFrame(CameraImage cameraImage) {
    // Drop frames if: already processing, session done, or widget gone
    if (_isProcessingFrame || _sessionComplete || !mounted) return;
    if (_directorState == null || _directorState!.isComplete) return;

    _isProcessingFrame = true;
    _processFrame(cameraImage).whenComplete(() => _isProcessingFrame = false);
  }

  Future<void> _processFrame(CameraImage cameraImage) async {
    try {
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) return;

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
    await Future.delayed(FaceLivenessTheme.successFlashDuration);

    if (!mounted) return;
    setState(() => _showSuccessFlash = false);

    // Advance director to next challenge (or emit pass if last)
    _director.onChallengePass();
  }

  // ---------------------------------------------------------------------------
  // InputImage construction
  // ---------------------------------------------------------------------------

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    // Determine rotation based on camera sensor orientation
    final rotation = _sensorRotation(camera.sensorOrientation);

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _sensorRotation(int sensorOrientation) {
    return switch (sensorOrientation) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
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
        color: FaceLivenessColors.navyDark,
        child: _isCameraInitialized
            ? _buildLivenessView()
            : _buildLoadingView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: FaceLivenessColors.crimson,
        strokeWidth: 2.5,
      ),
    );
  }

  Widget _buildLivenessView() {
    final state = _directorState;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera preview (full screen)
        _CameraPreviewLayer(controller: _cameraController!),

        // 2. Cutout overlay — dims everything outside the face frame
        _CutoutOverlayLayer(style: widget.style),

        // 3. Success flash — brief green tint on challenge pass
        SuccessFlash(visible: _showSuccessFlash),

        // 4. "No face detected" hint — debounced, shown over the cutout
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

        // 5. Challenge UI — timer bar, progress dots, overlay panel
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
// Camera preview layer
// ---------------------------------------------------------------------------

class _CameraPreviewLayer extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cutout overlay layer — dims outside the face frame + draws the border
// ---------------------------------------------------------------------------

class _CutoutOverlayLayer extends StatelessWidget {
  final FaceLivenessStyle style;

  const _CutoutOverlayLayer({required this.style});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CutoutPainter(style: style),
      child: const SizedBox.expand(),
    );
  }
}

class _CutoutPainter extends CustomPainter {
  final FaceLivenessStyle style;

  const _CutoutPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final shape = style.cutoutShape;

    final cutoutWidth =
        size.width *
        (shape is OvalCutout
            ? shape.widthFactor
            : (shape as RectCutout).widthFactor);
    final cutoutHeight =
        size.height *
        (shape is OvalCutout
            ? shape.heightFactor
            : (shape as RectCutout).heightFactor);

    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: cutoutWidth,
      height: cutoutHeight,
    );

    // --- Dim overlay path (full screen minus cutout) ---
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = _buildCutoutPath(shape, cutoutRect);
    final dimPath = Path.combine(
      PathOperation.difference,
      overlayPath,
      cutoutPath,
    );

    canvas.drawPath(dimPath, Paint()..color = style.cameraOverlayColor);

    // --- Frame border ---
    canvas.drawPath(
      cutoutPath,
      Paint()
        ..color = style.frameBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.frameBorderWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  Path _buildCutoutPath(CutoutShape shape, Rect rect) {
    return switch (shape) {
      OvalCutout() => Path()..addOval(rect),
      RectCutout(borderRadius: final r) =>
        Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r))),
    };
  }

  @override
  bool shouldRepaint(_CutoutPainter oldDelegate) =>
      oldDelegate.style.cutoutShape != oldDelegate.style.cutoutShape ||
      oldDelegate.style.cameraOverlayColor != style.cameraOverlayColor ||
      oldDelegate.style.frameBorderColor != style.frameBorderColor;
}

// ---------------------------------------------------------------------------
// Challenge UI layer — overlaid on the camera at the bottom
// ---------------------------------------------------------------------------

class _ChallengeUiLayer extends StatelessWidget {
  final ChallengeDirectorState directorState;
  final double timerProgress;
  final FaceLivenessStyle style;
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
