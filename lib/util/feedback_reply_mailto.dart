/// Builds a mailto URI with [Uri.encodeComponent] (%20 spaces), not form-style (+).
Uri buildFeedbackReplyMailto({
  required String to,
  required String subject,
  required String body,
}) {
  final recipient = to.trim();
  final query =
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
  return Uri.parse('mailto:$recipient?$query');
}
