import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/friends/presentation/widgets/friend_widgets.dart';
import 'package:life_quest/shared/design/lq_hero_tags.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_stagger.dart';
import 'package:life_quest/shared/widgets/lq_swap.dart';

/// 연결감(`10-motion-plan.md` P2) — Hero · LqSwap · LqStagger.
void main() {
  group('LqHeroTags', () {
    test('같은 id라도 종류가 다르면 tag가 겹치지 않는다', () {
      expect(LqHeroTags.adventurer(3), isNot(equals(LqHeroTags.adventurer(4))));
      expect(LqHeroTags.adventurer(3), LqHeroTags.adventurer(3));
    });

    testWidgets('한 목록 안에서 아바타 tag가 중복되지 않는다', (tester) async {
      // 같은 tag가 한 화면에 둘이면 Hero는 즉시 크래시한다. 목록을 그리는 것만으로
      // 앱이 죽는 사고라 테스트로 미리 잡는다.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final userId in const [7, 8, 9])
                  LqAvatar(
                    nickname: '모험가$userId',
                    seed: userId,
                    heroTag: LqHeroTags.adventurer(userId),
                  ),
              ],
            ),
          ),
        ),
      );

      final tags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((hero) => hero.tag)
          .toList();
      expect(tags, hasLength(3));
      expect(tags.toSet(), hasLength(3));
    });

    testWidgets('heroTag가 없으면 Hero로 감싸지 않는다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LqAvatar(nickname: '모험가', seed: 1)),
        ),
      );

      expect(find.byType(Hero), findsNothing);
    });
  });

  group('LqSwap', () {
    testWidgets('값이 바뀌면 옛 값과 새 값이 잠시 겹친다', (tester) async {
      Widget build(int level) => MaterialApp(
        home: Scaffold(
          body: LqSwap(value: level, child: Text('Lv. $level')),
        ),
      );

      await tester.pumpWidget(build(3));
      expect(find.text('Lv. 3'), findsOneWidget);

      await tester.pumpWidget(build(4));
      await tester.pump();
      await tester.pump(LqMotion.normal ~/ 2);
      expect(find.text('Lv. 3'), findsOneWidget);
      expect(find.text('Lv. 4'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Lv. 3'), findsNothing);
      expect(find.text('Lv. 4'), findsOneWidget);
    });

    testWidgets('값이 그대로면 교체가 일어나지 않는다', (tester) async {
      Widget build() => const MaterialApp(
        home: Scaffold(body: LqSwap(value: 3, child: Text('Lv. 3'))),
      );

      await tester.pumpWidget(build());
      await tester.pumpWidget(build());
      await tester.pump(LqMotion.normal ~/ 2);

      expect(find.text('Lv. 3'), findsOneWidget);
    });
  });

  group('LqStagger', () {
    test('상한을 넘는 항목은 기다리지 않는다', () {
      expect(LqStagger.delayFor(0), Duration.zero);
      expect(LqStagger.delayFor(1), LqMotion.staggerStep);
      expect(
        LqStagger.delayFor(LqMotion.staggerMaxItems - 1),
        LqMotion.staggerStep * (LqMotion.staggerMaxItems - 1),
      );
      // 아래쪽 항목까지 줄줄이 기다리면 목록이 느린 앱이 된다.
      expect(LqStagger.delayFor(LqMotion.staggerMaxItems), Duration.zero);
      expect(LqStagger.delayFor(30), Duration.zero);
    });

    test('가장 늦은 항목도 400ms 안에 끝난다', () {
      // 화면이 다 차기까지의 총 시간. 이 상한을 올리려면 stagger가 정말 필요한지
      // 부터 다시 봐야 한다 — 기다림은 곧 느린 앱이다.
      final last =
          LqStagger.delayFor(LqMotion.staggerMaxItems - 1) +
          LqStagger.itemDuration;
      expect(last, lessThanOrEqualTo(const Duration(milliseconds: 400)));
    });

    testWidgets('나중 항목일수록 늦게 또렷해지고 결국 모두 보인다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LqStagger(index: 0, child: Text('첫째')),
                LqStagger(index: 3, child: Text('넷째')),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(LqMotion.staggerStep);

      double opacityOf(String text) => tester
          .widget<Opacity>(
            find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
          )
          .opacity;

      expect(opacityOf('첫째'), greaterThan(opacityOf('넷째')));

      await tester.pumpAndSettle();
      expect(opacityOf('첫째'), 1);
      expect(opacityOf('넷째'), 1);
    });

    testWidgets('다시 빌드해도 처음부터 재생하지 않는다', (tester) async {
      Widget build(String label) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const LqStagger(index: 2, child: Text('섹션')),
              Text(label),
            ],
          ),
        ),
      );

      await tester.pumpWidget(build('처음'));
      await tester.pumpAndSettle();

      // 형제 위젯이 바뀌어 다시 빌드되는 상황(당김-새로고침 등).
      await tester.pumpWidget(build('갱신'));
      await tester.pump();

      final opacity = tester
          .widget<Opacity>(
            find.ancestor(of: find.text('섹션'), matching: find.byType(Opacity)),
          )
          .opacity;
      expect(opacity, 1, reason: '스크롤·갱신 때마다 다시 날아오면 안 된다');
    });
  });
}
