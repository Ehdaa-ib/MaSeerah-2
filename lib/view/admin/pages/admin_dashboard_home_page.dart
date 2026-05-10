import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../util/wait_for_auth.dart';
import '../../../core/error_messages.dart';
import '../../../model/journey.dart';

class AdminDashboardHomePage extends StatefulWidget {
  const AdminDashboardHomePage({super.key});

  @override
  State<AdminDashboardHomePage> createState() => _AdminDashboardHomePageState();
}

class _AdminDashboardHomePageState extends State<AdminDashboardHomePage> {
  bool _loading = true;
  String? _error;
  int _totalUsers = 0;
  int _totalJourneys = 0;
  int _totalFeedback = 0;
  int _totalCompletions = 0;
  double _avgOverallRating = 0;
  int _ratingSamples = 0;
  int _completionsLast7Days = 0;
  List<_TopJourneyRow> _topJourneys = const [];
  List<_RecentUser> _recentUsers = const [];

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
      await waitForAuth();
      final usersCountFuture =
          FirebaseFirestore.instance.collection('users').count().get();
      final journeysCountFuture =
          FirebaseFirestore.instance.collection('journeys').count().get();

      final recentUsersFuture = FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get()
          .then((snapshot) {
        return snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          return _RecentUser(
            name: (data['name'] as String?)?.trim().isNotEmpty == true
                ? (data['name'] as String).trim()
                : '—',
            email: (data['email'] as String?) ?? '—',
          );
        }).toList();
      }).catchError((_) => <_RecentUser>[]);

      final feedbackCountFuture =
          _safeCount(FirebaseFirestore.instance.collection('feedback'));
      final completionsCountFuture =
          _safeCount(FirebaseFirestore.instance.collection('journeyCompletions'));
      final analyticsFuture = _loadEngagementAnalytics();

      final results = await Future.wait([
        usersCountFuture,
        journeysCountFuture,
        recentUsersFuture,
        feedbackCountFuture,
        completionsCountFuture,
        analyticsFuture,
      ]);

      final usersAgg = results[0] as AggregateQuerySnapshot;
      final journeysAgg = results[1] as AggregateQuerySnapshot;
      final recentUsers = results[2] as List<_RecentUser>;
      final feedbackCount = results[3] as int;
      final completionsCount = results[4] as int;
      final analytics = results[5] as _EngagementAnalytics;

      if (!mounted) return;
      setState(() {
        _totalUsers = usersAgg.count ?? 0;
        _totalJourneys = journeysAgg.count ?? 0;
        _recentUsers = recentUsers;
        _totalFeedback = feedbackCount;
        _totalCompletions = completionsCount;
        _avgOverallRating = analytics.avgOverallRating;
        _ratingSamples = analytics.ratingSamples;
        _completionsLast7Days = analytics.completionsLast7Days;
        _topJourneys = analytics.topJourneys;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = toUserFriendlyMessage(e);
        _loading = false;
      });
    }
  }

  Future<int> _safeCount(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    try {
      final a = await collection.count().get();
      return a.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<_EngagementAnalytics> _loadEngagementAnalytics() async {
    var avgOverall = 0.0;
    var ratingN = 0;
    try {
      final fb =
          await FirebaseFirestore.instance.collection('feedback').limit(400).get();
      for (final d in fb.docs) {
        final r = d.data()['overallRating'];
        if (r is num) {
          avgOverall += r.toDouble();
          ratingN++;
        }
      }
    } catch (_) {}

    final avg = ratingN > 0 ? avgOverall / ratingN : 0.0;

    var completed7d = 0;
    try {
      final weekAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)),
      );
      final q = await FirebaseFirestore.instance
          .collection('journeyCompletions')
          .where('completedAt', isGreaterThanOrEqualTo: weekAgo)
          .get();
      completed7d = q.docs.length;
    } catch (_) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('journeyCompletions')
            .limit(500)
            .get();
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        for (final d in snap.docs) {
          final ts = d.data()['completedAt'];
          if (ts is Timestamp && ts.toDate().isAfter(cutoff)) {
            completed7d++;
          }
        }
      } catch (_) {}
    }

    final counts = <String, int>{};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('journeyCompletions')
          .limit(500)
          .get();
      for (final d in snap.docs) {
        final jid = d.data()['journeyId'] as String?;
        if (jid == null || jid.isEmpty) continue;
        counts[jid] = (counts[jid] ?? 0) + 1;
      }
    } catch (_) {}

    final topEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFive = topEntries.take(5).toList();

    final rows = <_TopJourneyRow>[];
    for (final e in topFive) {
      var label = e.key;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('journeys')
            .doc(e.key)
            .get();
        if (doc.exists && doc.data() != null) {
          label = Journey.fromMap(
            Map<String, dynamic>.from(doc.data()!),
            id: doc.id,
          ).name;
        }
      } catch (_) {}
      rows.add(
        _TopJourneyRow(journeyId: e.key, title: label, completions: e.value),
      );
    }

    return _EngagementAnalytics(
      avgOverallRating: avg,
      ratingSamples: ratingN,
      completionsLast7Days: completed7d,
      topJourneys: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(
              child: CircularProgressIndicator(color: AppColors.brown),
            ),
          ] else if (_error != null) ...[
            _ErrorCard(message: _error!, onRetry: _load),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Users',
                    value: _totalUsers.toString(),
                    icon: Icons.people_alt_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Journeys',
                    value: _totalJourneys.toString(),
                    icon: Icons.travel_explore_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Feedback entries',
                    value: _totalFeedback.toString(),
                    icon: Icons.feedback_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Journey completions',
                    value: _totalCompletions.toString(),
                    icon: Icons.flag_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Avg overall rating',
                    value: _ratingSamples == 0
                        ? '—'
                        : _avgOverallRating.toStringAsFixed(2),
                    icon: Icons.star_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Completions (7 days)',
                    value: _completionsLast7Days.toString(),
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Most completed journeys (sample)',
              child: _topJourneys.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No completion data in the sampled window.',
                        style: TextStyle(color: AppColors.brown),
                      ),
                    )
                  : Column(
                      children: _topJourneys
                          .map(
                            (r) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.route_rounded,
                                  color: AppColors.brown),
                              title: Text(
                                r.title,
                                style: const TextStyle(color: AppColors.brown),
                              ),
                              subtitle: Text(
                                '${r.journeyId} • ${r.completions} completions',
                                style: const TextStyle(color: AppColors.brown),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Recent users',
              child: _recentUsers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No recent users to show.',
                        style: TextStyle(color: AppColors.brown),
                      ),
                    )
                  : Column(
                      children: _recentUsers
                          .map(
                            (u) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.orange,
                                child: const Icon(Icons.person,
                                    color: AppColors.beige),
                              ),
                              title: Text(u.name,
                                  style:
                                      const TextStyle(color: AppColors.brown)),
                              subtitle: Text(u.email,
                                  style:
                                      const TextStyle(color: AppColors.brown)),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brown,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.beige),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.brown,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.brown,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couldn’t load dashboard',
            style: TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: AppColors.brown)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brown,
              foregroundColor: AppColors.beige,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _RecentUser {
  final String name;
  final String email;
  const _RecentUser({required this.name, required this.email});
}

class _TopJourneyRow {
  final String journeyId;
  final String title;
  final int completions;

  const _TopJourneyRow({
    required this.journeyId,
    required this.title,
    required this.completions,
  });
}

class _EngagementAnalytics {
  final double avgOverallRating;
  final int ratingSamples;
  final int completionsLast7Days;
  final List<_TopJourneyRow> topJourneys;

  const _EngagementAnalytics({
    required this.avgOverallRating,
    required this.ratingSamples,
    required this.completionsLast7Days,
    required this.topJourneys,
  });
}

