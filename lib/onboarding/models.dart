class OnboardingData {
  String selectedCompany = '';
  String selectedExperience = '';
  String selectedInterviewDate = '';
  String answer1 = '';
  String answer2 = '';
  String answer3 = '';
}

class AssessmentResult {
  final double score;
  final String feedbackText;
  final List<String> strengths;
  final List<String> needsImprovement;
  final Map<String, double> traitScores;

  const AssessmentResult({
    required this.score,
    required this.feedbackText,
    required this.strengths,
    required this.needsImprovement,
    required this.traitScores,
  });

  factory AssessmentResult.generate(OnboardingData data) {
    int totalWords = 0;
    for (final ans in [data.answer1, data.answer2, data.answer3]) {
      totalWords += ans.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }

    double baseScore = 60.0;
    if (totalWords > 150) {
      baseScore = 78.0;
    } else if (totalWords > 80) {
      baseScore = 68.0;
    } else if (totalWords > 30) {
      baseScore = 62.0;
    } else {
      baseScore = 45.0;
    }

    final Map<String, double> traits = {
      'STAR Structure': totalWords > 120 ? 0.8 : (totalWords > 50 ? 0.6 : 0.4),
      'Leadership': data.answer2.length > 50 ? 0.75 : 0.45,
      'Ownership': data.answer1.length > 50 ? 0.85 : 0.55,
      'Impact': totalWords > 150 ? 0.7 : 0.35,
      'Communication': totalWords > 100 ? 0.8 : 0.5,
    };

    String feedback = 'Not Bad! Keep Improving';
    if (baseScore >= 80) {
      feedback = 'Excellent Job! You are ready';
    } else if (baseScore >= 70) {
      feedback = 'Good Effort! A few minor tweaks needed';
    } else if (baseScore >= 50) {
      feedback = 'Not Bad! Keep Improving';
    } else {
      feedback = 'More Practice Needed';
    }

    final strengths = <String>[];
    final needsImprove = <String>[];

    if (traits['Ownership']! >= 0.6) strengths.add('Ownership');
    if (traits['Leadership']! >= 0.6) strengths.add('Leadership');
    if (traits['Communication']! >= 0.6) strengths.add('Conflict Resolution');

    if (strengths.isEmpty) {
      strengths.addAll(['Ownership', 'Conflict Resolution']);
    }

    if (traits['Impact']! < 0.6) needsImprove.add('Impact Metrics');
    if (traits['STAR Structure']! < 0.6) needsImprove.add('STAR Structure');
    if (totalWords < 60) needsImprove.add('Conciseness');

    if (needsImprove.isEmpty) {
      needsImprove.add('STAR Structure');
    }

    return AssessmentResult(
      score: baseScore,
      feedbackText: feedback,
      strengths: strengths,
      needsImprovement: needsImprove,
      traitScores: traits,
    );
  }
}
