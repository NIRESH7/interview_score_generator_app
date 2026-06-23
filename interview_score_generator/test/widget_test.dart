import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:interview_score_generator/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Smoke test - App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const InterviewApp());
    await tester.pumpAndSettle();

    expect(find.text('InterviewReady AI'), findsOneWidget);
  });
}
