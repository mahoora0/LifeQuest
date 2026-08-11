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
      body: _BranchFade(
        index: navigationShell.currentIndex,
        child: navigationShell,
      ),
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

/// 탭이 바뀌는 순간에만 짧게 겹쳐 흐린다(fade through).
///
/// 탭은 옆으로 미는 관계가 아니라 서로 독립된 화면이므로 slide를 쓰지 않는다.
///
/// [child]를 `AnimatedSwitcher`에 넣지 않는 이유가 중요하다 — 그러면 브랜치의
/// `IndexedStack`이 통째로 교체돼 각 탭의 스크롤 위치와 화면 상태가 날아간다.
/// 여기서는 같은 자식을 그대로 두고 불투명도만 한 번 밟고 지나간다.
class _BranchFade extends StatefulWidget {
  const _BranchFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LqMotion.normal,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = LqMotion.of(context, LqMotion.normal);
  }

  @override
  void didUpdateWidget(_BranchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: LqMotion.standard,
    );
    return FadeTransition(
      // 0에서 시작하면 탭을 옮길 때마다 화면이 깜빡인 것처럼 읽힌다.
      opacity: Tween<double>(begin: 0.55, end: 1).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.99, end: 1).animate(curved),
        child: widget.child,
      ),
    );
  }
}
