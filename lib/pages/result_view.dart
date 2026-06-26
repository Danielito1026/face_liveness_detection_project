import 'package:face_detect_trial/widgets/detection_styles/detection_theme.dart';
import 'package:flutter/material.dart';

class ResultView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? content;

  const ResultView({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 20),
            Text(
              title,
              style: DetectionTextStyles.dialogTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: DetectionTextStyles.dialogBody,
              textAlign: TextAlign.center,
            ),
            if (content != null) ...[const SizedBox(height: 12), content!],
            const SizedBox(height: 32),
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
