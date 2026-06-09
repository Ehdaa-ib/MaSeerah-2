import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Shown when a catalog journey exists but is not released yet.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.journeyName});

  final String journeyName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.brown,
        elevation: 0,
        title: Text(
          journeyName.trim().isEmpty ? l10n.comingSoonTitle : journeyName,
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: AppColors.beige.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 56,
                      color: AppColors.orange.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.comingSoonTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brown,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.comingSoonBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: AppColors.brown.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(l10n.comingSoonBack),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
