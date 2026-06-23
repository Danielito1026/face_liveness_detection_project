// unsupported_device_prompt.dart
// Location: lib/features/face/widgets/unsupported_device_prompt.dart
//
// Shows a modal dialog when the front camera or ML Kit fails to initialize.
// This is a hard block — the face step cannot proceed.
//
// Design decisions:
//   - A function, not a Widget subclass. Called via showUnsupportedDeviceDialog()
//     from FaceLivenessWidget's initState error handler.
//   - Fully style-driven via DetectionStyle — colors, text styles, button style.
//   - Not dismissible by tapping outside (barrierDismissible: false).
//     User must explicitly tap the action button.
//   - Supports an optional [onContactHR] callback. If provided, a "Contact HR"
//     button is shown. If null, only a "Go Back" button appears.
//
// Usage:
//   showUnsupportedDeviceDialog(
//     context: context,
//     style: widget.style,
//     onGoBack: () => context.pop(),
//     onContactHR: () => launchUrl(hrContactUri),  // optional
//   );

import 'package:flutter/material.dart';
import '../detection_styles/detection_style.dart';
import '../detection_styles/detection_theme.dart';

/// Shows the unsupported device dialog.
///
/// [onGoBack] is always shown — navigates away from the face step.
/// [onContactHR] is optional — if provided, a secondary "Contact HR" action
/// is shown so the user knows how to resolve the issue.
void showUnsupportedDeviceDialog({
  required BuildContext context,
  required DetectionStyle style,
  required VoidCallback onGoBack,
  VoidCallback? onContactHR,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC000000),
    builder: (_) => _UnsupportedDeviceDialog(
      style: style,
      onGoBack: onGoBack,
      onContactHR: onContactHR,
    ),
  );
}

// ---------------------------------------------------------------------------
// Dialog widget (private)
// ---------------------------------------------------------------------------

class _UnsupportedDeviceDialog extends StatelessWidget {
  final DetectionStyle style;
  final VoidCallback onGoBack;
  final VoidCallback? onContactHR;

  const _UnsupportedDeviceDialog({
    required this.style,
    required this.onGoBack,
    this.onContactHR,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: _DialogContent(
        style: style,
        onGoBack: onGoBack,
        onContactHR: onContactHR,
      ),
    );
  }
}

class _DialogContent extends StatelessWidget {
  final DetectionStyle style;
  final VoidCallback onGoBack;
  final VoidCallback? onContactHR;

  const _DialogContent({
    required this.style,
    required this.onGoBack,
    this.onContactHR,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: style.dialogBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: style.dialogBorderColor,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogIcon(style: style),
          const SizedBox(height: 20),
          _DialogTitle(style: style),
          const SizedBox(height: 12),
          _DialogBody(style: style),
          const SizedBox(height: 28),
          _DialogActions(
            style: style,
            onGoBack: onGoBack,
            onContactHR: onContactHR,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

class _DialogIcon extends StatelessWidget {
  final DetectionStyle style;

  const _DialogIcon({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DetectionColors.crimsonGlow,
        border: Border.all(
          color: DetectionColors.crimson.withValues(alpha:0.4),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.no_photography_outlined,
        size: 30,
        color: DetectionColors.crimsonLight,
      ),
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final DetectionStyle style;

  const _DialogTitle({required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Camera Unavailable',
      style: style.dialogTitleStyle,
      textAlign: TextAlign.center,
    );
  }
}

class _DialogBody extends StatelessWidget {
  final DetectionStyle style;

  const _DialogBody({required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Face verification requires a working front camera. '
      'Your device may not support this feature, or camera '
      'access was denied.',
      style: style.dialogBodyStyle,
      textAlign: TextAlign.center,
    );
  }
}

class _DialogActions extends StatelessWidget {
  final DetectionStyle style;
  final VoidCallback onGoBack;
  final VoidCallback? onContactHR;

  const _DialogActions({
    required this.style,
    required this.onGoBack,
    this.onContactHR,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary: Go Back
        _DialogButton(
          label: 'Go Back',
          style: style,
          isPrimary: true,
          onTap: onGoBack,
        ),

        // Secondary: Contact HR (only shown if callback provided)
        if (onContactHR != null) ...[
          const SizedBox(height: 10),
          _DialogButton(
            label: 'Contact HR',
            style: style,
            isPrimary: false,
            onTap: onContactHR!,
          ),
        ],
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final DetectionStyle style;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.style,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: DetectionColors.crimson,
            foregroundColor: DetectionColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: style.dialogButtonStyle.copyWith(
              color: DetectionColors.white,
            ),
          ),
        ),
      );
    }

    // Secondary button — ghost/outlined style
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: DetectionColors.crimsonLight,
          side: BorderSide(
            color: DetectionColors.crimson.withValues(alpha:0.5),
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: style.dialogButtonStyle),
      ),
    );
  }
}