import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_pressable.dart';
import 'package:life_quest/shared/widgets/lq_pulse_ring.dart';
import 'package:life_quest/shared/widgets/lq_speck.dart';
import 'package:life_quest/shared/widgets/lq_stagger.dart';

/// 동작 줄이기 대응(`10-motion-plan.md` P3-a).
///
/// 접근성 요건이자 테스트 부채 상환이다 — 끝나지 않는 장식 때문에 이 위젯이 든
/// 화면에서는 `pumpAndSettle()`을 쓸 수 없었다.
void main() {
  Widget host(Widget child, {required bool reduced}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  group('LqMotion', () {
    testWidgets('동작 줄이기를 켜면 duration이 0이 된다', (tester) async {
      late Duration reduced;
      late Duration normal;

      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              reduced = LqMotion.of(context, LqMotion.normal);
              return const SizedBox();
            },
          ),
          reduced: true,
        ),
      );
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              normal = LqMotion.of(context, LqMotion.normal);
              return const SizedBox();
            },
          ),
          reduced: false,
        ),
      );

      expect(reduced, Duration.zero);
      expect(normal, LqMotion.normal);
    });
  });

  group('끝나지 않는 장식', () {
    testWidgets('LqSpeck은 동작 줄이기에서 멈춘다', (tester) async {
      await tester.pumpWidget(
        host(const LqSpeck(color: LqColors.gold), reduced: true),
      );

      // 평소에는 이 줄이 타임아웃한다. 통과한다는 것 자체가 애니메이션이
      // 멈췄다는 증거다.
      await tester.pumpAndSettle();
      expect(find.byType(LqSpeck), findsOneWidget);
    });

    testWidgets('지연을 준 LqSpeck도 타이머를 걸지 않는다', (tester) async {
      await tester.pumpWidget(
        host(
          const LqSpeck(
            color: LqColors.gold,
            delay: Duration(milliseconds: 400),
          ),
          reduced: true,
        ),
      );

      // 타이머가 남으면 테스트가 !timersPending으로 실패한다.
      await tester.pumpAndSettle();
    });

    testWidgets('LqPulseRing도 동작 줄이기에서 멈춘다', (tester) async {
      await tester.pumpWidget(host(const LqPulseRing(), reduced: true));

      await tester.pumpAndSettle();
      expect(find.byType(LqPulseRing), findsOneWidget);
    });

    testWidgets('평소에는 계속 움직인다', (tester) async {
      await tester.pumpWidget(
        host(const LqSpeck(color: LqColors.gold), reduced: false),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(SchedulerBinding.instance.hasScheduledFrame, isTrue);

      // 무한 애니메이션이 도는 화면은 pumpAndSettle 없이 정리한다.
      await tester.pumpWidget(host(const SizedBox(), reduced: false));
    });
  });

  group('일반 모션', () {
    testWidgets('LqStagger는 동작 줄이기에서 시간차 없이 바로 보인다', (tester) async {
      await tester.pumpWidget(
        host(const LqStagger(index: 5, child: Text('섹션')), reduced: true),
      );
      await tester.pump();

      expect(find.byType(Opacity), findsNothing);
      expect(find.text('섹션'), findsOneWidget);
    });

    testWidgets('프레스 피드백은 즉시 반영된다', (tester) async {
      await tester.pumpWidget(
        host(
          LqPressable(
            onTap: () {},
            builder: (context, t) =>
                SizedBox(width: 100, height: 44, child: Text('$t')),
          ),
          reduced: true,
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LqPressable)),
      );
      // duration이 0이므로 한 프레임 만에 끝까지 간다.
      await tester.pump();
      await tester.pump();
      expect(find.text('1.0'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
