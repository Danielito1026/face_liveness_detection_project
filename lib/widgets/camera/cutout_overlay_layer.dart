import 'package:face_detect_trial/widgets/face_liveness/face_liveness_style.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Cutout overlay layer — dims outside the face frame + draws the border
// ---------------------------------------------------------------------------

class CutoutOverlayLayer extends StatelessWidget {
  final FaceLivenessStyle style;

  const CutoutOverlayLayer({super.key, required this.style});

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
