import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import '../models.dart';
import '../services/config.dart';

class OnboardingState {
  final int currentStep;
  final OnboardingData data;
  final AssessmentResult? result;
  
  // Selection/Loading states
  final bool isLoadingQuestions;
  final bool isLoadingReport;
  final String? questionLoadError;
  final String? reportLoadError;

  // Speech-to-Text & Recording states
  final bool isRecording;
  final bool isTranscribing;
  final int recordingSeconds;
  final int activeRecordingQuestion;
  final String wordsSpoken;
  final bool speechEnabled;

  OnboardingState({
    this.currentStep = 0,
    required this.data,
    this.result,
    this.isLoadingQuestions = false,
    this.isLoadingReport = false,
    this.questionLoadError,
    this.reportLoadError,
    this.isRecording = false,
    this.isTranscribing = false,
    this.recordingSeconds = 0,
    this.activeRecordingQuestion = 0,
    this.wordsSpoken = '',
    this.speechEnabled = false,
  });

  OnboardingState copyWith({
    int? currentStep,
    OnboardingData? data,
    AssessmentResult? result,
    bool? isLoadingQuestions,
    bool? isLoadingReport,
    String? questionLoadError,
    String? reportLoadError,
    bool? isRecording,
    bool? isTranscribing,
    int? recordingSeconds,
    int? activeRecordingQuestion,
    String? wordsSpoken,
    bool? speechEnabled,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      data: data ?? this.data,
      result: result ?? this.result,
      isLoadingQuestions: isLoadingQuestions ?? this.isLoadingQuestions,
      isLoadingReport: isLoadingReport ?? this.isLoadingReport,
      questionLoadError: questionLoadError ?? this.questionLoadError,
      reportLoadError: reportLoadError ?? this.reportLoadError,
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      recordingSeconds: recordingSeconds ?? this.recordingSeconds,
      activeRecordingQuestion: activeRecordingQuestion ?? this.activeRecordingQuestion,
      wordsSpoken: wordsSpoken ?? this.wordsSpoken,
      speechEnabled: speechEnabled ?? this.speechEnabled,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _recordingTimer;
  final PageController pageController = PageController();

  OnboardingNotifier() : super(OnboardingState(data: OnboardingData())) {
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final enabled = await _speech.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (errorNotification) => debugPrint('Speech error: $errorNotification'),
      );
      state = state.copyWith(speechEnabled: enabled);
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
    }
  }

  void nextPage() {
    if (state.currentStep < 11) {
      state = state.copyWith(currentStep: state.currentStep + 1);
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void prevPage() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void jumpToPage(int step) {
    state = state.copyWith(currentStep: step);
    pageController.jumpToPage(step);
  }

  // Update selections
  void setCompany(String company) {
    state.data.selectedCompany = company;
    state = state.copyWith(data: state.data);
  }

  void setExperience(String experience) {
    state.data.selectedExperience = experience;
    state = state.copyWith(data: state.data);
  }

  void setRoleFamily(String family) {
    state.data.selectedRoleFamily = family;
    state = state.copyWith(data: state.data);
  }

  void setRoleTrack(String track) {
    state.data.selectedRoleTrack = track;
    state = state.copyWith(data: state.data);
  }

  void setInterviewDate(String date) {
    state.data.selectedInterviewDate = date;
    state = state.copyWith(data: state.data);
  }

  // Speech Recording
  void startRecording(int qNumber) async {
    if (!state.speechEnabled) {
      await _initSpeech();
    }

    state = state.copyWith(
      isRecording: true,
      isTranscribing: false,
      recordingSeconds: 0,
      activeRecordingQuestion: qNumber,
      wordsSpoken: '',
    );

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(recordingSeconds: state.recordingSeconds + 1);
    });

    if (state.speechEnabled) {
      await _speech.listen(
        onResult: (result) {
          state = state.copyWith(wordsSpoken: result.recognizedWords);
        },
      );
    }
  }

  Future<void> stopAndTranscribe(int qNumber, TextEditingController controller) async {
    _recordingTimer?.cancel();
    if (state.speechEnabled) {
      await _speech.stop();
    }

    final spokenText = state.wordsSpoken;

    state = state.copyWith(
      isRecording: false,
      isTranscribing: true,
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    
    state = state.copyWith(isTranscribing: false);

    if (spokenText.isNotEmpty) {
      controller.text = spokenText;
    } else {
      // Trigger error state to be caught by UI listener or returned from function
      throw Exception('No speech detected. Please type your answer or try speaking again.');
    }
  }

  // API calls
  Future<void> fetchQuestions() async {
    state = state.copyWith(isLoadingQuestions: true, questionLoadError: null);

    final companyMapped = state.data.selectedCompany == 'General Behavioral' ? 'General' : state.data.selectedCompany;
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/v1/questions/filter?'
      'company=$companyMapped&'
      'role_family=${state.data.selectedRoleFamily}&'
      'role_level=${state.data.selectedExperience}&'
      'role_track=${state.data.selectedRoleTrack}'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 35));
      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        state.data.questions = List<Map<String, dynamic>>.from(list);
        state = state.copyWith(data: state.data, isLoadingQuestions: false);
        if (state.data.questions.isNotEmpty) {
          nextPage();
        } else {
          state = state.copyWith(questionLoadError: 'Backend returned an empty questions list.');
        }
      } else {
        state = state.copyWith(
          isLoadingQuestions: false,
          questionLoadError: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingQuestions: false,
        questionLoadError: 'Failed to fetch questions: $e',
      );
    }
  }

  Future<void> submitAssessment(String ans1, String ans2, String ans3) async {
    state.data.answer1 = ans1;
    state.data.answer2 = ans2;
    state.data.answer3 = ans3;
    state = state.copyWith(data: state.data, isLoadingReport: true, reportLoadError: null);

    // Proceed to loading screen first
    nextPage();

    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/assessment/evaluate');
    final payload = {
      "answers": [
        {
          "question_id": state.data.questions[0]["questionID"],
          "question": state.data.questions[0]["question"],
          "theme": state.data.questions[0]["questionCompetency"],
          "company": state.data.selectedCompany,
          "role_family": state.data.selectedRoleFamily,
          "role_track": state.data.selectedRoleTrack,
          "role_level": state.data.selectedExperience,
          "answer": state.data.answer1
        },
        {
          "question_id": state.data.questions[1]["questionID"],
          "question": state.data.questions[1]["question"],
          "theme": state.data.questions[1]["questionCompetency"],
          "company": state.data.selectedCompany,
          "role_family": state.data.selectedRoleFamily,
          "role_track": state.data.selectedRoleTrack,
          "role_level": state.data.selectedExperience,
          "answer": state.data.answer2
        },
        {
          "question_id": state.data.questions[2]["questionID"],
          "question": state.data.questions[2]["question"],
          "theme": state.data.questions[2]["questionCompetency"],
          "company": state.data.selectedCompany,
          "role_family": state.data.selectedRoleFamily,
          "role_track": state.data.selectedRoleTrack,
          "role_level": state.data.selectedExperience,
          "answer": state.data.answer3
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resJson = json.decode(response.body);
        final assessmentResult = AssessmentResult.fromJson(resJson);
        state = state.copyWith(
          result: assessmentResult,
          isLoadingReport: false,
        );
        nextPage();
      } else {
        state = state.copyWith(
          isLoadingReport: false,
          reportLoadError: 'Evaluation server returned status ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingReport: false,
        reportLoadError: 'Failed to evaluate assessment: $e',
      );
    }
  }

  void reset() {
    state = OnboardingState(data: OnboardingData());
    jumpToPage(1);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    pageController.dispose();
    super.dispose();
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
