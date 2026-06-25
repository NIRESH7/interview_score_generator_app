import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/onboarding_provider.dart';
import 'screens/welcome_step.dart';
import 'screens/option_selection_steps.dart';
import 'screens/question_step.dart';
import 'screens/report_step.dart';

class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  final TextEditingController _q1Controller = TextEditingController();
  final TextEditingController _q2Controller = TextEditingController();
  final TextEditingController _q3Controller = TextEditingController();

  @override
  void dispose() {
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    super.dispose();
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Evaluation Failed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The AI service could not complete the evaluation. Please check your backend connection, API keys configuration, or internet connectivity.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                constraints: const BoxConstraints(maxHeight: 80),
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(int currentStep, OnboardingNotifier notifier) {
    if (currentStep == 0 || currentStep == 10 || currentStep == 11) {
      return null;
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
        onPressed: () => notifier.prevPage(),
      ),
      centerTitle: true,
      title: currentStep >= 7 && currentStep <= 9
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Question ${currentStep - 6} of 3',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (currentStep - 6) / 3,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    // Listen to error states
    ref.listen(onboardingProvider, (previous, next) {
      if (next.questionLoadError != null && next.questionLoadError != previous?.questionLoadError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.questionLoadError!),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (next.reportLoadError != null && next.reportLoadError != previous?.reportLoadError) {
        _showErrorDialog(context, next.reportLoadError!);
        notifier.prevPage(); // Go back to question 3 from loading page
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(state.currentStep, notifier),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: PageView(
              controller: notifier.pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                const WelcomeStep(), // 0
                const CompanySelectionStep(), // 1
                const ExperienceSelectionStep(), // 2
                const RoleFamilySelectionStep(), // 3
                const RoleTrackSelectionStep(), // 4
                const DateSelectionStep(), // 5
                const IntroStep(), // 6
                QuestionStep(
                  qNumber: 1,
                  controller: _q1Controller,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    notifier.nextPage();
                  },
                ), // 7
                QuestionStep(
                  qNumber: 2,
                  controller: _q2Controller,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    notifier.nextPage();
                  },
                ), // 8
                QuestionStep(
                  qNumber: 3,
                  controller: _q3Controller,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    notifier.submitAssessment(
                      _q1Controller.text,
                      _q2Controller.text,
                      _q3Controller.text,
                    );
                  },
                ), // 9
                const AnalyzingStep(), // 10
                ReportStep(
                  onReset: () {
                    _q1Controller.clear();
                    _q2Controller.clear();
                    _q3Controller.clear();
                    notifier.reset();
                  },
                ), // 11
              ],
            ),
          ),
        ),
      ),
    );
  }
}
