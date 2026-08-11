import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/shared/widgets/lq_parallax.dart';

/// 스크롤 패럴랙스(D).
void main() {
  Widget host({
    double factor = 0.2,
    double maxOffset = 40,
    bool reduced = false,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ListView(
        children: [
          // 스크롤해도 화면에 남아 있어야 값을 읽을 수 있다.
          const SizedBox(height: 300),
          LqParallax(
            factor: factor,
            maxOffset: maxOffset,
            child: const Text('캐릭터'),
          ),
          const SizedBox(height: 2000),
        ],
      ),
    ),
  );

  double offsetOf(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .ancestor(of: find.text('캐릭터'), matching: find.byType(Transform))
            .first,
      )
      .transform
      .getTranslation()
      .y;

  testWidgets('스크롤한 만큼 본문보다 뒤처진다', (tester) async {
    await tester.pumpWidget(host());
    expect(offsetOf(tester), 0);

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();

    // 100 * 0.2 = 20. 본문이 100 올라가는 동안 20만 덜 올라간다.
    expect(offsetOf(tester), closeTo(20, 0.01));
  });

  testWidgets('상한을 넘어서는 따라가지 않는다', (tester) async {
    // 계수를 크게 잡아 상한이 곧바로 걸리게 한다(100 * 1.0 > 30).
    await tester.pumpWidget(host(factor: 1, maxOffset: 30));

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();

    // 상한이 없으면 요소가 화면 밖으로 떠내려간다.
    expect(offsetOf(tester), 30);
  });

  testWidgets('동작 줄이기에서는 따라 움직이지 않는다', (tester) async {
    await tester.pumpWidget(host(reduced: true));

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();

    expect(
      find.ancestor(of: find.text('캐릭터'), matching: find.byType(Transform)),
      findsNothing,
    );
  });

  testWidgets('스크롤 뷰 밖에서는 그냥 그려진다', (tester) async {
    // 위젯을 다른 화면으로 옮겼을 때 예외가 나면 안 된다.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LqParallax(child: Text('캐릭터')),
      ),
    );

    expect(find.text('캐릭터'), findsOneWidget);
  });
}
