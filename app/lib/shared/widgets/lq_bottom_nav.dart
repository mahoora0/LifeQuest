import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_icon.dart';
import 'package:life_quest/shared/widgets/lq_pressable.dart';

/// 하단 탭바 — Material `NavigationBar`는 스타일이 맞지 않아 사용하지 않는다.
///
/// `surfaceNav` 배경 · 상단 ink 2px 테두리 · 상하 패딩 8/10 · 아이콘 20 + 라벨 11.5.
///
/// 탭 바는 프레임(`surfacePanel`)보다 한 톤 어둡게 두어 화면 바탕과 구분한다.
class LqBottomNav extends StatelessWidget {
  const LqBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const destinations = <LqNavDestination>[
    LqNavDestination(icon: LqIcons.home, label: '홈'),
    LqNavDestination(icon: LqIcons.quest, label: '퀘스트'),
    // 지도 대신 그룹이 들어간다. 그룹은 마이페이지 메뉴 안쪽에 있어 찾기 어려웠고,
    // 지도는 이 자리를 쓰던 화면 중 진입 빈도가 가장 낮았다.
    LqNavDestination(icon: LqIcons.group, label: '그룹'),
    // LifeDex 도감은 탭에서 빠지고 마이페이지 "나의 기록"에서 push로 연다.
    LqNavDestination(icon: LqIcons.friends, label: '친구'),
    LqNavDestination(icon: LqIcons.my, label: '마이'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: LqColors.surfaceNav,
        border: Border(
          top: BorderSide(color: LqColors.ink, width: LqShape.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LqNavDestination {
  const LqNavDestination({required this.icon, required this.label});

  /// `LqIcons`의 SVG 에셋 경로.
  final String icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final LqNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? LqColors.tabActive : LqColors.tabInactive;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      // 탭 아이템에는 섀도가 없어 내려앉힐 자리가 없다. 아주 약한 축소로만
      // 눌린 것을 알린다 — 탭 바가 통째로 출렁이면 산만하다.
      child: LqPressable(
        onTap: onTap,
        builder: (context, t) => Transform.scale(
          scale: 1 - 0.06 * t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LqIcon(destination.icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: LqText.tabLabel.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
