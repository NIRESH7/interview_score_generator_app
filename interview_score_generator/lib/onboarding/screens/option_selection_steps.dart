import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/onboarding_provider.dart';
import '../widgets.dart';

class CompanySelectionStep extends ConsumerWidget {
  const CompanySelectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final companies = [
      'Google',
      'Meta',
      'Amazon',
      'Microsoft',
      'General Behavioral'
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Which company are you\npreparing for?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E1B4B),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 36),
          ...companies.map((company) => OptionSelectorTile(
                label: company,
                isSelected: state.data.selectedCompany == company,
                leading: CompanyBrandEmblem(companyName: company),
                onTap: () {
                  notifier.setCompany(company);
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            onPressed: state.data.selectedCompany.isEmpty ? null : () => notifier.nextPage(),
          ),
        ],
      ),
    );
  }
}

class ExperienceSelectionStep extends ConsumerWidget {
  const ExperienceSelectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final levels = [
      'Entry',
      'Senior',
      'Staff / Manager',
      'Sr. Staff / Sr. Manager'
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'What is your\nexperience level?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E1B4B),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 36),
          ...levels.map((level) => OptionSelectorTile(
                label: level,
                isSelected: state.data.selectedExperience == level,
                onTap: () {
                  notifier.setExperience(level);
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            onPressed: state.data.selectedExperience.isEmpty ? null : () => notifier.nextPage(),
          ),
        ],
      ),
    );
  }
}

class RoleFamilySelectionStep extends ConsumerWidget {
  const RoleFamilySelectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final families = [
      {'val': 'Engineering', 'label': 'Engineering'},
      {'val': 'ProductManager', 'label': 'Product Management'},
      {'val': 'DataScience/ML', 'label': 'Data Science / ML'}
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'What is your\nrole family?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E1B4B),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 36),
          ...families.map((f) => OptionSelectorTile(
                label: f['label']!,
                isSelected: state.data.selectedRoleFamily == f['val'],
                onTap: () {
                  notifier.setRoleFamily(f['val']!);
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            onPressed: state.data.selectedRoleFamily.isEmpty ? null : () => notifier.nextPage(),
          ),
        ],
      ),
    );
  }
}

class RoleTrackSelectionStep extends ConsumerWidget {
  const RoleTrackSelectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final tracks = [
      {'val': 'IC', 'label': 'IC'},
      {'val': 'Manager', 'label': 'Manager'}
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'What is your\nrole track?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E1B4B),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 36),
          ...tracks.map((t) => OptionSelectorTile(
                label: t['label']!,
                isSelected: state.data.selectedRoleTrack == t['val'],
                onTap: () {
                  notifier.setRoleTrack(t['val']!);
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            isLoading: state.isLoadingQuestions,
            onPressed: state.data.selectedRoleTrack.isEmpty ? null : () => notifier.fetchQuestions(),
          ),
        ],
      ),
    );
  }
}

class DateSelectionStep extends ConsumerWidget {
  const DateSelectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final dates = [
      'This Week',
      'Within 2 Weeks',
      'Within 1 Month',
      'Just Exploring',
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'When is your\ninterview?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E1B4B),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 36),
          ...dates.map((date) => OptionSelectorTile(
                label: date,
                isSelected: state.data.selectedInterviewDate == date,
                onTap: () {
                  notifier.setInterviewDate(date);
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            onPressed: state.data.selectedInterviewDate.isEmpty ? null : () => notifier.nextPage(),
          ),
        ],
      ),
    );
  }
}
