import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_icon.dart';
import 'package:life_quest/shared/widgets/lq_pressable.dart';

/// 필터 칩(pill).
///
/// 선택: `primary` 배경 + ink 테두리 + 흰 글자.
/// 미선택: `card` 배경 + `borderMuted` 테두리.
class LqChip extends StatelessWidget {
  const LqChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// 라벨 앞에 붙는 선 아이콘의 자산 경로([LqIcons]·[LqQuestIcons]).
  ///
  /// 색은 글자와 같이 뒤집히므로 선택 상태별 파일을 따로 두지 않는다.
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? LqColors.onDark : LqColors.textSecondary;
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: foreground,
      ),
    );

    return LqPressable(
      onTap: onTap,
      // 칩도 섀도가 없다. 탭 아이템보다는 작게 줄인다.
      builder: (context, t) => Transform.scale(
        scale: 1 - 0.04 * t,
        child: Container(
          // 칩 자체는 낮지만 최소 터치 타깃 44를 확보하기 위해 세로 여백을 준다.
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? LqColors.primary : LqColors.surfaceRaised,
            borderRadius: LqShape.pillRadius,
            border: Border.all(
              color: selected ? LqColors.ink : LqColors.borderMuted,
              width: LqShape.borderWidth,
            ),
          ),
          alignment: Alignment.center,
          child: icon == null
              ? text
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LqIcon(icon!, size: 16, color: foreground),
                    const SizedBox(width: 6),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

/// 칩을 가로 스크롤로 늘어놓는 필터 행.
class LqChipRow extends StatelessWidget {
  const LqChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: LqSpacing.screen),
    this.icons,
  }) : assert(
         icons == null || icons.length == labels.length,
         '아이콘을 주려면 라벨과 같은 길이여야 한다 — 짧으면 뒤쪽 칩만 조용히 아이콘을 잃는다',
       );

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  /// 칩별 아이콘 자산 경로. [labels]와 같은 길이여야 하고, 아이콘이 없는 칩은
  /// 그 자리를 null로 둔다("모든 주제"처럼 카테고리가 아닌 칩).
  final List<String?>? icons;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Center(
          child: LqChip(
            label: labels[index],
            selected: index == selectedIndex,
            onTap: () => onSelected(index),
            icon: icons?[index],
          ),
        ),
      ),
    );
  }
}
