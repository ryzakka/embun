import 'package:flutter/material.dart';

/// Tombol "Login dengan Google" mengikuti pedoman merek Google: tema terang,
/// bentuk pill, tinggi 40, logo "G" empat warna. Warna, jarak, dan logo
/// sengaja tidak disesuaikan ke gaya Embun.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Login dengan Google',
  });

  /// null = nonaktif.
  final VoidCallback? onPressed;
  final String label;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _hover = false, _focus = false, _down = false;
  bool get _on => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final overlay = !_on
        ? 0.0
        : (_down || _focus)
        ? 0.12
        : _hover
        ? 0.08
        : 0.0;
    final radius = BorderRadius.circular(20);
    const fade = Duration(milliseconds: 218);
    final dim = _on ? 1.0 : 0.38;

    return Semantics(
      button: true,
      enabled: _on,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _on,
        mouseCursor: _on ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _on ? (_) => setState(() => _down = true) : null,
          onTapUp: _on ? (_) => setState(() => _down = false) : null,
          onTapCancel: _on ? () => setState(() => _down = false) : null,
          onTap: widget.onPressed,
          // Padding atas-bawah 4 px: tinggi tombol tetap 40, area sentuh 48.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AnimatedContainer(
                duration: fade,
                height: 40,
                decoration: BoxDecoration(
                  color: _on ? Colors.white : const Color(0x61FFFFFF),
                  borderRadius: radius,
                  border: Border.all(
                    color: _on
                        ? const Color(0xFF747775)
                        : const Color(0x1F1F1F1F),
                  ),
                  boxShadow: _on && _hover
                      ? const [
                    BoxShadow(
                      color: Color(0x4D3C4043),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Color(0x263C4043),
                      blurRadius: 3,
                      spreadRadius: 1,
                      offset: Offset(0, 1),
                    ),
                  ]
                      : const [],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: overlay,
                          duration: fade,
                          child: const ColoredBox(color: Color(0xFF303030)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: dim,
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CustomPaint(painter: _GoogleGPainter()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Opacity(
                                opacity: dim,
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.25,
                                    color: Color(0xFF1F1F1F),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo "G" resmi (viewBox 48x48), digambar dari data path SVG aslinya.
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static final _layers = <(Path, Color)>[
    (
    _svgPath(
      'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
          '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
    ),
    const Color(0xFFEA4335),
    ),
    (
    _svgPath(
      'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 '
          '5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
    ),
    const Color(0xFF4285F4),
    ),
    (
    _svgPath(
      'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19'
          'C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
    ),
    const Color(0xFFFBBC05),
    ),
    (
    _svgPath(
      'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 '
          '2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z',
    ),
    const Color(0xFF34A853),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    for (final (path, color) in _layers) {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

final _svgToken = RegExp(r'[a-zA-Z]|-?(?:\d+\.?\d*|\.\d+)');
final _svgCommand = RegExp(r'^[a-zA-Z]$');

/// Pembaca data path SVG seperlunya: M m L l H h V v C c S s Z z.
Path _svgPath(String d) {
  final t = _svgToken.allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var cmd = '';
  double x = 0, y = 0, sx = 0, sy = 0, lcx = 0, lcy = 0;
  var prevCurve = false;

  double n() => double.parse(t[i++]);

  while (i < t.length) {
    if (_svgCommand.hasMatch(t[i])) {
      cmd = t[i++];
      if (cmd == 'z' || cmd == 'Z') {
        path.close();
        x = sx;
        y = sy;
        prevCurve = false;
      }
      continue;
    }
    final rel = cmd == cmd.toLowerCase();
    var curve = false;
    switch (cmd.toUpperCase()) {
      case 'M':
        {
          final nx = n(), ny = n();
          x = rel ? x + nx : nx;
          y = rel ? y + ny : ny;
          path.moveTo(x, y);
          sx = x;
          sy = y;
          cmd = rel ? 'l' : 'L'; // pasangan berikutnya = garis
        }
      case 'L':
        {
          final nx = n(), ny = n();
          x = rel ? x + nx : nx;
          y = rel ? y + ny : ny;
          path.lineTo(x, y);
        }
      case 'H':
        {
          final nx = n();
          x = rel ? x + nx : nx;
          path.lineTo(x, y);
        }
      case 'V':
        {
          final ny = n();
          y = rel ? y + ny : ny;
          path.lineTo(x, y);
        }
      case 'C':
        {
          final bx = rel ? x : 0.0, by = rel ? y : 0.0;
          final x1 = bx + n(), y1 = by + n();
          final x2 = bx + n(), y2 = by + n();
          final ex = bx + n(), ey = by + n();
          path.cubicTo(x1, y1, x2, y2, ex, ey);
          lcx = x2;
          lcy = y2;
          x = ex;
          y = ey;
          curve = true;
        }
      case 'S':
        {
          final bx = rel ? x : 0.0, by = rel ? y : 0.0;
          final x1 = prevCurve ? 2 * x - lcx : x;
          final y1 = prevCurve ? 2 * y - lcy : y;
          final x2 = bx + n(), y2 = by + n();
          final ex = bx + n(), ey = by + n();
          path.cubicTo(x1, y1, x2, y2, ex, ey);
          lcx = x2;
          lcy = y2;
          x = ex;
          y = ey;
          curve = true;
        }
      default:
        i++; // perintah tak dikenal: lewati
    }
    prevCurve = curve;
  }
  return path;
}