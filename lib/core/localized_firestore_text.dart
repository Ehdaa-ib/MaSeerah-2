import 'package:flutter/material.dart';

/// Picks a localized string from Firestore map data when you add optional
/// `name_en` / `name_ar` (or `description_en` / `description_ar`) fields later.
///
/// Falls back to [baseKey] (e.g. `name`, `description`) when bilingual keys are absent.
String localizedFirestoreString(
  Map<String, dynamic> data,
  String baseKey,
  Locale locale, {
  String suffixEn = '_en',
  String suffixAr = '_ar',
}) {
  final isAr = locale.languageCode == 'ar';
  final localizedKey = isAr ? '$baseKey$suffixAr' : '$baseKey$suffixEn';
  final localized = data[localizedKey];
  if (localized is String && localized.trim().isNotEmpty) {
    return localized.trim();
  }
  final base = data[baseKey];
  if (base is String && base.trim().isNotEmpty) {
    return base.trim();
  }
  return '';
}
