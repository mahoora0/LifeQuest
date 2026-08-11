import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_pressable.dart';

/// 누르는 피드백(`10-motion-plan.md` P0).
///
/// 검증 대상은 "부드러워 보이는지"가 아니라 **눌린 상태의 값 · 복귀 · 취소** 셋이다.
/// 중간 상태는 `pumpAndSettle()`이 아니라 `pump(LqMotion.press)`로 프레임을 밟아 본다.
void main() {
  /// 첫 번째 `Container` 데코레이션의 섀도 오프셋.
  Offset shadowOffset(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(LqPressable),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    return decoration.boxShadow!.first.offset;
  }

  double translateY(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(LqPressable),
            matching: find.byType(Transform),
          )
          .first,
    );
    return transform.transform.getTranslation().y;
  }

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('누르면 섀도가 줄고 그만큼 내려간다', (tester) async {
    await tester.pumpWidget(host(LqButton(label: '확인', onPressed: () {})));

    expect(shadowOffset(tester), LqShape.buttonShadow.first.offset);
    expect(translateY(tester), 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LqButton)),
    );
    await tester.pump();
    await tester.pump(LqMotion.press);

    expect(shadowOffset(tester), LqShape.pressedShadowOffset);
    // 섀도가 줄어든 만큼 내려가야 섀도의 바깥 경계가 제자리에 남는다.
    expect(translateY(tester), LqShape.pressDepth(LqShape.buttonShadow).dy);

    await gesture.up();
  });

  testWidgets('손을 떼면 원래 상태로 돌아온다', (tester) async {
    await tester.pumpWidget(host(LqButton(label: '확인', onPressed: () {})));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LqButton)),
    );
    await tester.pump();
    await tester.pump(LqMotion.press);
    await gesture.up();
    await tester.pump();
    await tester.pump(LqMotion.press);

    expect(shadowOffset(tester), LqShape.buttonShadow.first.offset);
    expect(translateY(tester), 0);
  });

  testWidgets('드래그로 손가락이 벗어나면 눌림이 풀리고 탭도 일어나지 않는다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(LqCard(onTap: () => taps++, child: const Text('카드'))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LqCard)),
    );
    await tester.pump();
    await tester.pump(LqMotion.press);
    expect(shadowOffset(tester), LqShape.pressedShadowOffset);

    // 목록 안에서 스크롤로 빠져나가는 상황. onTapCancel이 와야 한다.
    await gesture.moveBy(const Offset(0, 80));
    await gesture.up();
    await tester.pump();
    await tester.pump(LqMotion.press);

    expect(shadowOffset(tester), LqShape.cardShadow.first.offset);
    expect(translateY(tester), 0);
    expect(taps, 0);
  });

  testWidgets('비활성 버튼은 눌리지 않는다', (tester) async {
    await tester.pumpWidget(host(const LqButton(label: '확인')));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LqButton)),
    );
    await tester.pump();
    await tester.pump(LqMotion.press);

    // 비활성은 섀도 자체가 없고, 내려가지도 않는다.
    expect(translateY(tester), 0);

    await gesture.up();
  });

  testWidgets('탭 콜백은 그대로 한 번 호출된다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(LqButton(label: '확인', onPressed: () => taps++)),
    );

    await tester.tap(find.byType(LqButton));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('탭이 없는 카드는 눌림 상태로 진입하지 않는다', (tester) async {
    await tester.pumpWidget(host(const LqCard(child: Text('카드'))));

    expect(find.byType(LqPressable), findsNothing);
  });

  test('눌린 섀도는 진행도에 따라 보간된다', () {
    final half = LqShape.pressShadow(LqShape.cardShadow, 0.5)!.first.offset;
    expect(half.dx, greaterThan(LqShape.pressedShadowOffset.dx));
    expect(half.dx, lessThan(LqShape.cardShadow.first.offset.dx));

    expect(
      LqShape.pressShadow(LqShape.cardShadow, 0)!.first.offset,
      LqShape.cardShadow.first.offset,
    );
    expect(
      LqShape.pressShadow(LqShape.cardShadow, 1)!.first.offset,
      LqShape.pressedShadowOffset,
    );
    expect(LqShape.pressShadow(null, 1), isNull);
  });
}
