import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/firebase/feedback_data_source.dart';
import '../../model/feedback.dart';
import '../../core/app_colors.dart';

class FeedbackScreen extends StatefulWidget {
  final String journeyId;

  const FeedbackScreen({super.key, required this.journeyId});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _picker = ImagePicker();

  int _overallRating = 0;
  int _contentRating = 0;
  int _recommendationRating = 0;
  int _challengeRating = 0;

  bool _submitting = false;
  String? _error;
  final List<File> _photos = [];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() {
      _photos.addAll(images.map((x) => File(x.path)));
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _error = null;
    });

    if (!_formKey.currentState!.validate()) return;
    if (_overallRating == 0 ||
        _contentRating == 0 ||
        _recommendationRating == 0 ||
        _challengeRating == 0) {
      setState(() => _error = 'Please rate all categories (1–5).');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Please sign in to submit feedback.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final ds = FeedbackDataSource();
      final photoUrls = await ds.uploadPhotos(
        userId: uid,
        journeyId: widget.journeyId,
        files: List<File>.from(_photos),
      );

      final entry = FeedbackEntry(
        userId: uid,
        journeyId: widget.journeyId,
        overallRating: _overallRating,
        contentRating: _contentRating,
        recommendationRating: _recommendationRating,
        challengeRating: _challengeRating,
        overallComment: _commentController.text.trim(),
        photos: photoUrls,
      );

      await ds.createOnce(entry: entry);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you! Feedback submitted.'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.brown,
        title: const Text('Journey Feedback'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RatingRow(
                label: 'Overall',
                value: _overallRating,
                onChanged: (v) => setState(() => _overallRating = v),
              ),
              _RatingRow(
                label: 'Content',
                value: _contentRating,
                onChanged: (v) => setState(() => _contentRating = v),
              ),
              _RatingRow(
                label: 'Recommendation',
                value: _recommendationRating,
                onChanged: (v) => setState(() => _recommendationRating = v),
              ),
              _RatingRow(
                label: 'Challenge',
                value: _challengeRating,
                onChanged: (v) => setState(() => _challengeRating = v),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Overall comment (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _submitting ? null : _pickPhotos,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Add photos'),
                  ),
                  const SizedBox(width: 12),
                  Text('${_photos.length} selected'),
                ],
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _photos.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _photos[i],
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: _submitting
                                  ? null
                                  : () => setState(() => _photos.removeAt(i)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit feedback'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.brown, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                final filled = star <= value;
                return IconButton(
                  tooltip: '$star',
                  onPressed: () => onChanged(star),
                  icon: Icon(filled ? Icons.star : Icons.star_border, color: AppColors.orange),
                );
              }),
            ),
          ),
          if (value == 0)
            const Text('Required', style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
    );
  }
}

