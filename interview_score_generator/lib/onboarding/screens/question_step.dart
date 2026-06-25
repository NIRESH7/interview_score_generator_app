import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/onboarding_provider.dart';
import '../widgets.dart';

class QuestionStep extends ConsumerStatefulWidget {
  final int qNumber;
  final TextEditingController controller;
  final VoidCallback onPressed;

  const QuestionStep({
    super.key,
    required this.qNumber,
    required this.controller,
    required this.onPressed,
  });

  @override
  ConsumerState<QuestionStep> createState() => _QuestionStepState();
}

class _QuestionStepState extends ConsumerState<QuestionStep> {
  static const int _charLimit = 2000;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleStopAndTranscribe() async {
    try {
      await ref.read(onboardingProvider.notifier).stopAndTranscribe(
            widget.qNumber,
            widget.controller,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    if (state.data.questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final questionData = state.data.questions[widget.qNumber - 1];
    final String questionText = questionData['question'] ?? '';
    final textLength = widget.controller.text.length;
    final isValid = textLength > 0;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
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
                          height: 240,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: state.isRecording && state.activeRecordingQuestion == widget.qNumber
                                ? SingleChildScrollView(
                                    child: Column(
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
                                              '${state.recordingSeconds ~/ 60}:${(state.recordingSeconds % 60).toString().padLeft(2, '0')}',
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
                                            state.wordsSpoken.isNotEmpty
                                                ? '"${state.wordsSpoken}"'
                                                : 'Speak your response...',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                              color: state.wordsSpoken.isNotEmpty
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
                                        AnimatedWaveform(color: const Color(0xFF4F46E5)),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: _handleStopAndTranscribe,
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
                                    ),
                                  )
                                : state.isTranscribing && state.activeRecordingQuestion == widget.qNumber
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
                                              controller: widget.controller,
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
                                                onPressed: () => notifier.startRecording(widget.qNumber),
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
                          label: widget.qNumber == 3 ? 'Generate Report' : 'Next',
                          onPressed: isValid && textLength <= _charLimit ? widget.onPressed : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
