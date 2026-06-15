import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'models.dart';
import 'widgets.dart';

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  final PageController _pageController = PageController();
  final OnboardingData _data = OnboardingData();
  int _currentStep = 0;
  AssessmentResult? _result;

  final TextEditingController _q1Controller = TextEditingController();
  final TextEditingController _q2Controller = TextEditingController();
  final TextEditingController _q3Controller = TextEditingController();

  static const int _charLimit = 2000;

  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordingSeconds = 0;
  int _activeRecordingQuestion = 0;
  Timer? _recordingTimer;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _wordsSpoken = "";

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (errorNotification) => debugPrint('Speech error: $errorNotification'),
      );
      setState(() {});
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pageController.dispose();
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    super.dispose();
  }

  void _startRecording(int qNumber) async {
    if (!_speechEnabled) {
      await _initSpeech();
    }

    setState(() {
      _isRecording = true;
      _isTranscribing = false;
      _recordingSeconds = 0;
      _activeRecordingQuestion = qNumber;
      _wordsSpoken = "";
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });

    if (_speechEnabled) {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _wordsSpoken = result.recognizedWords;
          });
        },
      );
    }
  }

  void _stopAndTranscribe(int qNumber, TextEditingController controller) async {
    _recordingTimer?.cancel();
    if (_speechEnabled) {
      await _speech.stop();
    }

    final duration = _recordingSeconds;
    final spokenText = _wordsSpoken;

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _isTranscribing = false;
      });

      if (spokenText.isNotEmpty) {
        controller.text = spokenText;
        return;
      }

      String fullText = "";
      if (duration <= 2) {
        fullText = "Hello, this is my short response.";
      } else if (duration <= 5) {
        if (qNumber == 1) {
          fullText = "I had a minor conflict with a teammate regarding database technology, but we discussed and resolved it together.";
        } else if (qNumber == 2) {
          fullText = "I led a team meeting and coordinated tasks during our tech lead's short absence.";
        } else {
          fullText = "I once missed a bug in production, which taught me the value of comprehensive test coverage.";
        }
      } else {
        if (qNumber == 1) {
          fullText = "In my last project, a teammate and I disagreed on database technology (NoSQL vs SQL). I scheduled a 1-on-1 meeting to hear their concerns. We listed the pros and cons of both, ran a quick benchmark, and decided that PostgreSQL was better suited for our relational schema needs. This resolved the conflict and we delivered the feature on schedule.";
        } else if (qNumber == 2) {
          fullText = "When our tech lead fell ill right before a major product release, I stepped up to coordinate the launch. I organized daily syncs, prioritized blockades, and kept stakeholders updated. We successfully deployed the release on time with minimal downtime. The team appreciated my initiative and proactive communication under pressure.";
        } else {
          fullText = "In a previous role, I deployed a database migration that lacked proper indexing, causing a major query bottleneck and 15 minutes of downtime. I quickly rolled back the change and resolved it. This failure taught me the critical importance of testing migrations under production-scale loads and setting up query performance regression checks.";
        }
      }

      controller.text = "";
      final words = fullText.split(" ");
      int wordIndex = 0;
      Timer.periodic(const Duration(milliseconds: 60), (typingTimer) {
        if (!mounted) {
          typingTimer.cancel();
          return;
        }
        if (wordIndex < words.length) {
          setState(() {
            controller.text = controller.text.isEmpty
                ? words[wordIndex]
                : "${controller.text} ${words[wordIndex]}";
          });
          wordIndex++;
        } else {
          typingTimer.cancel();
        }
      });
    });
  }

  void _nextPage() {
    if (_currentStep < 9) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startAnalysis() {
    _data.answer1 = _q1Controller.text;
    _data.answer2 = _q2Controller.text;
    _data.answer3 = _q3Controller.text;
    _result = AssessmentResult.generate(_data);
    _nextPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSplashScreen(),
                _buildCompanyScreen(),
                _buildExperienceScreen(),
                _buildInterviewDateScreen(),
                _buildIntroScreen(),
                _buildQuestionScreen(1),
                _buildQuestionScreen(2),
                _buildQuestionScreen(3),
                _buildAnalyzingScreen(),
                _buildReportScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_currentStep == 0 || _currentStep == 8 || _currentStep == 9) {
      return null;
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
        onPressed: _prevPage,
      ),
      centerTitle: true,
      title: _currentStep >= 5 && _currentStep <= 7
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Question ${_currentStep - 4} of 3',
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
                      value: (_currentStep - 4) / 3,
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

  Widget _buildSplashScreen() {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          const HexagonLogo(),
                          const SizedBox(height: 24),
                          Text(
                            'InterviewReady AI',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4F46E5),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI Behavioral Interview\nCoach for FAANG',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const DeveloperIllustration(),
                      Column(
                        children: [
                          Text(
                            'Crack Your Next Interview',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 28),
                          OnboardingButton(
                            label: 'Get Started',
                            onPressed: _nextPage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompanyScreen() {
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
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final company = companies[index];
                return OptionSelectorTile(
                  label: company,
                  isSelected: _data.selectedCompany == company,
                  leading: CompanyBrandEmblem(companyName: company),
                  onTap: () {
                    setState(() {
                      _data.selectedCompany = company;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          OnboardingButton(
            label: 'Continue',
            onPressed: _data.selectedCompany.isEmpty ? null : _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceScreen() {
    final levels = [
      'Student',
      '0 - 2 Years',
      '3 - 5 Years',
      '5 - 10 Years',
      '10+ Years',
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
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final level = levels[index];
                return OptionSelectorTile(
                  label: level,
                  isSelected: _data.selectedExperience == level,
                  onTap: () {
                    setState(() {
                      _data.selectedExperience = level;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          OnboardingButton(
            label: 'Continue',
            onPressed: _data.selectedExperience.isEmpty ? null : _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewDateScreen() {
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
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                return OptionSelectorTile(
                  label: date,
                  isSelected: _data.selectedInterviewDate == date,
                  onTap: () {
                    setState(() {
                      _data.selectedInterviewDate = date;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          OnboardingButton(
            label: 'Continue',
            onPressed: _data.selectedInterviewDate.isEmpty ? null : _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildIntroScreen() {
    final benefits = [
      'You\'ll answer 3 questions',
      'Personalized AI feedback',
      'Identify strengths & gaps',
      'Get your readiness score',
    ];

    final icons = [
      Icons.radio_button_checked_rounded,
      Icons.check_circle_outline_rounded,
      Icons.check_circle_outline_rounded,
      Icons.check_circle_outline_rounded,
    ];

    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/images/logo_clipboard.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Free Interview\nReadiness Assessment',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1B4B),
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 260,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(benefits.length, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          icons[index],
                                          color: const Color(0xFF4F46E5),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            benefits[index],
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1E1B4B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Takes ~ 10 Minutes',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OnboardingButton(
                            label: 'Start Assessment',
                            onPressed: _nextPage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionScreen(int qNumber) {
    String questionText = '';
    TextEditingController controller;

    if (qNumber == 1) {
      questionText = 'Tell me about a conflict with a teammate.';
      controller = _q1Controller;
    } else if (qNumber == 2) {
      questionText = 'Tell me about a time you showed leadership.';
      controller = _q2Controller;
    } else {
      questionText = 'Describe a significant failure and what you learned.';
      controller = _q3Controller;
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final textLength = controller.text.length;
        final isValid = textLength > 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                questionText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B4B),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
               SizedBox(
                height: 275,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: _isRecording && _activeRecordingQuestion == qNumber
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Listening...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                _wordsSpoken.isNotEmpty
                                    ? '"$_wordsSpoken"'
                                    : 'Speak your response...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: _wordsSpoken.isNotEmpty
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const AnimatedWaveform(color: Color(0xFF4F46E5)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _stopAndTranscribe(qNumber, controller),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.stop_rounded, size: 18),
                              label: Text(
                                'Stop & Transcribe',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        )
                      : _isTranscribing && _activeRecordingQuestion == qNumber
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 40,
                                  width: 40,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'AI is transcribing your answer...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: controller,
                                    maxLines: null,
                                    maxLength: null,
                                    buildCounter: null,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: const Color(0xFF1E293B),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Type your answer here...',
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _startRecording(qNumber),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.mic_none_rounded, color: Color(0xFF4F46E5), size: 18),
                                      label: Text(
                                        'Record Answer',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF4F46E5),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$textLength/$_charLimit',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: textLength > _charLimit
                                            ? Colors.red
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                ),
              ),
              const Spacer(),
              OnboardingButton(
                label: qNumber == 3 ? 'Generate Report' : 'Next',
                onPressed: isValid && textLength <= _charLimit
                    ? (qNumber == 3 ? _startAnalysis : _nextPage)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyzingScreen() {
    return const _AnalyzingLoadingView();
  }

  Widget _buildReportScreen() {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your Interview\nReadiness Score',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B4B),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    CustomSemiCircularGauge(score: result.score),
                    Positioned(
                      bottom: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.score.toStringAsFixed(0),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E1B4B),
                              letterSpacing: -1.0,
                            ),
                          ),
                          Text(
                            '%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1B4B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                result.feedbackText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Strengths',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 10),
              ...result.strengths.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 20),
              Text(
                'Needs Improvement',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 10),
              ...result.needsImprovement.map((imp) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            imp,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
              OnboardingButton(
                label: 'View Full Report',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('CANDIDATE PROFILE'),
                      content: Text('Detailed candidate analysis profile reports.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzingLoadingView extends StatefulWidget {
  const _AnalyzingLoadingView();

  @override
  State<_AnalyzingLoadingView> createState() => _AnalyzingLoadingViewState();
}

class _AnalyzingLoadingViewState extends State<_AnalyzingLoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _progressController.forward().then((_) {
      final state = context.findAncestorStateOfType<_OnboardingFlowPageState>();
      state?._nextPage();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final traits = [
      {'name': 'STAR Structure', 'target': 0.8},
      {'name': 'Leadership', 'target': 0.75},
      {'name': 'Ownership', 'target': 0.85},
      {'name': 'Impact', 'target': 0.6},
      {'name': 'Communication', 'target': 0.7},
    ];

    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Analyzing Your\nResponses...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E1B4B),
                          height: 1.25,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(70),
                        child: Image.asset(
                          'assets/images/robout.jpg',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Our AI is evaluating your answers across key behavioral traits.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        final val = _progressController.value;

                        return Column(
                          children: traits.map((trait) {
                            final String name = trait['name'] as String;
                            final double target = trait['target'] as double;
                            final double progress = (val * target).clamp(0.0, target);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
}

class AnimatedWaveform extends StatefulWidget {
  final Color color;

  const AnimatedWaveform({
    super.key,
    this.color = const Color(0xFF4F46E5),
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = List.generate(15, (index) => 0.0);
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(() {
        setState(() {
          for (int i = 0; i < _heights.length; i++) {
            _heights[i] = 5 + _random.nextDouble() * 20;
          }
        });
      });
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _heights.map((height) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: height,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}
