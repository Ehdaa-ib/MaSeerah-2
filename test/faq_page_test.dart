import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maseerah_app/model/faq_item.dart';
import 'package:maseerah_app/view/faq/faqs_page.dart';

void main() {
  Widget _wrap(Widget child) => MaterialApp(home: child);

  testWidgets('FaqsPage shows loading while waiting with no data', (tester) async {
    final controller = StreamController<List<FaqItem>>();

    await tester.pumpWidget(_wrap(FaqsPage(faqsStream: controller.stream)));

    expect(find.text('FAQs'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await controller.close();
  });

  testWidgets('FaqsPage shows empty state when stream emits empty list', (tester) async {
    final controller = StreamController<List<FaqItem>>();

    await tester.pumpWidget(_wrap(FaqsPage(faqsStream: controller.stream)));

    controller.add(const <FaqItem>[]);
    await tester.pump();

    expect(find.text('No questions yet'), findsOneWidget);
    expect(find.text('Still have questions? Contact us at:'), findsOneWidget);
    expect(find.text('MaSeerah.help@gmail.com'), findsOneWidget);

    await controller.close();
  });

  testWidgets('FaqsPage renders FAQ items and expands to show answer', (tester) async {
    final controller = StreamController<List<FaqItem>>();

    await tester.pumpWidget(_wrap(FaqsPage(faqsStream: controller.stream)));

    controller.add(const [
      FaqItem(id: '1', question: 'What is MaSeerah?', answer: 'A journey app.'),
    ]);
    await tester.pump();

    expect(find.text('What is MaSeerah?'), findsOneWidget);
    expect(find.text('A journey app.'), findsNothing);

    await tester.tap(find.text('What is MaSeerah?'));
    await tester.pumpAndSettle();

    expect(find.text('A journey app.'), findsOneWidget);

    await controller.close();
  });

  testWidgets('FaqsPage shows error UI when stream emits error', (tester) async {
    final controller = StreamController<List<FaqItem>>();

    await tester.pumpWidget(_wrap(FaqsPage(faqsStream: controller.stream)));

    controller.addError(Exception('boom'));
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await controller.close();
  });
}

