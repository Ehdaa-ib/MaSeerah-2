import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'google_map_page.dart';
import 'widgets/journey_svg_map.dart';

class JourneyMapScreen extends StatefulWidget {
  const JourneyMapScreen({super.key});

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  /// 1-based index of the currently active region.
  int currentRegion = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map', style: TextStyle(color: AppColors.brown)),
        backgroundColor: AppColors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.brown),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: AppColors.beige,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // SVG viewBox is 430x850 (map is tall). Render at full width and
                  // compute height by aspect ratio so it can scroll if needed.
                  const svgWidth = 430.0;
                  const svgHeight = 850.0;
                  final w = constraints.maxWidth;
                  final h = w * (svgHeight / svgWidth);

                  return SingleChildScrollView(
                    // Edge-to-edge width with a tiny top gap.
                    padding: const EdgeInsets.only(top: 6, bottom: 120),
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: JourneySvgMap(
                        currentRegion: currentRegion,
                        allowTapInactive: true,
                        onRegionTap: (region) => _onRegionTap(region),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _showMessage('Current region: $currentRegion'),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Info'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    onPressed: (currentRegion < 9)
                        ? () => setState(() => currentRegion += 1)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onRegionTap(int region) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Region'),
        content: Text('Region number: $region'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Example behavior: region_1 opens the Google map page.
    if (region == 1 && region == currentRegion) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GoogleMapPage()),
      );
      return;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.brown,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}