import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../util/wait_for_auth.dart';
import '../../../core/error_messages.dart';
import '../../../data/firebase/user_data_source.dart';
import '../../../data/repoImp/user_repository_firebase.dart';
import '../../../model/app_user.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _repo = UserRepositoryFirebase(UserDataSource());
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<AppUser> _users = const [];

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
      final users = await _repo.getAll();
      users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _users = users;
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

  Future<void> _editUser(AppUser user) async {
    final result = await showDialog<_UserEditResult>(
      context: context,
      builder: (_) => _UserEditDialog(user: user),
    );
    if (result == null) return;

    try {
      await _repo.update(
        userId: user.userId,
        data: {
          'name': result.name.trim(),
          'role': result.role,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated'),
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
        ? _users
        : _users.where((u) {
            return u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.role.toLowerCase().contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SearchField(controller: _searchController, hintText: 'Search users'),
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
          else if (_users.isEmpty)
            const _EmptyState(
              icon: Icons.people_alt_rounded,
              title: 'No users yet',
              subtitle: 'Users will appear from the Firestore users collection.',
            )
          else if (visible.isEmpty)
            const _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results',
              subtitle: 'Try a different search term.',
            )
          else
            ...visible.map(
              (u) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppColors.beige,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.orange,
                    child: const Icon(Icons.person, color: AppColors.beige),
                  ),
                  title: Text(
                    u.name,
                    style: const TextStyle(
                      color: AppColors.brown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${u.email}\nRole: ${u.role}',
                    style: const TextStyle(color: AppColors.brown),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Edit user',
                    onPressed: () => _editUser(u),
                    icon: const Icon(Icons.edit_rounded, color: AppColors.brown),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            'Couldn’t load users',
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

class _UserEditDialog extends StatefulWidget {
  final AppUser user;
  const _UserEditDialog({required this.user});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _role;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _role = widget.user.role.trim().isEmpty ? 'user' : widget.user.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _UserEditResult(
        name: _nameController.text,
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.beige,
      title: const Text(
        'Edit user',
        style: TextStyle(color: AppColors.brown, fontWeight: FontWeight.w800),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LabeledTextField(
              label: 'Email',
              child: TextFormField(
                initialValue: widget.user.email,
                enabled: false,
                style: const TextStyle(color: AppColors.brown),
                decoration: _inputDecoration(hintText: ''),
              ),
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Name',
              child: TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.brown),
                decoration: _inputDecoration(hintText: 'Enter name'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Role',
              child: DropdownButtonFormField<String>(
                value: (_role == 'admin' || _role == 'user') ? _role : 'user',
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('user')),
                  DropdownMenuItem(value: 'admin', child: Text('admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'user'),
                decoration: _inputDecoration(hintText: ''),
                dropdownColor: AppColors.beige,
                style: const TextStyle(color: AppColors.brown),
              ),
            ),
          ],
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

class _UserEditResult {
  final String name;
  final String role;
  const _UserEditResult({required this.name, required this.role});
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

