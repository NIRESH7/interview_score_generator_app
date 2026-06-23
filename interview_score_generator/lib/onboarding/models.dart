class OnboardingData {
  String selectedCompany = '';
  String selectedExperience = ''; // maps to roleLevel
  String selectedRoleFamily = '';
  String selectedRoleTrack = '';
  String selectedInterviewDate = '';
  
  // Storing fetched question details
  List<Map<String, dynamic>> questions = [];
  
  String answer1 = '';
  String answer2 = '';
  String answer3 = '';
}

class QuestionEvaluation {
  final String questionTheme;
  final String targetCompany;
  final String role;
  final String roleTrack;
  final String roleLevel;
  final int readinessScore;
  final String readinessLabel;
  final String band;
  final String signal;
  final int totalScore;
  final Map<String, TraitScore> parameters;
  final List<String> strengths;
  final List<String> improvements;

  QuestionEvaluation({
    required this.questionTheme,
    required this.targetCompany,
    required this.role,
    required this.roleTrack,
    required this.roleLevel,
    required this.readinessScore,
    required this.readinessLabel,
    required this.band,
    required this.signal,
    required this.totalScore,
    required this.parameters,
    required this.strengths,
    required this.improvements,
  });

  factory QuestionEvaluation.fromJson(Map<String, dynamic> json) {
    final paramsJson = json['parameters'] as Map<String, dynamic>? ?? {};
    final params = <String, TraitScore>{};
    paramsJson.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        params[key] = TraitScore(
          name: val['name']?.toString() ?? '',
          score: (val['score'] as num?)?.toDouble() ?? 0.0,
        );
      }
    });

    return QuestionEvaluation(
      questionTheme: json['question_theme']?.toString() ?? '',
      targetCompany: json['target_company']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      roleTrack: json['role_track']?.toString() ?? '',
      roleLevel: json['role_level']?.toString() ?? '',
      readinessScore: (json['readiness_score'] as num?)?.toInt() ?? 0,
      readinessLabel: json['readiness_label']?.toString() ?? '',
      band: json['band']?.toString() ?? '',
      signal: json['signal']?.toString() ?? '',
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      parameters: params,
      strengths: List<String>.from(json['strengths'] ?? []),
      improvements: List<String>.from(json['improvements'] ?? []),
    );
  }
}

class TraitScore {
  final String name;
  final double score; // 1-5 scale

  const TraitScore({required this.name, required this.score});
}

class AssessmentResult {
  final int overallReadinessScore;
  final String overallReadinessLabel;
  final String overallBand;
  final String overallSignal;
  final int overallTotalScore;
  final int overallMaxScore;
  final List<QuestionEvaluation> results;
  final List<String> overallStrengths;
  final List<String> overallImprovements;

  const AssessmentResult({
    required this.overallReadinessScore,
    required this.overallReadinessLabel,
    required this.overallBand,
    required this.overallSignal,
    required this.overallTotalScore,
    required this.overallMaxScore,
    required this.results,
    required this.overallStrengths,
    required this.overallImprovements,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List? ?? [];
    final evaluations = resultsList
        .map((item) => QuestionEvaluation.fromJson(item as Map<String, dynamic>))
        .toList();

    return AssessmentResult(
      overallReadinessScore: (json['overall_readiness_score'] as num?)?.toInt() ?? 0,
      overallReadinessLabel: json['overall_readiness_label']?.toString() ?? '',
      overallBand: json['overall_band']?.toString() ?? '',
      overallSignal: json['overall_signal']?.toString() ?? '',
      overallTotalScore: (json['overall_total_score'] as num?)?.toInt() ?? 0,
      overallMaxScore: (json['overall_max_score'] as num?)?.toInt() ?? 75,
      results: evaluations,
      overallStrengths: List<String>.from(json['overall_strengths'] ?? []),
      overallImprovements: List<String>.from(json['overall_improvements'] ?? []),
    );
  }
}
