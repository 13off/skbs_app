import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Лёгкая векторная сцена «Строй На Века» для splash-анимации.
///
/// Геометрия логотипа записывается в ui.Picture один раз. На каждом кадре
/// меняются только clip/translate/scale для нескольких готовых слоёв. Это
/// заметно снижает нагрузку на CPU/GPU в Safari PWA и убирает микрофризы при
/// параллельной инициализации приложения под заставкой.
class SmoothStroyNaVekaLogoScene extends StatelessWidget {
  final Animation<double> animation;

  const SmoothStroyNaVekaLogoScene({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(236, 258),
        isComplex: false,
        willChange: true,
        painter: _SmoothStroyNaVekaPainter(animation),
      ),
    );
  }
}

class _SmoothStroyNaVekaPainter extends CustomPainter {
  static final _ScenePictures _scene = _ScenePictures.build();

  final Animation<double> animation;

  _SmoothStroyNaVekaPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = _phase(animation.value);
    if (phase <= 0) return;

    final sx = size.width / 236;
    final sy = size.height / 258;
    canvas.save();
    canvas.scale(sx, sy);

    // Все детали перекрываются по времени, чтобы логотип собирался одним
    // непрерывным движением. Крыши начинают движение ещё во время подъёма
    // башен и получают самую длинную мягкую фазу вместо позднего «вылета».
    final shield = _interval(phase, 0.00, 0.34);
    final wall = _interval(phase, 0.05, 0.56);
    final towers = _interval(phase, 0.10, 0.64);
    final roofs = _interval(phase, 0.16, 0.78);
    final title = _interval(phase, 0.48, 0.88);

    _revealFromCenter(
      canvas,
      _scene.shield,
      shield,
      const Rect.fromLTRB(18, 6, 218, 246),
    );
    _riseReveal(
      canvas,
      _scene.wall,
      wall,
      const Rect.fromLTRB(67, 72, 169, 154),
      lift: 5,
    );
    _riseReveal(
      canvas,
      _scene.leftTower,
      towers,
      const Rect.fromLTRB(38, 63, 80, 154),
      lift: 7,
    );
    _riseReveal(
      canvas,
      _scene.rightTower,
      _interval(towers, 0.025, 1),
      const Rect.fromLTRB(156, 63, 198, 154),
      lift: 7,
    );
    _roofReveal(
      canvas,
      _scene.leftRoof,
      roofs,
      const Rect.fromLTRB(36, 22, 82, 68),
      const Offset(59, 68),
    );
    _roofReveal(
      canvas,
      _scene.rightRoof,
      _interval(roofs, 0.025, 1),
      const Rect.fromLTRB(154, 22, 200, 68),
      const Offset(177, 68),
    );
    _riseReveal(
      canvas,
      _scene.title,
      title,
      const Rect.fromLTRB(35, 148, 201, 218),
      lift: 5,
    );

    canvas.restore();
  }

  double _phase(double value) => _clamp01(value);

  void _revealFromCenter(
    Canvas canvas,
    ui.Picture picture,
    double progress,
    Rect bounds,
  ) {
    if (progress <= 0) return;
    final eased = Curves.easeInOutCubic.transform(progress);
    final halfHeight = (bounds.height / 2) * eased;
    final centerY = bounds.center.dy;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        bounds.left,
        centerY - halfHeight,
        bounds.right,
        centerY + halfHeight,
      ),
    );
    final scale = 0.975 + (0.025 * eased);
    canvas.translate(bounds.center.dx, bounds.center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void _riseReveal(
    Canvas canvas,
    ui.Picture picture,
    double progress,
    Rect bounds, {
    required double lift,
  }) {
    if (progress <= 0) return;
    final eased = Curves.easeInOutCubic.transform(progress);
    final revealTop = bounds.bottom - (bounds.height * eased);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        bounds.left - 4,
        revealTop - 2,
        bounds.right + 4,
        bounds.bottom + 6,
      ),
    );
    canvas.translate(0, lift * (1 - eased));
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void _roofReveal(
    Canvas canvas,
    ui.Picture picture,
    double progress,
    Rect bounds,
    Offset anchor,
  ) {
    if (progress <= 0) return;

    final eased = Curves.easeInOutCubic.transform(progress);
    final reveal = Curves.easeInOutSine.transform(progress);
    final revealTop = bounds.bottom - (bounds.height * reveal);
    final scale = 0.985 + (0.015 * eased);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        bounds.left - 4,
        revealTop - 2,
        bounds.right + 4,
        bounds.bottom + 8,
      ),
    );
    canvas.translate(0, 4 * (1 - eased));
    canvas.translate(anchor.dx, anchor.dy);
    canvas.scale(scale, scale);
    canvas.translate(-anchor.dx, -anchor.dy);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  double _interval(double value, double begin, double end) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return Curves.easeInOutCubic.transform((value - begin) / (end - begin));
  }

  double _clamp01(double value) {
    if (value <= 0) return 0;
    if (value >= 1) return 1;
    return value;
  }

  @override
  bool shouldRepaint(covariant _SmoothStroyNaVekaPainter oldDelegate) => false;
}

class _ScenePictures {
  static const Color _blue = Color(0xFF315B9D);
  static const Color _blueDark = Color(0xFF23477F);
  static const Color _blueSoft = Color(0xFF6686BA);
  static const Color _white = Color(0xFFF7F9FC);

  final ui.Picture shield;
  final ui.Picture wall;
  final ui.Picture leftTower;
  final ui.Picture rightTower;
  final ui.Picture leftRoof;
  final ui.Picture rightRoof;
  final ui.Picture title;

  const _ScenePictures({
    required this.shield,
    required this.wall,
    required this.leftTower,
    required this.rightTower,
    required this.leftRoof,
    required this.rightRoof,
    required this.title,
  });

  factory _ScenePictures.build() {
    return _ScenePictures(
      shield: _record(_drawShield),
      wall: _record(_drawWall),
      leftTower: _record((canvas) => _drawTower(canvas, 59)),
      rightTower: _record((canvas) => _drawTower(canvas, 177)),
      leftRoof: _record((canvas) => _drawRoof(canvas, 59)),
      rightRoof: _record((canvas) => _drawRoof(canvas, 177)),
      title: _record(_drawTitle),
    );
  }

  static ui.Picture _record(void Function(Canvas canvas) draw) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas);
    return recorder.endRecording();
  }

  static void _drawShield(Canvas canvas) {
    final outer = Path()
      ..moveTo(118, 8)
      ..lineTo(212, 60)
      ..lineTo(212, 172)
      ..lineTo(118, 244)
      ..lineTo(24, 172)
      ..lineTo(24, 60)
      ..close();
    canvas.drawPath(outer, Paint()..color = _blue);
    canvas.drawPath(
      outer,
      Paint()
        ..color = _blueDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeJoin = StrokeJoin.round,
    );

    final inner = Path()
      ..moveTo(118, 23)
      ..lineTo(198, 67)
      ..lineTo(198, 164)
      ..lineTo(118, 226)
      ..lineTo(38, 164)
      ..lineTo(38, 67)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..color = _white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static void _drawWall(Canvas canvas) {
    const rows = 5;
    const columns = 4;
    const left = 76.0;
    const bottom = 151.0;
    const brickW = 21.0;
    const brickH = 13.0;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final x = left + (col * brickW) - (row.isOdd ? 7 : 0);
        final y = bottom - ((row + 1) * brickH);
        _brick(canvas, Rect.fromLTWH(x, y, brickW - 2, brickH - 2));
      }
    }

    for (var i = 0; i < 5; i++) {
      _brick(canvas, Rect.fromLTWH(81 + (i * 15), 78, 10, 12));
    }
  }

  static void _drawTower(Canvas canvas, double cx) {
    const rows = 6;
    const bottom = 151.0;
    const rowH = 13.5;

    for (var row = 0; row < rows; row++) {
      final y = bottom - ((row + 1) * rowH);
      final leftW = row.isOdd ? 15.0 : 18.0;
      _brick(canvas, Rect.fromLTWH(cx - 18, y, leftW - 1, rowH - 2));
      _brick(
        canvas,
        Rect.fromLTWH(cx - 18 + leftW, y, 36 - leftW - 1, rowH - 2),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 18, 67, 36, 84),
        const Radius.circular(6),
      ),
      Paint()
        ..color = _blueDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _window(canvas, cx, 96);
    _window(canvas, cx, 124);
  }

  static void _drawRoof(Canvas canvas, double cx) {
    final roof = Path()
      ..moveTo(cx, 22)
      ..lineTo(cx - 23, 68)
      ..lineTo(cx + 23, 68)
      ..close();
    canvas.drawPath(roof, Paint()..color = _white);
    canvas.drawPath(
      roof,
      Paint()
        ..color = _blueDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static void _drawTitle(Canvas canvas) {
    final panel = Path()
      ..moveTo(39, 151)
      ..lineTo(197, 151)
      ..lineTo(181, 204)
      ..lineTo(55, 204)
      ..close();
    canvas.drawPath(panel, Paint()..color = _blueDark);

    final title1 = TextPainter(
      text: const TextSpan(
        text: 'СТРОЙ',
        style: TextStyle(
          color: _white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final title2 = TextPainter(
      text: const TextSpan(
        text: 'НА ВЕКА',
        style: TextStyle(
          color: _white,
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    title1.paint(canvas, Offset(118 - (title1.width / 2), 159));
    title2.paint(canvas, Offset(118 - (title2.width / 2), 178));

    final ornamentPaint = Paint()
      ..color = _white
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(72, 213), const Offset(107, 213), ornamentPaint);
    canvas.drawLine(const Offset(129, 213), const Offset(164, 213), ornamentPaint);
  }

  static void _window(Canvas canvas, double cx, double y) {
    final path = Path()
      ..moveTo(cx - 4, y + 8)
      ..lineTo(cx - 4, y)
      ..quadraticBezierTo(cx, y - 5, cx + 4, y)
      ..lineTo(cx + 4, y + 8)
      ..close();
    canvas.drawPath(path, Paint()..color = _blueDark.withValues(alpha: 0.88));
  }

  static void _brick(Canvas canvas, Rect rect) {
    final brick = RRect.fromRectAndRadius(rect, const Radius.circular(1.3));
    canvas.drawRRect(brick, Paint()..color = _white);
    canvas.drawRRect(
      brick,
      Paint()
        ..color = _blueSoft.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }
}
