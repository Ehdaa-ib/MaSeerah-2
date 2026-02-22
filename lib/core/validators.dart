class Validators {
  static bool validateEmail(String email) {
    // This pattern checks if email looks like: something@something.com
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email.trim());
  }

  /// Admin emails that receive admin role. All others get "user" role.
  static const Set<String> _adminEmails = {
    'ehdaa.test@admin.com',
    'q.test@admin.com',
    'm.test@admin.com',
    'r.test@admin.com',
  };

  /// Returns "admin" if email is in the admin list, otherwise "user".
  /// Used to route: admin → admin dashboard, user → user page (book, play, etc.).
  static String roleFromEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (_adminEmails.contains(normalized)) {
      return 'admin';
    }
    return 'user';
  }
}
