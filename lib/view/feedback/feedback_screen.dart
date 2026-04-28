import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/feedback_data_source.dart';
import '../../model/feedback.dart';

class FeedbackScreen extends StatefulWidget {
  final String journeyId;
  /// Optional override for tests so they don't need Firebase Auth.
  final String? Function()? currentUserId;

  const FeedbackScreen({
    super.key,
    required this.journeyId,
    this.currentUserId,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  double _overallRating = 0;
  int _contentRating = 0;
  int _nearbyRating = 0;
  int _challengesRating = 0;

  final TextEditingController _commentsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  bool get _overallRatingValid => _overallRating >= 1;

  Future<void> _pickPhotos() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() => _photos.addAll(images));
  }

  Future<void> _submitFeedback() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (!_overallRatingValid) {
      setState(() {
        _isLoading = false;
        _error = 'overall rating is required';
      });
      return;
    }

    final uid = widget.currentUserId?.call() ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in to submit feedback.';
      });
      return;
    }

    try {
      final ds = FeedbackDataSource();
      final photoUrls = await ds.uploadPhotos(
        userId: uid,
        journeyId: widget.journeyId,
        files: _photos,
      );

      final entry = FeedbackEntry(
        userId: uid,
        journeyId: widget.journeyId,
        overallRating: _overallRating.round().clamp(1, 5),
        contentRating: _contentRating.clamp(0, 5),
        recommendationRating: _nearbyRating.clamp(0, 5),
        challengeRating: _challengesRating.clamp(0, 5),
        overallComment: _commentsController.text.trim(),
        photos: photoUrls,
      );

      await ds.create(entry: entry);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'images/name.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 35,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.beige.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Journey Feedback',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brown,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Overall Rating
                          Text(
                            'Overall',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brown,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () => setState(
                                  () => _overallRating = index + 1.0,
                                ),
                                child: Icon(
                                  index < _overallRating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to rate your experience',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.brown.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Comments
                          Text(
                            'COMMENTS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brown,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _commentsController,
                            maxLines: 3,
                            maxLength: 1000,
                            style: const TextStyle(color: AppColors.brown),
                            decoration: InputDecoration(
                              hintText: 'Tell us about your journey...',
                              hintStyle:
                                  TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: AppColors.brown,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Specifics Section
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'Specifics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brown,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(optional)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildRatingRow('Content', _contentRating, (val) {
                            setState(() => _contentRating = val);
                          }),
                          _buildRatingRow(
                            'Nearby recommendations',
                            _nearbyRating,
                            (val) => setState(() => _nearbyRating = val),
                          ),
                          _buildRatingRow('Challenges', _challengesRating, (val) {
                            setState(() => _challengesRating = val);
                          }),
                          const SizedBox(height: 20),

                          // Add a photo
                          Text(
                            'Add a photo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brown,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.brown.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _pickPhotos,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brown.withOpacity(0.2),
                              foregroundColor: AppColors.brown,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: BorderSide(
                                  color: AppColors.brown.withOpacity(0.5),
                                ),
                              ),
                            ),
                            child: Text(
                              _photos.isEmpty
                                  ? 'UPLOAD'
                                  : 'UPLOAD (${_photos.length})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (_photos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final p in _photos)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(p.path),
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Feedback note
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.beige.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: AppColors.brown.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Your feedback helps us improve future journeys. We value your honest opinion.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.brown.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Submit button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submitFeedback,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brown,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                              shadowColor:
                                  AppColors.brown.withOpacity(0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Submit Review',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
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

  Widget _buildRatingRow(
    String label,
    int rating,
    void Function(int) onRatingChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.brown,
              ),
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => onRatingChanged(index + 1),
                child: Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

