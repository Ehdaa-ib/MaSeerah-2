import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/error_messages.dart';

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

      final results = await Future.wait([
        usersCountFuture,
        journeysCountFuture,
        recentUsersFuture,
      ]);

      final usersAgg = results[0] as AggregateQuerySnapshot;
      final journeysAgg = results[1] as AggregateQuerySnapshot;
      final recentUsers = results[2] as List<_RecentUser>;

      if (!mounted) return;
      setState(() {
        _totalUsers = usersAgg.count ?? 0;
        _totalJourneys = journeysAgg.count ?? 0;
        _recentUsers = recentUsers;
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

