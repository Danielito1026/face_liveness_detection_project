# Detection Styles

This folder contains styling configuration and theme constants for the face liveness widgets.

## Files

- `detection_style.dart`
  - Defines `DetectionStyle`, a complete style model for the face liveness UI.
  - Includes camera cutout shape types: `OvalCutout` and `RectCutout`.
  - Controls colors, text styles, icon sizes, timer bar appearance, progress dot appearance, dialog styles, and the no-face hint.
  - Supports per-challenge display overrides via `challengeDisplayMap`.
  - Sample usage:
    ```dart
    final style = DetectionStyle.defaults().copyWith(
      frameBorderColor: Colors.blue,
      cutoutShape: RectCutout(borderRadius: 18),
      noFaceHintMessage: 'Please bring your face into view.',
    );

    FaceLivenessWidget(
      config: config,
      style: style,
      onPass: _handlePass,
      onTimeout: _handleTimeout,
    );
    ```

- `detection_theme.dart`
  - Provides default color palette and text styles used by the liveness widgets.
  - Defines `DetectionTheme` constants such as default challenge display data, timer bar height, dot size, and animation durations.
  - Defines `CutoutDefaults` for cutout dimensions and frame border width.
  - Sample usage:
    ```dart
    final displayConfig = DetectionTheme.challengeDisplayDefaults[
      LivenessChallenge.smile,
    ];
    ```

## Purpose

These files centralize the visual design system for the face liveness flow, making it easy to apply a consistent default look or customize the appearance for other projects.
