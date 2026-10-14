import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class Neon {
  static const purple = Color(0xFF9146FF);
  static const violet = Color(0xFFB98CFF);
  static const pink = Color(0xFFFF4FD8);
  static const cyan = Color(0xFF3DF2FF);
  static const gold = Color(0xFFFFD54F);
  static const peach = Color(0xFFFFC89A);
  static const live = Color(0xFFFF3B6B);

  static const brandGradient = LinearGradient(
    colors: [purple, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class NeonColors {
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color text;
  final Color muted;

  final double glow;

  const NeonColors({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.text,
    required this.muted,
    required this.glow,
  });

  static const dark = NeonColors(
    background: Color(0xFF0B0718),
    backgroundAlt: Color(0xFF1B0F3D),
    surface: Color(0xFF140E2B),
    surfaceRaised: Color(0xFF1E1641),
    border: Color(0xFF342A60),
    text: Color(0xFFF4F0FF),
    muted: Color(0xFFA99DCF),
    glow: 1,
  );

  static const light = NeonColors(
    background: Color(0xFFF4EFFF),
    backgroundAlt: Color(0xFFE2D6FF),
    surface: Colors.white,
    surfaceRaised: Color(0xFFF8F5FF),
    border: Color(0xFFDCD0FA),
    text: Color(0xFF221A3D),
    muted: Color(0xFF6E6491),
    glow: 0.45,
  );

  static NeonColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildNeonTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? NeonColors.dark : NeonColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Neon.purple,
        brightness: brightness,
      ).copyWith(
        primary: Neon.purple,
        onPrimary: Colors.white,
        secondary: Neon.pink,
        surface: c.surface,
        onSurface: c.text,
        onSurfaceVariant: c.muted,
        outline: c.border,
      );
  final rounded14 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceRaised,
      prefixIconColor: c.muted,
      suffixIconColor: c.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Neon.purple, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Neon.purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: rounded14,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: const BorderSide(color: Neon.purple, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: rounded14,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brightness == Brightness.dark
            ? Neon.violet
            : Neon.purple,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceRaised,
      selectedColor: Neon.purple.withValues(alpha: 0.28),
      side: BorderSide(color: c.border),
      labelStyle: TextStyle(color: c.text, fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: c.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceRaised,
      contentTextStyle: TextStyle(color: c.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Neon.purple),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Neon.purple.withValues(alpha: 0.24),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected) ? c.text : c.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (brightness == Brightness.dark ? Neon.violet : Neon.purple)
              : c.muted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Neon.purple : null,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Neon.purple.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
    ),
    dividerTheme: DividerThemeData(color: c.border),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Neon.purple,
    ),
  );
}

class NeonScrollBehavior extends MaterialScrollBehavior {
  const NeonScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class NeonBackground extends StatelessWidget {
  final Widget child;
  const NeonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.background, c.backgroundAlt],
                ),
              ),
              child: CustomPaint(painter: _StarfieldPainter(c)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final NeonColors colors;
  _StarfieldPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    void haze(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.22 * colors.glow),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    haze(Offset(size.width * 0.1, 0), size.shortestSide * 0.8, Neon.purple);
    haze(
      Offset(size.width, size.height * 0.75),
      size.shortestSide * 0.7,
      Neon.pink,
    );

    final random = math.Random(42);
    final starColor = colors.glow >= 1 ? Colors.white : Neon.purple;
    final count = (size.width * size.height / 9000).clamp(40, 220).toInt();
    final dot = Paint();
    for (var i = 0; i < count; i++) {
      final p = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      dot.color = starColor.withValues(
        alpha: 0.15 + random.nextDouble() * 0.45,
      );
      canvas.drawCircle(p, 0.4 + random.nextDouble() * 1.2, dot);
    }
    for (var i = 0; i < count ~/ 14; i++) {
      final p = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      drawSparkle(
        canvas,
        p,
        3 + random.nextDouble() * 4,
        starColor.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

void drawSparkle(Canvas canvas, Offset c, double r, Color color) {
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

class PlanetPainter extends CustomPainter {
  final Color body;
  final Color bodyShade;
  final List<Color> ring;

  const PlanetPainter({
    this.body = Neon.peach,
    this.bodyShade = Neon.pink,
    this.ring = const [Neon.violet, Neon.peach, Neon.pink],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.3;
    final center = size.center(Offset.zero);

    canvas.drawCircle(
      center,
      r * 1.25,
      Paint()
        ..color = bodyShade.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.38);
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 3.2,
      height: r * 0.95,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.17
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: ring).createShader(ringRect);

    canvas.drawArc(ringRect, math.pi, math.pi, false, ringPaint);

    final planet = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: [Color.lerp(body, Colors.white, 0.35)!, body, bodyShade],
          stops: const [0, 0.55, 1],
        ).createShader(planet),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(planet));
    final band = Paint()..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -r * 0.3),
        width: r * 2.4,
        height: r * 0.28,
      ),
      band,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.25),
        width: r * 2.4,
        height: r * 0.18,
      ),
      band,
    );
    canvas.restore();

    canvas.drawArc(ringRect, 0, math.pi, false, ringPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlanetPainter oldDelegate) =>
      oldDelegate.body != body || oldDelegate.bodyShade != bodyShade;
}

class TwinkleField extends StatefulWidget {
  final List<Offset> points;
  final Color color;
  const TwinkleField({
    super.key,
    required this.points,
    this.color = Colors.white,
  });

  @override
  State<TwinkleField> createState() => _TwinkleFieldState();
}

class _TwinkleFieldState extends State<TwinkleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
    value: 0.25,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _TwinklePainter(_controller, widget.points, widget.color),
      ),
    );
  }
}

class _TwinklePainter extends CustomPainter {
  final Animation<double> animation;
  final List<Offset> points;
  final Color color;

  _TwinklePainter(this.animation, this.points, this.color)
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length; i++) {
      final phase = (animation.value + i / points.length) * 2 * math.pi;
      final t = (math.sin(phase) + 1) / 2;
      final p = Offset(points[i].dx * size.width, points[i].dy * size.height);
      drawSparkle(
        canvas,
        p,
        4 + t * 4,
        color.withValues(alpha: 0.35 + t * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter oldDelegate) => false;
}

class NeonCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final VoidCallback? onTap;
  final double radius;

  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent = Neon.purple,
    this.onTap,
    this.radius = 20,
  });

  @override
  State<NeonCard> createState() => _NeonCardState();
}

class _NeonCardState extends State<NeonCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final radius = BorderRadius.circular(widget.radius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered && widget.onTap != null ? 1.012 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: c.glow >= 1 ? 0.88 : 1),
            borderRadius: radius,
            border: Border.all(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.85)
                  : c.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(
                  alpha: (_hovered ? 0.35 : 0.12) * c.glow,
                ),
                blurRadius: _hovered ? 28 : 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              child: ClipRRect(
                borderRadius: radius,
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final Color foreground;
  final bool expand;

  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.gradient = Neon.brandGradient,
    this.foreground = Colors.white,
    this.expand = false,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final glow = NeonColors.of(context).glow;
    final firstColor = widget.gradient.colors.first;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: widget.foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: firstColor.withValues(
                alpha: (_hovered ? 0.6 : 0.35) * glow,
              ),
              blurRadius: _hovered ? 24 : 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? textAlign;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = Neon.brandGradient,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

class NeonAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final bool live;

  const NeonAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 48,
    this.imageUrl,
    this.imageBytes,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final glow = NeonColors.of(context).glow;
    final fallback = Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );

    Widget picture = fallback;
    if (imageBytes != null) {
      picture = Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (imageUrl != null) {
      picture = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        frameBuilder: (_, child, frame, wasSync) => Stack(
          fit: StackFit.expand,
          children: [
            fallback,
            AnimatedOpacity(
              opacity: wasSync || frame != null ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: child,
            ),
          ],
        ),
      );
    }

    final ringColors = live
        ? const [Neon.live, Neon.pink, Neon.live]
        : const [Neon.purple, Neon.pink, Neon.cyan, Neon.purple];

    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(math.max(2, size * 0.05)),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: ringColors),
        boxShadow: [
          BoxShadow(
            color: ringColors.first.withValues(alpha: 0.45 * glow),
            blurRadius: size * 0.3,
          ),
        ],
      ),
      child: ClipOval(child: SizedBox.expand(child: picture)),
    );

    if (!live) return avatar;

    return SizedBox(
      width: size,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          avatar,
          Positioned(bottom: 0, child: LiveBadge(small: size < 56)),
        ],
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 18});

  static const color = Color(0xFF0866FF);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified creator',
      child: Semantics(
        label: 'Verified creator',
        child: CustomPaint(
          size: Size.square(size),
          painter: const _VerifiedPainter(),
        ),
      ),
    );
  }
}

class _VerifiedPainter extends CustomPainter {
  const _VerifiedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    const bumps = 12;
    final rim = Path();
    for (var i = 0; i <= 360; i++) {
      final a = i * math.pi / 180;
      final r = radius * (0.9 + 0.1 * math.cos(bumps * a));
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? rim.moveTo(p.dx, p.dy) : rim.lineTo(p.dx, p.dy);
    }
    rim.close();
    canvas.drawPath(rim, Paint()..color = VerifiedBadge.color);

    final w = size.width;
    final check = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.72, w * 0.37);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_VerifiedPainter oldDelegate) => false;
}

class LiveBadge extends StatelessWidget {
  final bool small;
  const LiveBadge({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 8,
        vertical: small ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: Neon.live,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Neon.live.withValues(alpha: 0.6), blurRadius: 10),
        ],
      ),
      child: Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 8 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class NeonPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const NeonPill({
    super.key,
    required this.label,
    this.color = Neon.purple,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = NeonColors.of(context).glow >= 1;
    final fg = dark ? Color.lerp(color, Colors.white, 0.35)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class JarJarLogo extends StatelessWidget {
  final double size;
  const JarJarLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final glow = NeonColors.of(context).glow;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: Neon.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: Neon.purple.withValues(alpha: 0.55 * glow),
            blurRadius: size * 0.5,
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.66),
          painter: const _JarPainter(
            jarColor: Colors.white,
            coinColor: Neon.gold,
          ),
        ),
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  final Color jarColor;
  final Color coinColor;

  const _JarPainter({required this.jarColor, required this.coinColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final jarPaint = Paint()..color = jarColor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.26, h * 0.04, w * 0.48, h * 0.14),
        Radius.circular(w * 0.05),
      ),
      jarPaint,
    );

    final body = Path()
      ..moveTo(w * 0.34, h * 0.22)
      ..lineTo(w * 0.66, h * 0.22)
      ..lineTo(w * 0.66, h * 0.28)
      ..quadraticBezierTo(w * 0.88, h * 0.34, w * 0.88, h * 0.52)
      ..lineTo(w * 0.88, h * 0.82)
      ..quadraticBezierTo(w * 0.88, h * 0.96, w * 0.74, h * 0.96)
      ..lineTo(w * 0.26, h * 0.96)
      ..quadraticBezierTo(w * 0.12, h * 0.96, w * 0.12, h * 0.82)
      ..lineTo(w * 0.12, h * 0.52)
      ..quadraticBezierTo(w * 0.12, h * 0.34, w * 0.34, h * 0.28)
      ..close();
    canvas.drawPath(body, jarPaint);

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.64),
      w * 0.16,
      Paint()..color = coinColor,
    );
  }

  @override
  bool shouldRepaint(_JarPainter oldDelegate) =>
      oldDelegate.jarColor != jarColor || oldDelegate.coinColor != coinColor;
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 44,
          margin: const EdgeInsets.only(right: 12, top: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Neon.purple, Neon.pink],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Neon.pink.withValues(alpha: 0.6 * c.glow),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: c.muted, height: 1.4)),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(_curve),
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
