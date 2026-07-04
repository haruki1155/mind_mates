import 'dart:math' as math;

import 'package:flutter/material.dart';

class LogMoodScreen extends StatefulWidget {
  const LogMoodScreen({super.key});

  @override
  State<LogMoodScreen> createState() => _LogMoodScreenState();
}

class _LogMoodScreenState extends State<LogMoodScreen> {
  final TextEditingController _noteController = TextEditingController();
  _MoodChoice? _selectedMood;
  int _noteLength = 0;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_handleNoteChanged);
  }

  @override
  void dispose() {
    _noteController
      ..removeListener(_handleNoteChanged)
      ..dispose();
    super.dispose();
  }

  void _handleNoteChanged() {
    if (_noteLength == _noteController.text.length) return;
    setState(() => _noteLength = _noteController.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoodLogPalette.background,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _MoodLogHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Expanded(child: _MoodLogIntro()),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: math.min(
                                  340,
                                  constraints.maxWidth * .34,
                                ),
                                height: 190,
                                child: const _CalmCloudIllustration(),
                              ),
                            ],
                          )
                        else ...[
                          const _MoodLogIntro(),
                          const SizedBox(height: 20),
                          Center(
                            child: SizedBox(
                              width: math.min(280, constraints.maxWidth * .9),
                              height: 150,
                              child: const _CalmCloudIllustration(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _MoodChoiceGrid(
                          selectedMood: _selectedMood,
                          onSelected: (mood) =>
                              setState(() => _selectedMood = mood),
                        ),
                        const SizedBox(height: 28),
                        _ThoughtsBox(
                          controller: _noteController,
                          characterCount: _noteLength,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodLogHeader extends StatelessWidget {
  const _MoodLogHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      padding: EdgeInsets.only(
        left: 40,
        right: 24,
        top: MediaQuery.paddingOf(context).top + 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9A3), Color(0xFFFFD975), Color(0xFFFFF3C8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeaderBackButton(onPressed: () => Navigator.of(context).pop()),
          const SizedBox(width: 46),
          const _MindMateMark(),
          const SizedBox(width: 18),
          const Flexible(
            child: Text(
              'MindMate',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MoodLogPalette.ink,
                fontSize: 38,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 74,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x25000000),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: MoodLogPalette.ink,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _MindMateMark extends StatelessWidget {
  const _MindMateMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 58,
      child: CustomPaint(painter: _MindMateMarkPainter()),
    );
  }
}

class _MoodLogIntro extends StatelessWidget {
  const _MoodLogIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling?',
          style: TextStyle(
            color: MoodLogPalette.goldText,
            fontSize: 46,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Your feelings matter. Check in with yourself.',
          style: TextStyle(
            color: MoodLogPalette.bodyText,
            fontSize: 25,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MoodChoiceGrid extends StatelessWidget {
  const _MoodChoiceGrid({required this.selectedMood, required this.onSelected});

  final _MoodChoice? selectedMood;
  final ValueChanged<_MoodChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 2;
        final gap = constraints.maxWidth >= 760 ? 28.0 : 16.0;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 16,
          spacing: gap,
          children: [
            for (final mood in _moodChoices)
              SizedBox(
                width: cardWidth,
                child: _MoodChoiceCard(
                  mood: mood,
                  selected: mood == selectedMood,
                  onTap: () => onSelected(mood),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MoodChoiceCard extends StatelessWidget {
  const _MoodChoiceCard({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final _MoodChoice mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 240;
        final glyphSize = compact ? 104.0 : 136.0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: AnimatedContainer(
              key: ValueKey('mood-card-${mood.label}'),
              duration: const Duration(milliseconds: 180),
              height: compact ? 282 : 356,
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 18,
                compact ? 18 : 28,
                compact ? 14 : 18,
                compact ? 16 : 22,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: selected ? .98 : .86),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? MoodLogPalette.gold
                      : MoodLogPalette.gold.withValues(alpha: .55),
                  width: selected ? 2 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0x33F0AA12)
                        : const Color(0x16EAB14A),
                    blurRadius: selected ? 24 : 14,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MoodEmojiBadge(
                    mood: mood,
                    selected: selected,
                    size: glyphSize,
                  ),
                  SizedBox(height: compact ? 16 : 22),
                  Text(
                    mood.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MoodLogPalette.ink,
                      fontSize: compact ? 25 : 32,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: compact ? 11 : 16),
                  Text(
                    mood.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MoodLogPalette.bodyText,
                      fontSize: compact ? 17 : 22,
                      height: 1.28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoodEmojiBadge extends StatelessWidget {
  const _MoodEmojiBadge({
    required this.mood,
    required this.selected,
    required this.size,
  });

  final _MoodChoice mood;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? size + 4 : size,
      height: selected ? size + 4 : size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mood.auraColor,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: mood.accentColor.withValues(alpha: .28),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: SizedBox.square(
          dimension: size * .76,
          child: CustomPaint(
            painter: _MoodGlyphPainter(
              glyph: mood.glyph,
              accentColor: mood.accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThoughtsBox extends StatelessWidget {
  const _ThoughtsBox({required this.controller, required this.characterCount});

  final TextEditingController controller;
  final int characterCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 208),
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MoodLogPalette.gold.withValues(alpha: .68)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x13E8AA32),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_square, color: MoodLogPalette.goldText, size: 28),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  "What's on your mind today?",
                  style: TextStyle(
                    color: MoodLogPalette.ink,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            maxLength: 300,
            maxLines: 4,
            minLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: 'Share your thoughts...',
              hintStyle: TextStyle(
                color: MoodLogPalette.hintText,
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
            style: const TextStyle(
              color: MoodLogPalette.bodyText,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$characterCount/300 characters',
              style: const TextStyle(
                color: MoodLogPalette.bodyText,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalmCloudIllustration extends StatelessWidget {
  const _CalmCloudIllustration();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _CalmCloudPainter());
  }
}

class _MindMateMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD969)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = MoodLogPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = size.center(Offset.zero);
    final left = Rect.fromCenter(
      center: Offset(center.dx - size.width * .12, center.dy),
      width: size.width * .44,
      height: size.height * .72,
    );
    final right = Rect.fromCenter(
      center: Offset(center.dx + size.width * .12, center.dy),
      width: size.width * .44,
      height: size.height * .72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(left, Radius.circular(size.width * .2)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(right, Radius.circular(size.width * .2)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(left, Radius.circular(size.width * .2)),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(right, Radius.circular(size.width * .2)),
      outline,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * .18),
      Offset(center.dx, size.height * .82),
      outline,
    );
    for (final dot in [
      Offset(size.width * .28, size.height * .28),
      Offset(size.width * .24, size.height * .48),
      Offset(size.width * .32, size.height * .66),
      Offset(size.width * .72, size.height * .28),
      Offset(size.width * .76, size.height * .48),
      Offset(size.width * .68, size.height * .66),
    ]) {
      canvas.drawCircle(dot, 2.8, Paint()..color = MoodLogPalette.ink);
    }
    _drawSpark(canvas, Offset(size.width * .04, size.height * .26), 7);
    _drawSpark(canvas, Offset(size.width * .08, size.height * .78), 6);
  }

  void _drawSpark(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = MoodLogPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MindMateMarkPainter oldDelegate) => false;
}

class _CalmCloudPainter extends CustomPainter {
  const _CalmCloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 190);
    canvas.save();
    canvas.translate((size.width - 360 * scale) / 2, size.height - 190 * scale);
    canvas.scale(scale);

    _drawLeaves(canvas, const Offset(58, 150), -1);
    _drawLeaves(canvas, const Offset(302, 150), 1);
    _drawSpark(canvas, const Offset(102, 26), 9);
    _drawSpark(canvas, const Offset(284, 50), 7);
    _drawSpark(canvas, const Offset(322, 22), 5);

    final cloudPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE389), Color(0xFFFFC442), Color(0xFFFFB929)],
      ).createShader(const Rect.fromLTWH(70, 48, 220, 126));
    for (final circle in const [
      (Offset(132, 118), 62.0),
      (Offset(180, 82), 74.0),
      (Offset(226, 124), 60.0),
      (Offset(101, 145), 48.0),
      (Offset(260, 150), 48.0),
      (Offset(179, 151), 66.0),
    ]) {
      canvas.drawCircle(circle.$1, circle.$2, cloudPaint);
    }

    final face = Paint()
      ..color = MoodLogPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(142, 88, 28, 22),
      0,
      math.pi,
      false,
      face,
    );
    canvas.drawArc(
      const Rect.fromLTWH(198, 88, 28, 22),
      0,
      math.pi,
      false,
      face,
    );
    canvas.drawArc(
      const Rect.fromLTWH(168, 116, 36, 26),
      0,
      math.pi,
      false,
      face,
    );

    final heart = Path()
      ..moveTo(180, 158)
      ..cubicTo(155, 140, 148, 118, 168, 112)
      ..cubicTo(176, 109, 181, 116, 184, 124)
      ..cubicTo(189, 116, 197, 109, 206, 113)
      ..cubicTo(224, 121, 210, 146, 180, 158);
    canvas.drawPath(heart, Paint()..color = Colors.white);

    final cheek = Paint()
      ..color = const Color(0xFFF2AA27).withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(106, 121, 58, 42),
      -.1,
      2.1,
      false,
      cheek,
    );
    canvas.drawArc(
      const Rect.fromLTWH(215, 121, 58, 42),
      1.0,
      2.0,
      false,
      cheek,
    );
    canvas.restore();
  }

  void _drawLeaves(Canvas canvas, Offset root, int direction) {
    final stem = Paint()
      ..color = direction < 0
          ? const Color(0xFFFFCC4D)
          : const Color(0xFFD2D2D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(root, root + Offset(42.0 * direction, -88), stem);
    final leafPaint = Paint()
      ..color = direction < 0
          ? const Color(0xFFFFD45B)
          : const Color(0xFFD8D8D8)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      final center = root + Offset(direction * (12 + i * 8), -20.0 - i * 16);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(direction * (.7 - i * .08));
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 42),
        leafPaint,
      );
      canvas.restore();
    }
  }

  void _drawSpark(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + 3,
        center.dy - 3,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + 3,
        center.dy + 3,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - 3,
        center.dy + 3,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - 3,
        center.dy - 3,
        center.dx,
        center.dy - radius,
      );
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFD565));
  }

  @override
  bool shouldRepaint(covariant _CalmCloudPainter oldDelegate) => false;
}

class _MoodGlyphPainter extends CustomPainter {
  const _MoodGlyphPainter({required this.glyph, required this.accentColor});

  final _MoodGlyph glyph;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (glyph == _MoodGlyph.excited) {
      _drawParty(canvas, size);
      return;
    }

    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .42;
    final faceRect = Rect.fromCircle(center: center, radius: radius);
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.35),
        radius: .9,
        colors: [
          const Color(0xFFFFF3AC),
          accentColor.withValues(alpha: .7),
          const Color(0xFFFFBC3F),
        ],
        stops: const [0, .62, 1],
      ).createShader(faceRect);

    canvas.drawCircle(center, radius, facePaint);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.width * .018)
        ..color = const Color(0xFFFFB42E),
    );

    switch (glyph) {
      case _MoodGlyph.great:
        _drawGreat(canvas, size, center, radius);
      case _MoodGlyph.okay:
        _drawOkay(canvas, size, center, radius);
      case _MoodGlyph.stressed:
        _drawStressed(canvas, size, center, radius);
      case _MoodGlyph.sad:
        _drawSad(canvas, size, center, radius);
      case _MoodGlyph.angry:
        _drawAngry(canvas, size, center, radius);
      case _MoodGlyph.tired:
        _drawTired(canvas, size, center, radius);
      case _MoodGlyph.excited:
        break;
    }
  }

  Paint get _ink => Paint()
    ..color = MoodLogPalette.ink
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _drawGreat(Canvas canvas, Size size, Offset center, double radius) {
    final ink = _ink..strokeWidth = size.width * .055;
    _drawHappyEyes(canvas, center, radius, ink);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * .2),
        width: radius * 1.18,
        height: radius * .82,
      ),
      .08,
      math.pi - .16,
      false,
      ink,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * .28),
        width: radius * .92,
        height: radius * .42,
      ),
      .08,
      math.pi - .16,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .04
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawOkay(Canvas canvas, Size size, Offset center, double radius) {
    final fill = Paint()..color = MoodLogPalette.ink;
    canvas.drawCircle(
      Offset(center.dx - radius * .34, center.dy - radius * .12),
      radius * .085,
      fill,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * .34, center.dy - radius * .12),
      radius * .085,
      fill,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * .17),
        width: radius * .82,
        height: radius * .52,
      ),
      .12,
      math.pi - .24,
      false,
      _ink..strokeWidth = size.width * .04,
    );
  }

  void _drawStressed(Canvas canvas, Size size, Offset center, double radius) {
    final ink = _ink..strokeWidth = size.width * .048;
    canvas.drawLine(
      Offset(center.dx - radius * .54, center.dy - radius * .48),
      Offset(center.dx - radius * .18, center.dy - radius * .34),
      ink,
    );
    canvas.drawLine(
      Offset(center.dx + radius * .54, center.dy - radius * .48),
      Offset(center.dx + radius * .18, center.dy - radius * .34),
      ink,
    );
    _drawDotEyes(canvas, center, radius, radius * .085);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * .5),
        width: radius * .86,
        height: radius * .7,
      ),
      math.pi + .2,
      math.pi - .4,
      false,
      ink,
    );
  }

  void _drawSad(Canvas canvas, Size size, Offset center, double radius) {
    _drawDotEyes(canvas, center, radius, radius * .09);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * .52),
        width: radius * .86,
        height: radius * .72,
      ),
      math.pi + .2,
      math.pi - .4,
      false,
      _ink..strokeWidth = size.width * .045,
    );
  }

  void _drawAngry(Canvas canvas, Size size, Offset center, double radius) {
    final ink = _ink..strokeWidth = size.width * .052;
    canvas.drawLine(
      Offset(center.dx - radius * .54, center.dy - radius * .42),
      Offset(center.dx - radius * .16, center.dy - radius * .25),
      ink,
    );
    canvas.drawLine(
      Offset(center.dx + radius * .54, center.dy - radius * .42),
      Offset(center.dx + radius * .16, center.dy - radius * .25),
      ink,
    );
    _drawDotEyes(canvas, center, radius, radius * .08);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * .52),
        width: radius * .72,
        height: radius * .62,
      ),
      math.pi + .14,
      math.pi - .28,
      false,
      ink,
    );
  }

  void _drawTired(Canvas canvas, Size size, Offset center, double radius) {
    final ink = _ink..strokeWidth = size.width * .042;
    _drawClosedEyes(canvas, center, radius, ink);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * .46),
        width: radius * .56,
        height: radius * .42,
      ),
      math.pi + .2,
      math.pi - .4,
      false,
      ink,
    );
    _drawZ(
      canvas,
      Offset(center.dx + radius * .68, center.dy - radius * .62),
      size.width * .18,
    );
    _drawZ(
      canvas,
      Offset(center.dx + radius * .9, center.dy - radius * .88),
      size.width * .23,
    );
  }

  void _drawParty(Canvas canvas, Size size) {
    final body = Path()
      ..moveTo(size.width * .28, size.height * .76)
      ..lineTo(size.width * .52, size.height * .18)
      ..lineTo(size.width * .72, size.height * .62)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6FA7E8), Color(0xFFFFC24E), Color(0xFFF0808F)],
        ).createShader(Offset.zero & size),
    );
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .39, size.height * .51),
      Offset(size.width * .58, size.height * .6),
      stripe,
    );
    canvas.drawLine(
      Offset(size.width * .45, size.height * .36),
      Offset(size.width * .62, size.height * .45),
      stripe,
    );
    for (final star in [
      Offset(size.width * .74, size.height * .22),
      Offset(size.width * .82, size.height * .42),
      Offset(size.width * .55, size.height * .1),
    ]) {
      _drawStar(canvas, star, size.width * .07, const Color(0xFFF4B844));
    }
    final confettiPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .025
      ..strokeCap = StrokeCap.round;
    for (final item in [
      (Offset(size.width * .34, size.height * .2), const Color(0xFF78B7AE)),
      (Offset(size.width * .7, size.height * .12), const Color(0xFFE88EA0)),
      (Offset(size.width * .26, size.height * .35), const Color(0xFFF6C24B)),
    ]) {
      confettiPaint.color = item.$2;
      canvas.drawLine(
        item.$1,
        item.$1 + Offset(size.width * .03, -size.height * .08),
        confettiPaint,
      );
    }
  }

  void _drawHappyEyes(Canvas canvas, Offset center, double radius, Paint ink) {
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx - radius * .34, center.dy - radius * .18),
        width: radius * .3,
        height: radius * .22,
      ),
      math.pi,
      math.pi,
      false,
      ink,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + radius * .34, center.dy - radius * .18),
        width: radius * .3,
        height: radius * .22,
      ),
      math.pi,
      math.pi,
      false,
      ink,
    );
  }

  void _drawClosedEyes(Canvas canvas, Offset center, double radius, Paint ink) {
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx - radius * .32, center.dy - radius * .18),
        width: radius * .34,
        height: radius * .18,
      ),
      0,
      math.pi,
      false,
      ink,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + radius * .32, center.dy - radius * .18),
        width: radius * .34,
        height: radius * .18,
      ),
      0,
      math.pi,
      false,
      ink,
    );
  }

  void _drawDotEyes(
    Canvas canvas,
    Offset center,
    double radius,
    double dotSize,
  ) {
    final fill = Paint()..color = MoodLogPalette.ink;
    canvas.drawCircle(
      Offset(center.dx - radius * .3, center.dy - radius * .08),
      dotSize,
      fill,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * .3, center.dy - radius * .08),
      dotSize,
      fill,
    );
  }

  void _drawZ(Canvas canvas, Offset topLeft, double size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Z',
        style: TextStyle(
          color: const Color(0xFF9D8CC7),
          fontSize: size,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, topLeft);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * .18,
        center.dy - radius * .18,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * .18,
        center.dy + radius * .18,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * .18,
        center.dy + radius * .18,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * .18,
        center.dy - radius * .18,
        center.dx,
        center.dy - radius,
      );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MoodGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.accentColor != accentColor;
  }
}

enum _MoodGlyph { great, okay, stressed, sad, angry, tired, excited }

class _MoodChoice {
  const _MoodChoice({
    required this.label,
    required this.description,
    required this.glyph,
    required this.auraColor,
    required this.accentColor,
  });

  final String label;
  final String description;
  final _MoodGlyph glyph;
  final Color auraColor;
  final Color accentColor;
}

const _moodChoices = [
  _MoodChoice(
    label: 'Great',
    description: 'Feeling good and positive',
    glyph: _MoodGlyph.great,
    auraColor: Color(0xFFD9EDB0),
    accentColor: Color(0xFF95C45F),
  ),
  _MoodChoice(
    label: 'Okay',
    description: "It's a normal, average day",
    glyph: _MoodGlyph.okay,
    auraColor: Color(0xFFC7DFF2),
    accentColor: Color(0xFF7EB5DC),
  ),
  _MoodChoice(
    label: 'Stressed',
    description: 'Feeling overwhelmed or anxious',
    glyph: _MoodGlyph.stressed,
    auraColor: Color(0xFFD8C8F2),
    accentColor: Color(0xFFA48BD7),
  ),
  _MoodChoice(
    label: 'Sad',
    description: 'Feeling down or low',
    glyph: _MoodGlyph.sad,
    auraColor: Color(0xFFF8E9C7),
    accentColor: Color(0xFFE3C57D),
  ),
  _MoodChoice(
    label: 'Angry',
    description: 'Frustrated or irritated',
    glyph: _MoodGlyph.angry,
    auraColor: Color(0xFFFFD0C2),
    accentColor: Color(0xFFFF8D63),
  ),
  _MoodChoice(
    label: 'Tired',
    description: 'Mentally or physically drained',
    glyph: _MoodGlyph.tired,
    auraColor: Color(0xFFD8CFF0),
    accentColor: Color(0xFF9D8CC7),
  ),
  _MoodChoice(
    label: 'Excited',
    description: 'Looking forward to something',
    glyph: _MoodGlyph.excited,
    auraColor: Color(0xFFFFEFD0),
    accentColor: Color(0xFFF0B141),
  ),
];

class MoodLogPalette {
  const MoodLogPalette._();

  static const background = Color(0xFFFFFEFB);
  static const ink = Color(0xFF26282D);
  static const bodyText = Color(0xFF4D535E);
  static const hintText = Color(0xFF9AA0A9);
  static const gold = Color(0xFFFFC94F);
  static const goldText = Color(0xFFEFA208);
}
