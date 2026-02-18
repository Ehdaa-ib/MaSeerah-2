class Validators {
  static bool validateEmail(String email) {
    // This pattern checks if email looks like: something@something.com
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email.trim());
  }
}
