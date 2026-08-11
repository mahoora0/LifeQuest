import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/shared/widgets/lq_swipe_action.dart';

/// 끌어서 실행하기(C).
///
/// 검증 대상은 **손가락을 따라오는지 · 임계값 판정 · 제자리로 돌아오는지**다.
/// 스프링의 모양(얼마나 튕기는지)은 테스트하지 않는다 — 값을 조정할 때마다
/// 깨지는 테스트는 조정을 막을 뿐이다.
void main() {
  double dxOf(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .ancestor(of: find.text('행'), matching: find.byType(Transform))
            .first,
      )
      .transform
      .getTranslation()
      .x;

  Widget host({
    required VoidCallback onCommit,
    bool enabled = true,
    bool reduced = false,
    double threshold = 80,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          child: LqSwipeAction(
            enabled: enabled,
            threshold: threshold,
            maxDrag: 120,
            onCommit: onCommit,
            semanticLabel: '완료',
            child: const SizedBox(height: 60, child: Text('행')),
          ),
        ),
      ),
    ),
  );

  testWidgets('끄는 동안 손가락을 그대로 따라온다', (tester) async {
    await tester.pumpWidget(host(onCommit: () {}));

    final gesture = await tester.startGesture(tester.getCenter(find.text('행')));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(dxOf(tester), closeTo(40, 0.01));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('상한을 넘겨 끌 수 없다', (tester) async {
    await tester.pumpWidget(host(onCommit: () {}));

    final gesture = await tester.startGesture(tester.getCenter(find.text('행')));
    await gesture.moveBy(const Offset(400, 0));
    await tester.pump();

    expect(dxOf(tester), 120);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('임계값을 넘겨 놓으면 실행되고 제자리로 돌아온다', (tester) async {
    var commits = 0;
    await tester.pumpWidget(host(onCommit: () => commits++));

    final gesture = await tester.startGesture(tester.getCenter(find.text('행')));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(commits, 1);
    // 실행 뒤에도 행은 제자리에 남는다 — 사라지면 무엇이 됐는지 확인할 수 없다.
    expect(dxOf(tester), closeTo(0, 0.5));
  });

  testWidgets('임계값에 못 미치면 실행하지 않고 되돌아온다', (tester) async {
    var commits = 0;
    await tester.pumpWidget(host(onCommit: () => commits++));

    final gesture = await tester.startGesture(tester.getCenter(find.text('행')));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(commits, 0);
    expect(dxOf(tester), closeTo(0, 0.5));
  });

  testWidgets('되돌아가는 중에 다시 잡으면 그 지점에서 이어받는다', (tester) async {
    await tester.pumpWidget(host(onCommit: () {}));

    final first = await tester.startGesture(tester.getCenter(find.text('행')));
    await first.moveBy(const Offset(60, 0));
    await tester.pump();
    await first.up();

    // 스프링이 도는 중.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = dxOf(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(60));

    final second = await tester.startGesture(tester.getCenter(find.text('행')));
    await tester.pump();
    // 0으로 튀지 않고 그 자리에서 이어받아야 조작이 미끄러지지 않는다.
    expect(dxOf(tester), closeTo(mid, 0.01));

    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('끌 수 없는 행에는 제스처를 붙이지 않는다', (tester) async {
    await tester.pumpWidget(host(onCommit: () {}, enabled: false));

    expect(find.byType(GestureDetector), findsNothing);
    expect(find.text('행'), findsOneWidget);
  });

  testWidgets('동작 줄이기에서는 끌기를 제공하지 않는다', (tester) async {
    await tester.pumpWidget(host(onCommit: () {}, reduced: true));

    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('스크린 리더용 동작을 함께 등록한다', (tester) async {
    var commits = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(onCommit: () => commits++));

    // 끌기는 스크린 리더 사용자가 쓸 수 없는 조작이라, 같은 일을 하는 사용자 정의
    // 동작이 함께 있어야 한다.
    final node = tester.getSemantics(find.byType(LqSwipeAction));
    expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
    expect(commits, 0, reason: '등록만으로 실행되면 안 된다');

    handle.dispose();
  });
}
