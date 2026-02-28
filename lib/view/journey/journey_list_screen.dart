import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/error_messages.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/repoImp/journey_repository_firebase.dart';
import '../../model/journey.dart';
import 'journey_purchase_screen.dart';

/// Lists all predefined journeys from Firestore. Tap one to open purchase screen.
class JourneyListScreen extends StatefulWidget {
  const JourneyListScreen({super.key});

  @override
  State<JourneyListScreen> createState() => _JourneyListScreenState();
}

class _JourneyListScreenState extends State<JourneyListScreen> {
  final _journeyRepo = JourneyRepositoryFirebase(JourneyDataSource());

  List<Journey> _journeys = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final journeys = await _journeyRepo.getAll();
      if (mounted) {
        setState(() {
          _journeys = journeys;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = toUserFriendlyMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _openJourney(Journey journey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JourneyPurchaseScreen(
          journeyId: journey.journeyId,
          initialJourney: journey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.green,
        appBar: AppBar(
          title: const Text('Journeys'),
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.beige,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.brown)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.green,
        appBar: AppBar(
          title: const Text('Journeys'),
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.beige,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.brown),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.brown),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brown,
                    foregroundColor: AppColors.beige,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_journeys.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.green,
        appBar: AppBar(
          title: const Text('Journeys'),
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.beige,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.travel_explore, size: 64, color: AppColors.brown),
                const SizedBox(height: 16),
                Text(
                  'No journeys yet.\nAdd journeys in Firestore (journeys collection).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        title: const Text('Journeys'),
        backgroundColor: AppColors.brown,
        foregroundColor: AppColors.beige,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _journeys.length,
          itemBuilder: (context, index) {
            final journey = _journeys[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.beige,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.orange,
                  child: const Icon(Icons.travel_explore, color: AppColors.beige),
                ),
                title: Text(journey.name, style: const TextStyle(color: AppColors.brown)),
                subtitle: Text('${journey.price.toStringAsFixed(2)} SAR', style: const TextStyle(color: AppColors.brown)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.brown),
                onTap: () => _openJourney(journey),
              ),
            );
          },
        ),
      ),
    );
  }
}
