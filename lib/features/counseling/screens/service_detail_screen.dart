import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import 'pacc_counseling_screen.dart';
import 'reactivation_request_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({
    super.key,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.headerColor,
    this.showAppointmentCta = false,
    this.showReactivationCta = false,
  });

  final String title;
  final String description;
  final String iconAsset;
  final Color headerColor;
  final bool showAppointmentCta;
  final bool showReactivationCta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5E8),
      appBar: AppBar(
        title: const Text('Service Details'),
        backgroundColor: const Color(0xFFFFCD3A),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceAssetImage(assetName: iconAsset, width: 42, height: 42),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: Colors.black87,
              ),
            ),
          ),
          if (showAppointmentCta) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PaccCounselingScreen(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Request an Appointment',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          if (showReactivationCta) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReactivationRequestScreen(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Request reactivation',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceAssetImage extends StatelessWidget {
  const _ServiceAssetImage({required this.assetName, this.width, this.height});

  final String assetName;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppAssets.servicesImages}/$assetName',
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}
