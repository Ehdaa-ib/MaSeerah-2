import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/faq_data_source.dart';
import '../../model/faq_item.dart';

const String _kSupportEmail = 'MaSeerah.help@gmail.com';

final Uri _kMailtoUri = Uri(
  scheme: 'mailto',
  path: _kSupportEmail,
);

String _messageForFaqError(Object? error) {
  if (error is FirebaseException) {
    return error.message ?? 'Could not load FAQs. Please try again.';
  }
  return 'Could not load FAQs. Please try again.';
}

/// Loads FAQ entries from Firestore collection [FaqDataSource.collection].
class FaqsPage extends StatefulWidget {
  const FaqsPage({super.key});

  @override
  State<FaqsPage> createState() => _FaqsPageState();
}

class _FaqsPageState extends State<FaqsPage> {
  int _streamGeneration = 0;

  Future<void> _openSupportEmail() async {
    try {
      final launched = await launchUrl(
        _kMailtoUri,
        mode: LaunchMode.platformDefault,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        title: const Text('FAQs'),
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.brown,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: StreamBuilder<List<FaqItem>>(
        key: ValueKey(_streamGeneration),
        stream: FaqDataSource().watchFaqs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              children: [
                Expanded(
                  child: _ErrorState(
                    message: _messageForFaqError(snapshot.error),
                    onRetry: () => setState(() => _streamGeneration++),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: _ContactFooter(onEmailTap: _openSupportEmail),
                ),
              ],
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brown),
            );
          }

          final items = snapshot.data ?? const <FaqItem>[];

          if (items.isEmpty) {
            return _EmptyState(
              footer: _ContactFooter(onEmailTap: _openSupportEmail),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _ContactFooter(onEmailTap: _openSupportEmail),
                );
              }

              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FaqExpansionTile(item: item),
              );
            },
          );
        },
      ),
    );
  }
}

class _FaqExpansionTile extends StatelessWidget {
  final FaqItem item;

  const _FaqExpansionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final q = item.question.trim().isEmpty ? 'Question' : item.question.trim();
    final a = item.answer.trim().isEmpty
        ? 'No answer provided yet.'
        : item.answer.trim();

    return Material(
      color: AppColors.beige,
      elevation: 0.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          iconColor: AppColors.brown,
          collapsedIconColor: AppColors.brown,
          title: Text(
            q,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.brown,
              height: 1.35,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                a,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.brown.withOpacity(0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Widget footer;

  const _EmptyState({required this.footer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline_rounded,
              size: 56,
              color: AppColors.brown.withOpacity(0.55),
            ),
            const SizedBox(height: 16),
            Text(
              'No questions yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.brown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back soon or reach out using the contact below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.brown.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 32),
            footer,
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: AppColors.brown.withOpacity(0.55),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.brown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.brown.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brown,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactFooter extends StatelessWidget {
  final VoidCallback onEmailTap;

  const _ContactFooter({required this.onEmailTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.beige.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Still have questions? Contact us at:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppColors.brown,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onEmailTap,
              child: Text(
                _kSupportEmail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.orange.withOpacity(0.6),
                  color: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
