import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/quest/presentation/widgets/quest_rows.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 체크 버튼 자리 연출(B).
///
/// 완료를 누른 자리에서 무엇이 일어났는지 보이는 것이 목적이다. 검증 대상은
/// **연출이 도는 조건**이지 모양이 아니다.
void main() {
  Widget host({
    required bool checked,
    int? expReward = 10,
    bool reduced = false,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: QuestCheckButton(
          checked: checked,
          expReward: expReward,
          onTap: () {},
        ),
      ),
    ),
  );

  testWidgets('완료로 바뀌면 +EXP가 떠올랐다 사라진다', (tester) async {
    await tester.pumpWidget(host(checked: false));
    expect(find.text('+10'), findsNothing);

    await tester.pumpWidget(host(checked: true));
    await tester.pump();
    await tester.pump(LqMotion.emphasized ~/ 2);
    expect(find.text('+10'), findsOneWidget);

    await tester.pumpAndSettle();
    // 떠오른 뒤에는 자리를 차지하지 않는다.
    expect(find.text('+10'), findsNothing);
  });

  testWidgets('처음부터 완료인 행은 연출하지 않는다', (tester) async {
    // 목록을 다시 열었을 때 모든 완료 행이 한꺼번에 터지면 안 된다.
    await tester.pumpWidget(host(checked: true));
    await tester.pump();
    await tester.pump(LqMotion.emphasized ~/ 2);

    expect(find.text('+10'), findsNothing);
  });

  testWidgets('동작 줄이기에서는 연출 없이 상태만 바뀐다', (tester) async {
    await tester.pumpWidget(host(checked: false, reduced: true));
    await tester.pumpWidget(host(checked: true, reduced: true));
    await tester.pump();
    await tester.pump(LqMotion.emphasized ~/ 2);

    expect(find.text('+10'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('EXP를 주지 않으면 라벨을 만들지 않는다', (tester) async {
    await tester.pumpWidget(host(checked: false, expReward: null));
    await tester.pumpWidget(host(checked: true, expReward: null));
    await tester.pump();
    await tester.pump(LqMotion.emphasized ~/ 2);

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  test('연출 길이는 결과 화면으로 넘어가기 전에 끝난다', () {
    // 이 값보다 이동이 빠르면 체크가 채워지는 것을 못 본다.
    expect(questCheckCelebration.inMilliseconds, greaterThan(300));
    expect(
      questCheckCelebration,
      lessThan(const Duration(milliseconds: 600)),
      reason: '더 끌면 반응이 굼뜨게 느껴진다',
    );
  });
}
