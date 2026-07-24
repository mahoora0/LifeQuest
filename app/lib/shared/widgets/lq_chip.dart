import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

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
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 칩 자체는 낮지만 최소 터치 타깃 44를 확보하기 위해 세로 여백을 준다.
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? LqColors.primary : LqColors.card,
          borderRadius: LqShape.pillRadius,
          border: Border.all(
            color: selected ? LqColors.ink : LqColors.borderMuted,
            width: LqShape.borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: selected ? LqColors.onDark : LqColors.textSecondary,
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
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

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
          ),
        ),
      ),
    );
  }
}
