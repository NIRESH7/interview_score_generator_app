import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFC7D2FE),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
      ),
    );
  }
}

class OptionSelectorTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? leading;

  const OptionSelectorTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                      width: isSelected ? 6 : 2,
                    ),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompanyBrandEmblem extends StatelessWidget {
  final String companyName;

  const CompanyBrandEmblem({super.key, required this.companyName});

  @override
  Widget build(BuildContext context) {
    final String? svgPath = _svgPath(companyName);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _bgColor(companyName),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: svgPath != null
          ? SvgPicture.asset(svgPath, fit: BoxFit.contain)
          : const Icon(Icons.business_center_rounded, color: Color(0xFF475569), size: 18),
    );
  }

  String? _svgPath(String name) {
    switch (name.toLowerCase()) {
      case 'google':    return 'assets/logos/google.svg';
      case 'meta':      return 'assets/logos/meta.svg';
      case 'amazon':    return 'assets/logos/amazon.svg';
      case 'apple':     return 'assets/logos/apple.svg';
      case 'microsoft': return 'assets/logos/microsoft.svg';
      case 'uber':      return 'assets/logos/uber.svg';
      default:          return null;
    }
  }

  Color _bgColor(String name) {
    switch (name.toLowerCase()) {
      case 'google':    return const Color(0xFFF8FAFF);
      case 'meta':      return const Color(0xFFEFF6FF);
      case 'amazon':    return const Color(0xFFFFF7ED);
      case 'apple':     return const Color(0xFFF1F5F9);
      case 'microsoft': return const Color(0xFFFAFAFA);
      case 'uber':      return Colors.black;
      default:          return const Color(0xFFF1F5F9);
    }
  }
}



class HexagonLogo extends StatelessWidget {
  const HexagonLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _HexagonPainter(),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final path = Path();
    
    for (int i = 0; i < 6; i++) {
      double angle = -math.pi / 2 + i * (math.pi / 3);
      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'ai',
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF4F46E5),
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DeveloperIllustration extends StatelessWidget {
  const DeveloperIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/person.png',
      height: 200,
      fit: BoxFit.contain,
    );
  }
}


class CustomSemiCircularGauge extends StatefulWidget {
  final double score;

  const CustomSemiCircularGauge({super.key, required this.score});

  @override
  State<CustomSemiCircularGauge> createState() => _CustomSemiCircularGaugeState();
}

class _CustomSemiCircularGaugeState extends State<CustomSemiCircularGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CustomSemiCircularGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: _animation.value, end: widget.score).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 110),
          painter: _SemiCircularGaugePainter(score: _animation.value),
        );
      },
    );
  }
}

class _SemiCircularGaugePainter extends CustomPainter {
  final double score;

  _SemiCircularGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 10;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    paint.color = const Color(0xFFF1F5F9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      paint,
    );

    final double sweepAngle = (score / 100) * math.pi;

    if (sweepAngle > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      paint.shader = SweepGradient(
        colors: const [
          Color(0xFFEF4444),
          Color(0xFFF59E0B),
          Color(0xFF10B981),
        ],
        stops: const [0.0, 0.5, 1.0],
        startAngle: math.pi,
        endAngle: math.pi * 2,
      ).createShader(rect);

      canvas.drawArc(
        rect,
        math.pi,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SemiCircularGaugePainter oldDelegate) {
    return oldDelegate.score != score;
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
