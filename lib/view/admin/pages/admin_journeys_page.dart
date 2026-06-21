import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../util/wait_for_auth.dart';
import '../../../core/error_messages.dart';
import '../../../core/landmarks_journey_id.dart';
import '../../../data/firebase/journey_data_source.dart';
import '../../../data/repoImp/journey_repository_firebase.dart';
import '../../../model/journey.dart';
import 'admin_journey_landmarks_page.dart';

class AdminJourneysPage extends StatefulWidget {
  const AdminJourneysPage({super.key});

  @override
  State<AdminJourneysPage> createState() => _AdminJourneysPageState();
}

class _AdminJourneysPageState extends State<AdminJourneysPage> {
  final _repo = JourneyRepositoryFirebase(JourneyDataSource());
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Journey> _journeys = const [];

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
      final journeys = await _repo.getAll(forceRefresh: true);
      developer.log(
        'AdminJourneysPage: loaded ${journeys.length} journeys '
        '(ids: ${journeys.map((j) => j.journeyId).toList()})',
        name: 'AdminJourneysPage',
      );
      journeys.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _journeys = journeys;
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

  Future<void> _openAdd() async {
    final result = await showDialog<_JourneyFormResult>(
      context: context,
      builder: (_) => const _JourneyFormDialog(),
    );
    if (result == null) return;

    try {
      await _repo.create(journeyId: result.journeyId, journey: result.journey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journey added'),
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

  void _openLandmarks(Journey j) {
    final explicit = j.landmarksJourneyId?.trim();
    final inferred = inferLandmarksJourneyIdFromCatalogId(j.journeyId);
    final lm = (explicit != null && explicit.isNotEmpty) ? explicit : inferred;
    if (lm == null || lm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set “Landmarks journey ID” on this journey (or use a journey_# ID) to manage landmarks.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminJourneyLandmarksPage(
          landmarksJourneyId: lm,
          titleLabel: j.name,
        ),
      ),
    );
  }

  Future<void> _openEdit(Journey journey) async {
    final result = await showDialog<_JourneyFormResult>(
      context: context,
      builder: (_) => _JourneyFormDialog(existing: journey),
    );
    if (result == null) return;

    try {
      await _repo.update(journeyId: journey.journeyId, journey: result.journey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journey updated'),
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
        ? _journeys
        : _journeys.where((j) {
            return j.journeyId.toLowerCase().contains(q) ||
                j.name.toLowerCase().contains(q) ||
                (j.city ?? '').toLowerCase().contains(q);
          }).toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SearchField(
                controller: _searchController,
                hintText: 'Search journeys',
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
                _ErrorBanner(message: _error!, onRetry: _load)
              else if (_journeys.isEmpty)
                const _EmptyState(
                  icon: Icons.travel_explore_rounded,
                  title: 'No journeys yet',
                  subtitle:
                      'Journeys will appear from the Firestore journeys collection.',
                )
              else if (visible.isEmpty)
                const _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No results',
                  subtitle: 'Try a different search term.',
                )
              else
                ...visible.map(
                  (j) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppColors.beige,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.orange,
                        child: const Icon(
                          Icons.travel_explore,
                          color: AppColors.beige,
                        ),
                      ),
                      title: Text(
                        j.name,
                        style: const TextStyle(
                          color: AppColors.brown,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'ID: ${j.journeyId}\n${j.price.toStringAsFixed(2)} SAR${(j.city != null && j.city!.trim().isNotEmpty) ? ' • ${j.city}' : ''}',
                        style: const TextStyle(color: AppColors.brown),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Stories, clues & landmarks',
                            onPressed: () => _openLandmarks(j),
                            icon: const Icon(
                              Icons.place_rounded,
                              color: AppColors.brown,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit journey',
                            onPressed: () => _openEdit(j),
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: AppColors.brown,
                            ),
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
            onPressed: _openAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add journey'),
          ),
        ),
      ],
    );
  }
}

class _JourneyFormDialog extends StatefulWidget {
  final Journey? existing;
  const _JourneyFormDialog({this.existing});

  @override
  State<_JourneyFormDialog> createState() => _JourneyFormDialogState();
}

class _JourneyFormDialogState extends State<_JourneyFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _journeyIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _startPointController;
  late final TextEditingController _endPointController;
  late final TextEditingController _stopsController;
  late final TextEditingController _estimatedDurationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _goodToKnowController;
  late final TextEditingController _languagesController;
  late final TextEditingController _cityController;
  late final TextEditingController _landmarksJourneyIdController;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final j = widget.existing;
    _journeyIdController = TextEditingController(text: j?.journeyId ?? '');
    _nameController = TextEditingController(text: j?.name ?? '');
    _priceController = TextEditingController(
      text: j == null ? '' : j.price.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(text: j?.description ?? '');
    _startPointController = TextEditingController(text: j?.startPoint ?? '');
    _endPointController = TextEditingController(text: j?.endPoint ?? '');
    _stopsController = TextEditingController(text: j?.stops ?? '');
    _estimatedDurationController = TextEditingController(
      text: j?.estimatedDuration ?? '',
    );
    _distanceController = TextEditingController(text: j?.distance ?? '');
    _goodToKnowController = TextEditingController(text: j?.goodToKnow ?? '');
    _languagesController = TextEditingController(text: j?.languages ?? '');
    _cityController = TextEditingController(text: j?.city ?? '');
    _landmarksJourneyIdController = TextEditingController(
      text: j?.landmarksJourneyId ?? '',
    );
  }

  @override
  void dispose() {
    _journeyIdController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _startPointController.dispose();
    _endPointController.dispose();
    _stopsController.dispose();
    _estimatedDurationController.dispose();
    _distanceController.dispose();
    _goodToKnowController.dispose();
    _languagesController.dispose();
    _cityController.dispose();
    _landmarksJourneyIdController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final journeyId = _journeyIdController.text.trim();
    final price = double.parse(_priceController.text.trim());

    final journey = Journey(
      journeyId: journeyId,
      name: _nameController.text.trim(),
      price: price,
      description: _nullIfEmpty(_descriptionController.text),
      startPoint: _nullIfEmpty(_startPointController.text),
      endPoint: _nullIfEmpty(_endPointController.text),
      stops: _nullIfEmpty(_stopsController.text),
      estimatedDuration: _nullIfEmpty(_estimatedDurationController.text),
      distance: _nullIfEmpty(_distanceController.text),
      goodToKnow: _nullIfEmpty(_goodToKnowController.text),
      languages: _nullIfEmpty(_languagesController.text),
      city: _nullIfEmpty(_cityController.text),
      landmarksJourneyId: _nullIfEmpty(_landmarksJourneyIdController.text),
    );

    Navigator.of(
      context,
    ).pop(_JourneyFormResult(journeyId: journeyId, journey: journey));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.beige,
      title: Text(
        _isEdit ? 'Edit journey' : 'Add journey',
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
                _LabeledTextField(
                  label: 'Journey ID',
                  child: TextFormField(
                    controller: _journeyIdController,
                    enabled: !_isEdit,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'e.g. journey_1'),
                    validator: (v) {
                      if (_isEdit) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Journey ID is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Name',
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(
                      hintText: 'Enter journey name',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Price (SAR)',
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: '0.00'),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Price is required';
                      final d = double.tryParse(s);
                      if (d == null) return 'Enter a valid number';
                      if (d < 0) return 'Price can’t be negative';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'City (optional)',
                  child: TextFormField(
                    controller: _cityController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'Enter city'),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Landmarks journey ID (optional)',
                  child: TextFormField(
                    controller: _landmarksJourneyIdController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(
                      hintText:
                          'e.g. journey1 — links catalog journey to journey_landmarks',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Description (optional)',
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'Enter description'),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Start point (optional)',
                  child: TextFormField(
                    controller: _startPointController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'Enter start point'),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Stops (optional)',
                  child: TextFormField(
                    controller: _stopsController,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'Enter stops'),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'End point (optional)',
                  child: TextFormField(
                    controller: _endPointController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'Enter end point'),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Estimated duration (optional)',
                  child: TextFormField(
                    controller: _estimatedDurationController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'e.g. 2-3 hours'),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Distance (optional)',
                  child: TextFormField(
                    controller: _distanceController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(hintText: 'e.g. 5 km'),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Languages (optional)',
                  child: TextFormField(
                    controller: _languagesController,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(
                      hintText: 'e.g. Arabic, English',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Good to know (optional)',
                  child: TextFormField(
                    controller: _goodToKnowController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.brown),
                    decoration: _inputDecoration(
                      hintText: 'Enter good to know',
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
}

class _JourneyFormResult {
  final String journeyId;
  final Journey journey;
  const _JourneyFormResult({required this.journeyId, required this.journey});
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _SearchField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.brown),
      decoration: InputDecoration(
        hintText: hintText,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

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
            'Couldn’t load journeys',
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
          Icon(icon, size: 48, color: AppColors.brown),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.brown),
          ),
        ],
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledTextField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.brown,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _inputDecoration({required String hintText}) {
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  );
}

String? _nullIfEmpty(String? s) {
  final v = s?.trim() ?? '';
  return v.isEmpty ? null : v;
}
