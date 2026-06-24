import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
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

  // Active tab in Report Screen: 0 for Q1, 1 for Q2, 2 for Q3
  int _selectedReportTab = 0;

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
  
  bool _isLoadingQuestions = false;

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

      // Safe fallbacks for typing simulation
      String fullText = "";
      if (duration <= 2) {
        fullText = "Hello, this is my response to the interview question.";
      } else {
        if (qNumber == 1) {
          fullText = "In my last role, a cross-functional teammate and I disagreed on database technology selection. I scheduled a constructive 1-on-1 meeting to hear their concerns. We listed the pros and cons, ran a benchmark, and decided that PostgreSQL was better suited. This resolved the conflict and we delivered the feature on schedule with 100% test coverage.";
        } else if (qNumber == 2) {
          fullText = "When our team leader fell ill right before a major release, I stepped up to coordinate the launch. I organized daily syncs, prioritized blockades, and kept stakeholders updated. We successfully deployed the release on time with zero downtime, and the team appreciated my initiative and proactive communication under pressure.";
        } else {
          fullText = "In a previous role, I deployed a database migration that lacked proper indexing, causing a query bottleneck and 15 minutes of downtime. I quickly rolled back the change and resolved it. This failure taught me the critical importance of testing migrations under production-scale loads and setting up query checks.";
        }
      }

      controller.text = "";
      final words = fullText.split(" ");
      int wordIndex = 0;
      Timer.periodic(const Duration(milliseconds: 50), (typingTimer) {
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
    if (_currentStep < 11) {
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

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoadingQuestions = true;
    });

    final companyMapped = _data.selectedCompany == 'General Behavioral' ? 'General' : _data.selectedCompany;
    final url = Uri.parse(
      'http://localhost:8000/api/v1/questions/filter?'
      'company=$companyMapped&'
      'role_family=${_data.selectedRoleFamily}&'
      'role_level=${_data.selectedExperience}&'
      'role_track=${_data.selectedRoleTrack}'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        _data.questions = List<Map<String, dynamic>>.from(list);
      }
    } catch (e) {
      debugPrint('Failed to fetch questions from backend: $e. Falling back to default questions.');
    }

    // Default Fallbacks if list is empty or request failed
    if (_data.questions.isEmpty) {
      _data.questions = [
        {
          "questionID": 1,
          "question": "Tell me about a time you made a mistake.",
          "companyApplicable": _data.selectedCompany,
          "roleFamily": _data.selectedRoleFamily,
          "roleLevel": _data.selectedExperience,
          "roleTrack": _data.selectedRoleTrack,
          "prepMode": "This week",
          "questionCompetency": "LEARNING_AND_GROWTH"
        },
        {
          "questionID": 2,
          "question": "Tell me about a time you disagreed with a teammate and how you resolved it.",
          "companyApplicable": _data.selectedCompany,
          "roleFamily": _data.selectedRoleFamily,
          "roleLevel": _data.selectedExperience,
          "roleTrack": _data.selectedRoleTrack,
          "prepMode": "This week",
          "questionCompetency": "CONFLICT_RESOLUTION"
        },
        {
          "questionID": 3,
          "question": "Tell me about a time you took the lead on a challenging project.",
          "companyApplicable": _data.selectedCompany,
          "roleFamily": _data.selectedRoleFamily,
          "roleLevel": _data.selectedExperience,
          "roleTrack": _data.selectedRoleTrack,
          "prepMode": "This week",
          "questionCompetency": "OWNERSHIP"
        }
      ];
    }

    setState(() {
      _isLoadingQuestions = false;
    });
    _nextPage();
  }

  Future<void> _submitAssessment() async {
    _data.answer1 = _q1Controller.text;
    _data.answer2 = _q2Controller.text;
    _data.answer3 = _q3Controller.text;

    // Go to analyzing screen
    _nextPage();

    final url = Uri.parse('http://localhost:8000/api/v1/assessment/evaluate');
    final payload = {
      "answers": [
        {
          "question_id": _data.questions[0]["questionID"],
          "question": _data.questions[0]["question"],
          "theme": _data.questions[0]["questionCompetency"],
          "company": _data.selectedCompany,
          "role_family": _data.selectedRoleFamily,
          "role_track": _data.selectedRoleTrack,
          "role_level": _data.selectedExperience,
          "answer": _data.answer1
        },
        {
          "question_id": _data.questions[1]["questionID"],
          "question": _data.questions[1]["question"],
          "theme": _data.questions[1]["questionCompetency"],
          "company": _data.selectedCompany,
          "role_family": _data.selectedRoleFamily,
          "role_track": _data.selectedRoleTrack,
          "role_level": _data.selectedExperience,
          "answer": _data.answer2
        },
        {
          "question_id": _data.questions[2]["questionID"],
          "question": _data.questions[2]["question"],
          "theme": _data.questions[2]["questionCompetency"],
          "company": _data.selectedCompany,
          "role_family": _data.selectedRoleFamily,
          "role_track": _data.selectedRoleTrack,
          "role_level": _data.selectedExperience,
          "answer": _data.answer3
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _result = AssessmentResult.fromJson(data);
        });
      } else {
        throw Exception('Server responded with status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to submit evaluation to backend: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AI Evaluation Failed',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
                        e.toString(),
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
        _prevPage();
      }
    }

    if (_result != null) {
      // Advance from analyzing screen to report screen
      _nextPage();
    }
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
                _buildSplashScreen(),       // 0
                _buildCompanyScreen(),      // 1
                _buildExperienceScreen(),   // 2
                _buildRoleFamilyScreen(),   // 3 (NEW)
                _buildRoleTrackScreen(),    // 4 (NEW)
                _buildInterviewDateScreen(),// 5
                _buildIntroScreen(),        // 6
                _buildQuestionScreen(1),    // 7
                _buildQuestionScreen(2),    // 8
                _buildQuestionScreen(3),    // 9
                _buildAnalyzingScreen(),    // 10
                _buildReportScreen(),       // 11
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_currentStep == 0 || _currentStep == 10 || _currentStep == 11) {
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
      title: _currentStep >= 7 && _currentStep <= 9
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Question ${_currentStep - 6} of 3',
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
                      value: (_currentStep - 6) / 3,
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
          const SizedBox(height: 36),
          ...companies.map((company) => OptionSelectorTile(
                label: company,
                isSelected: _data.selectedCompany == company,
                leading: CompanyBrandEmblem(companyName: company),
                onTap: () {
                  setState(() {
                    _data.selectedCompany = company;
                  });
                },
              )),
          const Spacer(),
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
                isSelected: _data.selectedExperience == level,
                onTap: () {
                  setState(() {
                    _data.selectedExperience = level;
                  });
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            onPressed: _data.selectedExperience.isEmpty ? null : _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFamilyScreen() {
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
                isSelected: _data.selectedRoleFamily == f['val'],
                onTap: () {
                  setState(() {
                    _data.selectedRoleFamily = f['val']!;
                  });
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            onPressed: _data.selectedRoleFamily.isEmpty ? null : _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTrackScreen() {
    final tracks = [
      {'val': 'IC', 'label': 'Individual Contributor (IC)'},
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
                isSelected: _data.selectedRoleTrack == t['val'],
                onTap: () {
                  setState(() {
                    _data.selectedRoleTrack = t['val']!;
                  });
                },
              )),
          const Spacer(),
          OnboardingButton(
            label: 'Continue',
            isLoading: _isLoadingQuestions,
            onPressed: _data.selectedRoleTrack.isEmpty ? null : _fetchQuestions,
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
          const SizedBox(height: 36),
          ...dates.map((date) => OptionSelectorTile(
                label: date,
                isSelected: _data.selectedInterviewDate == date,
                onTap: () {
                  setState(() {
                    _data.selectedInterviewDate = date;
                  });
                },
              )),
          const Spacer(),
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
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 120,
                                height: 120,
                                color: const Color(0xFFEEF2FF),
                                child: const Icon(Icons.assignment_rounded, color: Color(0xFF4F46E5), size: 48),
                              ),
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
    if (_data.questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final questionData = _data.questions[qNumber - 1];
    final String questionText = questionData['question'] ?? '';
    
    TextEditingController controller;
    if (qNumber == 1) {
      controller = _q1Controller;
    } else if (qNumber == 2) {
      controller = _q2Controller;
    } else {
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
                    ? (qNumber == 3 ? _submitAssessment : _nextPage)
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

    final selectedEvaluation = result.results[_selectedReportTab];

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Answer Feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B4B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${selectedEvaluation.questionTheme} · ${selectedEvaluation.targetCompany} · ${selectedEvaluation.roleLevel}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    CustomSemiCircularGauge(score: result.overallReadinessScore.toDouble()),
                    Positioned(
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.overallReadinessScore.toString(),
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
                          Text(
                            'readiness',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.overallReadinessLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      result.overallBand,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      result.overallSignal,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${result.overallTotalScore}/${result.overallMaxScore}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '3 questions · Overall',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'QUESTIONS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Tabbed Layout for Q1, Q2, Q3
              Row(
                children: List.generate(3, (index) {
                  final qEval = result.results[index];
                  final isSelected = _selectedReportTab == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedReportTab = index;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                          left: index == 0 ? 0 : 4,
                          right: index == 2 ? 0 : 4,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Q${index + 1}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              qEval.questionTheme.split('_').first,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white.withOpacity(0.8) : const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${qEval.readinessScore}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag(_data.selectedCompany),
                  _buildTag(_data.selectedRoleFamily),
                  _buildTag(_data.selectedRoleTrack),
                  _buildTag(_data.selectedExperience),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'PARAMETERS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Display Scores for F1, F2, F3, D1, D2
              _buildParameterRow('F1', selectedEvaluation.parameters['F1']?.name ?? 'Situation Clarity', selectedEvaluation.parameters['F1']?.score ?? 0.0),
              _buildParameterRow('F2', selectedEvaluation.parameters['F2']?.name ?? 'Personal Ownership', selectedEvaluation.parameters['F2']?.score ?? 0.0),
              _buildParameterRow('F3', selectedEvaluation.parameters['F3']?.name ?? 'Quantified Result', selectedEvaluation.parameters['F3']?.score ?? 0.0),
              _buildParameterRow('D1', selectedEvaluation.parameters['D1']?.name ?? 'Dynamic Parameter 1', selectedEvaluation.parameters['D1']?.score ?? 0.0),
              _buildParameterRow('D2', selectedEvaluation.parameters['D2']?.name ?? 'Dynamic Parameter 2', selectedEvaluation.parameters['D2']?.score ?? 0.0),
              
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total score',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                  Text(
                    '${selectedEvaluation.totalScore}/25',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              Text(
                'STRENGTHS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...selectedEvaluation.strengths.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
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
                'NEEDS IMPROVEMENT',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...selectedEvaluation.improvements.map((imp) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            imp,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 28),
              OnboardingButton(
                label: 'Start New Assessment',
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                    _data.selectedCompany = '';
                    _data.selectedExperience = '';
                    _data.selectedRoleFamily = '';
                    _data.selectedRoleTrack = '';
                    _data.selectedInterviewDate = '';
                    _data.questions = [];
                    _result = null;
                    _q1Controller.clear();
                    _q2Controller.clear();
                    _q3Controller.clear();
                  });
                  _pageController.jumpToPage(1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildParameterRow(String code, String name, double score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${score.toInt()}/5',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 5.0,
                minHeight: 5,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingLoadingView extends StatefulWidget {
  const _AnalyzingLoadingView();

  @override
  State<_AnalyzingLoadingView> createState() => _AnalyzingLoadingViewState();
}

class _AnalyzingLoadingViewState extends State<_AnalyzingLoadingView> {
  Timer? _timer;
  final math.Random _random = math.Random();
  
  late List<double> _currentValues;
  
  final List<Map<String, dynamic>> _traits = [
    {'name': 'STAR Structure', 'target': 80.0},
    {'name': 'Leadership Signal', 'target': 75.0},
    {'name': 'Ownership & Drive', 'target': 85.0},
    {'name': 'Impact & Metrics', 'target': 60.0},
    {'name': 'Communication Clarity', 'target': 70.0},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with a random starting value
    _currentValues = List.generate(_traits.length, (index) => 15.0 + _random.nextDouble() * 10.0);
    
    // Start periodic timer to simulate dynamic analysis with fluctuations
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _traits.length; i++) {
          final target = _traits[i]['target'] as double;
          final current = _currentValues[i];
          
          if (current < target - 4) {
            // Smoothly progress towards the target range
            _currentValues[i] += 1.5 + _random.nextDouble() * 2.5;
          } else {
            // Fluctuate up and down dynamically around the target range (simulating active evaluation)
            final change = (_random.nextDouble() * 4.0) - 2.0; // -2% to +2%
            _currentValues[i] = (current + change).clamp(target - 6, target + 6);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 140,
                            height: 140,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F3FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.psychology_rounded, color: Color(0xFF4F46E5), size: 56),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Our FAANG behavioral evaluator is scoring your answers across parameters.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: List.generate(_traits.length, (index) {
                          final trait = _traits[index];
                          final String name = trait['name'] as String;
                          final double currentVal = _currentValues[index];
                          final double displayProgress = (currentVal / 100.0).clamp(0.0, 1.0);

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
                                      '${currentVal.toStringAsFixed(0)}%',
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
                                    value: displayProgress,
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
