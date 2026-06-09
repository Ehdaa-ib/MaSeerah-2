import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client-side checks: format, disposable domains, and MX records for the domain.
class EmailValidation {
  EmailValidation._();

  static final _disposableDomains = <String>{
    'tempmail.com',
    'guerrillamail.com',
    '10minutemail.com',
    'mailinator.com',
    'throwaway.email',
    'fakeinbox.com',
    'trashmail.com',
    'yopmail.com',
    'temp-mail.org',
    'getnada.com',
    'maildrop.cc',
    'sharklasers.com',
    'dispostable.com',
    'mail.tm',
    'email-fake.com',
    'tempail.com',
    'burnermail.io',
    'mailnesia.com',
    'mailcatch.com',
    'mohmal.com',
    'tmpmail.org',
    'tmpmail.net',
    '1secmail.com',
    '1secmail.org',
  };

  /// Returns null if OK, otherwise a user-facing error message.
  static String? validateFormat(String email) {
    final t = email.trim();
    if (t.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(t)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Blocks common throwaway domains.
  static String? validateNotDisposable(String email) {
    final domain = email.trim().split('@').last.toLowerCase();
    if (_disposableDomains.contains(domain)) {
      return 'Please use a real email address, not a temporary or disposable inbox.';
    }
    return null;
  }

  static const int _dnsNoError = 0;
  static const int _dnsNxDomain = 3;

  /// Returns null if the domain has MX, an error message if it definitively
  /// cannot receive mail, or (when [strict] is false) null if DNS could not
  /// be reached so password reset is not blocked by flaky networks.
  static Future<String?> validateDomainReceivesMail(
    String email, {
    required bool strict,
  }) async {
    final parts = email.trim().split('@');
    if (parts.length != 2) return 'Enter a valid email address';
    final domain = parts.last.toLowerCase();
    if (domain.isEmpty) return 'Enter a valid email address';

    final outcome = await _mxLookupWithFallback(domain);
    switch (outcome) {
      case _MxOutcome.hasMx:
        return null;
      case _MxOutcome.noMx:
        return 'This email domain cannot receive mail (no mail server found). '
            'Use a real email address.';
      case _MxOutcome.inconclusive:
        if (strict) {
          return 'Could not verify this email domain. Check your internet '
              'connection and try again.';
        }
        return null;
    }
  }

  static Future<_MxOutcome> _mxLookupWithFallback(String domain) async {
    for (final query in <Future<_MxOutcome?> Function(String)>[
      _queryGoogleMx,
      _queryCloudflareMx,
    ]) {
      try {
        final r = await query(domain).timeout(const Duration(seconds: 6));
        if (r != null) return r;
      } catch (_) {}
    }
    return _MxOutcome.inconclusive;
  }

  static Future<_MxOutcome?> _queryGoogleMx(String domain) async {
    final uri = Uri.parse(
      'https://dns.google/resolve?name=${Uri.encodeComponent(domain)}&type=MX',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    return _parseGoogleDnsMx(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<_MxOutcome?> _queryCloudflareMx(String domain) async {
    final uri = Uri.parse(
      'https://cloudflare-dns.com/dns-query?name=${Uri.encodeComponent(domain)}&type=MX',
    );
    final res = await http.get(
      uri,
      headers: {'accept': 'application/dns-json'},
    );
    if (res.statusCode != 200) return null;
    return _parseGoogleDnsMx(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Google and Cloudflare use the same JSON shape for `application/dns-json`.
  static _MxOutcome? _parseGoogleDnsMx(Map<String, dynamic> json) {
    final status = json['Status'] as int? ?? -1;
    if (status == _dnsNxDomain) {
      return _MxOutcome.noMx;
    }
    if (status != _dnsNoError) {
      return null;
    }
    final answer = json['Answer'];
    if (answer is! List || answer.isEmpty) {
      return _MxOutcome.noMx;
    }
    return _MxOutcome.hasMx;
  }
}

enum _MxOutcome { hasMx, noMx, inconclusive }
