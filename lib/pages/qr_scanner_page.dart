// qr_scanner_page.dart
// Location: lib/features/qr_scanner/qr_scanner_page.dart
//
// Full-screen QR scanner page.
// Hosts QrScannerWidget and navigates to QrResultPage on a successful scan.
// After returning from the result page, the scanner resets and is ready again.

import 'package:face_detect_trial/pages/qr_result_page.dart';
import 'package:face_detect_trial/widgets/camera/unsupported_device_prompt.dart';
import 'package:face_detect_trial/widgets/detection_styles/detection_style.dart';
import 'package:face_detect_trial/widgets/qr_scanner/qr_scanner_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final GlobalKey<QrScannerWidgetState> _scannerKey = GlobalKey();
  bool _navigating = false; // guards against double-navigation

  Future<void> _onBarcodeDetected(Barcode barcode) async {
    if (_navigating) return;
    _navigating = true;

    await Navigator.push(
      context,
      _slideUpRoute(QrResultPage(barcode: barcode)),
    );

    // User came back — reset scanner so they can scan again
    if (mounted) {
      setState(() => _navigating = false);
      _scannerKey.currentState?.reset();
    }
  }

  void _onInitFailure() {
    if (!mounted) return;
    showUnsupportedDeviceDialog(
      context: context,
      style: DetectionStyle.defaults(),
      onGoBack: () {
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: QrScannerWidget(
        key: _scannerKey,
        onBarcodeDetected: _onBarcodeDetected,
        onInitFailure: _onInitFailure,
      ),
    );
  }
}

// Slide-up page transition
PageRouteBuilder _slideUpRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, animation, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final tween = Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}
