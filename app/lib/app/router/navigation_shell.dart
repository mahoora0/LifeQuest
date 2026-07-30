import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_bottom_nav.dart';

class NavigationShell extends StatelessWidget {
  const NavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: navigationShell,
      bottomNavigationBar: LqBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) {
          navigationShell.goBranch(
            index,
            // 이미 선택된 탭을 다시 누르면 해당 브랜치의 첫 화면으로 돌아간다.
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
