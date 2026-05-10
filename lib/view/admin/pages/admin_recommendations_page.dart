import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../util/wait_for_auth.dart';
import '../../../core/error_messages.dart';
import '../../../data/firebase/recommendation_places_admin_data_source.dart';
import '../../../model/recommendation_place.dart';

/// Curates `recommendation_places` without altering how [RecommendationPlace] reads `images`.
class AdminRecommendationsPage extends StatefulWidget {
  const AdminRecommendationsPage({super.key});

  @override
  State<AdminRecommendationsPage> createState() =>
      _AdminRecommendationsPageState();
}

class _AdminRecommendationsPageState extends State<AdminRecommendationsPage> {
  final _ds = RecommendationPlacesAdminDataSource();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<RecommendationPlace> _places = const [];

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
      final list = await _ds.fetchAll();
      if (!mounted) return;
      setState(() {
        _places = list;
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

  Future<void> _confirmDelete(RecommendationPlace p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.beige,
        title: const Text(
          'Delete recommendation?',
          style: TextStyle(color: AppColors.brown, fontWeight: FontWeight.w800),
        ),
        content: Text(
          p.name,
          style: const TextStyle(color: AppColors.brown),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.brown)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brown,
              foregroundColor: AppColors.beige,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ds.delete(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recommendation deleted'),
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

  Future<void> _openEditor({RecommendationPlace? existing}) async {
    final raw =
        existing != null ? await _ds.rawDocument(existing.id) : null;
    final result = await showDialog<_RecFormResult>(
      context: context,
      builder: (_) => _RecommendationFormDialog(
        existing: existing,
        rawFallback: raw,
      ),
    );
    if (result == null) return;
    try {
      await _ds.upsert(documentId: result.documentId, data: result.data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Recommendation added' : 'Saved'),
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
    final q = _searchController.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? _places
        : _places.where((p) {
            return p.name.toLowerCase().contains(q) ||
                p.id.toLowerCase().contains(q) ||
                (p.landmarksJourneyId ?? '')
                    .toLowerCase()
                    .contains(q);
          }).toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.brown),
                decoration: InputDecoration(
                  hintText: 'Search recommendations',
                  hintStyle:
                      TextStyle(color: AppColors.brown.withOpacity(0.6)),
                  filled: true,
                  fillColor: AppColors.beige,
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: AppColors.brown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        BorderSide(color: Colors.grey.shade700, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        BorderSide(color: Colors.grey.shade700, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: AppColors.brown, width: 2),
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
                _RecErrorBanner(message: _error!, onRetry: _load)
              else if (_places.isEmpty)
                const _RecEmpty(search: false)
              else if (visible.isEmpty)
                const _RecEmpty(search: true)
              else
                ...visible.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppColors.beige,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.orange,
                        child: Text(
                          '${p.order}',
                          style: const TextStyle(
                            color: AppColors.beige,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(
                          color: AppColors.brown,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'ID: ${p.id}\n'
                        '${p.landmarksJourneyId ?? '—'}',
                        style: const TextStyle(color: AppColors.brown),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon:
                                const Icon(Icons.edit_rounded, color: AppColors.brown),
                            onPressed: () => _openEditor(existing: p),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.brown),
                            onPressed: () => _confirmDelete(p),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
      ],
    );
  }
}

class _RecFormResult {
  final String documentId;
  final Map<String, dynamic> data;
  _RecFormResult({required this.documentId, required this.data});
}

class _RecommendationFormDialog extends StatefulWidget {
  final RecommendationPlace? existing;
  final Map<String, dynamic>? rawFallback;

  const _RecommendationFormDialog({
    this.existing,
    this.rawFallback,
  });

  @override
  State<_RecommendationFormDialog> createState() =>
      _RecommendationFormDialogState();
}

class _RecommendationFormDialogState extends State<_RecommendationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _orderController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationUrlController;
  late final TextEditingController _averagePriceController;
  late final TextEditingController _distanceController;
  late final TextEditingController _walkingController;
  late final TextEditingController _landmarksJourneyIdController;
  late final TextEditingController _catalogJourneyIdController;
  late final TextEditingController _imagesController;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    final raw = widget.rawFallback;
    _idController = TextEditingController(text: p?.id ?? '');
    _orderController = TextEditingController(
      text: p != null ? '${p.order}' : '',
    );
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _locationUrlController = TextEditingController(text: p?.locationUrl ?? '');
    _averagePriceController =
        TextEditingController(text: p?.averagePrice ?? '');
    _distanceController =
        TextEditingController(text: p?.distanceLabel == '—' ? '' : p?.distanceLabel);
    _walkingController =
        TextEditingController(text: p?.walkingLabel == '—' ? '' : p?.walkingLabel);
    _landmarksJourneyIdController =
        TextEditingController(text: p?.landmarksJourneyId ?? '');
    _catalogJourneyIdController =
        TextEditingController(text: p?.catalogJourneyId ?? '');

    final imgs = raw != null ? raw['images'] : null;
    if (imgs is List) {
      final lines = imgs.whereType<String>().join('\n');
      _imagesController = TextEditingController(text: lines);
    } else {
      _imagesController = TextEditingController(
        text: p?.imageUrls.join('\n') ?? '',
      );
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _orderController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _locationUrlController.dispose();
    _averagePriceController.dispose();
    _distanceController.dispose();
    _walkingController.dispose();
    _landmarksJourneyIdController.dispose();
    _catalogJourneyIdController.dispose();
    _imagesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final docId = _idController.text.trim();
    final order = int.parse(_orderController.text.trim());

    final images = _imagesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.startsWith('http'))
        .toList();

    final distanceRaw = _distanceController.text.trim();
    final walkRaw = _walkingController.text.trim();

    final loc = _locationUrlController.text.trim();
    final data = <String, dynamic>{
      'order': order,
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': loc,
      'locationUrl': loc,
      'averagePrice': _averagePriceController.text.trim().isEmpty
          ? '—'
          : _averagePriceController.text.trim(),
      'images': images,
    };

    if (distanceRaw.isNotEmpty) {
      data['distanceFromPreviousLandmark'] = distanceRaw;
    }
    if (walkRaw.isNotEmpty) {
      data['avgWalkingTime'] = walkRaw;
    }

    final lj = _landmarksJourneyIdController.text.trim();
    if (lj.isNotEmpty) data['landmarksJourneyId'] = lj;

    final cj = _catalogJourneyIdController.text.trim();
    if (cj.isNotEmpty) data['catalogJourneyId'] = cj;

    if (widget.rawFallback != null && widget.rawFallback!['prices'] != null) {
      data['prices'] = widget.rawFallback!['prices'];
    }

    Navigator.of(context).pop(_RecFormResult(documentId: docId, data: data));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.beige,
      title: Text(
        _isEdit ? 'Edit recommendation' : 'Add recommendation',
        style: const TextStyle(
          color: AppColors.brown,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _label(
                  'Document ID',
                  TextFormField(
                    controller: _idController,
                    enabled: !_isEdit,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: 'e.g. place_01'),
                    validator: (v) {
                      if (_isEdit) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Document ID is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Order',
                  TextFormField(
                    controller: _orderController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: '1'),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Order is required';
                      final n = int.tryParse(s);
                      if (n == null) return 'Enter a whole number';
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
                    decoration: _dec(hintText: 'Place name'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Description',
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: 'Description'),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Location (Google Maps)',
                  TextFormField(
                    controller: _locationUrlController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(
                      hintText: 'Firestore field `location` — https://maps.google.com/…',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Average price label',
                  TextFormField(
                    controller: _averagePriceController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: 'e.g. 25 SAR'),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Distance label (optional)',
                  TextFormField(
                    controller: _distanceController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: 'Stored as distanceFromPreviousLandmark'),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Walking label (optional)',
                  TextFormField(
                    controller: _walkingController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: 'Stored as avgWalkingTime'),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Landmarks journey ID (optional)',
                  TextFormField(
                    controller: _landmarksJourneyIdController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: 'e.g. journey1'),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Catalog journey ID (optional)',
                  TextFormField(
                    controller: _catalogJourneyIdController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(hintText: 'e.g. journey_1'),
                  ),
                ),
                const SizedBox(height: 12),
                _label(
                  'Images (https URLs, one per line)',
                  TextFormField(
                    controller: _imagesController,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _dec(
                      hintText:
                          'https://…\nhttps://…\n(Uses Firestore field `images`.)',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.brown,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  InputDecoration _dec({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}

class _RecErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RecErrorBanner({required this.message, required this.onRetry});

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
            'Couldn’t load recommendations',
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

class _RecEmpty extends StatelessWidget {
  final bool search;

  const _RecEmpty({required this.search});

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
            search ? Icons.search_off_rounded : Icons.storefront_outlined,
            size: 48,
            color: AppColors.brown,
          ),
          const SizedBox(height: 10),
          Text(
            search ? 'No results' : 'No recommendations',
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
                : 'Add curated places for the map.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.brown),
          ),
        ],
      ),
    );
  }
}
