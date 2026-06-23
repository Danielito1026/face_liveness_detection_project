// qr_scanner_widget.dart
// Location: lib/shared/widgets/qr_scanner_widget.dart
//
// QR code scanner widget built on top of CameraInputStream.
// Uses google_mlkit_barcode_scanning to decode QR codes from the camera feed.
//
// Responsibilities:
//   - Wire CameraInputStream (back camera) to BarcodeScanner
//   - Gate frames with _isProcessing to avoid overlapping ML Kit calls
//   - Emit the first decoded barcode via [onBarcodeDetected]
//   - Lock after first detection so the caller can navigate away cleanly
//   - Draw the QR frame cutout overlay via CutoutOverlayLayer
//
// This widget does NOT:
//   - Navigate anywhere — that's the caller's job (QrScannerPage)
//   - Know what a URL, vCard, or WiFi payload means — it just emits the raw value
//
// ---------------------------------------------------------------------------
// Usage:
//
//   QrScannerWidget(
//     onBarcodeDetected: (barcode) {
//       Navigator.push(context, MaterialPageRoute(
//         builder: (_) => QrResultPage(barcode: barcode),
//       ));
//     },
//   )
// ---------------------------------------------------------------------------

import 'package:camera/camera.dart';
import 'package:face_detect_trial/widgets/camera/camera_input_stream.dart';
import 'package:face_detect_trial/widgets/camera/cutout_overlay_layer.dart';
import 'package:face_detect_trial/widgets/detection_styles/detection_style.dart';
import 'package:face_detect_trial/widgets/detection_styles/detection_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class QrScannerWidget extends StatefulWidget {
  /// Called once when a QR code (or other barcode) is successfully decoded.
  /// After this fires, the scanner locks and stops processing frames until
  /// the widget is disposed or [reset] is called on the state key.
  final void Function(Barcode barcode) onBarcodeDetected;

  /// Optional style. Defaults to a rect cutout variant of DetectionStyle.defaults().
  final DetectionStyle? style;

  /// Optional callback if the camera fails to initialize.
  final VoidCallback? onInitFailure;

  const QrScannerWidget({
    super.key,
    required this.onBarcodeDetected,
    this.style,
    this.onInitFailure,
  });

  @override
  State<QrScannerWidget> createState() => QrScannerWidgetState();
}

class QrScannerWidgetState extends State<QrScannerWidget> {
  final BarcodeScanner _scanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  bool _locked = false; // true after first successful scan

  DetectionStyle get _style =>
      widget.style ??
      DetectionStyle.defaults().copyWith(
        // Square-ish rect cutout is more natural for QR codes
        cutoutShape: const RectCutout(
          widthFactor: 0.75,
          heightFactor: 0.40,
          borderRadius: CutoutDefaults.rectBorderRadius,
        ),
        frameBorderColor: DetectionColors.crimson,
        frameBorderWidth: 3.0,
      );

  /// Unlocks the scanner so it processes frames again.
  /// Call this if the result page is dismissed and you want to re-scan.
  void reset() {
    setState(() => _locked = false);
  }

  @override
  void dispose() {
    _scanner.close();
    super.dispose();
  }

  Future<void> _processFrame(InputImage inputImage) async {
    if (_isProcessing || _locked) return;
    _isProcessing = true;

    try {
      final barcodes = await _scanner.processImage(inputImage);
      if (_locked) return; // double-check after async gap

      if (barcodes.isNotEmpty) {
        _locked = true;
        widget.onBarcodeDetected(barcodes.first);
      }
    } catch (_) {
      // Swallow per-frame errors — camera keeps running
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CameraInputStream(
      lensDirection: CameraLensDirection.back,
      onImage: _processFrame,
      onInitFailure: widget.onInitFailure,
      overlayBuilder: (ctx) => _QrOverlay(style: _style),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay — cutout + scan line animation + hint label
// ---------------------------------------------------------------------------

class _QrOverlay extends StatefulWidget {
  final DetectionStyle style;

  const _QrOverlay({required this.style});

  @override
  State<_QrOverlay> createState() => _QrOverlayState();
}

class _QrOverlayState extends State<_QrOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLine = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim layer + rect cutout border
        CutoutOverlayLayer(style: widget.style),

        // Animated scan line inside the cutout
        AnimatedBuilder(
          animation: _scanLine,
          builder: (context, _) {
            return _ScanLine(style: widget.style, progress: _scanLine.value);
          },
        ),

        // Hint label at the bottom
        Positioned(
          bottom: 56,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.style.overlayPanelColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.style.overlayPanelBorderColor,
                  width: 1,
                ),
              ),
              child: Text(
                'Point your camera at a QR code',
                style: widget.style.subtitleTextStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Draws a horizontal scan line that sits inside the cutout rect
class _ScanLine extends StatelessWidget {
  final DetectionStyle style;
  final double progress; // 0.0 → 1.0 within the cutout height

  const _ScanLine({required this.style, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shape = style.cutoutShape as RectCutout;
        final cutoutW = constraints.maxWidth * shape.widthFactor;
        final cutoutH = constraints.maxHeight * shape.heightFactor;
        final left = (constraints.maxWidth - cutoutW) / 2;
        // Mirror the vertical offset used in the painter (0.42 of screen height)
        final cutoutTop = constraints.maxHeight * 0.42 - cutoutH / 2;
        final lineY = cutoutTop + cutoutH * progress;

        return Positioned(
          top: lineY,
          left: left + 4,
          child: Container(
            width: cutoutW - 8,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  style.frameBorderColor.withValues(alpha: 0.8),
                  style.frameBorderColor,
                  style.frameBorderColor.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
