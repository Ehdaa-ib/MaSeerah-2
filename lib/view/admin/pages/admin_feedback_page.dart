import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../util/wait_for_auth.dart';
import '../../../core/error_messages.dart';
import '../../../data/firebase/feedback_admin_data_source.dart';
import '../../../model/feedback.dart';

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  final _ds = FeedbackAdminDataSource();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<FeedbackAdminRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await waitForAuth();
      final rows = await _ds.fetchAll();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  Future<void> _openDetail(FeedbackAdminRow row) async {
    final replyController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.beige,
          title: Text(
            'Feedback • ${row.entry.journeyId}',
            style: const TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _kv(
                    'User',
                    row.userDisplayName != null
                        ? '${row.userDisplayName} (${row.entry.userId})'
                        : row.entry.userId,
                  ),
                  _kv('Submitted',
                      row.entry.createdAt?.toLocal().toString() ?? '—'),
                  _kv('Overall', '${row.entry.overallRating}/5'),
                  _kv(
                      'Detail ratings',
                      'content ${row.entry.contentRating}, '
                      'rec ${row.entry.recommendationRating}, '
                      'challenge ${row.entry.challengeRating}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Comment',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.entry.overallComment.isEmpty
                        ? '—'
                        : row.entry.overallComment,
                    style: const TextStyle(color: AppColors.brown),
                  ),
                  if (row.entry.photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...row.entry.photos.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          url,
                          style: const TextStyle(
                            color: AppColors.brown,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (row.entry.adminResponse != null &&
                      row.entry.adminResponse!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Latest admin response',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _responseTile(
                      AdminFeedbackReply(
                        message: row.entry.adminResponse!,
                        adminEmail: FirebaseAuth.instance.currentUser?.email,
                        respondedAt: row.entry.respondedAt,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Response history',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (row.entry.adminResponses.isEmpty)
                    const Text(
                      'No responses yet.',
                      style: TextStyle(color: AppColors.brown),
                    )
                  else
                    ...row.entry.adminResponses.map(_responseTile),
                  const SizedBox(height: 16),
                  TextField(
                    controller: replyController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: InputDecoration(
                      hintText: 'Write a response…',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.brown),
              ),
            ),
            FilledButton(
              onPressed: () async {
                final text = replyController.text.trim();
                if (text.isEmpty) return;
                final email =
                    FirebaseAuth.instance.currentUser?.email ?? 'admin';
                try {
                  await _ds.appendAdminResponse(
                    feedbackDocumentId: row.documentId,
                    message: text,
                    adminEmail: email,
                  );
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Response saved'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _load();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(toUserFriendlyMessage(e)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brown,
                foregroundColor: AppColors.beige,
              ),
              child: const Text('Send response'),
            ),
          ],
        );
      },
    );
    replyController.dispose();
  }

  Widget _responseTile(AdminFeedbackReply r) {
    final when = r.respondedAt?.toLocal().toString() ?? '—';
    final who = r.adminEmail ?? 'Admin';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$who • $when',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.brown,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              r.message.isEmpty ? '—' : r.message,
              style: const TextStyle(color: AppColors.brown),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.brown,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(color: AppColors.brown),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? _rows
        : _rows.where((r) {
            final e = r.entry;
            return e.journeyId.toLowerCase().contains(q) ||
                e.userId.toLowerCase().contains(q) ||
                e.overallComment.toLowerCase().contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.brown),
            decoration: InputDecoration(
              hintText: 'Search feedback',
              hintStyle: TextStyle(color: AppColors.brown.withOpacity(0.6)),
              filled: true,
              fillColor: AppColors.beige,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.brown),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.brown, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.brown),
              ),
            )
          else if (_error != null)
            _FeedbackErrorBanner(message: _error!, onRetry: _load)
          else if (_rows.isEmpty)
            const _EmptyFeedback()
          else if (visible.isEmpty)
            const _EmptyFeedback(search: true)
          else
            ...visible.map(
              (r) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppColors.beige,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.orange,
                    child: Text(
                      '${r.entry.overallRating}',
                      style: const TextStyle(
                        color: AppColors.beige,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    r.entry.journeyId,
                    style: const TextStyle(
                      color: AppColors.brown,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${r.userDisplayName ?? r.entry.userId}\n'
                    '${r.entry.createdAt?.toLocal().toString() ?? '—'}',
                    style: const TextStyle(color: AppColors.brown),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right, color: AppColors.brown),
                  onTap: () => _openDetail(r),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _FeedbackErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FeedbackErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couldn’t load feedback',
            style: TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.brown)),
          const SizedBox(height: 10),
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

class _EmptyFeedback extends StatelessWidget {
  final bool search;

  const _EmptyFeedback({this.search = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            search ? Icons.search_off_rounded : Icons.feedback_outlined,
            size: 48,
            color: AppColors.brown,
          ),
          const SizedBox(height: 10),
          Text(
            search ? 'No results' : 'No feedback yet',
            style: const TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            search
                ? 'Try a different search term.'
                : 'Feedback appears when users finish journeys.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.brown),
          ),
        ],
      ),
    );
  }
}
