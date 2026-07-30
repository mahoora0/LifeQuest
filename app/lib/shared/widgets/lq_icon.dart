import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 선 아이콘 — `LqIcons`의 SVG를 지정한 색으로 칠해 그린다.
///
/// SVG 원본은 stroke 색이 잉크로 고정되어 있으므로 [color]를 `srcIn`으로 덮어쓴다.
/// 아이콘 폰트를 쓰지 않는 것이 시안 규칙이라 화면 코드는 이 위젯만 사용한다.
class LqIcon extends StatelessWidget {
  const LqIcon(
    this.asset, {
    super.key,
    this.size = 20,
    this.color = LqColors.ink,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      // 에셋이 아직 배치되지 않은 환경에서도 레이아웃이 흔들리지 않게 자리를 잡아 둔다.
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}
