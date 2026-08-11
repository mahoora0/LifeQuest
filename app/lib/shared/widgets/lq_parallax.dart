import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 스크롤을 따라 본문보다 **느리게** 움직이는 요소.
///
/// 화면 전체가 한 덩어리로 밀려 올라가면 종이 한 장을 넘기는 느낌이 든다.
/// 일부 요소가 뒤처지면 층이 생겨 화면이 살아 있는 것처럼 읽힌다.
///
/// 값은 아주 작아야 한다 — 크게 주면 요소가 제자리에 있지 않고 떠다녀서
/// 어디에 속한 것인지 알 수 없어진다.
class LqParallax extends StatefulWidget {
  const LqParallax({
    super.key,
    required this.child,
    this.factor = 0.14,
    this.maxOffset = 48,
  });

  /// 스크롤 거리 대비 뒤처지는 비율. 양수면 본문보다 느리게 올라간다.
  final double factor;

  /// 아무리 스크롤해도 이만큼까지만 뒤처진다. 없으면 화면 밖으로 떠내려간다.
  final double maxOffset;

  final Widget child;

  @override
  State<LqParallax> createState() => _LqParallaxState();
}

class _LqParallaxState extends State<LqParallax> {
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 스크롤 뷰 밖에서도 그냥 그려지도록 없으면 null로 둔다.
    _position = Scrollable.maybeOf(context)?.position;
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    if (position == null || LqMotion.isReduced(context)) return widget.child;

    return AnimatedBuilder(
      animation: position,
      builder: (context, child) {
        // hasPixels 확인 없이 읽으면 첫 프레임에 예외가 난다.
        final pixels = position.hasPixels ? position.pixels : 0.0;
        final offset = (pixels * widget.factor).clamp(
          -widget.maxOffset,
          widget.maxOffset,
        );
        return Transform.translate(offset: Offset(0, offset), child: child);
      },
      child: widget.child,
    );
  }
}
