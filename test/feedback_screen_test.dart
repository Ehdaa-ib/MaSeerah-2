import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maseerah_app/view/feedback/feedback_screen.dart';

import 'test_asset_bundle.dart';

void main() {
  Widget _wrap(Widget child) {
    return DefaultAssetBundle(
      bundle: TestPngAssetBundle(),
      child: MaterialApp(home: child),
    );
  }

  Finder _overallStars() => find.descendant(
        of: find.ancestor(
          of: find.text('Overall'),
          matching: find.byType(Column),
        ),
        matching: find.byIcon(Icons.star_border),
      );

  testWidgets('FeedbackScreen renders title and submit button', (tester) async {
    await tester.pumpWidget(_wrap(const FeedbackScreen(journeyId: 'j1')));

    expect(find.text('Journey Feedback'), findsOneWidget);
    expect(find.text('Submit Review'), findsOneWidget);
    expect(find.text('Overall'), findsOneWidget);
    expect(find.text('Specifics'), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget);
  });

  testWidgets('Submit requires Overall rating only', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FeedbackScreen(
          journeyId: 'j1',
          currentUserId: () => 'u1',
        ),
      ),
    );

    await tester.tap(find.text('Submit Review'));
    await tester.pump();

    expect(find.text('Please rate Overall (1–5).'), findsOneWidget);
  });

  testWidgets('With Overall rating set, signed-out user sees sign-in error', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FeedbackScreen(
          journeyId: 'j1',
          currentUserId: () => null,
        ),
      ),
    );

    // Tap the 5th overall star (index 4).
    final stars = _overallStars();
    expect(stars, findsWidgets);
    await tester.tap(stars.at(4));
    await tester.pump();

    await tester.tap(find.text('Submit Review'));
    await tester.pump();

    expect(find.text('Please sign in to submit feedback.'), findsOneWidget);
  });

  testWidgets('Comments field accepts input', (tester) async {
    await tester.pumpWidget(_wrap(const FeedbackScreen(journeyId: 'j1')));

    await tester.enterText(find.byType(TextFormField), 'Nice journey');
    await tester.pump();

    expect(find.text('Nice journey'), findsOneWidget);
  });
}

