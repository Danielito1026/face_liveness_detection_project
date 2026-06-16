// camera_input_stream.dart
// Location: lib/shared/widgets/camera_input_stream.dart
//
// Reusable camera widget for any ML Kit-based feature (face liveness,
// barcode scanning, document scanning, etc).
//
// Responsibilities:
//   - Acquire and initialize a CameraController for the requested lens
//   - Render the live preview, scaled to fill its bounds (BoxFit.cover)
//   - Stream camera frames, convert each to an InputImage, and emit via [onImage]
//   - Handle pause/resume lifecycle (stops/restarts the image stream)
//   - Report init failure via [onInitFailure] — caller decides what UI to show
//
// This widget does NOT know about:
//   - Face detection, barcode scanning, or any ML Kit processor
//   - Challenges, sequencing, or business logic
//   - Cutout shapes or any overlay UI — those are drawn by the parent on top
//
// Frame throttling / "is processing" gating is the CALLER's responsibility
// (different consumers have different processing costs — face liveness runs
// ML Kit face detection per frame, a barcode scanner might too, but a raw
// preview-only consumer wouldn't need any gating at all).
//
// ---------------------------------------------------------------------------
// Usage — face liveness:
//
//   CameraInputStream(
//     lensDirection: CameraLensDirection.front,
//     onImage: (inputImage) => _processFaceFrame(inputImage),
//     onInitFailure: () => _showUnsupportedDeviceDialog(),
//     overlayBuilder: (context) => _CutoutOverlayLayer(style: style),
//   )
//
// Usage — future barcode scanner:
//
//   CameraInputStream(
//     lensDirection: CameraLensDirection.back,
//     onImage: (inputImage) => _processBarcodeFrame(inputImage),
//     onInitFailure: () => _showCameraErrorDialog(),
//   )
// ---------------------------------------------------------------------------

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart'
    show InputImage, InputImageMetadata, InputImageRotation, InputImageFormatValue;

class CameraInputStream extends StatefulWidget {
  /// Which camera to use. Front for face liveness, back for barcode/document scanning.
  final CameraLensDirection lensDirection;

  /// Resolution preset. Medium is a good balance for ML Kit detection + perf.
  /// Higher presets may improve barcode/small-text detection at a perf cost.
  final ResolutionPreset resolutionPreset;

  /// Called for every camera frame, converted to an [InputImage].
  /// The caller is responsible for any throttling/gating — this widget
  /// emits as fast as the camera produces frames.
  final void Function(InputImage image) onImage;

  /// Called if the camera fails to initialize (no camera found, permission
  /// denied at the platform level, controller init exception, etc).
  /// The caller decides what UI to show (dialog, full-screen message, etc).
  final VoidCallback? onInitFailure;

  /// Optional builder for overlay content drawn on top of the preview
  /// (cutout shapes, frame guides, etc). Receives the same BuildContext
  /// so it can read theme/MediaQuery if needed.
  final WidgetBuilder? overlayBuilder;

  /// Widget shown while the camera is initializing.
  /// Defaults to a centered CircularProgressIndicator.
  final Widget? loadingWidget;

  const CameraInputStream({
    super.key,
    required this.lensDirection,
    required this.onImage,
    this.resolutionPreset = ResolutionPreset.medium,
    this.onInitFailure,
    this.overlayBuilder,
    this.loadingWidget,
  });

  @override
  State<CameraInputStream> createState() => CameraInputStreamState();
}

class CameraInputStreamState extends State<CameraInputStream>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed) {
      _resumeStream();
    }
  }

  // ---------------------------------------------------------------------------
  // Camera lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == widget.lensDirection,
        orElse: () => throw CameraException(
          'NoCameraFound',
          'No camera matching ${widget.lensDirection} found on this device.',
        ),
      );

      final controller = CameraController(
        camera,
        widget.resolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // required for ML Kit on Android
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
      });

      _startStream();
    } catch (_) {
      widget.onInitFailure?.call();
    }
  }

  void _startStream() {
    final controller = _controller;
    if (controller == null || _isStreaming) return;

    controller.startImageStream(_onFrame);
    _isStreaming = true;
  }

  void _stopStream() {
    final controller = _controller;
    if (controller == null || !_isStreaming) return;

    controller.stopImageStream();
    _isStreaming = false;
  }

  void _resumeStream() {
    if (!_isInitialized) return;
    _startStream();
  }

  /// Stops the image stream without disposing the controller.
  /// Exposed for callers that want to pause frame processing (e.g. when
  /// the session completes) without tearing down the preview.
  void pauseStream() => _stopStream();

  /// Resumes a previously paused stream.
  void resumeStream() => _startStream();

  // ---------------------------------------------------------------------------
  // Frame conversion
  // ---------------------------------------------------------------------------

  void _onFrame(CameraImage image) {
    final inputImage = _buildInputImage(image);
    if (inputImage != null) widget.onImage(inputImage);
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _controller?.description;
    if (camera == null) return null;

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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (!_isInitialized || controller == null) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _CameraPreview(controller: controller),
        if (widget.overlayBuilder != null) widget.overlayBuilder!(context),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Preview — scaled to fill bounds
// ---------------------------------------------------------------------------

class _CameraPreview extends StatelessWidget {
  final CameraController controller;

  const _CameraPreview({required this.controller});

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