import 'package:flutter/material.dart';

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
        builder: (_) => JourneyPurchaseScreen(journeyId: journey.journeyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journeys')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journeys')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_journeys.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journeys')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.travel_explore, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'No journeys yet.\nAdd journeys in Firestore (journeys collection).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Journeys')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _journeys.length,
          itemBuilder: (context, index) {
            final journey = _journeys[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.travel_explore),
                ),
                title: Text(journey.name),
                subtitle: Text('${journey.price.toStringAsFixed(2)} SAR'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openJourney(journey),
              ),
            );
          },
        ),
      ),
    );
  }
}
