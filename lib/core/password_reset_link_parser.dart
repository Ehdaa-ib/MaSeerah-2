/// Extracts Firebase Auth `oobCode` from a pasted reset link or returns the
/// raw value if the user pasted the code alone.
String? extractOobCodeFromPasswordResetInput(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;

  for (final candidate in <String>[t, t.replaceAll(RegExp(r'\s+'), '')]) {
    final uri = Uri.tryParse(candidate);
    if (uri != null) {
      final c = uri.queryParameters['oobCode'];
      if (c != null && c.isNotEmpty) return c;
    }
  }

  final match = RegExp(r'[?&]oobCode=([^&]+)').firstMatch(t);
  if (match != null && match.groupCount >= 1) {
    final encoded = match.group(1)!;
    try {
      return Uri.decodeQueryComponent(encoded);
    } catch (_) {
      return encoded;
    }
  }

  return t;
}
