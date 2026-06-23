# Camera Widget Files

This folder contains reusable camera widgets used by face liveness and other ML Kit features.

## Files

- `camera_input_stream.dart`
  - A reusable camera preview and image stream widget.
  - Initializes the requested camera lens, starts an image stream, and converts frames to `InputImage` for ML Kit.
  - Handles app lifecycle pause/resume and reports initialization failure.
  - Sample usage:
    ```dart
    CameraInputStream(
      lensDirection: CameraLensDirection.front,
      onImage: (inputImage) => _processFaceFrame(inputImage),
      onInitFailure: () => _showUnsupportedDeviceDialog(),
      overlayBuilder: (context) => CutoutOverlayLayer(style: detectionStyle),
    )
    ```

- `cutout_overlay_layer.dart`
  - Draws the camera cutout overlay used to focus the user's face on screen.
  - Dims the area outside the cutout and paints a stylized border around the active region.
  - Uses `DetectionStyle` for colors, frame border, and cutout shape.
  - Sample usage:
    ```dart
    CutoutOverlayLayer(style: detectionStyle)
    ```

- `unsupported_device_prompt.dart`
  - Displays a modal dialog when the camera or ML Kit initialization fails.
  - Provides a mandatory "Go Back" action and optionally shows a secondary support action.
  - Styled with `DetectionStyle` and blocks dismissal by tapping outside.
  - Sample usage:
    ```dart
    showUnsupportedDeviceDialog(
      context: context,
      style: detectionStyle,
      onGoBack: () => Navigator.of(context).pop(),
      onContactHR: () => launchUrl(hrContactUri),
    );
    ```

## Purpose

These files provide the camera input, overlay, and unsupported-device handling building blocks for the face liveness experience.
