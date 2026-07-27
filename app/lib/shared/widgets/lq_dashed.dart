import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 점선 테두리 페인터.
///
/// 시안의 "잠김 / 비어있음" 상태는 모두 2px 점선 테두리를 쓴다.
/// 외부 패키지 대신 이 `CustomPainter` 하나로 테두리·구분선을 모두 그린다.
class LqDashedBorderPainter extends CustomPainter {
  const LqDashedBorderPainter({
    this.radius = LqShape.cardRadius,
    this.color = LqColors.borderMuted,
    this.strokeWidth = LqShape.borderWidth,
    this.dashLength = 6,
    this.gapLength = 4.5,
  });

  final BorderRadius radius;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - strokeWidth),
      math.max(0, size.height - strokeWidth),
    );
    final path = Path()..addRRect(radius.toRRect(rect));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(LqDashedBorderPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}

/// 점선 구분선(시안의 대부분 구분선은 dashed).
///
/// [axis]를 [Axis.vertical]로 두면 세로 구분선이 된다 — 시안의 성장 기록 3칸처럼
/// 나란한 칸을 나눌 때 쓴다. 세로일 때는 부모가 높이를 정해 줘야 한다.
class LqDashedDivider extends StatelessWidget {
  const LqDashedDivider({
    super.key,
    this.color = LqColors.divider,
    this.thickness = 1.6,
    this.dashLength = 5,
    this.gapLength = 4,
    this.axis = Axis.horizontal,
  });

  final Color color;
  final double thickness;
  final double dashLength;
  final double gapLength;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final painter = _LqDashedLinePainter(
      color: color,
      thickness: thickness,
      dashLength: dashLength,
      gapLength: gapLength,
      axis: axis,
    );

    if (axis == Axis.vertical) {
      return SizedBox(
        width: thickness,
        child: CustomPaint(painter: painter),
      );
    }
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(painter: painter),
    );
  }
}

class _LqDashedLinePainter extends CustomPainter {
  const _LqDashedLinePainter({
    required this.color,
    required this.thickness,
    required this.dashLength,
    required this.gapLength,
    required this.axis,
  });

  final Color color;
  final double thickness;
  final double dashLength;
  final double gapLength;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    if (axis == Axis.vertical) {
      final x = size.width / 2;
      var y = 0.0;
      while (y < size.height) {
        final next = math.min(y + dashLength, size.height);
        canvas.drawLine(Offset(x, y), Offset(x, next), paint);
        y = next + gapLength;
      }
      return;
    }

    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final next = math.min(x + dashLength, size.width);
      canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      x = next + gapLength;
    }
  }

  @override
  bool shouldRepaint(_LqDashedLinePainter old) =>
      old.color != color ||
      old.thickness != thickness ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength ||
      old.axis != axis;
}

/// 점선 원(GPS 레이더의 동심원).
class LqDashedCirclePainter extends CustomPainter {
  const LqDashedCirclePainter({
    this.color = LqColors.borderMuted,
    this.strokeWidth = 2,
    this.dashCount = 34,
  });

  final Color color;
  final double strokeWidth;
  final int dashCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final sweep = (2 * math.pi) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(LqDashedCirclePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashCount != dashCount;
}
