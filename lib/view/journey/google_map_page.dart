import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class GoogleMapPage extends StatelessWidget {
  const GoogleMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Map', style: TextStyle(color: AppColors.brown)),
        backgroundColor: AppColors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.brown),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Text(
          'Google Map will be here',
          style: TextStyle(fontSize: 20, color: AppColors.brown),
        ),
      ),
    );
  }
}