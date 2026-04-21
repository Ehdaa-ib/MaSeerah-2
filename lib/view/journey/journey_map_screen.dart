import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'google_map_page.dart';

class JourneyMapScreen extends StatefulWidget {
  const JourneyMapScreen({super.key});

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  List<int> visitedPlaces = [];

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
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.beige,
            child: const Center(
              child: Text(
                'Map Image Here',
                style: TextStyle(color: AppColors.brown, fontSize: 24),
              ),
            ),
          ),
          _buildClickableSpot(1, top: 100, left: 50, width: 60, height: 60),
          _buildClickableSpot(2, top: 100, left: 150, width: 60, height: 60),
          _buildClickableSpot(3, top: 100, left: 250, width: 60, height: 60),
          _buildClickableSpot(4, top: 100, left: 350, width: 60, height: 60),
          _buildClickableSpot(5, top: 250, left: 50, width: 60, height: 60),
          _buildClickableSpot(6, top: 250, left: 150, width: 60, height: 60),
          _buildClickableSpot(7, top: 250, left: 250, width: 60, height: 60),
          _buildClickableSpot(8, top: 250, left: 350, width: 60, height: 60),
          Positioned(
            bottom: 20,
            left: 20,
            child: GestureDetector(
              onTap: () {
                _showMessage('You clicked the bottom left button!');
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brown,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Info',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableSpot(int placeNumber, {
    required double top,
    required double left,
    required double width,
    required double height,
  }) {
    final isVisited = visitedPlaces.contains(placeNumber);
    
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () {
          if (placeNumber == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GoogleMapPage(),
              ),
            );
          } else {
            _onPlaceTap(placeNumber);
          }
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isVisited 
                ? AppColors.orange.withOpacity(0.7)
                : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isVisited ? AppColors.orange : Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$placeNumber',
              style: TextStyle(
                color: isVisited ? Colors.white : Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPlaceTap(int placeNumber) {
    setState(() {
      if (!visitedPlaces.contains(placeNumber)) {
        visitedPlaces.add(placeNumber);
        _showMessage('You visited place $placeNumber! 🎉');
      } else {
        _showMessage('You already visited place $placeNumber');
      }
    });
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