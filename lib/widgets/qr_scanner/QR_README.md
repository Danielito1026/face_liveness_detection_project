# QR Scanner Widget

This folder contains the QR scanner widget used to decode QR codes from the camera feed.

## Files

- `qr_scanner_widget.dart`
  - A full QR code scanning widget built on top of `CameraInputStream`.
  - Uses ML Kit `BarcodeScanner` to decode QR codes from camera frames.
  - Handles frame gating to avoid overlapping ML Kit calls and locks after the first successful scan.
  - Draws a custom QR overlay with a scan line and instructions.
  - Sample usage:
    ```dart
    QrScannerWidget(
      onBarcodeDetected: (barcode) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QrResultPage(barcode: barcode),
          ),
        );
      },
      onInitFailure: () {
        // Show an error message or fallback UI
      },
    );
    ```

## Purpose

This widget provides a reusable QR scanning experience that emits decoded barcode values while keeping the camera input and overlay presentation self-contained.
