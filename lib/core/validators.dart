class Validators {
  static bool validateEmail(String email) {
    // This pattern checks if email looks like: something@something.com
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email.trim());
  }

  /// Returns "admin" if email domain is @admin.com, otherwise "user".
  /// Used to route: admin → admin dashboard, user → user page (book, play, etc.).
  static String roleFromEmail(String email) {
    if (email.trim().toLowerCase().endsWith('@admin.com')) {
      return 'admin';
    }
    return 'user';
  }
}
