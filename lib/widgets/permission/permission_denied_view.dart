import 'package:flutter/material.dart';
import 'package:face_detect_trial/widgets/detection_styles/detection_theme.dart';

class PermissionDeniedView extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const PermissionDeniedView({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: DetectionColors.crimson,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: DetectionTextStyles.dialogBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DetectionColors.crimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: DetectionTextStyles.dialogButton.copyWith(
                    color: DetectionColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
