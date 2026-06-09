import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../util/wait_for_auth.dart';
import '../../../core/error_messages.dart';
import '../../../data/firebase/journey_landmark_data_source.dart';
import '../../../model/journey_landmark.dart';

/// CRUD for `journey_landmarks`: narrative copy (**Story** = description),
/// challenge JSON (**Clue** = `quiz`), and routing fields.
class AdminJourneyLandmarksPage extends StatefulWidget {
  const AdminJourneyLandmarksPage({
    super.key,
    required this.landmarksJourneyId,
    this.titleLabel,
  });

  /// Value stored as `journeyId` on landmark documents (e.g. `journey1`).
  final String landmarksJourneyId;

  /// Optional subtitle in the app bar area (not used — parent is admin shell).
  final String? titleLabel;

  @override
  State<AdminJourneyLandmarksPage> createState() =>
      _AdminJourneyLandmarksPageState();
}

class _AdminJourneyLandmarksPageState extends State<AdminJourneyLandmarksPage> {
  final _ds = JourneyLandmarkDataSource();

  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = const [];

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
      final docs = await _ds.getLandmarkDocsForJourneyAdmin(
        widget.landmarksJourneyId,
      );
      if (!mounted) return;
      setState(() {
        _docs = docs;
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

  bool _isDeleted(Map<String, dynamic> data) => data['deletedAt'] != null;

  Future<void> _openEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final result = await showDialog<_LmResult>(
      context: context,
      builder: (_) => _LandmarkFormDialog(
        landmarksJourneyId: widget.landmarksJourneyId,
        existing: existing,
      ),
    );
    if (result == null) return;
    try {
      if (result.isDelete) {
        await _ds.softDeleteLandmark(result.documentId);
      } else if (result.isRestore) {
        await _ds.restoreLandmark(result.documentId);
      } else if (result.isCreate) {
        await _ds.createLandmark(
          documentId: result.documentId,
          data: result.data!,
        );
      } else {
        await _ds.updateLandmark(
          documentId: result.documentId,
          data: result.data!,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.snackbarLabel),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(toUserFriendlyMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.brown,
        elevation: 0,
        title: Text(
          widget.titleLabel != null && widget.titleLabel!.trim().isNotEmpty
              ? 'Landmarks • ${widget.titleLabel}'
              : 'Landmarks (${widget.landmarksJourneyId})',
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.beige,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Landmarks journey ID: ${widget.landmarksJourneyId}\n'
                    'Story = description field. Clue / challenge = `quiz` JSON.',
                    style: const TextStyle(
                      color: AppColors.brown,
                      fontSize: 13,
                    ),
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
                  _LmErrorBanner(message: _error!, onRetry: _load)
                else if (_docs.isEmpty)
                  const _LmEmpty()
                else
                  ..._docs.map((d) {
                    final lm = JourneyLandmark.fromFirestore(d.id, d.data());
                    final deleted = _isDeleted(d.data());
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppColors.beige,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.orange,
                          child: Text(
                            '${lm.order}',
                            style: const TextStyle(
                              color: AppColors.beige,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          lm.name,
                          style: TextStyle(
                            color: AppColors.brown,
                            fontWeight: FontWeight.w800,
                            decoration: deleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          'Doc: ${d.id}\n'
                          '${deleted ? "Archived (hidden on map)" : "Published"}',
                          style: const TextStyle(color: AppColors.brown),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (deleted)
                              IconButton(
                                tooltip: 'Restore',
                                icon: const Icon(
                                  Icons.unarchive_outlined,
                                  color: AppColors.brown,
                                ),
                                onPressed: () async {
                                  try {
                                    await _ds.restoreLandmark(d.id);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Landmark restored'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    await _load();
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(toUserFriendlyMessage(e)),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            IconButton(
                              tooltip: deleted ? 'View' : 'Edit',
                              icon: Icon(
                                deleted
                                    ? Icons.visibility_rounded
                                    : Icons.edit_rounded,
                                color: AppColors.brown,
                              ),
                              onPressed: () => _openEditor(existing: d),
                            ),
                          ],
                        ),
                        onTap: () => _openEditor(existing: d),
                      ),
                    );
                  }),
                const SizedBox(height: 120),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.brown,
              foregroundColor: AppColors.beige,
              onPressed: () => _openEditor(existing: null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add landmark'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LmResult {
  final String documentId;
  final Map<String, dynamic>? data;
  final bool isCreate;
  final bool isDelete;
  final bool isRestore;

  _LmResult({
    required this.documentId,
    this.data,
    this.isCreate = false,
    this.isDelete = false,
    this.isRestore = false,
  });

  String get snackbarLabel {
    if (isDelete) return 'Landmark archived';
    if (isRestore) return 'Landmark restored';
    if (isCreate) return 'Landmark created';
    return 'Landmark updated';
  }
}

class _LandmarkFormDialog extends StatefulWidget {
  final String landmarksJourneyId;
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;

  const _LandmarkFormDialog({required this.landmarksJourneyId, this.existing});

  @override
  State<_LandmarkFormDialog> createState() => _LandmarkFormDialogState();
}

class _LandmarkFormDialogState extends State<_LandmarkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _docIdController;
  late final TextEditingController _journeyIdController;
  late final TextEditingController _orderController;
  late final TextEditingController _nameController;
  late final TextEditingController _storyController;
  late final TextEditingController _quizController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _distController;
  late final TextEditingController _walkController;
  late final TextEditingController _nextController;

  bool get _edit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final snap = widget.existing;
    final lm = snap != null
        ? JourneyLandmark.fromFirestore(snap.id, snap.data())
        : null;
    _docIdController = TextEditingController(text: snap?.id ?? '');
    _journeyIdController = TextEditingController(
      text: lm?.journeyId ?? widget.landmarksJourneyId,
    );
    _orderController = TextEditingController(
      text: lm != null ? '${lm.order}' : '',
    );
    _nameController = TextEditingController(text: lm?.name ?? '');
    _storyController = TextEditingController(text: lm?.description ?? '');
    _quizController = TextEditingController(
      text: snap != null ? _quizToText(snap.data()['quiz']) : '',
    );
    _latController = TextEditingController(
      text: lm?.latitude?.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: lm?.longitude?.toString() ?? '',
    );
    _distController = TextEditingController(
      text: lm?.distanceFromPreviousMeters?.toString() ?? '',
    );
    _walkController = TextEditingController(
      text: lm?.walkingTimeFromPreviousMinutes?.toString() ?? '',
    );
    _nextController = TextEditingController(
      text: lm != null ? (lm.nextLandmarkId ?? '') : '',
    );
  }

  static String _quizToText(dynamic quiz) {
    if (quiz == null) return '';
    try {
      if (quiz is Map || quiz is List) {
        return const JsonEncoder.withIndent('  ').convert(quiz);
      }
      return quiz.toString();
    } catch (_) {
      return quiz.toString();
    }
  }

  @override
  void dispose() {
    _docIdController.dispose();
    _journeyIdController.dispose();
    _orderController.dispose();
    _nameController.dispose();
    _storyController.dispose();
    _quizController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _distController.dispose();
    _walkController.dispose();
    _nextController.dispose();
    super.dispose();
  }

  dynamic _parseQuiz(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final decoded = jsonDecode(t);
    return decoded;
  }

  Map<String, dynamic> _buildPayload({
    required bool clearQuiz,
    required bool forCreate,
  }) {
    final order = int.parse(_orderController.text.trim());
    final jid = _journeyIdController.text.trim();

    final payload = <String, dynamic>{
      'journeyId': jid,
      'order': order,
      'name': _nameController.text.trim(),
      'description': _storyController.text.trim(),
    };

    void optDouble(String key, String raw) {
      final t = raw.trim();
      if (t.isNotEmpty) {
        payload[key] = double.parse(t);
      } else if (!forCreate) {
        payload[key] = FieldValue.delete();
      }
    }

    optDouble('latitude', _latController.text);
    optDouble('longitude', _lngController.text);
    optDouble(
      JourneyLandmark.firestoreFieldDistanceFromPreviousMeters,
      _distController.text,
    );
    optDouble(
      JourneyLandmark.firestoreFieldWalkingTimeFromPreviousMinutes,
      _walkController.text,
    );

    final nx = _nextController.text.trim();
    if (nx.isNotEmpty) {
      payload['nextLandmarkId'] = nx;
    } else if (!forCreate) {
      payload['nextLandmarkId'] = FieldValue.delete();
    }

    if (clearQuiz && !forCreate) {
      payload['quiz'] = FieldValue.delete();
    }

    return payload;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final docId = _docIdController.text.trim();

    dynamic quizDecoded;
    try {
      quizDecoded = _parseQuiz(_quizController.text);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clue / quiz must be valid JSON (or empty).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final payload = _buildPayload(
      clearQuiz: quizDecoded == null,
      forCreate: !_edit,
    );
    if (quizDecoded != null) {
      payload['quiz'] = quizDecoded;
    }

    Navigator.of(
      context,
    ).pop(_LmResult(documentId: docId, data: payload, isCreate: !_edit));
  }

  void _archive() {
    final docId = _docIdController.text.trim();
    if (docId.isEmpty) return;
    Navigator.of(context).pop(_LmResult(documentId: docId, isDelete: true));
  }

  void _restore() {
    final docId = _docIdController.text.trim();
    if (docId.isEmpty) return;
    Navigator.of(context).pop(_LmResult(documentId: docId, isRestore: true));
  }

  @override
  Widget build(BuildContext context) {
    final deleted =
        widget.existing != null && widget.existing!.data()['deletedAt'] != null;

    return AlertDialog(
      backgroundColor: AppColors.beige,
      title: Text(
        _edit ? 'Edit landmark' : 'Add landmark',
        style: const TextStyle(
          color: AppColors.brown,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _label(
                  'Document ID',
                  TextFormField(
                    controller: _docIdController,
                    enabled: !_edit,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inp('e.g. journey1landmark3'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Document ID is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Landmarks journey ID (`journeyId` field)',
                  TextFormField(
                    controller: _journeyIdController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inp('e.g. journey1'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Order (map region)',
                  TextFormField(
                    controller: _orderController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inp('1'),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Required';
                      final n = int.tryParse(s);
                      if (n == null || n < 1) return 'Enter a positive integer';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Name',
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inp('Landmark title'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Story (description)',
                  TextFormField(
                    controller: _storyController,
                    maxLines: 4,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inp('Narrative shown in the landmark sheet'),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Clue / challenge (`quiz` JSON)',
                  TextFormField(
                    controller: _quizController,
                    maxLines: 8,
                    style: const TextStyle(
                      color: AppColors.brown,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: _inp('Valid JSON object/array or leave empty'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _label(
                        'Latitude',
                        TextFormField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          style: const TextStyle(color: AppColors.brown),
                          decoration: _inp('optional'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _label(
                        'Longitude',
                        TextFormField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          style: const TextStyle(color: AppColors.brown),
                          decoration: _inp('optional'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _label(
                        'Distance prev (m)',
                        TextFormField(
                          controller: _distController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: AppColors.brown),
                          decoration: _inp('optional'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _label(
                        'Walk time prev (min)',
                        TextFormField(
                          controller: _walkController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: AppColors.brown),
                          decoration: _inp('optional'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label(
                  'Next landmark document ID',
                  TextFormField(
                    controller: _nextController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inp('optional navigation override'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_edit && deleted)
          TextButton(
            onPressed: _restore,
            child: const Text(
              'Restore',
              style: TextStyle(color: AppColors.brown),
            ),
          ),
        if (_edit && !deleted)
          TextButton(
            onPressed: _archive,
            child: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.brown)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brown,
            foregroundColor: AppColors.beige,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _label(String title, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brown,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  InputDecoration _inp(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brown, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _LmErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LmErrorBanner({required this.message, required this.onRetry});

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
            'Couldn’t load landmarks',
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

class _LmEmpty extends StatelessWidget {
  const _LmEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.place_outlined, size: 48, color: AppColors.brown),
          SizedBox(height: 10),
          Text(
            'No landmarks for this journey key',
            style: TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Add a landmark document or check the Landmarks journey ID.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.brown),
          ),
        ],
      ),
    );
  }
}
