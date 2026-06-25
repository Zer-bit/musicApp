import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezsic/user_tutorial.dart';

void main() {
  testWidgets('UserTutorialDialog rendering test', (WidgetTester tester) async {
    // Build UserTutorialDialog inside a MaterialApp helper
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserTutorialDialog(),
        ),
      ),
    );

    // Verify that the header title "Jezsic Guide" is found
    expect(find.text('Jezsic Guide'), findsOneWidget);

    // Verify that the first slide title "Welcome to Jezsic" is found
    expect(find.text('Welcome to Jezsic'), findsOneWidget);

    // Verify that the 'Next' button is displayed
    expect(find.text('Next'), findsOneWidget);

    // Tap the 'Next' button to advance the slide
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Verify that the second slide title "Local Library" is found
    expect(find.text('Local Library'), findsOneWidget);

    // Verify that the 'Back' button is now displayed
    expect(find.text('Back'), findsOneWidget);

    // Tap the 'Back' button to return to the first slide
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    // Verify that we are back to the first slide
    expect(find.text('Welcome to Jezsic'), findsOneWidget);
  });

  testWidgets('UserTutorialDialog stress navigation test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserTutorialDialog(),
        ),
      ),
    );

    // Stress test: Navigate back and forth through all 5 slides repeatedly
    // This triggers 80 page transitions to ensure layout and memory stability.
    for (int run = 0; run < 10; run++) {
      // Go to last slide
      for (int i = 0; i < 4; i++) {
        expect(find.text('Next'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      // We should be on slide 5 (Smart Features), where the button says 'Finish'
      expect(find.text('Finish'), findsOneWidget);

      // Go back to first slide
      for (int i = 0; i < 4; i++) {
        expect(find.text('Back'), findsOneWidget);
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
      }

      // We should be back on slide 1
      expect(find.text('Welcome to Jezsic'), findsOneWidget);
    }
  });
}
