// qr_result_page.dart
// Location: lib/features/qr_scanner/qr_result_page.dart
//
// Displays the decoded QR code result.
// Shows the raw value, the barcode type, and type-specific parsed data when
// available (URL title, WiFi credentials, contact info, etc).
//
// The user can:
//   - Copy the raw value to clipboard
//   - Open a URL (if the barcode is a URL type)
//   - Go back to scan another code

import 'package:face_detect_trial/widgets/detection_styles/detection_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:url_launcher/url_launcher.dart';

class QrResultPage extends StatelessWidget {
  final Barcode barcode;

  const QrResultPage({super.key, required this.barcode});

  @override
  Widget build(BuildContext context) {
    final typeLabel = _barcodeTypeLabel(barcode.type);
    final rawValue = barcode.rawValue ?? '(empty)';
    final sections = _buildSections(barcode);

    return Scaffold(
      backgroundColor: DetectionColors.navyDark,
      appBar: AppBar(
        backgroundColor: DetectionColors.navyMid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Result',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Type badge + icon ---
              _TypeBadge(typeLabel: typeLabel, type: barcode.type),

              const SizedBox(height: 20),

              // --- Raw value card ---
              _SectionCard(
                title: 'Raw Value',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      rawValue,
                      style: const TextStyle(
                        color: DetectionColors.whiteHigh,
                        fontSize: 15,
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ActionButton(
                          icon: Icons.copy_rounded,
                          label: 'Copy',
                          onTap: () => _copyToClipboard(context, rawValue),
                        ),
                        if (_isUrl(barcode)) ...[
                          const SizedBox(width: 10),
                          _ActionButton(
                            icon: Icons.open_in_new_rounded,
                            label: 'Open',
                            onTap: () => _openUrl(context, rawValue),
                            primary: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // --- Parsed detail sections ---
              if (sections.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...sections.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: s,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // --- Scan again button ---
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: DetectionColors.crimsonLight,
                ),
                label: const Text(
                  'Scan Another',
                  style: TextStyle(
                    color: DetectionColors.crimsonLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: DetectionColors.crimson),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Type-specific parsed sections
  // ---------------------------------------------------------------------------

  List<Widget> _buildSections(Barcode barcode) {
    final sections = <Widget>[];

    switch (barcode.type) {
      case BarcodeType.url:
        final url = barcode.value as BarcodeUrl?;
        if (url != null) {
          sections.add(
            _SectionCard(
              title: 'URL Details',
              child: _DetailRow('Title', url.title ?? '—'),
            ),
          );
        }

      case BarcodeType.wifi:
        final wifi = barcode.value as BarcodeWifi?;
        if (wifi != null) {
          sections.add(
            _SectionCard(
              title: 'Wi-Fi Network',
              child: Column(
                children: [
                  _DetailRow('SSID', wifi.ssid ?? '—'),
                  _DetailRow('Password', wifi.password ?? '—'),
                  _DetailRow(
                    'Encryption',
                    _wifiEncryptionLabel(wifi.encryptionType),
                  ),
                ],
              ),
            ),
          );
        }

      case BarcodeType.contactInfo:
        final contact = barcode.value as BarcodeContactInfo?;
        if (contact != null) {
          sections.add(
            _SectionCard(
              title: 'Contact',
              child: Column(
                children: [
                  if (contact.formattedName != null)
                    _DetailRow('Name', contact.formattedName!),
                  if (contact.phoneNumbers.isNotEmpty)
                    _DetailRow(
                      'Phone',
                      contact.phoneNumbers.first.number ?? '—',
                    ),
                  if (contact.emails.isNotEmpty)
                    _DetailRow('Email', contact.emails.first.address ?? '—'),
                  if (contact.urls.isNotEmpty)
                    _DetailRow('Website', contact.urls.first),
                ],
              ),
            ),
          );
        }

      case BarcodeType.email:
        final email = barcode.value as BarcodeEmail?;
        if (email != null) {
          sections.add(
            _SectionCard(
              title: 'Email',
              child: Column(
                children: [
                  _DetailRow('To', email.address ?? '—'),
                  if (email.subject != null && email.subject!.isNotEmpty)
                    _DetailRow('Subject', email.subject!),
                  if (email.body != null && email.body!.isNotEmpty)
                    _DetailRow('Body', email.body!),
                ],
              ),
            ),
          );
        }

      case BarcodeType.phone:
        final phone = barcode.value as BarcodePhone?;
        if (phone != null) {
          sections.add(
            _SectionCard(
              title: 'Phone',
              child: _DetailRow('Number', phone.number ?? '—'),
            ),
          );
        }

      case BarcodeType.geoCoordinates:
        final geo = barcode.value as BarcodeGeoPoint?;
        if (geo != null) {
          sections.add(
            _SectionCard(
              title: 'Location',
              child: Column(
                children: [
                  _DetailRow('Latitude', geo.latitude.toString()),
                  _DetailRow('Longitude', geo.longitude.toString()),
                ],
              ),
            ),
          );
        }

      case BarcodeType.calendarEvent:
        final event = barcode.value as BarcodeCalenderEvent?;
        if (event != null) {
          sections.add(
            _SectionCard(
              title: 'Calendar Event',
              child: Column(
                children: [
                  if (event.summary != null)
                    _DetailRow('Title', event.summary!),
                  if (event.description != null)
                    _DetailRow('Description', event.description!),
                  if (event.location != null)
                    _DetailRow('Location', event.location!),
                ],
              ),
            ),
          );
        }

      default:
        break; // raw value is already shown above
    }

    return sections;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isUrl(Barcode barcode) {
    return barcode.type == BarcodeType.url ||
        (barcode.rawValue?.startsWith('http') ?? false);
  }

  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: DetectionColors.navyMid,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: DetectionColors.crimsonLight,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Copied to clipboard',
              style: TextStyle(color: DetectionColors.whiteHigh),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String rawValue) async {
    final uri = Uri.tryParse(rawValue);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this URL')),
        );
      }
    }
  }

  String _barcodeTypeLabel(BarcodeType type) {
    return switch (type) {
      BarcodeType.url => 'URL',
      BarcodeType.wifi => 'Wi-Fi',
      BarcodeType.contactInfo => 'Contact',
      BarcodeType.email => 'Email',
      BarcodeType.phone => 'Phone',
      BarcodeType.geoCoordinates => 'Location',
      BarcodeType.calendarEvent => 'Calendar Event',
      BarcodeType.text => 'Text',
      BarcodeType.isbn => 'ISBN',
      BarcodeType.product => 'Product',
      BarcodeType.sms => 'SMS',
      BarcodeType.driverLicense => 'Driver License',
      _ => 'Unknown',
    };
  }

  String _wifiEncryptionLabel(int? type) {
    return switch (type) {
      1 => 'Open',
      2 => 'WPA',
      3 => 'WEP',
      _ => 'Unknown',
    };
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TypeBadge extends StatelessWidget {
  final String typeLabel;
  final BarcodeType type;

  const _TypeBadge({required this.typeLabel, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DetectionColors.navyMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DetectionColors.glassBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DetectionColors.crimson.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForType(type),
              color: DetectionColors.crimsonLight,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: DetectionColors.crimson.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: DetectionColors.crimson.withValues(alpha: .5),
              ),
            ),
            child: Text(
              typeLabel,
              style: const TextStyle(
                color: DetectionColors.crimsonLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(BarcodeType type) {
    return switch (type) {
      BarcodeType.url => Icons.link_rounded,
      BarcodeType.wifi => Icons.wifi_rounded,
      BarcodeType.contactInfo => Icons.contact_page_outlined,
      BarcodeType.email => Icons.email_outlined,
      BarcodeType.phone => Icons.phone_outlined,
      BarcodeType.geoCoordinates => Icons.location_on_outlined,
      BarcodeType.calendarEvent => Icons.event_outlined,
      BarcodeType.sms => Icons.sms_outlined,
      _ => Icons.qr_code_rounded,
    };
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DetectionColors.navyMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DetectionColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: DetectionColors.whiteMid,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: DetectionColors.glassBorder, height: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: DetectionColors.whiteMid,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: DetectionColors.whiteHigh,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primary
              ? DetectionColors.crimson.withValues(alpha: .2)
              : DetectionColors.navyLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primary
                ? DetectionColors.crimson.withValues(alpha: .6)
                : DetectionColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: primary
                  ? DetectionColors.crimsonLight
                  : DetectionColors.whiteMid,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primary
                    ? DetectionColors.crimsonLight
                    : DetectionColors.whiteMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
