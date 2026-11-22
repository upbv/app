import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/palette.dart';

/// A smooth area chart drawn by hand so the look matches the rest of the app.
///
/// The curve uses monotone cubic interpolation, which keeps the line from
/// dipping below neighbours the way a naive spline would.
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 120,
    this.strokeWidth = 1.6,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.filled = true,
  });

  final List<double> values;
  final Color color;
  final double height;
  final double strokeWidth;
  final bool showGrid;
  final bool showAxisLabels;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            painter: _SparklinePainter(
              values: values,
              color: color,
              gridColor: isDark ? Palette.darkHairline : Palette.hairline,
              strokeWidth: strokeWidth,
              showGrid: showGrid,
              filled: filled,
              fillColor: color.withValues(alpha: isDark ? 0.16 : 0.10),
              labelStyle: theme.textTheme.labelSmall,
              showAxisLabels: showAxisLabels,
            ),
            size: Size(constraints.maxWidth, height),
          );
        },
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.gridColor,
    required this.strokeWidth,
    required this.showGrid,
    required this.filled,
    required this.fillColor,
    required this.labelStyle,
    required this.showAxisLabels,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;
  final double strokeWidth;
  final bool showGrid;
  final bool filled;
  final Color fillColor;
  final TextStyle? labelStyle;
  final bool showAxisLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final hasValues = values.length > 1;
    final top = showAxisLabels ? 16.0 : 4.0;
    final bottom = showAxisLabels ? 18.0 : 4.0;
    final chartHeight = size.height - top - bottom;
    if (chartHeight <= 0) return;

    // Horizontal guides.
    if (showGrid) {
      final paint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (var i = 0; i <= 3; i++) {
        final y = top + chartHeight * i / 3;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    if (!hasValues) {
      _drawPlaceholder(canvas, size, top, chartHeight);
      return;
    }

    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    var span = maxValue - minValue;
    if (span < 1e-6) {
      span = math.max(maxValue * 0.2, 1.0);
    }
    // Keep a little headroom so the line never touches the frame.
    final upper = maxValue + span * 0.12;
    final lower = math.max(0.0, minValue - span * 0.12);

    final dx = size.width / (values.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final norm = (values[i] - lower) / (upper - lower);
      final y = top + chartHeight * (1 - norm.clamp(0.0, 1.0));
      points.add(Offset(x, y));
    }

    final path = _smoothPath(points);

    if (filled) {
      final area = Path.from(path)
        ..lineTo(points.last.dx, top + chartHeight)
        ..lineTo(points.first.dx, top + chartHeight)
        ..close();
      canvas.drawPath(area, Paint()..color = fillColor);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Highlight the newest reading.
    final last = points.last;
    canvas.drawCircle(last, strokeWidth + 1.4, Paint()..color = fillColor);
    canvas.drawCircle(last, strokeWidth, Paint()..color = color);

    if (showAxisLabels) {
      _drawLabels(canvas, size, upper, lower, top, chartHeight);
    }
  }

  void _drawPlaceholder(Canvas canvas, Size size, double top, double chartHeight) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final midY = top + chartHeight / 2;
    final path = Path()..moveTo(0, midY);
    for (var x = 0.0; x <= size.width; x += 6) {
      path.lineTo(x, midY + math.sin(x / 9) * 3);
    }
    canvas.drawPath(path, paint);
  }

  void _drawLabels(
    Canvas canvas,
    Size size,
    double upper,
    double lower,
    double top,
    double chartHeight,
  ) {
    final style = labelStyle;
    if (style == null) return;

    void label(double value, double y, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(text: _short(value), style: style),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      tp.paint(canvas, Offset(align == TextAlign.right ? size.width - tp.width : 0, y));
    }

    label(upper, 0, TextAlign.left);
    label(lower, top + chartHeight - tpHeight(style), TextAlign.left);
  }

  double tpHeight(TextStyle style) => style.fontSize ?? 10;

  String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  /// Builds a monotone cubic path through the given points.
  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    final n = points.length;
    final dx = points[1].dx - points[0].dx;
    final slopes = List<double>.filled(n - 1, 0);
    for (var i = 0; i < n - 1; i++) {
      slopes[i] = (points[i + 1].dy - points[i].dy) / dx;
    }

    final tangents = List<double>.filled(n, 0);
    tangents[0] = slopes.first;
    tangents[n - 1] = slopes.last;
    for (var i = 1; i < n - 1; i++) {
      if (slopes[i - 1] * slopes[i] <= 0) {
        tangents[i] = 0;
      } else {
        tangents[i] = (slopes[i - 1] + slopes[i]) / 2;
      }
    }

    for (var i = 0; i < n - 1; i++) {
      final dxNext = points[i + 1].dx - points[i].dx;
      final dxMid = dxNext / 2;
      path.cubicTo(
        points[i].dx + dxMid,
        points[i].dy + tangents[i] * dxMid,
        points[i + 1].dx - dxMid,
        points[i + 1].dy - tangents[i + 1] * dxMid,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(_SparklinePainter old) {
    return old.values != values ||
        old.color != color ||
        old.filled != filled ||
        old.showGrid != showGrid;
  }
}

/// A donut style gauge used for the CPU and memory tiles.
class RadialGauge extends StatelessWidget {
  const RadialGauge({
    super.key,
    required this.value,
    required this.color,
    this.size = 116,
    this.strokeWidth = 9,
    this.label,
    this.caption,
  });

  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final String? label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _GaugePainter(
              value: value.clamp(0, 100) / 100,
              color: color,
              trackColor:
                  isDark ? Palette.darkSurfaceAlt : Palette.canvasDeep,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label ?? '${value.round()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: size * 0.17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (caption != null)
                Text(caption!, style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color;
}

/// A horizontal stacked bar for the storage overview.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({
    super.key,
    required this.segments,
    this.height = 10,
  });

  final List<({Color color, double value})> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return SizedBox(height: height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: segments.map((s) {
            return Expanded(
              flex: (s.value / total * 1000).round().clamp(1, 1000),
              child: Container(color: s.color),
            );
          }).toList(),
        ),
      ),
    );
  }
}
