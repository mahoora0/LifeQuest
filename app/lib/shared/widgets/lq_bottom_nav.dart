import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

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
    LqNavDestination(icon: Icons.home_outlined, label: '홈'),
    LqNavDestination(icon: Icons.flag_outlined, label: '퀘스트'),
    LqNavDestination(icon: Icons.map_outlined, label: '지도'),
    // LifeDex 도감은 탭에서 빠지고 마이페이지 "나의 기록"에서 push로 연다.
    LqNavDestination(icon: Icons.group_outlined, label: '친구'),
    LqNavDestination(icon: Icons.person_outline, label: '마이'),
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

  final IconData icon;
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, size: 20, color: color),
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
    );
  }
}
