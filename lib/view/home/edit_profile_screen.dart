import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/profile_photo_data_source.dart';
import '../../data/firebase/user_profile_data_source.dart';

/// Editable profile for the signed-in user (`users/{uid}` + Firebase Auth email/displayName).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();

  /// Firebase download URL after upload, or loaded from Firestore (no manual URL entry).
  String _profileImageUrl = '';

  final _profileDs = UserProfileDataSource();
  final _profilePhotoDs = ProfilePhotoDataSource();
  final _imagePicker = ImagePicker();

  static const _genders = ['Male', 'Female', 'Prefer not to say'];

  String _gender = 'Prefer not to say';
  DateTime? _dateOfBirth;
  /// Shown read-only (from Firebase Auth / Firestore). Not editable on this screen.
  String _displayEmail = '';
  bool _loadingDoc = true;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _loadError;

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.beige.withValues(alpha: 0.92),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.brown.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.brown, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.7)),
      ),
      labelStyle: const TextStyle(color: AppColors.brown, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: AppColors.brown.withValues(alpha: 0.45)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _nationalityCtrl.dispose();
    super.dispose();
  }

  DateTime? _readDob(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final uid = user.uid;

    setState(() {
      _loadingDoc = true;
      _loadError = null;
    });

    try {
      final data = await _profileDs.getUserProfileMap(uid);
      if (!mounted) return;

      if (kDebugMode) {
        debugPrint('[EditProfile] load uid=$uid');
        debugPrint('[EditProfile] firestore keys=${data?.keys.toList() ?? []}');
      }

      final username = (data?['username'] as String?)?.trim();
      final name = (data?['name'] as String?)?.trim();
      _usernameCtrl.text = (username != null && username.isNotEmpty)
          ? username
          : (name ?? '').trim();

      _displayEmail = (user.email ?? (data?['email'] as String?) ?? '').trim();
      _phoneCtrl.text = (data?['phoneNumber'] as String?)?.trim() ?? '';
      final g = (data?['gender'] as String?)?.trim() ?? '';
      _gender = _genders.contains(g) ? g : 'Prefer not to say';
      _nationalityCtrl.text = (data?['nationality'] as String?)?.trim() ?? '';
      _dateOfBirth = _readDob(data?['dateOfBirth']);
      _profileImageUrl = (data?['profileImageUrl'] as String?)?.trim() ?? '';

      if (kDebugMode) {
        debugPrint(
          '[EditProfile] defaulted missing: '
          'usernameEmpty=${_usernameCtrl.text.isEmpty} '
          'phoneEmpty=${_phoneCtrl.text.isEmpty} '
          'nationalityEmpty=${_nationalityCtrl.text.isEmpty} '
          'dobMissing=${_dateOfBirth == null} '
          'profileImageEmpty=${_profileImageUrl.isEmpty}',
        );
      }

      setState(() => _loadingDoc = false);
    } catch (e) {
      if (kDebugMode) debugPrint('[EditProfile] load failed: $e');
      if (!mounted) return;
      setState(() {
        _loadingDoc = false;
        _loadError = 'Could not load your profile. Pull to retry or open again.';
      });
    }
  }

  bool _validPhone(String s) {
    final t = s.trim();
    if (t.isEmpty) return true;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7 && digits.length <= 15;
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final x = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await _profilePhotoDs.uploadProfilePhoto(userId: uid, file: x);
      if (!mounted) return;
      setState(() => _profileImageUrl = url);
      try {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
      } catch (_) {}
      if (kDebugMode) debugPrint('[EditProfile] profile image uploaded');
    } catch (e) {
      if (kDebugMode) debugPrint('[EditProfile] profile image upload failed: $e');
      if (mounted) {
        final msg = e.toString();
        final friendly = msg.contains('Storage rules') || msg.contains('permission-denied')
            ? 'Upload blocked: deploy Firebase Storage rules (profilePhotos path) from this project, then try again.'
            : 'Could not upload photo: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendly)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _showImageSourceSheet() {
    if (_saving || _uploadingImage) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.beige,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.brown),
              title: const Text('Photos & gallery', style: TextStyle(color: AppColors.brown)),
              subtitle: Text(
                'Opens your device photo picker',
                style: TextStyle(fontSize: 12, color: AppColors.brown.withValues(alpha: 0.65)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: AppColors.brown),
              title: const Text('Take a photo', style: TextStyle(color: AppColors.brown)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(1900);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? DateTime(now.year - 18, 1, 1) : initial,
      firstDate: first,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.brown,
              onPrimary: AppColors.beige,
              surface: AppColors.beige,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _dateOfBirth = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    if (kDebugMode) {
      debugPrint('[EditProfile] save uid=$uid');
    }

    if (_dateOfBirth != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final d = DateTime(_dateOfBirth!.year, _dateOfBirth!.month, _dateOfBirth!.day);
      if (d.isAfter(today)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date of birth cannot be in the future.')),
          );
        }
        setState(() => _saving = false);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      try {
        await user.updateDisplayName(_usernameCtrl.text.trim());
      } catch (e) {
        if (kDebugMode) debugPrint('[EditProfile] updateDisplayName non-fatal: $e');
      }

      final emailForFirestore =
          (FirebaseAuth.instance.currentUser?.email ?? _displayEmail).trim();

      await _profileDs.mergeProfileFields(
        uid: uid,
        username: _usernameCtrl.text.trim(),
        email: emailForFirestore,
        phoneNumber: _phoneCtrl.text.trim(),
        gender: _gender,
        nationality: _nationalityCtrl.text.trim(),
        dateOfBirth: _dateOfBirth,
        profileImageUrl: _profileImageUrl.trim(),
      );

      if (kDebugMode) debugPrint('[EditProfile] Firestore profile update success uid=$uid');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (kDebugMode) debugPrint('[EditProfile] Firestore profile update failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.beige.withValues(alpha: 0.94),
        foregroundColor: AppColors.brown,
        elevation: 0,
        title: const Text('Edit profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: (_saving || _uploadingImage) ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: _loadingDoc
              ? const Center(child: CircularProgressIndicator(color: AppColors.brown))
              : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loadProfile,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                Center(child: _buildAvatarPreview()),
                                if (_profileImageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.center,
                                    child: TextButton(
                                      onPressed: (_saving || _uploadingImage)
                                          ? null
                                          : () async {
                                              setState(() => _profileImageUrl = '');
                                              try {
                                                await FirebaseAuth.instance.currentUser
                                                    ?.updatePhotoURL(null);
                                              } catch (_) {}
                                            },
                                      child: const Text(
                                        'Remove photo',
                                        style: TextStyle(color: AppColors.brown),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _usernameCtrl,
                                  decoration: _fieldDecoration('Username'),
                                  textCapitalization: TextCapitalization.words,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Username cannot be empty';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                InputDecorator(
                                  decoration: _fieldDecoration('Email').copyWith(
                                    suffixIcon: Icon(
                                      Icons.lock_outline,
                                      size: 20,
                                      color: AppColors.brown.withValues(alpha: 0.45),
                                    ),
                                    helperText: 'Sign-in email — not editable here',
                                    helperStyle: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.brown.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      _displayEmail.isEmpty ? '—' : _displayEmail,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.brown,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  decoration: _fieldDecoration('Phone number', hint: 'Optional'),
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]')),
                                  ],
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  validator: (v) {
                                    if (!_validPhone(v ?? '')) {
                                      return 'Use 7–15 digits (spaces and + allowed)';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                InputDecorator(
                                  decoration: _fieldDecoration('Gender'),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _genders.map((g) {
                                      final selected = _gender == g;
                                      return FilterChip(
                                        label: Text(g),
                                        selected: selected,
                                        showCheckmark: false,
                                        onSelected: _saving
                                            ? null
                                            : (v) {
                                                if (!v) return;
                                                setState(() => _gender = g);
                                              },
                                        selectedColor: AppColors.orange,
                                        backgroundColor: AppColors.beige.withValues(alpha: 0.85),
                                        side: BorderSide(
                                          color: selected
                                              ? AppColors.orange
                                              : AppColors.brown.withValues(alpha: 0.35),
                                          width: selected ? 2 : 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        labelStyle: TextStyle(
                                          color: selected ? AppColors.beige : AppColors.brown,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _nationalityCtrl,
                                  decoration: _fieldDecoration('Nationality', hint: 'Optional'),
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 16),
                                InputDecorator(
                                  decoration: _fieldDecoration('Date of birth', hint: 'Optional'),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _dateOfBirth == null
                                              ? 'Not set'
                                              : MaterialLocalizations.of(context).formatFullDate(
                                                    _dateOfBirth!,
                                                  ),
                                          style: const TextStyle(color: AppColors.brown),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(foregroundColor: AppColors.brown),
                                        onPressed: _saving ? null : _pickDob,
                                        child: const Text('Pick'),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(foregroundColor: AppColors.brown),
                                        onPressed: _saving || _dateOfBirth == null
                                            ? null
                                            : () => setState(() => _dateOfBirth = null),
                                        child: const Text('Clear'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: _saving ? null : _save,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brown,
                                    foregroundColor: AppColors.beige,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(_saving ? 'Saving…' : 'Save changes'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_saving || _uploadingImage)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(color: AppColors.beige),
                                    if (_uploadingImage && !_saving) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Uploading photo…',
                                        style: TextStyle(color: AppColors.beige.withValues(alpha: 0.95)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final url = _profileImageUrl.trim();
    final hasUrl = url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.beige.withValues(alpha: 0.9),
              backgroundImage: hasUrl ? NetworkImage(url) : null,
              onBackgroundImageError: hasUrl
                  ? (Object o, StackTrace? st) {
                      if (mounted) setState(() => _profileImageUrl = '');
                    }
                  : null,
              child: !hasUrl
                  ? Icon(Icons.person, size: 56, color: AppColors.brown.withValues(alpha: 0.55))
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: AppColors.orange,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: (_saving || _uploadingImage) ? null : _showImageSourceSheet,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _uploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.beige,
                            ),
                          )
                        : const Icon(Icons.edit, size: 18, color: AppColors.beige),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the pen to change your photo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}
