import 'package:flutter_test/flutter_test.dart';
import 'package:maseerah_app/util/feedback_reply_mailto.dart';

void main() {
  test('mailto encodes spaces as %20 not +', () {
    const body = '''مرحباً،

معك ملك من خدمة عملاء مسيرة، ونود الرد على تقييمكم لرحلتكم معنا:

Hello,

This is Malak from Masirah Customer Service, and we would like to respond to your feedback regarding your trip with us:

''';

    final uri = buildFeedbackReplyMailto(
      to: 'customer@example.com',
      subject: 'Feedback Response',
      body: body,
    );
    final s = uri.toString();

    expect(s, startsWith('mailto:customer@example.com?'));
    expect(s, isNot(contains('+')));
    expect(s, contains('Feedback%20Response'));
    expect(s, contains('%0A'));
    expect(Uri.decodeComponent(s.split('body=').last), body);
  });
}
