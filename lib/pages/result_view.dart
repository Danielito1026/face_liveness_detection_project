import 'package:face_detect_trial/widgets/face_liveness/face_liveness_theme.dart';
import 'package:flutter/material.dart';

class ResultView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const ResultView({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
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
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 20),
            Text(
              title,
              style: FaceLivenessTextStyles.dialogTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: FaceLivenessTextStyles.dialogBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FaceLivenessColors.crimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: FaceLivenessTextStyles.dialogButton.copyWith(
                    color: FaceLivenessColors.white,
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

