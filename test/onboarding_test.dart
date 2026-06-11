import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:interview_score_generator/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Onboarding Flow complete walkthrough test', (WidgetTester tester) async {
    await tester.pumpWidget(const InterviewApp());
    await tester.pumpAndSettle();

    expect(find.text('InterviewReady AI'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Which company are you'), findsOneWidget);
    final googleTile = find.text('Google');
    expect(googleTile, findsOneWidget);
    await tester.tap(googleTile);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('experience level?'), findsOneWidget);
    final experienceTile = find.text('3 - 5 Years');
    expect(experienceTile, findsOneWidget);
    await tester.tap(experienceTile);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('interview?'), findsOneWidget);
    final dateTile = find.text('Within 2 Weeks');
    expect(dateTile, findsOneWidget);
    await tester.tap(dateTile);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Free Interview'), findsOneWidget);
    expect(find.text('Start Assessment'), findsOneWidget);

    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Tell me about a conflict with a teammate.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'This is my conflict answer that is long enough.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Tell me about a time you showed leadership.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'This is my leadership answer for the second question.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Describe a significant failure and what you learned.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'This is my failure answer for the final question.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate Report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('Analyzing Your'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.textContaining('Readiness Score'), findsOneWidget);
    expect(find.text('View Full Report'), findsOneWidget);

    await tester.tap(find.text('View Full Report'));
    await tester.pumpAndSettle();

    expect(find.text('CANDIDATE PROFILE'), findsOneWidget);
  });
}
