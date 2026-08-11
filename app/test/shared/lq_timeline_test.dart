import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/shared/widgets/lq_timeline.dart';

/// 연출 시간표(A).
///
/// 검증 대상은 **순서**다 — 뒤 요소가 앞 요소보다 늦게 또렷해지고, 숫자가
/// 최종값에 한 번에 도달하지 않으며, 끝나면 전부 제자리라는 것.
void main() {
  const total = Duration(milliseconds: 1000);

  Widget host({required Widget child, bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LqTimeline(duration: total, child: child),
    ),
  );

  double opacityOf(WidgetTester tester, String text) => tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text(text), matching: find.byType(Opacity))
            .first,
      )
      .opacity;

  testWidgets('앞 단계가 뒤 단계보다 먼저 또렷해진다', (tester) async {
    await tester.pumpWidget(
      host(
        child: const Column(
          children: [
            LqTimelineStep(start: 0, end: 0.3, child: Text('먼저')),
            LqTimelineStep(start: 0.6, end: 1, child: Text('나중')),
          ],
        ),
      ),
    );

    await tester.pump();
    expect(opacityOf(tester, '먼저'), 0);
    expect(opacityOf(tester, '나중'), 0);

    await tester.pump(total * 0.35);
    expect(opacityOf(tester, '먼저'), 1);
    expect(opacityOf(tester, '나중'), 0, reason: '아직 자기 차례가 아니다');

    await tester.pump(total);
    expect(opacityOf(tester, '먼저'), 1);
    expect(opacityOf(tester, '나중'), 1);
  });

  testWidgets('숫자는 0에서 최종값까지 세어 올라간다', (tester) async {
    await tester.pumpWidget(
      host(
        child: LqCountUp(
          value: 40,
          start: 0,
          end: 1,
          builder: (context, value) => Text('EXP $value'),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('EXP 0'), findsOneWidget);

    await tester.pump(total ~/ 2);
    expect(find.text('EXP 0'), findsNothing);
    expect(find.text('EXP 40'), findsNothing, reason: '중간에 최종값이면 세는 의미가 없다');

    await tester.pump(total);
    expect(find.text('EXP 40'), findsOneWidget);
  });

  testWidgets('동작 줄이기에서는 연출을 건너뛰고 결과만 보여준다', (tester) async {
    await tester.pumpWidget(
      host(
        reduced: true,
        child: Column(
          children: [
            const LqTimelineStep(start: 0.6, end: 1, child: Text('나중')),
            LqCountUp(
              value: 40,
              builder: (context, value) => Text('EXP $value'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(opacityOf(tester, '나중'), 1);
    expect(find.text('EXP 40'), findsOneWidget);
    // 남은 애니메이션이 없다는 뜻이다.
    await tester.pumpAndSettle();
  });

  testWidgets('시간표 밖에서는 최종 상태로 그려진다', (tester) async {
    // 위젯을 재사용해 다른 화면에 붙였을 때 사라져 보이면 안 된다.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LqTimelineStep(start: 0.9, end: 1, child: Text('홀로')),
      ),
    );

    expect(find.text('홀로'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });
}
