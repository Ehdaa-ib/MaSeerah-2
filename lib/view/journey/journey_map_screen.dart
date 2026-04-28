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
              padding: const EdgeInsets.all(16),
              child: JourneySvgMap(
                currentRegion: currentRegion,
                onActiveRegionTap: (region) => _onRegionTap(region),
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
    // Only the active region should call into this.
    if (region != currentRegion) return;

    // Example behavior: region_1 opens the Google map page.
    if (region == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GoogleMapPage()),
      );
      return;
    }

    _showMessage('Tapped active region $region');
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